"""
Translation Processor - Consolidated translation and TTS processing.

This module handles translation and TTS for multiple target languages,
consolidating the shared pattern used by both:
- Batch pipeline (audio_worker.py)
- Streaming pipeline (streaming_translation_processor.py)

Usage:
    from app.services.translation.processor import TranslationProcessor, TranslationResult

    processor = TranslationProcessor(pipeline)
    results = await processor.process_for_languages(
        text="Hello",
        source_lang="en-US",
        target_langs_map={"he-IL": ["user1"], "ru-RU": ["user2"]},
        context="Previous conversation..."
    )

    for result in results:
        print(f"{result.target_lang}: {result.translation}")
"""

import asyncio
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

from app.services.protocols import SpeechPipelineProtocol
from app.services.translation.tts_cache import get_tts_cache

logger = logging.getLogger(__name__)


@dataclass
class TranslationResult:
    """
    Result of a translation+TTS operation for one target language.

    Attributes:
        target_lang: Target language code (e.g., "he-IL")
        recipient_ids: List of user IDs who should receive this translation
        translation: The translated text
        audio_content: Synthesized audio bytes (may be None if TTS failed)
    """
    target_lang: str
    recipient_ids: List[str]
    translation: str
    audio_content: Optional[bytes]


class TranslationProcessor:
    """
    Handles translation and TTS for multiple target languages.

    Consolidates the shared translation+TTS pattern used by both
    the batch pipeline (audio_worker) and streaming pipeline.

    Features:
    - Parallel processing of multiple target languages
    - TTS caching to reduce API calls
    - Translation memory support for consistency
    - Error handling per-language (one failure doesn't affect others)
    """

    def __init__(self, pipeline: SpeechPipelineProtocol):
        """
        Initialize the translation processor.

        Args:
            pipeline: Speech pipeline implementing SpeechPipelineProtocol
        """
        self._pipeline = pipeline
        self._tts_cache = get_tts_cache()

    async def process_for_languages(
        self,
        text: str,
        source_lang: str,
        target_langs_map: Dict[str, List[str]],
        context: str = "",
        translation_memory: Optional[Dict[str, str]] = None
    ) -> List[TranslationResult]:
        """
        Translate and synthesize for multiple target languages in parallel.

        Args:
            text: Text to translate
            source_lang: Source language code (e.g., "he-IL")
            target_langs_map: Dict of target_lang -> list of recipient IDs
                             Example: {"en-US": ["user2"], "ru-RU": ["user3"]}
            context: Optional context for translation coherence
            translation_memory: Optional dict for caching translations
                               Key format: "{text.lower()}|{lang[:2]}"

        Returns:
            List of TranslationResult objects for successful translations
        """
        if not target_langs_map:
            return []

        loop = asyncio.get_running_loop()

        async def process_language(
            tgt_lang: str,
            recipients: List[str]
        ) -> Optional[TranslationResult]:
            """Process a single target language."""
            try:
                # Check translation memory first for consistency
                memory_key = f"{text.strip().lower()}|{tgt_lang[:2]}"

                if translation_memory and memory_key in translation_memory:
                    translation = translation_memory[memory_key]
                    logger.debug(f"[TranslationProcessor] Memory hit for {tgt_lang}")
                else:
                    # Translate in thread pool (blocking GCP call)
                    def do_translate():
                        return self._pipeline.translate(
                            text,
                            source_lang[:2],
                            tgt_lang[:2],
                            context
                        )

                    translation = await loop.run_in_executor(None, do_translate)

                    # Store in memory for future consistency
                    if translation_memory is not None:
                        translation_memory[memory_key] = translation

                    logger.debug(
                        f"[TranslationProcessor] Translated to {tgt_lang}: "
                        f"'{text[:30]}...' -> '{translation[:30]}...'"
                    )

                # TTS with caching
                audio_content = self._tts_cache.get(translation, tgt_lang)

                if audio_content:
                    logger.debug(f"[TranslationProcessor] TTS cache hit for {tgt_lang}")
                else:
                    # Synthesize in thread pool (blocking GCP call)
                    def do_synthesize():
                        return self._pipeline.synthesize(translation, tgt_lang)

                    audio_content = await loop.run_in_executor(None, do_synthesize)

                    if audio_content:
                        self._tts_cache.put(translation, tgt_lang, audio_content)
                        logger.debug(
                            f"[TranslationProcessor] TTS synthesized "
                            f"{len(audio_content)} bytes for {tgt_lang}"
                        )

                return TranslationResult(
                    target_lang=tgt_lang,
                    recipient_ids=recipients,
                    translation=translation,
                    audio_content=audio_content
                )

            except Exception as e:
                logger.exception(f"[TranslationProcessor] Error processing {tgt_lang}")
                return None

        # Execute all languages in parallel
        tasks = [
            process_language(lang, recipients)
            for lang, recipients in target_langs_map.items()
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Filter successful results
        successful = []
        for result in results:
            if isinstance(result, Exception):
                logger.error(f"[TranslationProcessor] Task exception: {result}")
            elif result is not None:
                successful.append(result)

        logger.info(
            f"[TranslationProcessor] Processed {len(successful)}/{len(target_langs_map)} "
            f"languages successfully"
        )

        return successful

    async def translate_single(
        self,
        text: str,
        source_lang: str,
        target_lang: str,
        context: str = ""
    ) -> Optional[TranslationResult]:
        """
        Translate and synthesize for a single target language.

        Convenience method for when you only need one translation.

        Args:
            text: Text to translate
            source_lang: Source language code
            target_lang: Target language code
            context: Optional context for translation

        Returns:
            TranslationResult or None if failed
        """
        results = await self.process_for_languages(
            text=text,
            source_lang=source_lang,
            target_langs_map={target_lang: []},
            context=context
        )
        return results[0] if results else None
