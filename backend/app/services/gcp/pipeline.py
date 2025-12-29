"""
GCP Pipeline Service

Coordinates Speech-to-Text, Translation, and Text-to-Speech services.
"""

import asyncio
import functools
from dataclasses import dataclass
from typing import Optional

from app.services.gcp.speech import GCPSpeechService
from app.services.gcp.translate import GCPTranslationService
from app.services.gcp.tts import GCPTextToSpeechService


@dataclass
class PipelineResult:
    """Container for the output of the speech pipeline."""
    transcript: str
    translation: str
    synthesized_audio: bytes


class GCPSpeechPipeline:
    """Thin wrapper around Google Cloud Speech/Translate/TTS services."""

    def __init__(self, project_id: Optional[str] = None, location: str = "global"):
        self.speech_service = GCPSpeechService()
        self.translation_service = GCPTranslationService(project_id, location)
        self.tts_service = GCPTextToSpeechService()

    def process_chunk(
        self,
        chunk: bytes,
        source_language_code: str = "he-IL",
        target_language_code: str = "en-US",
        voice_name: Optional[str] = None,
    ) -> PipelineResult:
        """Run transcription -> translation -> speech synthesis for a chunk."""
        # 1. Transcribe
        transcript = self.speech_service.transcribe(chunk, source_language_code)
        if not transcript:
            return PipelineResult("", "", b"")

        # 2. Translate
        translation = self.translation_service.translate_text(
            transcript,
            source_language_code=source_language_code[:2],
            target_language_code=target_language_code[:2],
        )

        # 3. Synthesize
        synthesized = self.tts_service.synthesize(
            translation,
            language_code=target_language_code,
            voice_name=voice_name,
        )
        
        return PipelineResult(transcript, translation, synthesized)

    # Proxy method for streaming transcription used by the worker
    def streaming_transcribe(
        self,
        audio_generator,
        language_code: str = "he-IL",
    ):
        """
        Transcribe audio stream using Google Cloud Speech-to-Text Streaming API.
        Proxies to speech service.
        """
        return self.speech_service.streaming_transcribe(audio_generator, language_code)
    
    # Internal helpers proxies for worker direct access if needed (though worker uses pipeline methods mostly)
    # The worker accesses `_translate_text` and `_synthesize` directly in `_run_pipeline`.
    # We should expose public methods for these to avoid breaking the worker logic
    # or update the worker to use the services.
    # The requirement is to update the worker later, but for now `GCPSpeechPipeline` 
    # should arguably expose these.
    
    def _translate_text(self, *args, **kwargs):
        """Backwards compatibility proxy for worker."""
        return self.translation_service.translate_text(*args, **kwargs)
        
    def _synthesize(self, *args, **kwargs):
        """Backwards compatibility proxy for worker."""
        return self.tts_service.synthesize(*args, **kwargs)


@functools.lru_cache(maxsize=1)
def _get_pipeline() -> GCPSpeechPipeline:
    return GCPSpeechPipeline()


async def process_audio_chunk(
    chunk: bytes,
    source_language_code: str = "he-IL",
    target_language_code: str = "en-US",
    voice_name: Optional[str] = None,
) -> PipelineResult:
    """Async helper that executes the pipeline without blocking the event loop."""
    loop = asyncio.get_running_loop()
    pipeline = _get_pipeline()
    return await loop.run_in_executor(
        None,
        lambda: pipeline.process_chunk(
            chunk,
            source_language_code=source_language_code,
            target_language_code=target_language_code,
            voice_name=voice_name,
        ),
    )
