from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey, Text
from datetime import datetime, UTC
import uuid

from .database import Base


class VoiceModel(Base):
    """Voice model for storing user's voice cloning models"""
    __tablename__ = "voice_models"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Foreign key
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Voice sample details
    sample_file_path = Column(String(500), nullable=False)
    sample_duration_seconds = Column(Integer, nullable=True)
    sample_language = Column(String(10), nullable=False)  # he, en, ru
    
    # Model details
    model_file_path = Column(String(500), nullable=True)
    is_trained = Column(Boolean, default=False)
    training_status = Column(String(50), default="pending")  # pending, training, completed, failed
    
    # Quality metrics
    quality_score = Column(Integer, nullable=True)  # 0-100
    similarity_score = Column(Integer, nullable=True)  # 0-100
    
    # Voice characteristics (optional metadata)
    characteristics = Column(Text, nullable=True)  # JSON string with voice features
    
    # Usage statistics
    times_used = Column(Integer, default=0)
    last_used_at = Column(DateTime, nullable=True)
    
    # Metadata
    created_at = Column(DateTime, default=lambda: datetime.now(UTC), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))
    trained_at = Column(DateTime, nullable=True)
    
    def to_dict(self):
        """Convert to dictionary for JSON response"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "sample_file_path": self.sample_file_path,
            "sample_duration_seconds": self.sample_duration_seconds,
            "sample_language": self.sample_language,
            "is_trained": self.is_trained,
            "training_status": self.training_status,
            "quality_score": self.quality_score,
            "similarity_score": self.similarity_score,
            "times_used": self.times_used,
            "last_used_at": self.last_used_at.isoformat() if self.last_used_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "trained_at": self.trained_at.isoformat() if self.trained_at else None
        }
    
    def __repr__(self):
        return f"<VoiceModel {self.user_id} - {self.sample_language} - {self.training_status}>"
