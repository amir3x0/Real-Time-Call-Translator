"""
Interim Caption Service - Real-time streaming STT for live captions.

This service provides WhatsApp-style real-time transcription that appears
as the user speaks, without waiting for translation or TTS processing.

Architecture:
- Runs in parallel with the main translation pipeline
- Uses Google Streaming STT with interim_results=True
- Publishes interim_transcript messages immediately via Redis Pub/Sub
- Deduplicates repeated interim results to avoid flickering

Flow:
    Audio Chunks → InterimCaptionService → Streaming STT → Redis Pub/Sub → Mobile UI
                                                                ↓
                                         "[You] Hello how ar|" (blinking cursor)
"""

import asyncio
import json
import logging
import time
import threading
from typing import Dict, Optional, Set, Callable, Awaitable
from dataclasses import dataclass, field
from queue import Queue, Empty

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.config.constants import (
    INTERIM_PUBLISH_INTERVAL_MS,
    STREAMING_STT_TIMEOUT_SEC,
    INTERIM_MIN_CHARS_TO_PUBLISH,
    INTERIM_MAX_TEXT_LENGTH,
    INTERIM_DEDUP_WINDOW_SEC,
    AUDIO_SAMPLE_RATE,
)

logger = logging.getLogger(__name__)


# Type alias for the final transcript callback
# Signature: (session_id, speaker_id, transcript, source_lang) -> Awaitable[None]
FinalTranscriptCallback = Callable[[str, str, str, str], Awaitable[None]]


@dataclass
class InterimSession:
    """Tracks state for a single speaker's interim caption stream."""
    session_id: str
    speaker_id: str
    source_lang: str
    audio_queue: Queue = field(default_factory=Queue)
    last_interim_text: str = ""
    last_publish_time: float = 0.0
    is_active: bool = True
    task: Optional[asyncio.Task] = None
    published_texts: Set[str] = field(default_factory=set)  # For dedup within window
    on_final_transcript: Optional[FinalTranscriptCallback] = None  # Callback for streaming translation


