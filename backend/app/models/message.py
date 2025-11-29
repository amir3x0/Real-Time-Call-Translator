from sqlalchemy import Column, String, DateTime, Text, ForeignKey, Integer, Boolean
from datetime import datetime
import uuid

from .database import Base


class Message(Base):
    """Message model for storing call transcriptions and translations"""
    __tablename__ = "messages"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign keys
    call_id = Column(String, ForeignKey("calls.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(String, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    
    # Message content
    original_text = Column(Text, nullable=False)  # Original transcribed text
    original_language = Column(String(10), nullable=False)
    
    # Translation data (stored as JSON or separate table)
    translated_text = Column(Text, nullable=True)
    target_language = Column(String(10), nullable=True)
    
    # Audio data
    audio_file_path = Column(String(500), nullable=True)
    audio_duration_ms = Column(Integer, nullable=True)
    
    # Timestamps
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    # Translation metadata
    translation_confidence = Column(Integer, nullable=True)  # 0-100
    was_voice_cloned = Column(Boolean, default=False)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def to_dict(self):
        """Convert to dictionary for JSON response"""
        return {
            "id": self.id,
            "call_id": self.call_id,
            "sender_id": self.sender_id,
            "original_text": self.original_text,
            "original_language": self.original_language,
            "translated_text": self.translated_text,
            "target_language": self.target_language,
            "audio_duration_ms": self.audio_duration_ms,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "translation_confidence": self.translation_confidence,
            "was_voice_cloned": self.was_voice_cloned
        }
    
    def __repr__(self):
        return f"<Message {self.id} in call {self.call_id}>"
