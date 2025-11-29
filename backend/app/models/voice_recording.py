"""
VoiceRecording Model - Voice Sample Storage

Stores raw voice samples for future Chatterbox voice cloning.
"""
from sqlalchemy import Column, String, DateTime, Boolean, Integer, Text, ForeignKey
from datetime import datetime
import uuid

from .database import Base


class VoiceRecording(Base):
    """Voice recording for voice cloning"""
    __tablename__ = "voice_recordings"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # User reference
    user_id = Column(String(36), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    
    # Recording details
    language = Column(String(10), nullable=False)  # he, en, ru
    text_content = Column(Text, nullable=False)  # Text that was read
    
    # File info
    file_path = Column(String(500), nullable=False)
    file_size_bytes = Column(Integer, nullable=True)
    audio_format = Column(String(10), nullable=True)  # wav, mp3, etc.
    
    # Quality assessment
    quality_score = Column(Integer, nullable=True)  # 1-100
    
    # Processing status
    is_processed = Column(Boolean, default=False)
    processed_at = Column(DateTime, nullable=True)
    
    # Training flag
    used_for_training = Column(Boolean, default=False, index=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "language": self.language,
            "text_content": self.text_content,
            "file_path": self.file_path,
            "file_size_bytes": self.file_size_bytes,
            "quality_score": self.quality_score,
            "is_processed": self.is_processed,
            "used_for_training": self.used_for_training,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
