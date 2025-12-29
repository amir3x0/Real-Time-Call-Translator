"""
GCP Text-to-Speech Service

Handles Google Cloud Text-to-Speech operations.
"""

import os
from typing import Optional
from google.cloud import texttospeech
from app.config.settings import settings


class GCPTextToSpeechService:
    """Handles Text-to-Speech operations."""

    def __init__(self):
        self._ensure_credentials()
        self._client = texttospeech.TextToSpeechClient()

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

    def synthesize(
        self,
        text: str,
        *,
        language_code: str,
        voice_name: Optional[str] = None,
    ) -> bytes:
        """Synthesize text to speech audio."""
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
        
        response = self._client.synthesize_speech(
            input=synthesis_input,
            voice=voice_params,
            audio_config=audio_config,
        )
        
        return response.audio_content
