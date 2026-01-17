"""
Audio Worker - Main audio processing pipeline.

This module handles the Redis stream consumption and orchestrates
the audio processing pipeline for real-time translation.

Usage:
    from app.services.audio.worker import run_worker

    asyncio.run(run_worker())
"""

import asyncio
import json
import logging
import os
import time
from typing import Dict, List, Optional, Tuple
import queue
from dataclasses import dataclass, field

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline, get_gcp_executor
from app.services.interim_caption_service import (
    push_audio_for_interim,
    stop_interim_session,
    get_interim_caption_service,
)
from app.services.translation.streaming import get_streaming_processor
from app.config.settings import settings
from app.config.constants import (
    AUDIO_SAMPLE_RATE, AUDIO_BYTES_PER_SAMPLE,
    SILENCE_THRESHOLD_SEC, RMS_SILENCE_THRESHOLD, MIN_AUDIO_LENGTH_SEC,
    SEGMENT_MERGE_TIME_WINDOW_SEC, MIN_WORDS_TO_KEEP_SEPARATE,
    TRANSLATION_CONTEXT_MAX_CHARS, MAX_BUFFER_SEGMENTS,
    AUDIO_QUEUE_READ_TIMEOUT_SEC, MAX_ACCUMULATED_AUDIO_TIME_SEC,
    REDIS_STREAM_BLOCK_MS, REDIS_STREAM_MESSAGE_COUNT,
    ERROR_RECOVERY_SLEEP_SEC, GRACEFUL_SHUTDOWN_TIMEOUT_SEC,
    DEFAULT_PARTICIPANT_LANGUAGE, METRICS_SERVER_PORT,
)
# OOP Refactor: Use extracted components (now in audio submodule)
from app.services.audio.speech_detector import speech_detector
from app.services.audio.stream_manager import stream_manager
from app.services.audio.chunker import AudioChunker, ChunkResult, run_chunker_loop
# Core infrastructure components
from app.services.core.deduplicator import message_deduplicator
from app.services.core.repositories import call_repository
from app.services.translation.processor import TranslationProcessor
from app.services.metrics import (
    audio_processing_latency,
    segments_processed,
    active_streams_gauge,
    silence_triggers,
    start_metrics_server
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global shutdown flag for graceful termination
_shutdown_flag = False

# NOTE: The following have been moved to extracted services:
# - active_streams, active_tasks -> stream_manager (app/services/audio/stream_manager.py)
# - _spectral_history -> speech_detector (app/services/audio/speech_detector.py)
# - _processed_message_ids -> message_deduplicator (app/services/deduplicator.py)
# - process_audio_chunks logic -> AudioChunker (app/services/audio/chunker.py)
# - translation+TTS logic -> TranslationProcessor (app/services/translation_processor.py)

# === OPTION C: Hybrid Context Preservation (Pause-based + Smart Merging) ===

@dataclass
class SegmentBuffer:
    """
    Option C: Hybrid approach combining pause-based segmentation with
    context-aware merging for better translation quality.

    Features:
    - Tracks recent segments with (transcript, translation, timestamp)
    - should_merge_recent(): Checks if last 2 segments should be merged
    - finalize_for_publish(): Batch merges before sending
    - full_context: Accumulated transcript for Phase 4 context hints
    """
    # Configuration (uses constants from app.config.constants)
    MERGE_TIME_WINDOW: float = SEGMENT_MERGE_TIME_WINDOW_SEC
    MIN_WORDS_TO_KEEP_SEPARATE: int = MIN_WORDS_TO_KEEP_SEPARATE
    SENTENCE_ENDINGS: Tuple[str, ...] = ('.', '!', '?')
    CLAUSE_ENDINGS: Tuple[str, ...] = ('.', '!', '?', ',')  # Include comma for Option C

    # State
    segments: List[Tuple[str, str, float]] = field(default_factory=list)  # (transcript, translation, timestamp)
    full_context: str = ""  # All transcripts accumulated

    def should_merge_with_previous(self, new_transcript: str, timestamp: float) -> bool:
        """Check if new segment should be merged with the previous one."""
        if not self.segments:
            return False

        last_transcript, last_translation, last_time = self.segments[-1]
        time_diff = timestamp - last_time

        # Merge if:
        # - New fragment < 5 words AND within time window
        # - Previous segment doesn't end with sentence punctuation
        if (len(new_transcript.split()) < self.MIN_WORDS_TO_KEEP_SEPARATE and
            time_diff < self.MERGE_TIME_WINDOW and
            not last_transcript.rstrip().endswith(self.SENTENCE_ENDINGS)):
            return True

        return False

    def should_merge_recent(self) -> bool:
        """
        Option C: Check if the last 2 segments should be merged.
        Called before publishing to catch fragments that slipped through.
        """
        if len(self.segments) < 2:
            return False

        t1, trans1, time1 = self.segments[-2]
        t2, trans2, time2 = self.segments[-1]

        # Merge if:
        # - Both short fragments (<= 5 words each)
        # - Close together (< 1 second)
        # - No sentence boundary between them (no . ! ? ,)
        if (len(t1.split()) <= self.MIN_WORDS_TO_KEEP_SEPARATE and
            len(t2.split()) <= self.MIN_WORDS_TO_KEEP_SEPARATE and
            (time2 - time1) < self.MERGE_TIME_WINDOW and
            not t1.rstrip().endswith(self.CLAUSE_ENDINGS)):
            return True

        return False

    def add_segment(self, transcript: str, translation: str, timestamp: float):
        """Add a new segment to the buffer."""
        self.segments.append((transcript, translation, timestamp))
        self.full_context += " " + transcript

        # Bound context string to prevent memory leak (same as StreamContext)
        if len(self.full_context) > TRANSLATION_CONTEXT_MAX_CHARS * 2:
            self.full_context = self.full_context[-TRANSLATION_CONTEXT_MAX_CHARS:]

        # Keep only last N segments to prevent memory growth
        if len(self.segments) > MAX_BUFFER_SEGMENTS:
            self.segments.pop(0)

    def merge_last_two(self, new_translation: str, timestamp: float) -> Tuple[str, str]:
        """Merge the last two segments and update with new translation."""
        if len(self.segments) < 1:
            return ("", "")

        last_transcript, _, last_time = self.segments.pop()
        merged_transcript = last_transcript

        # Update the last segment with merged content
        if self.segments:
            prev_transcript, _, _ = self.segments.pop()
            merged_transcript = prev_transcript + " " + last_transcript

        self.segments.append((merged_transcript, new_translation, timestamp))
        return (merged_transcript, new_translation)

    async def finalize_for_publish(self, pipeline, source_lang: str, target_lang: str, loop) -> Optional[Tuple[str, str]]:
        """
        Option C: Batch merge recent segments before publishing.
        Returns the final (transcript, translation) after merging, or None if no segments.
        """
        if not self.segments:
            return None

        # Keep merging while should_merge_recent() is True
        merge_count = 0
        while self.should_merge_recent():
            t1, trans1, time1 = self.segments.pop(-2)
            t2, trans2, time2 = self.segments.pop(-1)

            merged_t = t1 + " " + t2

            # Re-translate merged text with context (Phase 4)
            context = self.get_context_for_translation()

            def translate_merged():
                return pipeline._translate_text_with_context(
                    merged_t,
                    context,
                    source_language_code=source_lang[:2],
                    target_language_code=target_lang[:2]
                )

            merged_trans = await loop.run_in_executor(get_gcp_executor(), translate_merged)
            self.segments.append((merged_t, merged_trans, time2))
            merge_count += 1

            logger.info(f"🔗 Finalize merge: '{t1}' + '{t2}' -> '{merged_t}'")

        if merge_count > 0:
            logger.info(f"📦 Finalized {merge_count} merge(s)")

        return self.segments[-1][:2] if self.segments else None

    def get_context_for_translation(self, max_chars: int = TRANSLATION_CONTEXT_MAX_CHARS) -> str:
        """Get recent context to help with translation (Phase 4)."""
        return self.full_context[-max_chars:].strip() if self.full_context else ""

# Segment buffers for context preservation
# Key: stream_key -> Value: SegmentBuffer
_segment_buffers: Dict[str, SegmentBuffer] = {}

async def handle_audio_stream(
    session_id: str,
    speaker_id: str,
    source_lang: str,
    audio_source: any # queue.Queue or iterator
):
    """
    Background task that uses pause-based chunking for aggressive real-time translation.

    Phase 3: Now supports multi-party calls. Target languages determined from database
    per audio chunk, allowing dynamic participant changes.

    OOP Refactor: Uses extracted AudioChunker class for pause-based segmentation.
    Accumulates audio chunks until silence is detected, then immediately
    transcribes, translates to all target languages, and synthesizes.
    """
    stream_key = f"{session_id}:{speaker_id}"
    logger.info(f"🎙️ Starting pause-based chunking for {stream_key} (source: {source_lang}, multiparty mode)")

    pipeline = _get_pipeline()
    redis = await get_redis()
    loop = asyncio.get_running_loop()

    # OOP Refactor: Callback for AudioChunker - processes accumulated audio
    def on_chunk_ready(result: ChunkResult):
        """Callback invoked when AudioChunker has audio ready to process."""
        # Track metrics based on trigger reason
        reason = result.trigger_reason
        if "Pause" in reason or "Silence" in reason:
            silence_triggers.labels(trigger_type='pause').inc()
        elif "Max" in reason or "accumulation" in reason:
            silence_triggers.labels(trigger_type='max_chunks').inc()
        else:
            silence_triggers.labels(trigger_type='end_stream').inc()

        # Process in async context (multiparty function handles all target languages)
        asyncio.run_coroutine_threadsafe(
            process_accumulated_audio_multiparty(
                result.audio_data, pipeline, redis, loop,
                session_id, speaker_id, source_lang
            ),
            loop
        )

    # OOP Refactor: Create AudioChunker with extracted SpeechDetector
    chunker = AudioChunker(
        stream_key=stream_key,
        on_chunk_ready=on_chunk_ready,
        speech_detector=speech_detector
    )

    def run_chunking():
        """Run the chunker loop in thread pool."""
        run_chunker_loop(
            chunker=chunker,
            audio_source=audio_source,
            shutdown_flag_getter=lambda: _shutdown_flag
        )

    async def process_accumulated_audio(audio_data: bytes, pipeline, redis, loop, session_id, speaker_id, source_lang, target_lang):
        """Process accumulated audio chunk: transcribe, translate, TTS, and publish.

        Implements:
        - Option C: Hybrid context-aware merging
        - Phase 4: Context hints passed to translation API
        """
        import time
        start_time = time.time()
        lang_pair = f"{source_lang}_{target_lang}"

        # Get or create segment buffer for this stream
        if stream_key not in _segment_buffers:
            _segment_buffers[stream_key] = SegmentBuffer()
        segment_buffer = _segment_buffers[stream_key]

        try:
            logger.info(f"🔄 Processing accumulated audio chunk ({len(audio_data)} bytes) after pause")

            # Run transcription in thread pool (blocking GCP call)
            def transcribe_chunk():
                return pipeline._transcribe(audio_data, source_lang)

            stt_start = time.time()
            transcript = await loop.run_in_executor(get_gcp_executor(), transcribe_chunk)
            audio_processing_latency.labels(
                component='stt', language_pair=lang_pair
            ).observe(time.time() - stt_start)

            if not transcript or len(transcript.strip()) == 0:
                logger.debug("No transcript generated from audio chunk")
                segments_processed.labels(status='empty', language_pair=lang_pair).inc()
                return

            logger.info(f"📝 Transcript: '{transcript}'")

            # === OPTION C: Context-aware merging with Phase 4 context hints ===
            should_merge = segment_buffer.should_merge_with_previous(transcript, start_time)

            # Get context for Phase 4 context-aware translation
            context = segment_buffer.get_context_for_translation()

            if should_merge and segment_buffer.segments:
                # Merge with previous segment
                last_transcript, last_translation, _ = segment_buffer.segments[-1]
                merged_transcript = last_transcript + " " + transcript

                logger.info(f"🔗 Merging segments: '{last_transcript}' + '{transcript}' -> '{merged_transcript}'")

                # Re-translate merged transcript with context (Phase 4)
                def translate_merged():
                    return pipeline._translate_text_with_context(
                        merged_transcript,
                        context,
                        source_language_code=source_lang[:2],
                        target_language_code=target_lang[:2]
                    )

                translate_start = time.time()
                translation = await loop.run_in_executor(get_gcp_executor(), translate_merged)
                audio_processing_latency.labels(
                    component='translate', language_pair=lang_pair
                ).observe(time.time() - translate_start)

                # Update buffer with merged segment
                segment_buffer.merge_last_two(translation, start_time)
                transcript = merged_transcript

                logger.info(f"🔄 Merged Translation (with context): '{translation}'")
            else:
                # Normal translation with context (Phase 4)
                def translate_chunk():
                    return pipeline._translate_text_with_context(
                        transcript,
                        context,
                        source_language_code=source_lang[:2],
                        target_language_code=target_lang[:2]
                    )

                translate_start = time.time()
                translation = await loop.run_in_executor(get_gcp_executor(), translate_chunk)
                audio_processing_latency.labels(
                    component='translate', language_pair=lang_pair
                ).observe(time.time() - translate_start)

                # Add to buffer for future merging
                segment_buffer.add_segment(transcript, translation, start_time)

                logger.info(f"🔄 Translation (with context): '{translation}'")

            # TTS (blocking)
            def synthesize_chunk():
                return pipeline._synthesize(
                    translation,
                    language_code=target_lang,
                    voice_name=None
                )

            tts_start = time.time()
            audio_content = await loop.run_in_executor(get_gcp_executor(), synthesize_chunk)
            audio_processing_latency.labels(
                component='tts', language_pair=lang_pair
            ).observe(time.time() - tts_start)
            logger.info(f"🔊 Synthesized {len(audio_content)} bytes of TTS audio")

            # Track total latency
            audio_processing_latency.labels(
                component='total', language_pair=lang_pair
            ).observe(time.time() - start_time)

            # Success counter
            segments_processed.labels(status='success', language_pair=lang_pair).inc()

            # Publish result
            payload = {
                "type": "translation",
                "session_id": session_id,
                "speaker_id": speaker_id,
                "transcript": transcript,
                "translation": translation,
                "audio_content": audio_content.hex() if audio_content else None,
                "source_lang": source_lang,
                "target_lang": target_lang,
                "is_final": True,
                "is_merged": should_merge,  # Flag to indicate this was a merged segment
                "has_context": bool(context)  # Flag to indicate context was used
            }

            channel = f"channel:translation:{session_id}"
            await redis.publish(channel, json.dumps(payload))
            logger.info(f"✅ Published translation result to {channel}")

        except Exception as e:
            logger.error(f"Error processing accumulated audio: {e}")
            segments_processed.labels(status='error', language_pair=lang_pair).inc()
            import traceback
            traceback.print_exc()

    async def process_accumulated_audio_multiparty(audio_data: bytes, pipeline, redis, loop, session_id, speaker_id, source_lang):
        """
        Phase 3: Process audio for multiple recipients with translation deduplication.

        Flow:
        1. Query database for target language map (all recipients except speaker)
        2. STT once (source_lang)
        3. Translate once per unique target language (parallel)
        4. TTS once per unique target language (parallel)
        5. Publish each translation with recipient_ids for routing
        """
        import time
        start_time = time.time()

        # Get or create segment buffer for this stream
        if stream_key not in _segment_buffers:
            _segment_buffers[stream_key] = SegmentBuffer()
        segment_buffer = _segment_buffers[stream_key]

        try:
            logger.info(f"🔄 [Multiparty] Processing audio chunk ({len(audio_data)} bytes) for session {session_id}")

            # === STEP 1: Query target languages from database ===
            # OOP Refactor: Use CallRepository instead of inline DB queries
            target_langs_map = await call_repository.get_target_languages(session_id, speaker_id)

            if not target_langs_map:
                logger.info(f"No recipients for speaker {speaker_id} in session {session_id}")
                return

            logger.info(f"🎯 Target language map: {target_langs_map}")

            # === STEP 2: STT (once) ===
            def transcribe_chunk():
                return pipeline._transcribe(audio_data, source_lang)

            stt_start = time.time()
            transcript = await loop.run_in_executor(get_gcp_executor(), transcribe_chunk)
            stt_latency = time.time() - stt_start

            if not transcript or len(transcript.strip()) == 0:
                logger.debug("No transcript generated")
                return

            logger.info(f"📝 Transcript: '{transcript}' (STT: {stt_latency:.2f}s)")

            # Get context for translation
            context = segment_buffer.get_context_for_translation()

            # === STEP 3 & 4: Translate + TTS per language (parallel) ===
            async def process_language(tgt_lang, recipients):
                """Process translation and TTS for one target language."""
                try:
                    lang_pair = f"{source_lang}_{tgt_lang}"

                    # Translate
                    def translate():
                        return pipeline._translate_text_with_context(
                            transcript,
                            context,
                            source_language_code=source_lang[:2],
                            target_language_code=tgt_lang[:2]
                        )

                    translate_start = time.time()
                    translation = await loop.run_in_executor(get_gcp_executor(), translate)
                    translate_latency = time.time() - translate_start

                    logger.info(f"🔄 Translation to {tgt_lang}: '{translation}' ({translate_latency:.2f}s)")
                    audio_processing_latency.labels(
                        component='translate', language_pair=lang_pair
                    ).observe(translate_latency)

                    # TTS with caching (Phase 3: cost optimization)
                    from app.services.translation.tts_cache import get_tts_cache

                    cache = get_tts_cache()
                    cached_audio = cache.get(translation, tgt_lang)

                    if cached_audio:
                        logger.info(f"✅ TTS cache HIT for {tgt_lang}: '{translation[:30]}...'")
                        audio_content = cached_audio
                        tts_latency = 0.0  # Cache hit, no actual TTS call
                    else:
                        def synthesize():
                            return pipeline._synthesize(translation, language_code=tgt_lang, voice_name=None)

                        tts_start = time.time()
                        audio_content = await loop.run_in_executor(get_gcp_executor(), synthesize)
                        tts_latency = time.time() - tts_start

                        # Cache for future use
                        cache.put(translation, tgt_lang, audio_content)
                        logger.info(f"🔊 TTS for {tgt_lang}: {len(audio_content)} bytes ({tts_latency:.2f}s) - CACHED")

                    audio_processing_latency.labels(
                        component='tts', language_pair=lang_pair
                    ).observe(tts_latency)

                    return {
                        "target_lang": tgt_lang,
                        "recipient_ids": recipients,
                        "translation": translation,
                        "audio_content": audio_content,
                        "lang_pair": lang_pair
                    }

                except Exception as e:
                    logger.error(f"Error processing language {tgt_lang}: {e}")
                    import traceback
                    traceback.print_exc()
                    return None

            # Execute all translations in parallel
            translation_tasks = [
                process_language(target_lang, recipient_ids)
                for target_lang, recipient_ids in target_langs_map.items()
            ]

            results = await asyncio.gather(*translation_tasks, return_exceptions=True)

            # === STEP 5: Publish results ===
            successful_count = 0
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
                    "recipient_ids": result["recipient_ids"],  # Phase 3: NEW!
                    "transcript": transcript,
                    "translation": result["translation"],
                    "audio_content": result["audio_content"].hex() if result["audio_content"] else None,
                    "source_lang": source_lang,
                    "target_lang": result["target_lang"],
                    "is_final": True,
                    "has_context": bool(context)
                }

                channel = f"channel:translation:{session_id}"
                await redis.publish(channel, json.dumps(payload))
                logger.info(f"✅ Published translation to {result['target_lang']} for {len(result['recipient_ids'])} recipients")

                segments_processed.labels(status='success', language_pair=result["lang_pair"]).inc()
                successful_count += 1

            # Update segment buffer (use first translation for context)
            if results and not isinstance(results[0], Exception) and results[0] is not None:
                segment_buffer.add_segment(transcript, results[0]["translation"], start_time)

            total_latency = time.time() - start_time
            logger.info(f"⏱️ Total multiparty processing time: {total_latency:.2f}s ({successful_count} languages)")

            # Track total latency for first language (representative)
            if results and not isinstance(results[0], Exception) and results[0] is not None:
                audio_processing_latency.labels(
                    component='total', language_pair=results[0]["lang_pair"]
                ).observe(total_latency)

        except Exception as e:
            logger.error(f"Error in multiparty audio processing: {e}")
            import traceback
            traceback.print_exc()

    try:
        # OOP Refactor: Use extracted AudioChunker via run_chunking wrapper
        await loop.run_in_executor(get_gcp_executor(), run_chunking)

    except asyncio.CancelledError:
        logger.info(f"Stream task cancelled for {stream_key}")
        # Signal shutdown to unblock queue - use StreamManager
        stream_manager.signal_end(session_id, speaker_id)
        chunker.shutdown()  # Mark chunker as shutdown
        raise
    except Exception as e:
        logger.error(f"Error in streaming task for {stream_key}: {e}")
    finally:
        logger.info(f"Streaming task ended for {stream_key}")
        # OOP Refactor: Use StreamManager for cleanup
        stream_manager.remove_stream(session_id, speaker_id)
        # Clean up spectral analysis history buffer
        speech_detector.clear_history(stream_key)
        # Clean up segment buffer for context preservation
        if stream_key in _segment_buffers:
            del _segment_buffers[stream_key]
        # DUAL-STREAM: Stop interim caption session
        try:
            await stop_interim_session(session_id, speaker_id)
        except Exception as e:
            logger.debug(f"Interim session cleanup failed (non-critical): {e}")

