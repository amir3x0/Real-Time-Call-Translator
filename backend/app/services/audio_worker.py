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
    audio_queue: queue.Queue
):
    """
    Background task that consumes audio chunks from a queue and streams them to GCP.
    """
    stream_key = f"{session_id}:{speaker_id}"
    logger.info(f"🎙️ Starting streaming task for {stream_key} ({source_lang} -> {target_lang})")
    
    pipeline = _get_pipeline()
    redis = await get_redis()
    
    # Generator that yields chunks from the thread-safe queue
    def audio_generator():
        while True:
            chunk = audio_queue.get()
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
            for transcript in run_pipeline():
                # Got a final transcript!
                logger.info(f"📝 Transcript: {transcript}")
                
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
                
                # Publish
                channel = f"channel:translation:{session_id}"
                payload = {
                    "type": "translation",
                    "session_id": session_id,
                    "speaker_id": speaker_id,
                    "transcript": transcript,
                    "translation": translation,
                    "audio_content": audio_content.hex() if audio_content else None,
                    "source_lang": source_lang,
                    "target_lang": target_lang
                }
                
                # Publish back to Redis
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
            asyncio.create_task(handle_audio_stream(
                session_id, speaker_id, source_lang, target_lang, q
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