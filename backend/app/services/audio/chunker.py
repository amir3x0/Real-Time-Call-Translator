"""
Audio Chunker - Pause-based audio segmentation.

This module provides intelligent audio chunking based on silence detection
and time-based forcing, ensuring optimal segment boundaries for translation.

Usage:
    from app.services.audio.chunker import AudioChunker

    chunker = AudioChunker(
        on_chunk_ready=lambda audio: process_audio(audio),
        speech_detector=speech_detector
    )

    for chunk in audio_stream:
        chunker.feed(chunk)

    chunker.flush()  # Process remaining audio
"""

import time
import queue
import logging
from typing import Callable, Optional, Union, Iterator
from dataclasses import dataclass, field

from app.config.constants import (
    AUDIO_SAMPLE_RATE,
    AUDIO_BYTES_PER_SAMPLE,
    SILENCE_THRESHOLD_SEC,
    MIN_AUDIO_LENGTH_SEC,
    AUDIO_QUEUE_READ_TIMEOUT_SEC,
    MAX_ACCUMULATED_AUDIO_TIME_SEC,
)
from app.services.audio.speech_detector import SpeechDetector

logger = logging.getLogger(__name__)


@dataclass
class ChunkResult:
    """Result of a chunk processing trigger."""
    audio_data: bytes
    trigger_reason: str
    chunk_count: int
    duration_seconds: float


class AudioChunker:
    """
    Pause-based audio chunker with time-based forcing.

    Accumulates audio chunks and triggers processing when:
    1. Silence is detected after speech (pause-based)
    2. Maximum accumulation time is reached (time-based forcing)
    3. Stream ends (flush remaining)

    This approach provides natural sentence boundaries for translation
    while preventing indefinite buffering during continuous speech.

    Attributes:
        stream_key: Unique identifier for this audio stream
        on_chunk_ready: Callback invoked when audio is ready to process
        speech_detector: SpeechDetector instance for voice activity detection
    """

    def __init__(
        self,
        stream_key: str,
        on_chunk_ready: Callable[[ChunkResult], None],
        speech_detector: SpeechDetector,
        silence_threshold: float = SILENCE_THRESHOLD_SEC,
        min_audio_length: float = MIN_AUDIO_LENGTH_SEC,
        max_accumulation_time: float = MAX_ACCUMULATED_AUDIO_TIME_SEC,
        sample_rate: int = AUDIO_SAMPLE_RATE,
        bytes_per_sample: int = AUDIO_BYTES_PER_SAMPLE,
    ):
        """
        Initialize the audio chunker.

        Args:
            stream_key: Unique identifier for this audio stream
            on_chunk_ready: Callback when audio chunk is ready to process
            speech_detector: SpeechDetector for voice activity detection
            silence_threshold: Seconds of silence before triggering
            min_audio_length: Minimum audio length before processing
            max_accumulation_time: Max seconds before forced processing
            sample_rate: Audio sample rate in Hz
            bytes_per_sample: Bytes per audio sample
        """
        self.stream_key = stream_key
        self.on_chunk_ready = on_chunk_ready
        self.speech_detector = speech_detector

        # Configuration
        self.silence_threshold = silence_threshold
        self.min_audio_length = min_audio_length
        self.max_accumulation_time = max_accumulation_time
        self.min_bytes = int(min_audio_length * sample_rate * bytes_per_sample)

        # State
        self._audio_buffer = bytearray()
        self._last_voice_time = time.time()
        self._last_process_time = time.time()
        self._chunk_count = 0
        self._is_shutdown = False

    def feed(self, chunk: bytes) -> bool:
        """
        Feed an audio chunk to the chunker.

        Args:
            chunk: Raw PCM16 audio bytes

        Returns:
            True if a chunk was processed, False otherwise
        """
        if self._is_shutdown:
            return False

        now = time.time()

        # Detect if this chunk contains speech
        is_voice = self.speech_detector.is_speech(self.stream_key, chunk)

        # Always add to buffer
        self._audio_buffer.extend(chunk)
        self._chunk_count += 1

        # Priority 1: Time-based forcing (prevents indefinite buffering)
        accumulation_time = now - self._last_process_time
        if accumulation_time >= self.max_accumulation_time:
            return self._process_and_reset(
                f"Max accumulation time ({accumulation_time:.2f}s)"
            )

        # Priority 2: Silence-based triggering (natural sentence boundaries)
        if is_voice:
            self._last_voice_time = now
        else:
            silence_duration = now - self._last_voice_time
            if (len(self._audio_buffer) >= self.min_bytes and
                    silence_duration >= self.silence_threshold):
                return self._process_and_reset(
                    f"Pause detected ({silence_duration:.2f}s)"
                )

        return False

    def check_silence_timeout(self) -> bool:
        """
        Check if we should process due to silence timeout.

        Call this during queue timeout to handle silence detection
        when no new chunks are arriving.

        Returns:
            True if a chunk was processed, False otherwise
        """
        if self._is_shutdown:
            return False

        now = time.time()
        silence_duration = now - self._last_voice_time

        if (len(self._audio_buffer) >= self.min_bytes and
                silence_duration >= self.silence_threshold):
            return self._process_and_reset(
                f"Silence detected ({silence_duration:.2f}s)"
            )

        return False

    def flush(self) -> bool:
        """
        Flush any remaining audio in the buffer.

        Call this when the stream ends to process any remaining audio.

        Returns:
            True if remaining audio was processed, False otherwise
        """
        if self._is_shutdown:
            return False

        if len(self._audio_buffer) >= self.min_bytes:
            return self._process_and_reset("Stream ended")

        return False

    def shutdown(self):
        """Mark the chunker as shutdown (no more processing)."""
        self._is_shutdown = True

    def _process_and_reset(self, reason: str) -> bool:
        """
        Process accumulated audio and reset the buffer.

        Args:
            reason: Description of why processing was triggered

        Returns:
            True if processing was triggered, False otherwise
        """
        if len(self._audio_buffer) < self.min_bytes:
            return False

        # Capture current state
        audio_data = bytes(self._audio_buffer)
        chunk_count = self._chunk_count
        duration = len(audio_data) / (AUDIO_SAMPLE_RATE * AUDIO_BYTES_PER_SAMPLE)

        # Reset state
        self._audio_buffer.clear()
        self._chunk_count = 0
        now = time.time()
        self._last_voice_time = now
        self._last_process_time = now

        logger.info(
            f"[AudioChunker] {reason} - processing {len(audio_data)} bytes "
            f"({chunk_count} chunks, {duration:.2f}s)"
        )

        # Invoke callback
        result = ChunkResult(
            audio_data=audio_data,
            trigger_reason=reason,
            chunk_count=chunk_count,
            duration_seconds=duration
        )
        self.on_chunk_ready(result)

        return True

    def get_stats(self) -> dict:
        """Get chunker statistics."""
        return {
            "buffer_size": len(self._audio_buffer),
            "chunk_count": self._chunk_count,
            "time_since_voice": time.time() - self._last_voice_time,
            "time_since_process": time.time() - self._last_process_time,
            "is_shutdown": self._is_shutdown
        }


