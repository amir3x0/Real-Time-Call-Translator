"""
CallTranscript Model - Call History & Transcription

Stores complete word-by-word record of all calls for history.
"""
from sqlalchemy import Column, String, DateTime, Integer, Text, ForeignKey
from datetime import datetime, UTC
import uuid

from .database import Base


class CallTranscript(Base):
    """Transcript entry for a call"""
    __tablename__ = "call_transcripts"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # References
    call_id = Column(String(36), ForeignKey('calls.id', ondelete='CASCADE'), nullable=False, index=True)
    speaker_user_id = Column(String(36), ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    
    # Content
    original_language = Column(String(10), nullable=False)
    original_text = Column(Text, nullable=False)
    translated_text = Column(Text, nullable=True)
    
    # Timing (milliseconds from call start)
    timestamp_ms = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)
    
    @classmethod
    def create_transcript(
        cls,
        call_id: str,
        speaker_user_id: str,
        original_language: str,
        original_text: str,
        timestamp_ms: int,
        translated_text: str = None,
        **kwargs  # Ignore extra params (target_language, tts_method, etc.)
    ):
        """
        Factory method to create a transcript entry.
        
        Args:
            call_id: ID of the call
            speaker_user_id: ID of the speaker
            original_language: Language of original speech
            original_text: Transcribed text
            timestamp_ms: Timestamp in milliseconds from call start
            translated_text: Translated text (optional)
            **kwargs: Additional parameters (ignored for now)
            
        Returns:
            CallTranscript instance
        """
        return cls(
            call_id=call_id,
            speaker_user_id=speaker_user_id,
            original_language=original_language,
            original_text=original_text,
            translated_text=translated_text,
            timestamp_ms=timestamp_ms
        )

    
    def to_dict(self):
        return {
            "id": self.id,
            "call_id": self.call_id,
            "speaker_user_id": self.speaker_user_id,
            "original_language": self.original_language,
            "original_text": self.original_text,
            "translated_text": self.translated_text,
            "timestamp_ms": self.timestamp_ms,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
