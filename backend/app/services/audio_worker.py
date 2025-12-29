"""
Audio Worker Service

Class-based architecture for processing audio streams via Redis.
Each speaker's stream is encapsulated in a StreamProcessor instance.
"""

import asyncio
import json
import logging
import os
import queue
from typing import Dict, Optional
from dataclasses import dataclass, field

from app.config.redis import get_redis
from app.services.gcp_pipeline import _get_pipeline
from app.config.settings import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class StreamConfig:
    """Configuration for a stream processor."""
    session_id: str
    speaker_id: str
    source_lang: str
    target_lang: str
    
    @property
    def stream_key(self) -> str:
        return f"{self.session_id}:{self.speaker_id}"


class StreamProcessor:
    """
    Encapsulates a single user's audio stream processing.
    
    Handles:
    - Queue management for audio chunks
    - GCP pipeline execution (STT -> Translation -> TTS)
    - Publishing results back to Redis
    """
    
    def __init__(self, config: StreamConfig, redis):
        self._config = config
        self._redis = redis
        self._queue: queue.Queue = queue.Queue()
        self._task: Optional[asyncio.Task] = None
        self._running = False
        self._pipeline = _get_pipeline()
        
    @property
    def stream_key(self) -> str:
        return self._config.stream_key
    
    def enqueue_chunk(self, audio_data: bytes) -> None:
        """Add an audio chunk to the processing queue."""
        if self._running:
            self._queue.put(audio_data)
    
    async def start(self) -> None:
        """Start the background processing task."""
        if self._running:
            logger.warning(f"StreamProcessor {self.stream_key} already running")
            return
            
        self._running = True
        self._task = asyncio.create_task(self._process_loop())
        logger.info(f"🎙️ Started StreamProcessor for {self.stream_key} "
                   f"({self._config.source_lang} -> {self._config.target_lang})")
    
    async def stop(self) -> None:
        """Gracefully stop processing and cleanup resources."""
        if not self._running:
            return
            
        self._running = False
        self._queue.put(None)  # Sentinel to stop generator
        
        if self._task:
            try:
                await asyncio.wait_for(self._task, timeout=5.0)
            except asyncio.TimeoutError:
                logger.warning(f"StreamProcessor {self.stream_key} stop timed out, cancelling")
                self._task.cancel()
                try:
                    await self._task
                except asyncio.CancelledError:
                    pass
                    
        logger.info(f"StreamProcessor {self.stream_key} stopped")
    
    def _audio_generator(self):
        """Generator that yields chunks from the thread-safe queue."""
        while True:
            chunk = self._queue.get()
            if chunk is None:  # Sentinel value
                return
            yield chunk
    
    def _run_pipeline(self):
        """Execute the blocking GCP pipeline. Runs in executor."""
        for transcript in self._pipeline.streaming_transcribe(
            self._audio_generator(),
            language_code=self._config.source_lang
        ):
            if not self._running:
                break
                
            logger.info(f"📝 Transcript: {transcript}")
            
            # Translate
            translation = self._pipeline._translate_text(
                transcript,
                source_language_code=self._config.source_lang[:2],
                target_language_code=self._config.target_lang[:2]
            )
            logger.info(f"🔄 Translation: {translation}")
            
            # TTS
            audio_content = self._pipeline._synthesize(
                translation,
                language_code=self._config.target_lang,
                voice_name=None
            )
            
            yield {
                "transcript": transcript,
                "translation": translation,
                "audio_content": audio_content
            }
    
    async def _process_loop(self) -> None:
        """Main processing loop - runs pipeline in executor and publishes results."""
        loop = asyncio.get_running_loop()
        channel = f"channel:translation:{self._config.session_id}"
        
        try:
            def process_and_collect():
                results = []
                for result in self._run_pipeline():
                    results.append(result)
                return results
            
            # Run blocking pipeline in executor
            results = await loop.run_in_executor(None, process_and_collect)
            
            # Publish results
            for result in results:
                payload = {
                    "type": "translation",
                    "session_id": self._config.session_id,
                    "speaker_id": self._config.speaker_id,
                    "transcript": result["transcript"],
                    "translation": result["translation"],
                    "audio_content": result["audio_content"].hex() if result["audio_content"] else None,
                    "source_lang": self._config.source_lang,
                    "target_lang": self._config.target_lang
                }
                await self._redis.publish(channel, json.dumps(payload))
                
        except Exception as e:
            logger.error(f"Error in StreamProcessor {self.stream_key}: {e}")
        finally:
            self._running = False
            logger.info(f"StreamProcessor {self.stream_key} processing ended")