async def process_stream_message(redis, stream_key: str, message_id: str, data: dict):
    try:
        # Issue #8 Fix: Skip duplicate messages to prevent echo
        # OOP Refactor: Use MessageDeduplicator instead of inline logic
        if message_deduplicator.is_duplicate(message_id):
            logger.debug(f"Skipping duplicate message: {message_id}")
            return

        # Get audio data
        audio_data = data.get(b"data")
        if not audio_data:
            return

        # Get metadata
        source_lang = data.get(b"source_lang", b"he-IL").decode("utf-8")
        # Phase 3: target_lang removed - determined by worker from database
        speaker_id = data.get(b"speaker_id", b"unknown").decode("utf-8")
        session_id = data.get(b"session_id", b"unknown").decode("utf-8")

        # OOP Refactor: Use StreamManager instead of global dicts
        # Check if we have an active stream
        if not stream_manager.has_stream(session_id, speaker_id):
            # Start new stream with StreamManager
            audio_queue = stream_manager.create_stream(session_id, speaker_id)

            # Start the pause-based audio processing task
            task = asyncio.create_task(handle_audio_stream(
                session_id, speaker_id, source_lang, audio_queue
            ))
            stream_manager.set_task(session_id, speaker_id, task)

        # Push chunk to queue
        stream_manager.push_audio(session_id, speaker_id, audio_data)

        # DUAL-STREAM: Push to interim caption service for real-time captions + streaming translation
        # The streaming processor callback is invoked when STT produces a final result,
        # enabling sub-2-second latency by bypassing the batch STT path
        try:
            streaming_processor = get_streaming_processor()
            await push_audio_for_interim(
                session_id,
                speaker_id,
                source_lang,
                audio_data,
                on_final_transcript=streaming_processor.process_final_transcript
            )
        except Exception as e:
            logger.debug(f"Interim caption push failed (non-critical): {e}")

        # Acknowledge message
        await redis.xack(stream_key, "audio_group", message_id)

    except Exception as e:
        logger.error(f"Error processing message {message_id}: {e}")

