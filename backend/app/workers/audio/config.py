"""
Audio Stream Configuration

Configuration dataclasses for audio processing.
"""

from dataclasses import dataclass

@dataclass
class StreamConfig:
    """Configuration for a stream processor."""
    session_id: str
    speaker_id: str
    source_lang: str
    target_lang: str
    
    @property
    def stream_key(self) -> str:
        return f"{self.session_id}:{self.speaker_id}"
