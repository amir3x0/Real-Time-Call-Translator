"""
Speech Detector - FFT-based speech detection with sliding window.

This module provides speech detection using spectral analysis to distinguish
speech from silence or noise. It uses frequency characteristics of human
voice (typically 80-4000 Hz) compared to background noise.

Usage:
    from app.services.audio.speech_detector import get_speech_detector

    if get_speech_detector().is_speech(stream_key, audio_chunk):
        # Process speech...
    else:
        # Handle silence...
"""

import numpy as np
from typing import Dict, Optional
from dataclasses import dataclass, field
import logging

from app.config.constants import (
    AUDIO_SAMPLE_RATE,
    SPECTRAL_HISTORY_MAX_BYTES,
    MIN_ANALYSIS_BYTES,
    FFT_SPEECH_FREQ_MIN,
    FFT_SPEECH_FREQ_MAX,
    FFT_NOISE_FREQ_MIN,
    SPEECH_NOISE_RATIO_THRESHOLD,
    RMS_SILENCE_THRESHOLD,
)

logger = logging.getLogger(__name__)


@dataclass
class SpeechDetector:
    """
    FFT-based speech detection with sliding window.

    Uses spectral analysis to distinguish speech from silence/noise
    based on frequency characteristics of human voice (80-4000 Hz).

    The detector maintains a sliding window of audio history per stream
    for more accurate detection (approximately 400ms at 16kHz).

    Attributes:
        sample_rate: Audio sample rate in Hz (default: 16000)
        history_max_bytes: Max history buffer size per stream
        min_analysis_bytes: Minimum bytes needed for FFT analysis
        speech_freq_min: Lower bound of speech frequency range (Hz)
        speech_freq_max: Upper bound of speech frequency range (Hz)
        noise_freq_min: Lower bound of noise frequency range (Hz)
        speech_noise_ratio: Threshold for speech/noise energy ratio
        rms_threshold: RMS threshold for silence detection
    """

    sample_rate: int = AUDIO_SAMPLE_RATE
    history_max_bytes: int = SPECTRAL_HISTORY_MAX_BYTES
    min_analysis_bytes: int = MIN_ANALYSIS_BYTES
    speech_freq_min: int = FFT_SPEECH_FREQ_MIN
    speech_freq_max: int = FFT_SPEECH_FREQ_MAX
    noise_freq_min: int = FFT_NOISE_FREQ_MIN
    speech_noise_ratio: float = SPEECH_NOISE_RATIO_THRESHOLD
    rms_threshold: int = RMS_SILENCE_THRESHOLD

    # Per-stream history buffers
    _history: Dict[str, bytearray] = field(default_factory=dict)

    def is_speech(self, stream_key: str, chunk: bytes) -> bool:
        """
        Detect if audio chunk contains speech.

        Uses a combination of RMS energy check and FFT spectral analysis
        to determine if the audio contains speech.

        Args:
            stream_key: Unique identifier for the audio stream
            chunk: Raw PCM16 audio bytes

        Returns:
            True if speech is detected, False otherwise
        """
        # Update history buffer
        if stream_key not in self._history:
            self._history[stream_key] = bytearray()

        history = self._history[stream_key]
        history.extend(chunk)

        # Trim to max size (sliding window)
        if len(history) > self.history_max_bytes:
            del history[:len(history) - self.history_max_bytes]

        # Need minimum data for meaningful analysis
        if len(history) < self.min_analysis_bytes:
            return True  # Assume speech when insufficient data

        try:
            # Convert to numpy array
            audio = np.frombuffer(bytes(history), dtype=np.int16).astype(np.float32)

            # RMS (Root Mean Square) check for basic volume
            rms = np.sqrt(np.mean(audio ** 2))
            if rms < self.rms_threshold:
                return False  # Too quiet - likely silence

            # FFT analysis for frequency characteristics
            fft = np.abs(np.fft.rfft(audio))
            freqs = np.fft.rfftfreq(len(audio), 1.0 / self.sample_rate)

            # Speech frequency energy (80-4000 Hz typical human voice)
            speech_mask = (freqs >= self.speech_freq_min) & (freqs <= self.speech_freq_max)
            speech_energy = np.sum(fft[speech_mask] ** 2)

            # Noise frequency energy (>5000 Hz - typically non-speech)
            noise_mask = freqs >= self.noise_freq_min
            noise_energy = np.sum(fft[noise_mask] ** 2) + 1e-10  # Avoid division by zero

            # If speech energy dominates, it's likely speech
            ratio = speech_energy / noise_energy
            is_speech = ratio > self.speech_noise_ratio

            logger.debug(
                f"[SpeechDetector] stream={stream_key}, rms={rms:.0f}, "
                f"speech_energy={speech_energy:.0f}, noise_energy={noise_energy:.0f}, "
                f"ratio={ratio:.2f}, is_speech={is_speech}"
            )

            return is_speech

        except Exception as e:
            logger.warning(f"[SpeechDetector] Error analyzing audio: {e}")
            return True  # Assume speech on error to avoid dropping valid audio

    def clear_history(self, stream_key: str):
        """
        Clear history for a specific stream.

        Call this when a stream ends or needs to be reset.

        Args:
            stream_key: Unique identifier for the audio stream
        """
        if stream_key in self._history:
            del self._history[stream_key]
            logger.debug(f"[SpeechDetector] Cleared history for {stream_key}")

    def clear_all(self):
        """Clear all stream histories."""
        self._history.clear()
        logger.debug("[SpeechDetector] Cleared all histories")

    def get_stats(self) -> dict:
        """
        Get detector statistics.

        Returns:
            Dict with active_streams and total_history_bytes
        """
        total_bytes = sum(len(h) for h in self._history.values())
        return {
            "active_streams": len(self._history),
            "total_history_bytes": total_bytes,
            "avg_history_bytes": total_bytes // max(1, len(self._history))
        }


# Global singleton instance (lazy initialization)
_speech_detector: Optional[SpeechDetector] = None


def get_speech_detector() -> SpeechDetector:
    """Get or create the global SpeechDetector instance."""
    global _speech_detector
    if _speech_detector is None:
        _speech_detector = SpeechDetector()
    return _speech_detector
