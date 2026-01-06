from __future__ import annotations

import os
import asyncio
import functools
from dataclasses import dataclass
from typing import Optional

from google.cloud import speech
from google.cloud import texttospeech
from google.cloud import translate

from app.config.settings import settings

import logging
logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    """Container for the output of the speech pipeline."""

    transcript: str
    translation: str
    synthesized_audio: bytes


class GCPSpeechPipeline:
    """Thin wrapper around Google Cloud Speech/Translate/TTS services."""

    def __init__(self, project_id: Optional[str] = None, location: str = "global"):
        # Ensure GOOGLE_APPLICATION_CREDENTIALS is set for client libraries
        if settings.GOOGLE_APPLICATION_CREDENTIALS and "GOOGLE_APPLICATION_CREDENTIALS" not in os.environ:
            creds_path = settings.GOOGLE_APPLICATION_CREDENTIALS
            # Handle Docker path when running locally
            if creds_path.startswith("/app/") and not os.path.exists(creds_path):
                # Common local paths to check
                possible_paths = [
                    creds_path.replace("/app/", ""),  # Strip /app/ prefix safely
                    creds_path.replace("/app/", "app/"), # Map /app/ to app/
                    os.path.join("app", "config", os.path.basename(creds_path)), # Hardcoded common location
                    os.path.join(os.getcwd(), "app", "config", os.path.basename(creds_path))
                ]
                
                for path in possible_paths:
                    if os.path.exists(path):
                        creds_path = path
                        break
            
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = creds_path

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
        logger.info(f"[GCP] Processing chunk of size {len(chunk)} bytes")
        
        transcript = self._transcribe(chunk, source_language_code)
        if not transcript:
            logger.debug("[GCP] No transcript generated (silence or error)")
            return PipelineResult("", "", b"")
            
        logger.info(f"[GCP] STT Result: '{transcript}'")

        translation = self._translate_text(
            transcript,
            source_language_code=source_language_code[:2],
            target_language_code=target_language_code[:2],
        )
        logger.info(f"[GCP] Translated: '{transcript}' -> '{translation}'")
        
        synthesized = self._synthesize(
            translation,
            language_code=target_language_code,
            voice_name=voice_name,
        )
        logger.info(f"[GCP] Synthesized {len(synthesized)} bytes of TTS audio")
        
        return PipelineResult(transcript, translation, synthesized)

    def _transcribe(self, chunk: bytes, language_code: str) -> str:
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
            # model="phone_call", # Removed to support more languages
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
            audio_encoding=texttospeech.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
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


    def streaming_transcribe(
        self,
        audio_generator,
        language_code: str = "he-IL",
    ):
        """
        Transcribe audio stream using Google Cloud Speech-to-Text Streaming API.
        
        Args:
            audio_generator: Iterator that yields bytes chunks.
            language_code: Language code for recognition.
            
        Yields:
            str: Final transcriptions.
        """
        if language_code.startswith("en"):
            model = "latest_long"
        else:
            model = "default"

        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
            model=model,
        )
        
        streaming_config = speech.StreamingRecognitionConfig(
            config=config,
            interim_results=True,
            single_utterance=False # We handle this manually now
        )

        SILENCE_SENTINEL = object()

        # We need a generator that we can "pause" and "resume" or just keep pulling from.
        # But streaming_recognize takes an iterable.
        # If we return from the generator, the server checks for final results and closes.
        
        # We need to peek at the audio_generator or handle special values.
        # Let's assume audio_generator yields bytes OR "SILENCE" string.

        def request_generator():
            for chunk in audio_generator:
                if chunk == b"SILENCE":
                    # End this stream segment, forcing finalization
                    return
                yield speech.StreamingRecognizeRequest(audio_content=chunk)

        while True:
            try:
                # We create a NEW request generator for each stream, 
                # but it consumes from the SAME upstream audio_generator
                requests = request_generator()
                
                responses = self._speech_client.streaming_recognize(
                    config=streaming_config,
                    requests=requests,
                )

                for response in responses:
                    if not response.results:
                        # logger.info(f"Received response with no results: {response}")
                        continue

                    result = response.results[0]
                    if not result.alternatives:
                        # logger.info("Received result with no alternatives")
                        continue

                    if result.is_final:
                        transcript = result.alternatives[0].transcript.strip()
                        if transcript:
                            yield transcript, True
                    else:
                        transcript = result.alternatives[0].transcript.strip()
                        if transcript:
                            # logger.info(f"Interim: {transcript}")
                            yield transcript, False
            except Exception as e:
                # If we run out of audio or hit an error, break. 
                # For single_utterance=True, it normally closes cleanly.
                # If it's a real error, we might want to log it.
                # But to be safe against infinite loops on error:
                logger.error(f"Stream loop error (restarting?): {e}")
                # Check if generator is exhausted? 
                # But we can't easily check for generator exhaustion without consuming.
                # For now, simplistic loop.
                # If it is just "Out of range" or forceful close, we continue.
                # But if it is a real crash, we might loop forever. 
                # Let's hope single_utterance just finishes the iteration.
                if "Audio Timeout" in str(e) or "400" in str(e):
                     break
                # break # Break on any error for safety for now
                pass
            
            # If we are using single_utterance=False (English), we only run once.
            if not streaming_config.single_utterance:
                break


@functools.lru_cache(maxsize=1)
def _get_pipeline() -> GCPSpeechPipeline:
    return GCPSpeechPipeline()


# Dedicated thread pool for GCP operations (larger than default)
from concurrent.futures import ThreadPoolExecutor
_gcp_executor = ThreadPoolExecutor(max_workers=16, thread_name_prefix="gcp_worker")


async def process_audio_chunk(
    chunk: bytes,
    source_language_code: str = "he-IL",
    target_language_code: str = "en-US",
    voice_name: Optional[str] = None,
) -> PipelineResult:
    """Async helper that executes the pipeline without blocking the event loop.
    
    Uses a dedicated thread pool to handle multiple concurrent GCP requests.
    """
    loop = asyncio.get_running_loop()
    pipeline = _get_pipeline()
    return await loop.run_in_executor(
        _gcp_executor,  # Use dedicated executor instead of default
        lambda: pipeline.process_chunk(
            chunk,
            source_language_code=source_language_code,
            target_language_code=target_language_code,
            voice_name=voice_name,
        ),
    )

