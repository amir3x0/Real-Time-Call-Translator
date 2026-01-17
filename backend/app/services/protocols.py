"""
Protocol definitions for speech pipeline services.

This module defines interfaces (Python Protocols) that allow:
- Swapping implementations (e.g., GCP → Azure → Local)
- Testing without real API credentials
- Clear contracts between components

Usage:
    from app.services.protocols import SpeechPipelineProtocol

    def process_audio(pipeline: SpeechPipelineProtocol, audio: bytes):
        transcript = pipeline.transcribe(audio, "en-US")
        translation = pipeline.translate(transcript, "en", "he")
        audio_out = pipeline.synthesize(translation, "he-IL")
"""

from typing import Protocol, Iterator, Tuple, Optional


class SpeechToTextProtocol(Protocol):
    """
    Interface for speech-to-text services.

    Implementations must provide both batch and streaming transcription.
    """

    def transcribe(self, audio_data: bytes, language_code: str) -> str:
        """
        Transcribe audio to text (batch mode).

        Args:
            audio_data: Raw PCM16 audio bytes at 16kHz
            language_code: Language code (e.g., "en-US", "he-IL")

        Returns:
            Transcribed text
        """
        ...

    def streaming_transcribe(
        self, audio_chunks: Iterator[bytes], language_code: str
    ) -> Iterator[Tuple[str, bool]]:
        """
        Stream transcribe audio, yielding results as they become available.

        Args:
            audio_chunks: Iterator of raw PCM16 audio chunks
            language_code: Language code (e.g., "en-US", "he-IL")

        Yields:
            Tuples of (transcript, is_final) where is_final indicates
            whether this is a final result or an interim result.
        """
        ...


class TranslationProtocol(Protocol):
    """
    Interface for translation services.

    Implementations should support context-aware translation for
    better coherence in conversations.
    """

    def translate(
        self,
        text: str,
        source_lang: str,
        target_lang: str,
        context: str = ""
    ) -> str:
        """
        Translate text from source to target language.

        Args:
            text: Text to translate
            source_lang: Source language code (e.g., "en", "he")
            target_lang: Target language code (e.g., "en", "he")
            context: Optional context from previous conversation
                     for better coherence (pronouns, etc.)

        Returns:
            Translated text
        """
        ...


class TextToSpeechProtocol(Protocol):
    """
    Interface for text-to-speech services.

    Implementations should return raw PCM16 audio at 16kHz.
    """

    def synthesize(
        self,
        text: str,
        language_code: str,
        voice: Optional[str] = None
    ) -> bytes:
        """
        Synthesize speech from text.

        Args:
            text: Text to synthesize
            language_code: Language code (e.g., "en-US", "he-IL")
            voice: Optional voice name/ID for the TTS service

        Returns:
            Raw PCM16 audio bytes at 16kHz
        """
        ...


class SpeechPipelineProtocol(Protocol):
    """
    Combined interface for a full speech processing pipeline.

    This protocol combines STT, translation, and TTS into a single
    interface for convenient dependency injection.

    Implementations:
        - GCPSpeechPipeline: Google Cloud Platform implementation
        - MockSpeechPipeline: For testing (returns predictable values)
    """

    def transcribe(self, audio_data: bytes, language_code: str) -> str:
        """Transcribe audio to text."""
        ...

    def streaming_transcribe(
        self, audio_chunks: Iterator[bytes], language_code: str
    ) -> Iterator[Tuple[str, bool]]:
        """Stream transcribe audio."""
        ...

    def translate(
        self,
        text: str,
        source_lang: str,
        target_lang: str,
        context: str = ""
    ) -> str:
        """Translate text."""
        ...

    def synthesize(
        self,
        text: str,
        language_code: str,
        voice: Optional[str] = None
    ) -> bytes:
        """Synthesize speech from text."""
        ...
