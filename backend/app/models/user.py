"""
User Model - User Management

Stores user profiles, authentication, language preferences, and voice cloning status.
"""
from sqlalchemy import Column, String, DateTime, Boolean, Integer
from datetime import datetime
import uuid

from .database import Base


class User(Base):
    """User model for authentication and profile"""
    __tablename__ = "users"
    
    # Primary key
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Authentication
    phone = Column(String(20), unique=True, nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    password = Column(String(255), nullable=True)  # Plain text for capstone
    
    # Language settings
    primary_language = Column(String(10), nullable=False, default='he')  # he, en, ru
    
    # Online status
    is_online = Column(Boolean, default=False, index=True)
    last_seen = Column(DateTime, nullable=True)
    
    # Voice cloning (for future Chatterbox integration)
    has_voice_sample = Column(Boolean, default=False)
    voice_model_trained = Column(Boolean, default=False)
    voice_quality_score = Column(Integer, nullable=True)  # 1-100
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        """Convert to dictionary for JSON response"""
        return {
            "id": self.id,
            "phone": self.phone,
            "full_name": self.full_name,
            "primary_language": self.primary_language,
            "has_voice_sample": self.has_voice_sample,
            "voice_model_trained": self.voice_model_trained,
            "voice_quality_score": self.voice_quality_score,
            "is_online": self.is_online,
            "last_seen": self.last_seen.isoformat() if self.last_seen else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
    
    def to_public_dict(self):
        """Convert to public dictionary (for other users to see)"""
        return {
            "id": self.id,
            "phone": self.phone,
            "full_name": self.full_name,
            "primary_language": self.primary_language,
            "is_online": self.is_online,
            "last_seen": self.last_seen.isoformat() if self.last_seen else None,
        }
    
    def get_voice_clone_quality(self) -> str:
        """Get voice clone quality level."""
        if not self.voice_model_trained or self.voice_quality_score is None:
            return 'fallback'
        if self.voice_quality_score > 80:
            return 'excellent'
        elif self.voice_quality_score > 60:
            return 'good'
        elif self.voice_quality_score > 40:
            return 'fair'
        return 'fallback'
    
    def __repr__(self):
        return f"<User {self.full_name}>"
