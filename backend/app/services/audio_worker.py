import asyncio
import json
import logging
import os
import time
from typing import Dict, List, Optional, Tuple
import queue
from dataclasses import dataclass, field

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.config.settings import settings
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

# Global state to track active streams
# Key: f"{session_id}:{speaker_id}" -> Value: queue.Queue (Thread-safe queue)
active_streams: Dict[str, queue.Queue] = {}

# Spectral analysis history buffers for sliding window FFT
# Key: stream_key -> Value: bytearray of recent audio for FFT
_spectral_history: Dict[str, bytearray] = {}
# Track active async tasks for cleanup
active_tasks: Dict[str, asyncio.Task] = {}
# Global shutdown flag for graceful termination
_shutdown_flag = False
# Issue #8 Fix: Track processed message IDs to prevent duplicate processing (echo)
# Uses a set with TTL-like cleanup to prevent unbounded growth
_processed_message_ids: Dict[str, float] = {}  # message_id -> timestamp
_DEDUP_TTL_SECONDS = 30.0  # How long to remember a message ID

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
    # Configuration
    MERGE_TIME_WINDOW: float = 1.0  # seconds - merge if within this time (increased from 0.5)
    MIN_WORDS_TO_KEEP_SEPARATE: int = 5  # don't merge segments with >= this many words
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
        
        # Keep only last 10 segments to prevent memory growth
        if len(self.segments) > 10:
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
            
            merged_trans = await loop.run_in_executor(None, translate_merged)
            self.segments.append((merged_t, merged_trans, time2))
            merge_count += 1
            
            logger.info(f"🔗 Finalize merge: '{t1}' + '{t2}' -> '{merged_t}'")
        
        if merge_count > 0:
            logger.info(f"📦 Finalized {merge_count} merge(s)")
        
        return self.segments[-1][:2] if self.segments else None
    
    def get_context_for_translation(self, max_chars: int = 200) -> str:
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

    Accumulates audio chunks until silence is detected, then immediately
    transcribes, translates to all target languages, and synthesizes.
    """
    import audioop

    stream_key = f"{session_id}:{speaker_id}"
    logger.info(f"🎙️ Starting pause-based chunking for {stream_key} (source: {source_lang}, multiparty mode)")
    
    pipeline = _get_pipeline()
    redis = await get_redis()
    loop = asyncio.get_running_loop()
    
    # Configuration for pause-based chunking
    SILENCE_THRESHOLD = 0.25  # 0.25 second of silence triggers processing (reduced from 0.4s for lower latency)
    RMS_THRESHOLD = 300   # RMS level below which we consider it silence (lowered to catch quiet speakers)
    MIN_AUDIO_LENGTH = 0.5  # Minimum 0.5 seconds of audio before processing (reduced from 1s for faster response)
    # MAX_CHUNKS_BEFORE_FORCE removed - now using time-based forcing in process_audio_chunks()
    SAMPLE_RATE = 16000
    BYTES_PER_SAMPLE = 2  # 16-bit PCM
    MIN_BYTES = int(MIN_AUDIO_LENGTH * SAMPLE_RATE * BYTES_PER_SAMPLE)  # ~16000 bytes for 0.5s
    
    def is_likely_speech(chunk: bytes) -> bool:
        """
        Detect speech using FFT on a SLIDING 400ms WINDOW.
        This reduces false negatives on speech starts compared to per-chunk analysis.
        
        Improvements over original:
        - 400ms window provides stable frequency content for FFT
        - Reduces false negatives at speech onset (first 100ms looks like noise)
        - Still uses quick RMS check as fast path
        
        Args:
            chunk: PCM16 audio bytes
            
        Returns:
            True if chunk likely contains speech, False otherwise
        """
        import numpy as np
        
        # Get or create history buffer for this stream
        if stream_key not in _spectral_history:
            _spectral_history[stream_key] = bytearray()
        
        history = _spectral_history[stream_key]
        history.extend(chunk)
        
        # Keep only last 400ms (16kHz × 2 bytes × 0.4s = 12800 bytes)
        MAX_HISTORY = 12800
        if len(history) > MAX_HISTORY:
            _spectral_history[stream_key] = history[-MAX_HISTORY:]
            history = _spectral_history[stream_key]
        
        # Need at least 100ms for meaningful analysis
        MIN_ANALYSIS_BYTES = 3200  # 100ms at 16kHz mono 16-bit
        if len(history) < MIN_ANALYSIS_BYTES:
            return True  # Not enough data, assume speech to avoid false negatives
        
        # FFT on accumulated history, not just single chunk
        try:
            audio = np.frombuffer(bytes(history), dtype=np.int16)
            rms = np.sqrt(np.mean(audio.astype(np.float64)**2))
            
            if rms < RMS_THRESHOLD:
                return False  # Too quiet to be speech
            
            # FFT for spectral content
            fft = np.fft.rfft(audio)
            fft_magnitude = np.abs(fft)
            
            # Calculate bin indices based on actual FFT size
            # bin_index = frequency * fft_size / sample_rate
            fft_size = len(audio)
            bin_80hz = int(80 * fft_size / SAMPLE_RATE)
            bin_4000hz = int(4000 * fft_size / SAMPLE_RATE)
            bin_5000hz = int(5000 * fft_size / SAMPLE_RATE)
            
            # Speech energy: 80-4000 Hz
            speech_band = fft_magnitude[bin_80hz:bin_4000hz].sum()
            
            # Noise energy: >5000 Hz
            noise_band = fft_magnitude[bin_5000hz:].sum()
            
            # Speech should have dominant energy in speech frequencies
            # Ratio 2.0 = speech band must be 2x larger than high-freq noise
            return speech_band > 2.0 * noise_band
            
        except Exception as e:
            logger.warning(f"Spectral analysis failed: {e}, falling back to RMS")
            return True  # Fallback: assume speech if analysis fails
    
    def process_audio_chunks():
        """Process audio chunks with pause-based chunking using TIME-BASED forcing."""
        # Audio buffer to accumulate chunks
        audio_buffer = bytearray()
        last_voice_time = time.time()
        last_process_time = time.time()  # NEW: Track when we last processed
        chunk_count = 0  # Keep for logging only
        chunk_timeout = 0.15  # 150ms timeout for queue reads (aligned with client send interval)
        
        # TIME-BASED constants (more reliable than chunk counting)
        MAX_ACCUMULATED_TIME = 0.75  # Force process after 750ms of audio (5 chunks at 150ms)
        
        # Check if audio_source is a queue or iterator
        is_queue = isinstance(audio_source, queue.Queue)
        
        # Helper function to process and reset buffer
        def process_and_reset(reason: str):
            nonlocal audio_buffer, chunk_count, last_voice_time, last_process_time
            if len(audio_buffer) >= MIN_BYTES:
                current_chunk_count = chunk_count
                audio_to_process = bytes(audio_buffer)
                audio_buffer.clear()
                chunk_count = 0
                now = time.time()
                last_voice_time = now
                last_process_time = now  # Reset accumulation timer
                
                logger.info(f"🔄 {reason} - processing {len(audio_to_process)} bytes ({current_chunk_count} chunks)")
                
                # Track what triggered processing
                if "Silence" in reason or "Pause" in reason:
                    silence_triggers.labels(trigger_type='pause').inc()
                elif "Max" in reason or "accumulation" in reason:
                    silence_triggers.labels(trigger_type='max_chunks').inc()
                else:
                    silence_triggers.labels(trigger_type='end_stream').inc()
                
                # Process this chunk in async context (Phase 3: using multiparty function)
                asyncio.run_coroutine_threadsafe(
                    process_accumulated_audio_multiparty(audio_to_process, pipeline, redis, loop, session_id, speaker_id, source_lang),
                    loop
                )
                return True
            return False
        
        while not _shutdown_flag:
            try:
                # Get next chunk
                if is_queue:
                    try:
                        chunk = audio_source.get(timeout=chunk_timeout)
                        if chunk is None or _shutdown_flag:
                            # None means end of stream, or shutdown requested
                            break
                    except queue.Empty:
                        # Queue timeout - check if we should process buffer due to silence
                        if _shutdown_flag:
                            break
                            
                        now = time.time()
                        silence_duration = now - last_voice_time
                        
                        if len(audio_buffer) >= MIN_BYTES and silence_duration >= SILENCE_THRESHOLD:
                            # Process accumulated buffer after silence
                            process_and_reset(f"⏸️  Silence detected ({silence_duration:.2f}s)")
                        # Continue loop to check queue again (with shorter timeout now)
                        continue
                else:
                    # Iterator/generator
                    try:
                        chunk = next(audio_source)
                        if chunk is None or _shutdown_flag:
                            break
                    except StopIteration:
                        break
                    except TypeError:
                        # Not iterable
                        logger.error("Audio source is not iterable or queue")
                        break
                
                
                # Use spectral analysis instead of simple RMS
                is_voice = is_likely_speech(chunk)
                
                now = time.time()
                
                # Always add chunk to buffer (even silent ones, as they might be pauses in speech)
                audio_buffer.extend(chunk)
                chunk_count += 1
                
                # Priority 1: TIME-BASED forcing (replaces unreliable chunk counting)
                # This handles continuous speech without pauses deterministically
                accumulation_time = now - last_process_time
                if accumulation_time >= MAX_ACCUMULATED_TIME:
                    if process_and_reset(f"⏭️  Max accumulation time ({accumulation_time:.2f}s)"):
                        continue  # Skip rest of iteration
                
                if is_voice:
                    # Voice detected - reset silence timer
                    last_voice_time = now
                else:
                    # Silence detected - check if we should process
                    silence_duration = now - last_voice_time
                    
                    if len(audio_buffer) >= MIN_BYTES and silence_duration >= SILENCE_THRESHOLD:
                        # Enough audio accumulated and enough silence - process it!
                        if process_and_reset(f"⏸️  Pause detected ({silence_duration:.2f}s)"):
                            continue  # Skip rest of iteration
                        
            except Exception as e:
                logger.error(f"Error processing audio chunks: {e}")
                import traceback
                traceback.print_exc()
                break
        
        # Process any remaining audio in buffer when stream ends (only if not shutting down)
        if not _shutdown_flag and len(audio_buffer) >= MIN_BYTES:
            logger.info(f"📤 Stream ended - processing remaining {len(audio_buffer)} bytes")
            audio_to_process = bytes(audio_buffer)
            asyncio.run_coroutine_threadsafe(
                process_accumulated_audio_multiparty(audio_to_process, pipeline, redis, loop, session_id, speaker_id, source_lang),
                loop
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
            transcript = await loop.run_in_executor(None, transcribe_chunk)
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
                translation = await loop.run_in_executor(None, translate_merged)
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
                translation = await loop.run_in_executor(None, translate_chunk)
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
            audio_content = await loop.run_in_executor(None, synthesize_chunk)
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
            from app.models.database import AsyncSessionLocal
            from app.models.call_participant import CallParticipant
            from app.models.call import Call
            from sqlalchemy import select, and_

            target_langs_map = {}
            try:
                async with AsyncSessionLocal() as db:
                    # Get call_id from session_id
                    call_result = await db.execute(
                        select(Call).where(Call.session_id == session_id)
                    )
                    call = call_result.scalar_one_or_none()

                    if not call:
                        logger.warning(f"No call found for session {session_id}")
                        return

                    # Get all participants except speaker who are connected
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

                    # Build language map: {language: [user_ids]}
                    for p in participants:
                        lang = p.participant_language or "en-US"
                        if lang not in target_langs_map:
                            target_langs_map[lang] = []
                        target_langs_map[lang].append(p.user_id)

            except Exception as e:
                logger.error(f"Error querying participants: {e}")
                import traceback
                traceback.print_exc()
                return

            if not target_langs_map:
                logger.info(f"No recipients for speaker {speaker_id} in session {session_id}")
                return

            logger.info(f"🎯 Target language map: {target_langs_map}")

            # === STEP 2: STT (once) ===
            def transcribe_chunk():
                return pipeline._transcribe(audio_data, source_lang)

            stt_start = time.time()
            transcript = await loop.run_in_executor(None, transcribe_chunk)
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
                    translation = await loop.run_in_executor(None, translate)
                    translate_latency = time.time() - translate_start

                    logger.info(f"🔄 Translation to {tgt_lang}: '{translation}' ({translate_latency:.2f}s)")
                    audio_processing_latency.labels(
                        component='translate', language_pair=lang_pair
                    ).observe(translate_latency)

                    # TTS with caching (Phase 3: cost optimization)
                    from app.services.tts_cache import get_tts_cache

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
                        audio_content = await loop.run_in_executor(None, synthesize)
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
        await loop.run_in_executor(None, process_audio_chunks)
        
    except asyncio.CancelledError:
        logger.info(f"Stream task cancelled for {stream_key}")
        # Signal shutdown to unblock queue
        if stream_key in active_streams:
            try:
                active_streams[stream_key].put(None)  # Sentinel to unblock queue.get()
            except:
                pass
        raise
    except Exception as e:
        logger.error(f"Error in streaming task for {stream_key}: {e}")
    finally:
        logger.info(f"Streaming task ended for {stream_key}")
        # Clean up tracking
        if stream_key in active_streams:
            del active_streams[stream_key]
            active_streams_gauge.set(len(active_streams))  # Update gauge
        if stream_key in active_tasks:
            # Task cleanup is handled by done callback, but remove here too just in case
            if stream_key in active_tasks:
                del active_tasks[stream_key]
        # Clean up spectral analysis history buffer
        if stream_key in _spectral_history:
            del _spectral_history[stream_key]
        # Clean up segment buffer for context preservation
        if stream_key in _segment_buffers:
            del _segment_buffers[stream_key]

async def process_stream_message(redis, stream_key: str, message_id: str, data: dict):
    global _processed_message_ids
    
    try:
        # Issue #8 Fix: Skip duplicate messages to prevent echo
        now = time.time()
        if message_id in _processed_message_ids:
            logger.debug(f"Skipping duplicate message: {message_id}")
            return
        
        # Clean up old entries to prevent memory growth
        expired = [mid for mid, ts in _processed_message_ids.items() if now - ts > _DEDUP_TTL_SECONDS]
        for mid in expired:
            del _processed_message_ids[mid]
        
        # Track this message
        _processed_message_ids[message_id] = now
        
        # Get audio data
        audio_data = data.get(b"data")
        if not audio_data:
            return

        # Get metadata
        source_lang = data.get(b"source_lang", b"he-IL").decode("utf-8")
        # Phase 3: target_lang removed - determined by worker from database
        speaker_id = data.get(b"speaker_id", b"unknown").decode("utf-8")
        session_id = data.get(b"session_id", b"unknown").decode("utf-8")

        key = f"{session_id}:{speaker_id}"

        # Check if we have an active stream
        if key not in active_streams:
            # Start new stream with a thread-safe Queue
            # The new pause-based approach handles silence detection internally
            q = queue.Queue()
            active_streams[key] = q
            active_streams_gauge.set(len(active_streams))  # Update gauge

            # Start the pause-based audio processing task and track it
            task = asyncio.create_task(handle_audio_stream(
                session_id, speaker_id, source_lang, q
            ))
            active_tasks[key] = task
            
            # Add done callback to clean up tracking
            def cleanup_task(task_key):
                def _cleanup(t):
                    if task_key in active_tasks:
                        del active_tasks[task_key]
                return _cleanup
            
            task.add_done_callback(cleanup_task(key))
        
        # Push chunk to queue - the handle_audio_stream will process it with pause detection
        if key in active_streams:
            active_streams[key].put(audio_data)
            
        # Acknowledge message
        await redis.xack(stream_key, "audio_group", message_id)
        
    except Exception as e:
        logger.error(f"Error processing message {message_id}: {e}")

async def run_worker():
    global _shutdown_flag
    _shutdown_flag = False  # Reset on start
    
    # Start metrics server
    start_metrics_server(port=8001)
    
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
                # Reduced block time from 2000ms to 500ms for faster shutdown response
                streams = await redis.xreadgroup(
                    group_name,
                    consumer_name,
                    {stream_key: ">"},
                    count=10,
                    block=500  # Reduced from 2000ms to 500ms for better responsiveness
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
                await asyncio.sleep(0.5)  # Reduced from 1s to 0.5s
    finally:
        # Signal all active streams to shutdown
        _shutdown_flag = True
        logger.info("Shutting down worker - canceling all tasks and signaling streams to stop...")
        
        # Put sentinel values in all queues first to unblock them
        logger.info(f"Unblocking {len(active_streams)} active streams...")
        for q in list(active_streams.values()):
            try:
                q.put(None)  # Sentinel to unblock queue.get()
            except:
                pass
        
        # Cancel all active tasks
        tasks_to_cancel = [t for t in active_tasks.values() if not t.done()]
        if tasks_to_cancel:
            logger.info(f"Cancelling {len(tasks_to_cancel)} active tasks...")
            for task in tasks_to_cancel:
                task.cancel()
            
            # Wait briefly for tasks to cancel (max 0.5s to avoid hanging)
            try:
                await asyncio.wait_for(
                    asyncio.gather(*tasks_to_cancel, return_exceptions=True),
                    timeout=0.5
                )
            except (asyncio.TimeoutError, Exception):
                pass  # Don't wait too long - tasks will finish in background

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