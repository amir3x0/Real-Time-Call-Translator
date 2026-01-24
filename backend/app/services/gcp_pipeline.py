from __future__ import annotations

import os
import json
import asyncio
import functools
from dataclasses import dataclass
from typing import Optional

from google.cloud import speech
from google.cloud import texttospeech
from google.cloud import translate

from app.config.settings import settings
from app.config.constants import (
    GCP_STT_SAMPLE_RATE_HZ, GCP_TTS_SAMPLE_RATE_HZ,
    GCP_STT_TIMEOUT_SEC, GCP_TRANSLATE_TIMEOUT_SEC, GCP_TTS_TIMEOUT_SEC,
    TTS_SPEAKING_RATE, TTS_PITCH,
    CONTEXT_SNIPPET_MAX_CHARS, LANGUAGE_CODE_MAP,
)

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
        # Find and set GOOGLE_APPLICATION_CREDENTIALS path
        creds_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or settings.GOOGLE_APPLICATION_CREDENTIALS
        
        # If not set or path doesn't exist, try to find credentials file
        if not creds_path or not os.path.exists(creds_path):
            possible_paths = [
                "config/google-credentials.json",  # Local relative path
                os.path.join(os.getcwd(), "config", "google-credentials.json"),
                os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "config", "google-credentials.json"),  # From app/services/ -> backend/config/
                "app/config/google-credentials.json",
                "/app/config/google-credentials.json",  # Docker path
            ]
            
            # If we had a path from settings but it was wrong, try to fix it
            if settings.GOOGLE_APPLICATION_CREDENTIALS:
                basename = os.path.basename(settings.GOOGLE_APPLICATION_CREDENTIALS)
                possible_paths.extend([
                    os.path.join("config", basename),
                    os.path.join(os.getcwd(), "config", basename),
                    settings.GOOGLE_APPLICATION_CREDENTIALS.replace("/app/", ""),
                    settings.GOOGLE_APPLICATION_CREDENTIALS.replace("/app/", "app/"),
                ])
            
            for path in possible_paths:
                if os.path.exists(path):
                    creds_path = os.path.abspath(path)
                    logger.info(f"Found credentials file at: {creds_path}")
                    break
        
        # Set environment variable if we found a valid path
        if creds_path and os.path.exists(creds_path):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = creds_path
        else:
            logger.warning("GOOGLE_APPLICATION_CREDENTIALS not found. GCP services may fail.")

        # Try to get project_id from: parameter, environment variable, or credentials file
        self.project_id = project_id or settings.GOOGLE_PROJECT_ID
        
        # If still not set, try to read from credentials JSON file
        if not self.project_id and creds_path and os.path.exists(creds_path):
            try:
                with open(creds_path, 'r') as f:
                    creds_data = json.load(f)
                    self.project_id = creds_data.get('project_id')
                    if self.project_id:
                        logger.info(f"Read project_id '{self.project_id}' from credentials file")
            except Exception as e:
                logger.warning(f"Could not read project_id from credentials file: {e}")
        
        if not self.project_id:
            raise RuntimeError(
                "GOOGLE_PROJECT_ID is not set. Please set it in environment variable, .env file, or ensure it's in google-credentials.json"
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
        
        # DEBUG: Save first few chunks to file for analysis
        import time
        debug_file = f"/app/data/debug_audio_{int(time.time())}.pcm"
        try:
            with open(debug_file, "wb") as f:
                f.write(chunk)
            logger.info(f"[GCP] DEBUG: Saved audio chunk to {debug_file}")
        except Exception as e:
            logger.warning(f"[GCP] DEBUG: Could not save audio: {e}")
        
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
        logger.info(f"[GCP] STT Starting for {len(chunk)} bytes, lang={language_code}")
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=GCP_STT_SAMPLE_RATE_HZ,
            language_code=language_code,
            enable_automatic_punctuation=True,
        )
        audio = speech.RecognitionAudio(content=chunk)
        try:
            # Add explicit timeout safely (fail fast)
            response = self._speech_client.recognize(
                config=config,
                audio=audio,
                timeout=GCP_STT_TIMEOUT_SEC
            )
            logger.info(f"[GCP] STT Response: results_count={len(response.results) if response.results else 0}")
            if not response.results:
                logger.info("[GCP] STT: No speech detected in this chunk")
                return ""
            transcript = " ".join(
                result.alternatives[0].transcript.strip()
                for result in response.results
                if result.alternatives
            ).strip()
            logger.info(f"[GCP] STT Transcript: '{transcript}'")
            return transcript
        except Exception as e:
            logger.error(f"[GCP] STT Error: {e}")
            return ""

    def _translate_text(
        self,
        text: str,
        *,
        source_language_code: str,
        target_language_code: str,
    ) -> str:
        # Skip translation if source and target languages are the same
        # GCP Translate API returns 400 error for source == target
        if source_language_code == target_language_code:
            logger.debug(f"[GCP] Skipping translation - same language: {source_language_code}")
            return text

        parent = f"projects/{self.project_id}/locations/{self.location}"
        try:
            response = self._translate_client.translate_text(
                request={
                    "parent": parent,
                    "contents": [text],
                    "mime_type": "text/plain",
                    "source_language_code": source_language_code,
                    "target_language_code": target_language_code,
                },
                timeout=GCP_TRANSLATE_TIMEOUT_SEC
            )
            if not response.translations:
                return ""
            return response.translations[0].translated_text
        except Exception as e:
            logger.error(f"[GCP] Translate Error: {e}")
            return text  # Fallback to original text

    def _get_clean_context(self, text: str, max_chars: int) -> str:
        """
        Slice context at word boundaries, not mid-word.

        This ensures context doesn't end with partial words like "...he sa"
        but instead ends at word boundaries like "...he said".

        Args:
            text: The context text to slice
            max_chars: Maximum characters to keep

        Returns:
            Context string sliced at word boundary
        """
        if not text or len(text) <= max_chars:
            return text.strip() if text else ""

        # Take last max_chars characters
        truncated = text[-max_chars:]

        # Find first space to start at word boundary
        first_space = truncated.find(' ')
        if first_space > 0 and first_space < len(truncated) - 1:
            # Skip partial word at the beginning
            return truncated[first_space:].strip()

        return truncated.strip()

    def _translate_text_with_context(
        self,
        text: str,
        context_history: str,
        *,
        source_language_code: str,
        target_language_code: str,
    ) -> str:
        """
        Translate text with context from previous segments (Phase 4).

        This helps the translation API understand the conversation flow
        and produce more coherent translations.

        Args:
            text: The text to translate
            context_history: Previous transcript text for context
            source_language_code: Source language (e.g., "en")
            target_language_code: Target language (e.g., "he")

        Returns:
            Translated text
        """
        # Skip translation if source and target languages are the same
        # GCP Translate API returns 400 error for source == target
        if source_language_code == target_language_code:
            logger.debug(f"[GCP] Skipping context translation - same language: {source_language_code}")
            return text

        # If no context, use regular translation
        if not context_history or len(context_history.strip()) == 0:
            return self._translate_text(
                text,
                source_language_code=source_language_code,
                target_language_code=target_language_code
            )

        # Create a context-aware prompt
        # Note: GCP Translate doesn't have native context support,
        # so we format the context as a hint that helps with coherence
        # Use word-boundary aware slicing to avoid cutting mid-word
        context_snippet = self._get_clean_context(context_history, CONTEXT_SNIPPET_MAX_CHARS)
        
        # Format: Translate the continuation of a conversation
        # The context helps with pronouns, subject continuity, etc.
        text_with_context = f"[...{context_snippet}] {text}"
        
        try:
            result = self._translate_text(
                text_with_context,
                source_language_code=source_language_code,
                target_language_code=target_language_code
            )
            
            # Remove any translated context prefix if present
            # (GCP might translate the [...] part)
            if result.startswith("[") and "]" in result:
                # Find the closing bracket and skip past it
                bracket_end = result.index("]") + 1
                result = result[bracket_end:].strip()
            
            logger.info(f"[GCP] Context-aware translation: '{text}' -> '{result}' (with {len(context_snippet)} chars context)")
            return result
            
        except Exception as e:
            logger.warning(f"Context-aware translation failed: {e}, falling back to regular translation")
            return self._translate_text(
                text,
                source_language_code=source_language_code,
                target_language_code=target_language_code
            )

    def _synthesize(
        self,
        text: str,
        *,
        language_code: str,
        voice_name: Optional[str],
    ) -> bytes:
        # Normalize language code to full format (e.g., "en" -> "en-US")
        if "-" not in language_code:
            language_code = LANGUAGE_CODE_MAP.get(language_code.lower(), f"{language_code}-{language_code.upper()}")
        
        voice_params = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            name=voice_name or f"{language_code}-Standard-A",
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.LINEAR16,
            sample_rate_hertz=GCP_TTS_SAMPLE_RATE_HZ,
            speaking_rate=TTS_SPEAKING_RATE,
            pitch=TTS_PITCH,
        )
        synthesis_input = texttospeech.SynthesisInput(text=text)
        try:
            response = self._tts_client.synthesize_speech(
                input=synthesis_input,
                voice=voice_params,
                audio_config=audio_config,
                timeout=GCP_TTS_TIMEOUT_SEC
            )
            return response.audio_content
        except Exception as e:
            logger.error(f"[GCP] TTS Error: {e}")
            return b""


    def streaming_transcribe(
        self,
        audio_generator,
        language_code: str = "he-IL",
    ):
        """
        Transcribe audio stream using Google Cloud Speech-to-Text Streaming API.

        Used for real-time interim captions (typing indicator).
        Translations are handled separately by the batch pipeline.

        Args:
            audio_generator: Iterator that yields bytes chunks.
            language_code: Language code for recognition.

        Yields:
            Tuple[str, bool]: (transcript, is_final)
            - transcript: The transcribed text
            - is_final: True for final results, False for interim
        """
        if language_code.startswith("en"):
            model = "latest_long"
        else:
            model = "default"

        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
            sample_rate_hertz=GCP_STT_SAMPLE_RATE_HZ,
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

        # Track last interim transcript to avoid duplicates
        # Google sends the FULL transcript so far in each interim update,
        # so we need to deduplicate to avoid showing the same text multiple times
        last_interim_transcript = ""
        
        def request_generator():
            chunk_count = 0
            for chunk in audio_generator:
                chunk_count += 1
                logger.info(f"[GCP Streaming] Received chunk #{chunk_count}, size={len(chunk)} bytes")
                if chunk == b"SILENCE":
                    # End this stream segment, forcing finalization
                    logger.info(f"[GCP Streaming] SILENCE marker received after {chunk_count} chunks, ending stream")
                    return
                yield speech.StreamingRecognizeRequest(audio_content=chunk)
            logger.info(f"[GCP Streaming] Generator exhausted after {chunk_count} chunks")

        # Process streaming recognition - run once per stream
        # The while loop was causing issues by recreating request_generator multiple times
        try:
            requests = request_generator()
            
            responses = self._speech_client.streaming_recognize(
                config=streaming_config,
                requests=requests,
            )

            logger.info("[GCP Streaming] Waiting for responses...")
            response_count = 0
            for response in responses:
                response_count += 1
                if not response.results:
                    logger.debug(f"[GCP Streaming] Response #{response_count}: no results")
                    continue

                result = response.results[0]
                if not result.alternatives:
                    continue

                transcript = result.alternatives[0].transcript.strip()
                
                if result.is_final:
                    if transcript:
                        logger.info(f"[GCP Streaming] Final: '{transcript[:50]}...'")
                        last_interim_transcript = ""
                        yield transcript, True
                else:
                    # Interim result - only yield if it's different from the last one
                    # This prevents duplicate interim results when Google sends the same
                    # full transcript multiple times as the user continues speaking
                    if transcript and transcript != last_interim_transcript:
                        last_interim_transcript = transcript
                        yield transcript, False
                        
        except Exception as e:
            # Audio timeout is expected when the stream ends - don't log as error
            # Other errors should be logged
            if "Audio Timeout" not in str(e):
                logger.error(f"Stream loop error: {e}")
            # Break on any error - the stream is done
            # Don't retry in a loop as this causes duplicate processing
            pass

    # =========================================================================
    # Protocol-compliant public methods (for SpeechPipelineProtocol)
    # =========================================================================

    def transcribe(self, audio_data: bytes, language_code: str) -> str:
        """
        Transcribe audio to text (protocol-compliant wrapper).

        Args:
            audio_data: Raw PCM16 audio bytes at 16kHz
            language_code: Language code (e.g., "en-US", "he-IL")

        Returns:
            Transcribed text
        """
        return self._transcribe(audio_data, language_code)

    def translate(
        self,
        text: str,
        source_lang: str,
        target_lang: str,
        context: str = ""
    ) -> str:
        """
        Translate text (protocol-compliant wrapper).

        Args:
            text: Text to translate
            source_lang: Source language code (e.g., "en", "he")
            target_lang: Target language code (e.g., "en", "he")
            context: Optional context for better translation coherence

        Returns:
            Translated text
        """
        if context:
            return self._translate_text_with_context(
                text,
                context,
                source_language_code=source_lang,
                target_language_code=target_lang
            )
        return self._translate_text(
            text,
            source_language_code=source_lang,
            target_language_code=target_lang
        )

    def synthesize(
        self,
        text: str,
        language_code: str,
        voice: Optional[str] = None
    ) -> bytes:
        """
        Synthesize speech from text (protocol-compliant wrapper).

        Args:
            text: Text to synthesize
            language_code: Language code (e.g., "en-US", "he-IL")
            voice: Optional voice name

        Returns:
            Raw PCM16 audio bytes
        """
        return self._synthesize(text, language_code=language_code, voice_name=voice)


@functools.lru_cache(maxsize=1)
def _get_pipeline() -> GCPSpeechPipeline:
    return GCPSpeechPipeline()


# Dedicated thread pool for GCP operations (larger than default)
from concurrent.futures import ThreadPoolExecutor
_gcp_executor = ThreadPoolExecutor(max_workers=16, thread_name_prefix="gcp_worker")


def get_gcp_executor() -> ThreadPoolExecutor:
    """
    Get the dedicated thread pool executor for GCP operations.

    This executor should be used for all blocking GCP API calls
    (STT, Translation, TTS) to prevent thread pool starvation.

    Returns:
        ThreadPoolExecutor with 16 workers
    """
    return _gcp_executor


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

