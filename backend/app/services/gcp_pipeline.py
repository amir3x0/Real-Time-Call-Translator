from __future__ import annotations

import asyncio
import functools
from dataclasses import dataclass
from typing import Optional

from google.cloud import speech
from google.cloud import texttospeech
from google.cloud import translate

from app.config.settings import settings


@dataclass
class PipelineResult:
    """Container for the output of the speech pipeline."""

    transcript: str
    translation: str
    synthesized_audio: bytes


class GCPSpeechPipeline:
    """Thin wrapper around Google Cloud Speech/Translate/TTS services."""

    def __init__(self, project_id: Optional[str] = None, location: str = "global"):
        self.project_id = project_id or settings.GOOGLE_PROJECT_ID
        if not self.project_id:
            raise RuntimeError(
                "GOOGLE_PROJECT_ID is not set. Please update backend/.env accordingly."
            )

        self.location = location
        self._speech_client = speech.SpeechClient()
        self._translate_client = translate.TranslationServiceClient()
        self._tts_client = texttospeech.TextToSpeechClient()

    def process_chunk(
        self,
        chunk: bytes,
        source_language_code: str = "he-IL",
        target_language_code: str = "en-US",
        voice_name: Optional[str] = None,
    ) -> PipelineResult:
        """Run transcription -> translation -> speech synthesis for a chunk."""
        transcript = self._transcribe(chunk, source_language_code)
        if not transcript:
            return PipelineResult("", "", b"")

        translation = self._translate_text(
            transcript,
            source_language_code=source_language_code[:2],
            target_language_code=target_language_code[:2],
        )
        synthesized = self._synthesize(
            translation,
            language_code=target_language_code,
            voice_name=voice_name,
        )
        return PipelineResult(transcript, translation, synthesized)

    def _transcribe(self, chunk: bytes, language_code: str) -> str:
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
            model="phone_call",
        )
        audio = speech.RecognitionAudio(content=chunk)
        response = self._speech_client.recognize(config=config, audio=audio)
        if not response.results:
            return ""
        return " ".join(
            result.alternatives[0].transcript.strip()
            for result in response.results
            if result.alternatives
        ).strip()

    def _translate_text(
        self,
        text: str,
        *,
        source_language_code: str,
        target_language_code: str,
    ) -> str:
        parent = f"projects/{self.project_id}/locations/{self.location}"
        response = self._translate_client.translate_text(
            request={
                "parent": parent,
                "contents": [text],
                "mime_type": "text/plain",
                "source_language_code": source_language_code,
                "target_language_code": target_language_code,
            }
        )
        if not response.translations:
            return ""
        return response.translations[0].translated_text

    def _synthesize(
        self,
        text: str,
        *,
        language_code: str,
        voice_name: Optional[str],
    ) -> bytes:
        voice_params = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            name=voice_name or f"{language_code}-Standard-A",
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=1.0,
            pitch=0.0,
        )
        synthesis_input = texttospeech.SynthesisInput(text=text)
        response = self._tts_client.synthesize_speech(
            input=synthesis_input,
            voice=voice_params,
            audio_config=audio_config,
        )
        return response.audio_content


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