async def run_worker():
    global _shutdown_flag
    _shutdown_flag = False  # Reset on start

    # Start metrics server
    start_metrics_server(port=METRICS_SERVER_PORT)

    logger.info("Starting Stateful Streaming Worker...")
    redis = await get_redis()

    stream_key = "stream:audio:global"
    group_name = "audio_processors"
    consumer_name = f"worker_{os.getpid()}"

    try:
        await redis.xgroup_create(stream_key, group_name, mkstream=True)
    except Exception as e:
        if "BUSYGROUP" not in str(e):
            logger.error(f"Error creating group: {e}")

    logger.info(f"Listening on {stream_key}...")

    try:
        while not _shutdown_flag:
            try:
                # Use configurable block time for responsive shutdown
                streams = await redis.xreadgroup(
                    group_name,
                    consumer_name,
                    {stream_key: ">"},
                    count=REDIS_STREAM_MESSAGE_COUNT,
                    block=REDIS_STREAM_BLOCK_MS
                )

                if _shutdown_flag:
                    break

                for stream, messages in streams:
                    if _shutdown_flag:
                        break
                    for message_id, data in messages:
                        if _shutdown_flag:
                            break
                        await process_stream_message(redis, stream, message_id, data)

            except Exception as e:
                if _shutdown_flag:
                    break
                logger.error(f"Error in worker loop: {e}")
                await asyncio.sleep(ERROR_RECOVERY_SLEEP_SEC)
    finally:
        # Signal all active streams to shutdown
        _shutdown_flag = True
        logger.info("Shutting down worker - canceling all tasks and signaling streams to stop...")

        # Shutdown interim caption service
        try:
            interim_service = get_interim_caption_service()
            await interim_service.shutdown()
        except Exception as e:
            logger.debug(f"Interim service shutdown failed (non-critical): {e}")

        # OOP Refactor: Use StreamManager for shutdown
        logger.info(f"Unblocking {stream_manager.get_active_count()} active streams...")
        stream_manager.signal_all_end()

        # Cancel all active tasks
        try:
            await stream_manager.cancel_all_tasks(timeout=GRACEFUL_SHUTDOWN_TIMEOUT_SEC)
        except Exception as e:
            logger.debug(f"Task cancellation error (non-critical): {e}")

if __name__ == "__main__":
    import signal

    def signal_handler(signum, frame):
        global _shutdown_flag
        logger.info(f"Received signal {signum} - initiating graceful shutdown...")
        _shutdown_flag = True

    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        logger.info("Worker stopped via KeyboardInterrupt")
    except Exception as e:
        logger.error(f"Worker error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        logger.info("Worker cleanup complete")