class StreamProcessorManager:
    """
    Manages active StreamProcessor instances.
    
    Thread-safe management of stream processors with automatic cleanup.
    """
    
    def __init__(self):
        self._processors: Dict[str, StreamProcessor] = {}
        self._lock = asyncio.Lock()
    
    async def get_or_create(
        self,
        session_id: str,
        speaker_id: str,
        source_lang: str,
        target_lang: str,
        redis
    ) -> StreamProcessor:
        """Get existing or create new processor for the given stream."""
        config = StreamConfig(
            session_id=session_id,
            speaker_id=speaker_id,
            source_lang=source_lang,
            target_lang=target_lang
        )
        key = config.stream_key
        
        async with self._lock:
            if key not in self._processors:
                processor = StreamProcessor(config, redis)
                self._processors[key] = processor
                await processor.start()
            return self._processors[key]
    
    async def remove(self, stream_key: str) -> None:
        """Stop and remove a processor."""
        async with self._lock:
            if stream_key in self._processors:
                await self._processors[stream_key].stop()
                del self._processors[stream_key]
    
    async def cleanup_all(self) -> None:
        """Stop all processors. Call on shutdown."""
        async with self._lock:
            for processor in self._processors.values():
                await processor.stop()
            self._processors.clear()
        logger.info("All StreamProcessors cleaned up")
    
    @property
    def active_count(self) -> int:
        """Number of active processors."""
        return len(self._processors)


class AudioWorker:
    """
    Main worker class that listens to Redis streams and dispatches to processors.
    
    Separates Redis listening logic from stream processing.
    """
    
    def __init__(self, manager: Optional[StreamProcessorManager] = None):
        self._manager = manager or StreamProcessorManager()
        self._running = False
        self._redis = None
        
    async def run(self) -> None:
        """Main Redis listening loop."""
        logger.info("Starting Audio Worker...")
        self._redis = await get_redis()
        
        stream_key = "stream:audio:global"
        group_name = "audio_processors"
        consumer_name = f"worker_{os.getpid()}"
        
        # Create consumer group if needed
        try:
            await self._redis.xgroup_create(stream_key, group_name, mkstream=True)
        except Exception as e:
            if "BUSYGROUP" not in str(e):
                logger.error(f"Error creating consumer group: {e}")
        
        logger.info(f"Listening on {stream_key}...")
        self._running = True
        
        while self._running:
            try:
                streams = await self._redis.xreadgroup(
                    group_name,
                    consumer_name,
                    {stream_key: ">"},
                    count=10,
                    block=2000
                )
                
                for stream, messages in streams:
                    for message_id, data in messages:
                        await self._process_message(stream, message_id, data)
                        
            except Exception as e:
                if self._running:  # Only log if not shutting down
                    logger.error(f"Error in worker loop: {e}")
                    await asyncio.sleep(1)
    
    async def _process_message(
        self,
        stream_key: str,
        message_id: str,
        data: dict
    ) -> None:
        """Process a single message from Redis stream."""
        try:
            # Extract audio data
            audio_data = data.get(b"data")
            if not audio_data:
                return
            
            # Extract metadata with defaults
            source_lang = data.get(b"source_lang", b"he-IL").decode("utf-8")
            target_lang = data.get(b"target_lang", b"en-US").decode("utf-8")
            speaker_id = data.get(b"speaker_id", b"unknown").decode("utf-8")
            session_id = data.get(b"session_id", b"unknown").decode("utf-8")
            
            # Get or create processor and enqueue chunk
            processor = await self._manager.get_or_create(
                session_id=session_id,
                speaker_id=speaker_id,
                source_lang=source_lang,
                target_lang=target_lang,
                redis=self._redis
            )
            processor.enqueue_chunk(audio_data)
            
            # Acknowledge message
            await self._redis.xack(stream_key, "audio_group", message_id)
            
        except Exception as e:
            logger.error(f"Error processing message {message_id}: {e}")
    
    async def shutdown(self) -> None:
        """Clean shutdown of worker and all streams."""
        logger.info("Shutting down Audio Worker...")
        self._running = False
        await self._manager.cleanup_all()
        logger.info("Audio Worker shutdown complete")


# Module-level convenience function for backwards compatibility
async def run_worker() -> None:
    """Run the audio worker. Convenience function for main entry point."""
    worker = AudioWorker()
    try:
        await worker.run()
    except KeyboardInterrupt:
        await worker.shutdown()


if __name__ == "__main__":
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        logger.info("Worker stopped")