class InterimCaptionService:
    """
    Manages real-time interim captions for all active speakers.

    Each speaker gets their own streaming STT session that runs in parallel
    with the main translation pipeline.
    """

    def __init__(self):
        self._sessions: Dict[str, InterimSession] = {}
        self._lock = threading.Lock()
        self._pipeline = None
        self._redis = None

    async def initialize(self):
        """Initialize GCP pipeline and Redis connection."""
        if self._pipeline is None:
            self._pipeline = _get_pipeline()
        if self._redis is None:
            self._redis = await get_redis()
        logger.info("InterimCaptionService initialized")

    def get_stream_key(self, session_id: str, speaker_id: str) -> str:
        """Generate unique key for a speaker's stream."""
        return f"{session_id}:{speaker_id}"

    async def start_session(
        self,
        session_id: str,
        speaker_id: str,
        source_lang: str,
        on_final_transcript: Optional[FinalTranscriptCallback] = None
    ) -> bool:
        """
        Start an interim caption session for a speaker.

        Args:
            session_id: The call session ID
            speaker_id: The user ID of the speaker
            source_lang: Language code (e.g., "he-IL")
            on_final_transcript: Optional callback invoked when streaming STT
                                 produces a final result. Used for low-latency
                                 translation pipeline.

        Returns True if a new session was created, False if already exists.
        """
        stream_key = self.get_stream_key(session_id, speaker_id)

        with self._lock:
            existing_session = self._sessions.get(stream_key)

            if existing_session and existing_session.is_active:
                # Check if the streaming task is actually still alive
                # This handles the case where the task died (e.g., STT timeout after mute)
                # but the session was never cleaned up
                if existing_session.task and existing_session.task.done():
                    logger.warning(f"⚠️ Found dead session for {stream_key} - task finished, restarting...")
                    # Clean up the dead session
                    del self._sessions[stream_key]
                else:
                    # Session exists and task is alive - just update callback
                    if on_final_transcript is not None:
                        existing_session.on_final_transcript = on_final_transcript
                    logger.debug(f"Interim session already active for {stream_key}")
                    return False

            # Create new session
            session = InterimSession(
                session_id=session_id,
                speaker_id=speaker_id,
                source_lang=source_lang,
                on_final_transcript=on_final_transcript
            )
            self._sessions[stream_key] = session

            # Create the streaming task INSIDE the lock to prevent race conditions
            # where another coroutine accesses session.task before it's set.
            # asyncio.create_task() is synchronous (just schedules, doesn't await),
            # so it's safe to call inside a threading.Lock.
            task = asyncio.create_task(self._run_streaming_session(session))
            session.task = task

        logger.info(f"🎤 Started interim caption session for {stream_key} (lang: {source_lang})")
        return True

    async def push_audio(self, session_id: str, speaker_id: str, audio_data: bytes):
        """
        Push audio data to a speaker's interim caption stream.

        This is called for every audio chunk, in parallel with the main pipeline.
        """
        stream_key = self.get_stream_key(session_id, speaker_id)

        with self._lock:
            session = self._sessions.get(stream_key)
            if session is None or not session.is_active:
                return

        # Push to queue (non-blocking)
        try:
            session.audio_queue.put_nowait(audio_data)
        except Exception as e:
            logger.warning(f"Failed to queue audio for {stream_key}: {e}")

    async def stop_session(self, session_id: str, speaker_id: str):
        """Stop an interim caption session."""
        stream_key = self.get_stream_key(session_id, speaker_id)

        with self._lock:
            session = self._sessions.get(stream_key)
            if session is None:
                return

            session.is_active = False
            # Signal the streaming task to stop
            session.audio_queue.put(None)

        # Cancel the task if still running
        if session.task and not session.task.done():
            session.task.cancel()
            try:
                await asyncio.wait_for(session.task, timeout=1.0)
            except (asyncio.TimeoutError, asyncio.CancelledError):
                pass

        with self._lock:
            if stream_key in self._sessions:
                del self._sessions[stream_key]

        logger.info(f"🛑 Stopped interim caption session for {stream_key}")

    async def _run_streaming_session(self, session: InterimSession):
        """
        Main loop for a streaming STT session.

        Reads audio from queue, feeds to streaming STT, publishes interim results.
        """
        stream_key = self.get_stream_key(session.session_id, session.speaker_id)
        logger.info(f"🎙️ Streaming STT task started for {stream_key}")

        await self.initialize()
        loop = asyncio.get_running_loop()

        def audio_generator():
            """Generator that yields audio chunks from the queue."""
            while session.is_active:
                try:
                    chunk = session.audio_queue.get(timeout=0.1)
                    if chunk is None:
                        logger.debug(f"Audio generator received stop signal for {stream_key}")
                        return
                    yield chunk
                except Empty:
                    # No audio available, continue waiting
                    continue
                except Exception as e:
                    logger.error(f"Error in audio generator for {stream_key}: {e}")
                    return

        try:
            # Run streaming transcription in executor (blocking API)
            async def run_streaming():
                min_interval_sec = INTERIM_PUBLISH_INTERVAL_MS / 1000.0

                def stream_transcribe():
                    """Blocking streaming transcription."""
                    for transcript, is_final in self._pipeline.streaming_transcribe(
                        audio_generator(),
                        language_code=session.source_lang
                    ):
                        if not session.is_active:
                            break

                        # Yield results for async processing
                        yield transcript, is_final

                # Process streaming results
                for transcript, is_final in stream_transcribe():
                    if not session.is_active:
                        break

                    await self._process_interim_result(
                        session,
                        transcript,
                        is_final,
                        min_interval_sec
                    )

            # Run in thread pool to avoid blocking
            await loop.run_in_executor(None, lambda: asyncio.run(run_streaming()))

        except asyncio.CancelledError:
            logger.info(f"Streaming task cancelled for {stream_key}")
            raise
        except Exception as e:
            logger.error(f"Error in streaming session for {stream_key}: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # Mark session as inactive so it can be restarted if needed
            # This handles the case where the task ends due to timeout (e.g., after mute)
            session.is_active = False
            logger.info(f"Streaming STT task ended for {stream_key} - marked inactive")

    async def _process_interim_result(
        self,
        session: InterimSession,
        transcript: str,
        is_final: bool,
        min_interval_sec: float
    ):
        """
        Process and publish an interim transcription result.

        Applies deduplication, rate limiting, and minimum length filtering.
        """
        if not transcript or len(transcript.strip()) < INTERIM_MIN_CHARS_TO_PUBLISH:
            return

        transcript = transcript.strip()

        # Truncate if too long
        if len(transcript) > INTERIM_MAX_TEXT_LENGTH:
            transcript = transcript[:INTERIM_MAX_TEXT_LENGTH] + "..."

        # Deduplicate within window
        now = time.time()

        # Clean up old published texts
        session.published_texts = {
            t for t in session.published_texts
            if now - session.last_publish_time < INTERIM_DEDUP_WINDOW_SEC
        }

        # Skip if we just published this exact text (dedup)
        if transcript == session.last_interim_text and not is_final:
            return

        # Rate limit (unless it's a final result)
        if not is_final and (now - session.last_publish_time) < min_interval_sec:
            return

        # Publish the interim caption
        await self._publish_interim_caption(session, transcript, is_final)

        session.last_interim_text = transcript
        session.last_publish_time = now

        if is_final:
            # Send clear signal to mobile BEFORE final translation
            # This allows UI to clean up old interim text
            await self._publish_interim_clear(session)

            # Invoke callback for streaming translation pipeline
            if session.on_final_transcript is not None:
                try:
                    logger.info(f"🚀 Triggering streaming translation for '{transcript[:50]}...'")
                    await session.on_final_transcript(
                        session.session_id,
                        session.speaker_id,
                        transcript,
                        session.source_lang
                    )
                except Exception as e:
                    logger.error(f"Error in final transcript callback: {e}")
                    import traceback
                    traceback.print_exc()

            # Clear tracking on final result
            session.published_texts.clear()
            session.last_interim_text = ""

    async def _publish_interim_caption(
        self,
        session: InterimSession,
        transcript: str,
        is_final: bool
    ):
        """Publish interim caption to Redis Pub/Sub."""
        try:
            payload = {
                "type": "interim_transcript",
                "session_id": session.session_id,
                "speaker_id": session.speaker_id,
                "text": transcript,
                "source_lang": session.source_lang,
                "is_final": is_final,
                "confidence": 0.85 if is_final else 0.70,  # Estimated confidence
                "timestamp": time.time()
            }

            channel = f"channel:translation:{session.session_id}"
            await self._redis.publish(channel, json.dumps(payload))

            log_icon = "✅" if is_final else "📝"
            logger.debug(f"{log_icon} Interim caption [{session.speaker_id}]: '{transcript[:50]}...' (final={is_final})")

        except Exception as e:
            logger.error(f"Failed to publish interim caption: {e}")

    async def _publish_interim_clear(self, session: InterimSession):
        """
        Signal mobile to clear interim display for this speaker.

        Sent before final translation so UI can clean up old interim text
        and prepare for the translated result.
        """
        try:
            payload = {
                "type": "interim_clear",
                "session_id": session.session_id,
                "speaker_id": session.speaker_id,
                "timestamp": time.time()
            }

            channel = f"channel:translation:{session.session_id}"
            await self._redis.publish(channel, json.dumps(payload))
            logger.debug(f"🧹 Interim clear signal sent for [{session.speaker_id}]")

        except Exception as e:
            logger.error(f"Failed to publish interim clear: {e}")

    async def shutdown(self):
        """Shutdown all active sessions."""
        logger.info("Shutting down InterimCaptionService...")

        with self._lock:
            sessions = list(self._sessions.values())

        for session in sessions:
            await self.stop_session(session.session_id, session.speaker_id)

        logger.info("InterimCaptionService shutdown complete")


# Global singleton instance
_interim_caption_service: Optional[InterimCaptionService] = None


def get_interim_caption_service() -> InterimCaptionService:
    """Get or create the global InterimCaptionService instance."""
    global _interim_caption_service
    if _interim_caption_service is None:
        _interim_caption_service = InterimCaptionService()
    return _interim_caption_service


async def push_audio_for_interim(
    session_id: str,
    speaker_id: str,
    source_lang: str,
    audio_data: bytes,
    on_final_transcript: Optional[FinalTranscriptCallback] = None
):
    """
    Convenience function to push audio for interim captioning.

    Automatically starts a session if one doesn't exist.
    Called from audio_worker.py in parallel with the main pipeline.

    Args:
        session_id: The call session ID
        speaker_id: The user ID of the speaker
        source_lang: Language code (e.g., "he-IL")
        audio_data: Raw PCM16 audio bytes
        on_final_transcript: Optional callback for streaming translation.
                             Invoked when streaming STT produces final result.
    """
    service = get_interim_caption_service()

    # Ensure session is started (with callback if provided)
    await service.start_session(session_id, speaker_id, source_lang, on_final_transcript)

    # Push audio
    await service.push_audio(session_id, speaker_id, audio_data)


async def stop_interim_session(session_id: str, speaker_id: str):
    """Convenience function to stop an interim session."""
    service = get_interim_caption_service()
    await service.stop_session(session_id, speaker_id)
