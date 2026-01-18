"""
Audio Processing Module

This module contains all audio-related services for the real-time translation pipeline:
- AudioChunker: Pause-based audio segmentation
- SpeechDetector: FFT-based speech detection
- StreamManager: Active stream lifecycle management
- worker: Main audio processing worker

Usage:
    from app.services.audio import speech_detector, stream_manager
    from app.services.audio.chunker import AudioChunker, ChunkResult
    from app.services.audio.worker import run_worker
"""

from app.services.audio.speech_detector import speech_detector, SpeechDetector
from app.services.audio.stream_manager import stream_manager, StreamManager
from app.services.audio.chunker import AudioChunker, ChunkResult, run_chunker_loop
from app.services.audio.worker import run_worker, handle_audio_stream, process_stream_message

__all__ = [
    # Singleton instances
    "speech_detector",
    "stream_manager",
    # Classes
    "SpeechDetector",
    "StreamManager",
    "AudioChunker",
    "ChunkResult",
    # Functions
    "run_chunker_loop",
    "run_worker",
    "handle_audio_stream",
    "process_stream_message",
]
