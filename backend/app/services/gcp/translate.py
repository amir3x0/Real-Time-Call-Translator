"""
GCP Translation Service

Handles Google Cloud Translation operations.
"""

import os
from typing import Optional
from google.cloud import translate
from app.config.settings import settings


class GCPTranslationService:
    """Handles translation operations."""

    def __init__(self, project_id: Optional[str] = None, location: str = "global"):
        self.project_id = project_id or settings.GOOGLE_PROJECT_ID
        if not self.project_id:
            raise RuntimeError(
                "GOOGLE_PROJECT_ID is not set. Please update backend/.env accordingly."
            )
        self.location = location
        self._ensure_credentials()
        self._client = translate.TranslationServiceClient()

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

    def translate_text(
        self,
        text: str,
        *,
        source_language_code: str,
        target_language_code: str,
    ) -> str:
        """Translate text from source to target language."""
        parent = f"projects/{self.project_id}/locations/{self.location}"
        
        response = self._client.translate_text(
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
