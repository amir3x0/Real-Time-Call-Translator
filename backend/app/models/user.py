from sqlalchemy import Column, String, DateTime, Boolean, JSON, Integer
from datetime import datetime
import uuid

from .database import Base

class User(Base):
    """User model for authentication and profile"""
    __tablename__ = "users"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Authentication
    email = Column(String(255), unique=True, nullable=False, index=True)
    phone = Column(String(20), unique=True, nullable=True)
    name = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=True)
    
    # Firebase integration (optional)
    firebase_uid = Column(String(255), unique=True, nullable=True, index=True)
    
    # Language preferences
    primary_language = Column(String(10), default='he')  # he, en, ru
    supported_languages = Column(JSON, default=['he'])  # Array of languages
    
    # Voice settings
    has_voice_sample = Column(Boolean, default=False)
    voice_sample_path = Column(String(500), nullable=True)
    voice_model_trained = Column(Boolean, default=False)
    voice_quality_score = Column(Integer, nullable=True)  # 0-100
    
    # Status
    is_active = Column(Boolean, default=True)
    is_online = Column(Boolean, default=False)
    last_seen = Column(DateTime, nullable=True)
    
    # Profile
    avatar_url = Column(String(500), nullable=True)
    bio = Column(String(500), nullable=True)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        """Convert to dictionary for JSON response"""
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "primary_language": self.primary_language,
            "supported_languages": self.supported_languages,
            "has_voice_sample": self.has_voice_sample,
            "is_online": self.is_online,
            "avatar_url": self.avatar_url,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
    
    def __repr__(self):
        return f"<User {self.email}>"