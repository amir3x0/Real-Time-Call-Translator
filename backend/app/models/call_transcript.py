"""
CallTranscript Model - Call History & Transcription

Stores complete word-by-word record of all calls for history.
"""
from sqlalchemy import Column, String, DateTime, Integer, Text, ForeignKey
from datetime import datetime
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
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
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
