"""
Streaming Translation Processor - Low-Latency Translation Pipeline

This module processes final transcripts from streaming STT immediately,
bypassing the slow batch STT path to achieve sub-2-second latency.

Architecture:
    Streaming STT (is_final=True) -> StreamingTranslationProcessor -> Translation -> TTS -> Redis Pub/Sub

Key Features:
- Receives callbacks from InterimCaptionService when streaming STT produces final results
- Maintains per-stream context for coherent translations
- Queries database for target languages (multiparty support)
- Runs translation + TTS in parallel per target language
- Includes deduplication to prevent double processing

Usage:
    from app.services.translation.streaming import get_streaming_processor

    processor = get_streaming_processor()
    await processor.process_final_transcript(session_id, speaker_id, transcript, source_lang)
"""

import asyncio
import json
import logging
import time
import threading
from collections import OrderedDict
from typing import Dict, Optional
from dataclasses import dataclass, field

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.services.translation.tts_cache import get_tts_cache
from app.services.core.repositories import call_repository
from app.config.constants import (
    TRANSLATION_CONTEXT_MAX_CHARS,
    DEFAULT_PARTICIPANT_LANGUAGE,
)

logger = logging.getLogger(__name__)

# Deduplication window in seconds
DEDUP_WINDOW_SEC = 30.0


@dataclass
class StreamContext:
    """
    Maintains translation context per speaker stream.

    Provides bounded context window for coherent translations,
    deduplication to prevent processing the same transcript twice,
    and translation memory for term consistency.

    Thread-safe: Uses internal lock for all mutable operations.
    """
    full_context: str = ""
    last_transcript: str = ""
    last_translation: str = ""
    last_process_time: float = 0.0

    # Deduplication: OrderedDict maintains insertion order for proper FIFO eviction
    # Key: normalized text, Value: timestamp when processed
    _processed_transcripts: OrderedDict = field(default_factory=OrderedDict)

    # Translation memory for consistent term translation
    # Key: "normalized_source|lang_code", Value: translation
    _translation_memory: Dict[str, str] = field(default_factory=dict)
    MEMORY_MAX_SIZE: int = 50  # Max entries to prevent memory growth

    # Lock for thread-safety
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def add_segment(self, transcript: str, translation: str):
        """Add a processed segment to the context."""
        with self._lock:
            self.full_context += " " + transcript
            # Keep context bounded
            if len(self.full_context) > TRANSLATION_CONTEXT_MAX_CHARS * 2:
                self.full_context = self.full_context[-TRANSLATION_CONTEXT_MAX_CHARS:]
            self.last_transcript = transcript
            self.last_translation = translation
            self.last_process_time = time.time()

    def get_context(self) -> str:
        """Get bounded context for translation."""
        with self._lock:
            return self.full_context[-TRANSLATION_CONTEXT_MAX_CHARS:].strip()

    def is_duplicate(self, transcript: str) -> bool:
        """
        Check if transcript was already processed (deduplication).

        Uses timestamp-based window instead of size-based limit to ensure
        proper FIFO behavior. Transcripts older than DEDUP_WINDOW_SEC are
        automatically removed.

        This prevents double processing when both streaming STT and
        the batch fallback might process the same audio.
        """
        normalized = transcript.strip().lower()
        now = time.time()

        with self._lock:
            # Clean expired entries (older than window)
            cutoff = now - DEDUP_WINDOW_SEC
            keys_to_remove = [
                key for key, timestamp in self._processed_transcripts.items()
                if timestamp < cutoff
            ]
            for key in keys_to_remove:
                del self._processed_transcripts[key]

            # Check if duplicate
            if normalized in self._processed_transcripts:
                return True

            # Add with current timestamp
            self._processed_transcripts[normalized] = now
            return False

    def clear_dedup(self):
        """Clear deduplication tracking (e.g., on long silence)."""
        with self._lock:
            self._processed_transcripts.clear()

    def remember_translation(self, source: str, target_lang: str, translation: str):
        """
        Store translation for consistency.

        Next time the same source text is spoken for the same target language,
        we return the same translation to avoid inconsistency
        (e.g., "שלום" to English always → "Hello", not sometimes "Hi").

        Args:
            source: Source text (will be normalized)
            target_lang: Target language code (e.g., "en-US")
            translation: The translation to store
        """
        # Key includes target language for language-pair specificity
        key = f"{source.strip().lower()}|{target_lang[:2]}"

        with self._lock:
            self._translation_memory[key] = translation

            # LRU-style eviction: remove oldest if over limit
            if len(self._translation_memory) > self.MEMORY_MAX_SIZE:
                oldest_key = next(iter(self._translation_memory))
                del self._translation_memory[oldest_key]

    def recall_translation(self, source: str, target_lang: str) -> Optional[str]:
        """
        Get previous translation if exists.

        Returns None if not found, meaning we need to translate fresh.

        Args:
            source: Source text to look up
            target_lang: Target language code (e.g., "en-US")
        """
        key = f"{source.strip().lower()}|{target_lang[:2]}"
        with self._lock:
            return self._translation_memory.get(key)


