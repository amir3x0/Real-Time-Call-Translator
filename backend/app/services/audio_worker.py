import asyncio
import json
import logging
import os
import time
from typing import Dict, Optional
import queue

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

async def handle_audio_stream(
    session_id: str,
    speaker_id: str,
    source_lang: str,
    target_lang: str,
    audio_source: any # queue.Queue or iterator
):
    """
    Background task that uses pause-based chunking for aggressive real-time translation.
    
    Accumulates audio chunks until silence >1 second is detected, then immediately
    transcribes, translates, and synthesizes the accumulated chunk.
    """
    import audioop
    
    stream_key = f"{session_id}:{speaker_id}"
    logger.info(f"🎙️ Starting pause-based chunking for {stream_key} ({source_lang} -> {target_lang})")
    
    pipeline = _get_pipeline()
    redis = await get_redis()
    loop = asyncio.get_running_loop()
    
    # Configuration for pause-based chunking
    SILENCE_THRESHOLD = 0.4  # 0.4 second of silence triggers processing (reduced over-segmentation)
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
        chunk_timeout = 0.1  # 100ms timeout for queue reads
        
        # TIME-BASED constants (more reliable than chunk counting)
        MAX_ACCUMULATED_TIME = 0.5  # Force process after 500ms of audio (replaces chunk counting)
        
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
                
                # Process this chunk in async context
                asyncio.run_coroutine_threadsafe(
                    process_accumulated_audio(audio_to_process, pipeline, redis, loop, session_id, speaker_id, source_lang, target_lang),
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
                process_accumulated_audio(audio_to_process, pipeline, redis, loop, session_id, speaker_id, source_lang, target_lang),
                loop
            )

    async def process_accumulated_audio(audio_data: bytes, pipeline, redis, loop, session_id, speaker_id, source_lang, target_lang):
        """Process accumulated audio chunk: transcribe, translate, TTS, and publish"""
        import time
        start_time = time.time()
        lang_pair = f"{source_lang}_{target_lang}"
        
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
            
            # Translate (also blocking, but faster)
            def translate_chunk():
                return pipeline._translate_text(
                    transcript,
                    source_language_code=source_lang[:2],
                    target_language_code=target_lang[:2]
                )
            
            translate_start = time.time()
            translation = await loop.run_in_executor(None, translate_chunk)
            audio_processing_latency.labels(
                component='translate', language_pair=lang_pair
            ).observe(time.time() - translate_start)
            logger.info(f"🔄 Translation: '{translation}'")
            
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
                "is_final": True
            }
            
            channel = f"channel:translation:{session_id}"
            await redis.publish(channel, json.dumps(payload))
            logger.info(f"✅ Published translation result to {channel}")
            
        except Exception as e:
            logger.error(f"Error processing accumulated audio: {e}")
            segments_processed.labels(status='error', language_pair=lang_pair).inc()
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

async def process_stream_message(redis, stream_key: str, message_id: str, data: dict):
    try:
        # Get audio data
        audio_data = data.get(b"data")
        if not audio_data:
            return

        # Get metadata
        source_lang = data.get(b"source_lang", b"he-IL").decode("utf-8")
        target_lang = data.get(b"target_lang", b"en-US").decode("utf-8")
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
                session_id, speaker_id, source_lang, target_lang, q
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