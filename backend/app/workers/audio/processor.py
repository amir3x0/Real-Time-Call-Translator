"""
Audio Stream Processor

Handles the processing pipeline for a single audio stream.
"""

import asyncio
import logging
import queue
from typing import Optional

from app.workers.audio.config import StreamConfig
# Import from the new GCP package
from app.services.gcp import _get_pipeline, GCPSpeechPipeline

logger = logging.getLogger(__name__)


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
        self._pipeline: GCPSpeechPipeline = _get_pipeline()
        
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
        # Note: streaming_transcribe is a proxy on the pipeline object
        for transcript in self._pipeline.streaming_transcribe(
            self._audio_generator(),
            language_code=self._config.source_lang
        ):
            if not self._running:
                break
                
            logger.info(f"📝 Transcript: {transcript}")
            
            # Translate
            translation = self._pipeline.translation_service.translate_text(
                transcript,
                source_language_code=self._config.source_lang[:2],
                target_language_code=self._config.target_lang[:2]
            )
            logger.info(f"🔄 Translation: {translation}")
            
            # TTS
            audio_content = self._pipeline.tts_service.synthesize(
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
            import json
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