class StreamingTranslationProcessor:
    """
    Processes final transcripts from streaming STT for low-latency translation.

    This is the core of the sub-2-second latency optimization. Instead of waiting
    for pause-based chunking and batch STT, this processor receives final transcripts
    directly from the streaming STT service and immediately triggers translation + TTS.

    Thread-safe: Uses per-stream context locking for concurrent speaker support.

    Usage:
        processor = get_streaming_processor()

        # Register as callback with InterimCaptionService
        await push_audio_for_interim(
            session_id, speaker_id, source_lang, audio_data,
            on_final_transcript=processor.process_final_transcript
        )
    """

    def __init__(self):
        self._contexts: Dict[str, StreamContext] = {}
        self._pipeline = None
        self._redis = None
        self._contexts_lock = asyncio.Lock()  # Protects _contexts dict access
        self._processing_count = 0  # For metrics
        self._total_latency_ms = 0.0

    async def initialize(self):
        """Initialize GCP pipeline and Redis connection."""
        if self._pipeline is None:
            self._pipeline = _get_pipeline()
        if self._redis is None:
            self._redis = await get_redis()

    def get_stream_key(self, session_id: str, speaker_id: str) -> str:
        """Generate unique key for a speaker's stream."""
        return f"{session_id}:{speaker_id}"

    async def process_final_transcript(
        self,
        session_id: str,
        speaker_id: str,
        transcript: str,
        source_lang: str
    ):
        """
        Process a final transcript from streaming STT.

        This is the callback invoked by InterimCaptionService when streaming STT
        produces a final result (is_final=True). It immediately triggers translation
        and TTS, then publishes results to Redis Pub/Sub.

        Args:
            session_id: The call session ID
            speaker_id: The user ID of the speaker
            transcript: The final transcript from streaming STT
            source_lang: Language code (e.g., "he-IL")
        """
        await self.initialize()

        stream_key = self.get_stream_key(session_id, speaker_id)
        start_time = time.time()

        # Validate transcript
        if not transcript or len(transcript.strip()) < 2:
            logger.debug(f"Skipping empty/short transcript for {stream_key}")
            return

        transcript = transcript.strip()
        logger.info(f"🚀 [StreamingTranslation] Processing: '{transcript[:50]}...' for {stream_key}")

        # Get or create context (lock protects dict access)
        async with self._contexts_lock:
            if stream_key not in self._contexts:
                self._contexts[stream_key] = StreamContext()
            context = self._contexts[stream_key]

        # Deduplication check (StreamContext has internal lock)
        if context.is_duplicate(transcript):
            logger.debug(f"Skipping duplicate transcript for {stream_key}: '{transcript[:30]}...'")
            return

        # Get target languages from database (multiparty support)
        target_langs_map = await self._get_target_languages(session_id, speaker_id)

        if not target_langs_map:
            logger.info(f"No recipients for {speaker_id} in session {session_id}, skipping translation")
            return

        # Get context for translation (StreamContext has internal lock)
        context_text = context.get_context()
        loop = asyncio.get_running_loop()

        async def process_language(tgt_lang: str, recipients: list):
            """Translate and synthesize for one target language."""
            try:
                # Check translation memory first for consistency
                # (StreamContext has internal lock)
                cached_translation = context.recall_translation(transcript, tgt_lang)

                if cached_translation:
                    translation = cached_translation
                    logger.info(f"📚 [{tgt_lang}] Memory hit: '{transcript[:30]}...' -> '{translation[:30]}...'")
                else:
                    # Translate with context
                    def do_translate():
                        return self._pipeline._translate_text_with_context(
                            transcript,
                            context_text,
                            source_language_code=source_lang[:2],
                            target_language_code=tgt_lang[:2]
                        )

                    translation = await loop.run_in_executor(None, do_translate)
                    logger.info(f"🔄 [{tgt_lang}] '{transcript[:30]}...' -> '{translation[:30]}...'")

                    # Store in memory for future consistency
                    # (StreamContext has internal lock)
                    context.remember_translation(transcript, tgt_lang, translation)

                # TTS with caching
                cache = get_tts_cache()
                audio_content = cache.get(translation, tgt_lang)

                if not audio_content:
                    def do_synthesize():
                        return self._pipeline._synthesize(
                            translation,
                            language_code=tgt_lang,
                            voice_name=None
                        )
                    audio_content = await loop.run_in_executor(None, do_synthesize)
                    if audio_content:
                        cache.put(translation, tgt_lang, audio_content)
                    logger.debug(f"TTS synthesized {len(audio_content) if audio_content else 0} bytes for {tgt_lang}")
                else:
                    logger.debug(f"TTS cache hit for {tgt_lang}")

                return {
                    "target_lang": tgt_lang,
                    "recipient_ids": recipients,
                    "translation": translation,
                    "audio_content": audio_content
                }
            except Exception as e:
                logger.error(f"Error processing {tgt_lang}: {e}")
                import traceback
                traceback.print_exc()
                return None

        # Execute all translations in parallel
        tasks = [
            process_language(lang, recipients)
            for lang, recipients in target_langs_map.items()
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Publish results to Redis Pub/Sub
        successful_results = []
        for result in results:
            if isinstance(result, Exception):
                logger.error(f"Translation task failed: {result}")
                continue
            if result is None:
                continue

            payload = {
                "type": "translation",
                "session_id": session_id,
                "speaker_id": speaker_id,
                "recipient_ids": result["recipient_ids"],
                "transcript": transcript,
                "translation": result["translation"],
                "audio_content": result["audio_content"].hex() if result["audio_content"] else None,
                "source_lang": source_lang,
                "target_lang": result["target_lang"],
                "is_final": True,
                "is_streaming": True,  # Flag indicating this came from streaming path
                "has_context": bool(context_text)
            }

            try:
                channel = f"channel:translation:{session_id}"
                await self._redis.publish(channel, json.dumps(payload))
                logger.info(f"✅ Published streaming translation to {result['target_lang']} for {len(result['recipient_ids'])} recipients")
                successful_results.append(result)
            except Exception as e:
                logger.error(f"Failed to publish translation: {e}")

        # Update context with first successful translation
        # (StreamContext has internal lock)
        if successful_results:
            context.add_segment(transcript, successful_results[0]["translation"])

        # Track metrics
        latency_ms = (time.time() - start_time) * 1000
        self._processing_count += 1
        self._total_latency_ms += latency_ms

        avg_latency = self._total_latency_ms / self._processing_count if self._processing_count > 0 else 0
        logger.info(f"⏱️ Streaming translation latency: {latency_ms:.0f}ms (avg: {avg_latency:.0f}ms)")

    async def _get_target_languages(self, session_id: str, speaker_id: str) -> Dict[str, list]:
        """
        Get target languages for translation from database.

        OOP Refactor: Delegates to CallRepository to eliminate code duplication.

        Returns:
            Dict mapping language code to list of user IDs
            e.g., {"en-US": ["user2", "user3"], "he-IL": ["user4"]}
        """
        # include_speaker=True ensures speaker sees their own messages in chat history
        return await call_repository.get_target_languages(session_id, speaker_id, include_speaker=True)

    def cleanup_stream(self, session_id: str, speaker_id: str):
        """Clean up context for a stream when it ends."""
        stream_key = self.get_stream_key(session_id, speaker_id)
        # Note: Using asyncio.Lock in sync context would deadlock
        # We accept this small race since cleanup is not critical
        if stream_key in self._contexts:
            del self._contexts[stream_key]
            logger.info(f"Cleaned up streaming context for {stream_key}")

    def get_stats(self) -> dict:
        """Get processor statistics for monitoring."""
        avg_latency = self._total_latency_ms / self._processing_count if self._processing_count > 0 else 0
        return {
            "processing_count": self._processing_count,
            "average_latency_ms": round(avg_latency, 2),
            "active_contexts": len(self._contexts),
        }


# Global singleton instance
_streaming_processor: Optional[StreamingTranslationProcessor] = None


def get_streaming_processor() -> StreamingTranslationProcessor:
    """Get or create the global StreamingTranslationProcessor instance."""
    global _streaming_processor
    if _streaming_processor is None:
        _streaming_processor = StreamingTranslationProcessor()
    return _streaming_processor
