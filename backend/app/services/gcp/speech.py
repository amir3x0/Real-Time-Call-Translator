"""
GCP Speech Service

Handles Google Cloud Speech-to-Text operations.
"""

import os
from typing import Generator
from google.cloud import speech
from app.config.settings import settings


class GCPSpeechService:
    """Handles Speech-to-Text operations."""

    def __init__(self):
        self._ensure_credentials()
        self._client = speech.SpeechClient()

    def _ensure_credentials(self):
        """Ensure Google credentials are set in environment."""
        if settings.GOOGLE_APPLICATION_CREDENTIALS and "GOOGLE_APPLICATION_CREDENTIALS" not in os.environ:
            creds_path = settings.GOOGLE_APPLICATION_CREDENTIALS
            if creds_path.startswith("/app/") and not os.path.exists(creds_path):
                possible_paths = [
                    creds_path.replace("/app/", ""),
                    creds_path.replace("/app/", "app/"),
                    os.path.join("app", "config", os.path.basename(creds_path)),
                    os.path.join(os.getcwd(), "app", "config", os.path.basename(creds_path))
                ]
                
                for path in possible_paths:
                    if os.path.exists(path):
                        creds_path = path
                        break
            
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = creds_path

    def transcribe(self, chunk: bytes, language_code: str) -> str:
        """Transcribe a single audio chunk."""
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
        )
        audio = speech.RecognitionAudio(content=chunk)
        
        try:
            response = self._client.recognize(config=config, audio=audio)
            if not response.results:
                return ""
                
            return " ".join(
                result.alternatives[0].transcript.strip()
                for result in response.results
                if result.alternatives
            ).strip()
        except Exception as e:
            # Log error but don't crash the flow? Original code didn't try/except, but good practice.
            # Sticking to original logic closely to avoid behavior change.
            raise e

    def streaming_transcribe(
        self,
        audio_generator,
        language_code: str = "he-IL",
    ) -> Generator[str, None, None]:
        """
        Transcribe audio stream using Google Cloud Speech-to-Text Streaming API.
        
        Args:
            audio_generator: Iterator that yields bytes chunks.
            language_code: Language code for recognition.
            
        Yields:
            str: Final transcriptions.
        """
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000,
            language_code=language_code,
            enable_automatic_punctuation=True,
        )
        
        streaming_config = speech.StreamingRecognitionConfig(
            config=config,
            interim_results=True
        )

        # Generator to yield StreamingRecognizeRequest
        def request_generator():
            for chunk in audio_generator:
                yield speech.StreamingRecognizeRequest(audio_content=chunk)

        responses = self._client.streaming_recognize(
            config=streaming_config,
            requests=request_generator(),
        )

        for response in responses:
            if not response.results:
                continue

            result = response.results[0]
            if not result.alternatives:
                continue

            if result.is_final:
                transcript = result.alternatives[0].transcript.strip()
                if transcript:
                    yield transcript
