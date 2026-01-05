import asyncio
import json
import logging
import os
from typing import Dict, Optional
import queue

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.config.settings import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global state to track active streams
# Key: f"{session_id}:{speaker_id}" -> Value: queue.Queue (Thread-safe queue)
active_streams: Dict[str, queue.Queue] = {}

async def handle_audio_stream(
    session_id: str,
    speaker_id: str,
    source_lang: str,
    target_lang: str,
    audio_source: any # queue.Queue or iterator
):
    """
    Background task that consumes audio chunks from a queue and streams them to GCP.
    """
    stream_key = f"{session_id}:{speaker_id}"
    logger.info(f"🎙️ Starting streaming task for {stream_key} ({source_lang} -> {target_lang})")
    
    pipeline = _get_pipeline()
    redis = await get_redis()
    
    # Generator that yields chunks from the thread-safe queue OR just uses the source if it's already a generator
    def audio_generator():
        if hasattr(audio_source, '__iter__') or hasattr(audio_source, '__next__'):
             yield from audio_source
        else:
            # Fallback for raw queue (legacy)
            while True:
                chunk = audio_source.get()
                if chunk is None:
                    return
                yield chunk

    # Helper to run the blocking pipeline
    def run_pipeline():
        return pipeline.streaming_transcribe(
            audio_generator(),
            language_code=source_lang
        )

    # Start the pipeline in a separate thread
    loop = asyncio.get_running_loop()
    
    try:
        def process_stream():
            for transcript, is_final in run_pipeline():
                if is_final:
                    # Got a final transcript!
                    logger.info(f"📝 Final Transcript: {transcript}")
                    
                    # Translate
                    translation = pipeline._translate_text(
                        transcript,
                        source_language_code=source_lang[:2],
                        target_language_code=target_lang[:2]
                    )
                    logger.info(f"🔄 Translation: {translation}")
                    
                    # TTS
                    audio_content = pipeline._synthesize(
                        translation,
                        language_code=target_lang,
                        voice_name=None
                    )
                    
                    # Publish Final
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
                else:
                    # Interim transcript - translate it for real-time feedback
                    # Note: This increases API usage
                    translation_interim = pipeline._translate_text(
                        transcript,
                        source_language_code=source_lang[:2],
                        target_language_code=target_lang[:2]
                    )
                    
                    payload = {
                        "type": "transcription_update", # Different type for interim
                        "session_id": session_id,
                        "speaker_id": speaker_id,
                        "transcript": transcript,
                        "translation": translation_interim,
                        "audio_content": None,
                        "source_lang": source_lang,
                        "target_lang": target_lang,
                        "is_final": False
                    }
                
                # Publish back to Redis
                channel = f"channel:translation:{session_id}"
                asyncio.run_coroutine_threadsafe(
                    redis.publish(channel, json.dumps(payload)),
                    loop
                )

        await loop.run_in_executor(None, process_stream)
        
    except Exception as e:
        logger.error(f"Error in streaming task for {stream_key}: {e}")
    finally:
        logger.info(f"Streaming task ended for {stream_key}")
        if stream_key in active_streams:
            del active_streams[stream_key]

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
            q = queue.Queue()
            active_streams[key] = q
            
            # Wrapper to add silence detection
            def silence_detecting_generator(input_q):
                import audioop
                import time
                
                last_voice_time = time.time()
                silence_threshold = 1.5 # Seconds
                # rms_threshold = 500 # Adjust based on mic. 
                # Since we don't know the mic levels well, let's rely on time between chunks? 
                # No, we get continuous chunks. We need RMS.
                rms_threshold = 300 
                
                while True:
                    try:
                        chunk = input_q.get(timeout=0.2) # Wait for audio
                        if chunk is None:
                            return
                        
                        # Calculate RMS
                        try:
                            # 2 bytes width for 16-bit audio
                            rms = audioop.rms(chunk, 2)
                        except:
                            rms = 1000 # Fallback
                            
                        now = time.time()
                        if rms > rms_threshold:
                            last_voice_time = now
                        else:
                            if now - last_voice_time > silence_threshold:
                                # Detected silence!
                                # logger.info("Silence detected - forcing finalization")
                                yield b"SILENCE"
                                last_voice_time = now # Reset so we don't spam
                        
                        yield chunk
                        
                    except queue.Empty:
                        continue

            asyncio.create_task(handle_audio_stream(
                session_id, speaker_id, source_lang, target_lang, silence_detecting_generator(q)
            ))
        
        # Push chunk to queue
        active_streams[key].put(audio_data)
            
        # Acknowledge message
        await redis.xack(stream_key, "audio_group", message_id)
        
    except Exception as e:
        logger.error(f"Error processing message {message_id}: {e}")

async def run_worker():
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
    
    while True:
        try:
            streams = await redis.xreadgroup(
                group_name,
                consumer_name,
                {stream_key: ">"},
                count=10,
                block=2000
            )
            
            for stream, messages in streams:
                for message_id, data in messages:
                    await process_stream_message(redis, stream, message_id, data)
                    
        except Exception as e:
            logger.error(f"Error in worker loop: {e}")
            await asyncio.sleep(1)

if __name__ == "__main__":
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        logger.info("Worker stopped")