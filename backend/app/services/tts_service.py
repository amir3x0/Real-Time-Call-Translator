"""
Text-to-Speech Service using Resemble AI Chatterbox Multilingual

This module provides voice synthesis and zero-shot voice cloning capabilities
using the Resemble AI Chatterbox Multilingual TTS model.
"""
import asyncio
import io
from pathlib import Path
from typing import Optional, TYPE_CHECKING
import logging

if TYPE_CHECKING:
    import torch
    import torchaudio

logger = logging.getLogger(__name__)


class ChatterboxTTSService:
    """Service for text-to-speech synthesis using Resemble AI Chatterbox."""
    
    def __init__(self, device: str = "auto"):
        """Initialize the Chatterbox TTS service.
        
        Args:
            device: Device to run the model on ("cuda", "cpu", or "auto")
        """
        if device == "auto":
            try:
                import torch
                device = "cuda" if torch.cuda.is_available() else "cpu"
            except ImportError:
                device = "cpu"
        
        self.device = device
        self._model = None
        self._multilingual_model = None
        self.sample_rate = 24000  # Default sample rate for Chatterbox
        
    async def initialize(self):
        """Initialize the TTS models asynchronously."""
        logger.info(f"Initializing Chatterbox TTS on device: {self.device}")
        
        # Run model loading in thread pool to avoid blocking event loop
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_models)
        
        logger.info("Chatterbox TTS initialized successfully")
    
    def _load_models(self):
        """Load the Chatterbox models (runs in thread pool)."""
        try:
            from chatterbox.tts import ChatterboxTTS
            from chatterbox.mtl_tts import ChatterboxMultilingualTTS
            
            # Load standard model
            self._model = ChatterboxTTS.from_pretrained(device=self.device)
            
            # Load multilingual model
            self._multilingual_model = ChatterboxMultilingualTTS.from_pretrained(
                device=self.device
            )
            
            # Update sample rate from the model
            if hasattr(self._model, 'sr'):
                self.sample_rate = self._model.sr
                
        except Exception as e:
            logger.error(f"Failed to load Chatterbox models: {e}")
            raise
    
    async def synthesize(
        self,
        text: str,
        language: str = "en",
        audio_prompt_path: Optional[str] = None,
        exaggeration: float = 0.5,
        temperature: float = 1.0,
        cfg_weight: float = 0.5,
        seed: Optional[int] = None
    ) -> bytes:
        """Synthesize speech from text with optional voice cloning.
        
        Args:
            text: The text to convert to speech
            language: Language code (he, en, ru, etc.)
            audio_prompt_path: Path to reference audio for voice cloning (3-10 seconds)
            exaggeration: Controls speech expressiveness (0.25-2.0, neutral=0.5)
            temperature: Controls randomness (0.05-5.0, lower=consistent)
            cfg_weight: Guidance weight (lower for cross-language, default=0.5)
            seed: Random seed for reproducibility
            
        Returns:
            Audio data as bytes (WAV format)
        """
        if not self._multilingual_model:
            await self.initialize()
        
        logger.info(f"Synthesizing text in {language}: '{text[:50]}...'")
        
        # Run synthesis in thread pool
        loop = asyncio.get_event_loop()
        audio_bytes = await loop.run_in_executor(
            None,
            self._synthesize_sync,
            text,
            language,
            audio_prompt_path,
            exaggeration,
            temperature,
            cfg_weight,
            seed
        )
        
        return audio_bytes
    
    def _synthesize_sync(
        self,
        text: str,
        language: str,
        audio_prompt_path: Optional[str],
        exaggeration: float,
        temperature: float,
        cfg_weight: float,
        seed: Optional[int]
    ) -> bytes:
        """Synchronous synthesis (runs in thread pool).
        
        Args:
            text: The text to convert to speech
            language: Language code
            audio_prompt_path: Path to reference audio for voice cloning
            exaggeration: Controls speech expressiveness
            temperature: Controls randomness
            cfg_weight: Guidance weight
            seed: Random seed for reproducibility
            
        Returns:
            Audio data as bytes
        """
        try:
            # Generate audio using multilingual model
            kwargs = {
                "lang": language,
                "exaggeration": exaggeration,
                "temperature": temperature,
                "cfg_weight": cfg_weight,
            }
            
            if seed is not None:
                kwargs["seed"] = seed
            
            if audio_prompt_path:
                kwargs["audio_prompt_path"] = audio_prompt_path
            
            wav = self._multilingual_model.generate(text, **kwargs)
            
            # Convert tensor to bytes
            audio_bytes = self._tensor_to_bytes(wav, self.sample_rate)
            
            logger.info(f"Successfully synthesized {len(audio_bytes)} bytes of audio")
            return audio_bytes
            
        except Exception as e:
            logger.error(f"Failed to synthesize speech: {e}")
            raise
    
    def _tensor_to_bytes(self, wav_tensor, sample_rate: int) -> bytes:
        """Convert audio tensor to WAV bytes.
        
        Args:
            wav_tensor: Audio tensor from the model
            sample_rate: Sample rate in Hz
            
        Returns:
            WAV format audio as bytes
        """
        import torchaudio
        
        # Create in-memory bytes buffer
        buffer = io.BytesIO()
        
        # Save as WAV to buffer
        torchaudio.save(
            buffer,
            wav_tensor,
            sample_rate,
            format="wav"
        )
        
        # Get bytes from buffer
        buffer.seek(0)
        return buffer.read()
    
    async def clone_voice(
        self,
        text: str,
        reference_audio_path: str,
        target_language: str = "en",
        cfg_weight: float = 0.0
    ) -> bytes:
        """Clone a voice from reference audio and generate speech.
        
        For best cross-language voice cloning, cfg_weight should be set to 0.0.
        
        Args:
            text: The text to speak in the cloned voice
            reference_audio_path: Path to reference audio (3-10 seconds recommended)
            target_language: Language code for the output speech
            cfg_weight: Guidance weight (0.0 recommended for cross-language)
            
        Returns:
            Audio data as bytes (WAV format)
        """
        logger.info(f"Cloning voice from {reference_audio_path}")
        
        return await self.synthesize(
            text=text,
            language=target_language,
            audio_prompt_path=reference_audio_path,
            cfg_weight=cfg_weight,
            exaggeration=0.5,  # Neutral expressiveness for voice cloning
            temperature=0.5    # Moderate consistency
        )


# Global service instance
_tts_service: Optional[ChatterboxTTSService] = None


async def get_tts_service() -> ChatterboxTTSService:
    """Get or create the global TTS service instance.
    
    Returns:
        ChatterboxTTSService instance
    """
    global _tts_service
    
    if _tts_service is None:
        _tts_service = ChatterboxTTSService()
        await _tts_service.initialize()
    
    return _tts_service
