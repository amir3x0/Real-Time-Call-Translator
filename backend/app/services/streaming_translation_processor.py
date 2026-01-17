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
"""

import asyncio
import json
import logging
import time
from typing import Dict, Optional, Set
from dataclasses import dataclass, field

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.services.tts_cache import get_tts_cache
from app.config.constants import (
    TRANSLATION_CONTEXT_MAX_CHARS,
    DEFAULT_PARTICIPANT_LANGUAGE,
)

logger = logging.getLogger(__name__)


@dataclass
class StreamContext:
    """
    Maintains translation context per speaker stream.

    Provides bounded context window for coherent translations
    and deduplication to prevent processing the same transcript twice.
    """
    full_context: str = ""
    last_transcript: str = ""
    last_translation: str = ""
    processed_transcripts: Set[str] = field(default_factory=set)
    last_process_time: float = 0.0

    def add_segment(self, transcript: str, translation: str):
        """Add a processed segment to the context."""
        self.full_context += " " + transcript
        # Keep context bounded
        if len(self.full_context) > TRANSLATION_CONTEXT_MAX_CHARS * 2:
            self.full_context = self.full_context[-TRANSLATION_CONTEXT_MAX_CHARS:]
        self.last_transcript = transcript
        self.last_translation = translation
        self.last_process_time = time.time()

    def get_context(self) -> str:
        """Get bounded context for translation."""
        return self.full_context[-TRANSLATION_CONTEXT_MAX_CHARS:].strip()

    def is_duplicate(self, transcript: str) -> bool:
        """
        Check if transcript was already processed (deduplication).

        This prevents double processing when both streaming STT and
        the batch fallback might process the same audio.
        """
        normalized = transcript.strip().lower()
        if normalized in self.processed_transcripts:
            return True
        self.processed_transcripts.add(normalized)
        # Keep set bounded to prevent memory growth
        if len(self.processed_transcripts) > 50:
            # Remove oldest (arbitrary, but set is small)
            self.processed_transcripts.pop()
        return False

    def clear_dedup(self):
        """Clear deduplication tracking (e.g., on long silence)."""
        self.processed_transcripts.clear()


class StreamingTranslationProcessor:
    """
    Processes final transcripts from streaming STT for low-latency translation.

    This is the core of the sub-2-second latency optimization. Instead of waiting
    for pause-based chunking and batch STT, this processor receives final transcripts
    directly from the streaming STT service and immediately triggers translation + TTS.

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
        self._lock = asyncio.Lock()
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

        # Get or create context
        async with self._lock:
            if stream_key not in self._contexts:
                self._contexts[stream_key] = StreamContext()
            context = self._contexts[stream_key]

        # Deduplication check
        if context.is_duplicate(transcript):
            logger.debug(f"Skipping duplicate transcript for {stream_key}: '{transcript[:30]}...'")
            return

        # Get target languages from database (multiparty support)
        target_langs_map = await self._get_target_languages(session_id, speaker_id)

        if not target_langs_map:
            logger.info(f"No recipients for {speaker_id} in session {session_id}, skipping translation")
            return

        # Get context for translation
        context_text = context.get_context()
        loop = asyncio.get_running_loop()

        async def process_language(tgt_lang: str, recipients: list):
            """Translate and synthesize for one target language."""
            try:
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

        Queries all connected participants in the call (except the speaker)
        and groups them by language.

        Returns:
            Dict mapping language code to list of user IDs
            e.g., {"en-US": ["user2", "user3"], "he-IL": ["user4"]}
        """
        from app.models.database import AsyncSessionLocal
        from app.models.call_participant import CallParticipant
        from app.models.call import Call
        from sqlalchemy import select, and_

        target_langs_map: Dict[str, list] = {}

        try:
            async with AsyncSessionLocal() as db:
                # Get call by session_id
                call_result = await db.execute(
                    select(Call).where(Call.session_id == session_id)
                )
                call = call_result.scalar_one_or_none()

                if not call:
                    logger.warning(f"No call found for session {session_id}")
                    return {}

                # Get other connected participants
                participants_result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == call.id,
                            CallParticipant.user_id != speaker_id,
                            CallParticipant.is_connected == True
                        )
                    )
                )
                participants = participants_result.scalars().all()

                for p in participants:
                    lang = p.participant_language or DEFAULT_PARTICIPANT_LANGUAGE
                    if lang not in target_langs_map:
                        target_langs_map[lang] = []
                    target_langs_map[lang].append(p.user_id)

                logger.debug(f"Target languages for {speaker_id}: {target_langs_map}")

        except Exception as e:
            logger.error(f"Error getting target languages: {e}")
            import traceback
            traceback.print_exc()

        return target_langs_map

    def cleanup_stream(self, session_id: str, speaker_id: str):
        """Clean up context for a stream when it ends."""
        stream_key = self.get_stream_key(session_id, speaker_id)
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