def run_chunker_loop(
    chunker: AudioChunker,
    audio_source: Union[queue.Queue, Iterator],
    shutdown_flag_getter: Callable[[], bool],
    queue_timeout: float = AUDIO_QUEUE_READ_TIMEOUT_SEC
) -> None:
    """
    Run the chunker loop for a given audio source.

    This is a blocking function that processes audio from the source
    until shutdown is signaled or the stream ends.

    Args:
        chunker: The AudioChunker instance
        audio_source: Queue or iterator of audio chunks
        shutdown_flag_getter: Function that returns True if shutdown requested
        queue_timeout: Timeout for queue reads
    """
    is_queue = isinstance(audio_source, queue.Queue)

    while not shutdown_flag_getter():
        try:
            # Get next chunk
            if is_queue:
                try:
                    chunk = audio_source.get(timeout=queue_timeout)
                    if chunk is None or shutdown_flag_getter():
                        break
                except queue.Empty:
                    if shutdown_flag_getter():
                        break
                    # Check for silence timeout
                    chunker.check_silence_timeout()
                    continue
            else:
                # Iterator/generator
                try:
                    chunk = next(audio_source)
                    if chunk is None or shutdown_flag_getter():
                        break
                except StopIteration:
                    break
                except TypeError:
                    logger.error("Audio source is not iterable or queue")
                    break

            # Feed chunk to chunker
            chunker.feed(chunk)

        except Exception as e:
            logger.error(f"Error in chunker loop: {e}")
            import traceback
            traceback.print_exc()
            break

    # Flush remaining audio
    if not shutdown_flag_getter():
        chunker.flush()
