"""
User Model - User Management

Purpose: Store user profiles, authentication, language preferences, and voice cloning status

Key Fields:
- `primary_language`: Immutable language of the user (set at registration, never changes)
- `is_online`: Real-time status (updated when user connects/disconnects via WebSocket)
- `voice_model_trained`: TRUE only after successful xTTS training with 2-3 voice samples
- `voice_quality_score`: 1-100 range. >80 = use voice clone, <80 = fallback to Google TTS
"""
from sqlalchemy import Column, String, DateTime, Boolean, JSON, Integer, CheckConstraint
from datetime import datetime
import uuid

from .database import Base


class User(Base):
    """User model for authentication and profile"""
    __tablename__ = "users"
    
    # Primary key
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Authentication / profile
    email = Column(String(255), unique=True, nullable=True, index=True)  # Optional email
    phone = Column(String(20), unique=True, nullable=True, index=True)  # Phone number (legacy)
    phone_number = Column(String(20), nullable=True)  # Phone number (database design spec)
    full_name = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=True)
    
    # Firebase integration (optional)
    firebase_uid = Column(String(255), unique=True, nullable=True, index=True)
    
    # Primary language (determines call language when user initiates) - IMMUTABLE
    primary_language = Column(String(10), nullable=False, default='he')
    
    # User's actively selected language (can change)
    language_code = Column(String(10), nullable=True)
    
    # Array of languages user supports
    supported_languages = Column(JSON, default=['he'])
    
    # Online status tracking
    is_online = Column(Boolean, default=False, index=True)
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=True)
    
    # Voice cloning attributes
    has_voice_sample = Column(Boolean, default=False)
    voice_sample_path = Column(String(500), nullable=True)  # Legacy path
    voice_model_trained = Column(Boolean, default=False)
    voice_quality_score = Column(Integer, nullable=True)  # 1-100 (set after xTTS training)
    voice_model_id = Column(String(255), nullable=True)  # Reference to trained xTTS model
    
    # Profile metadata
    avatar_url = Column(String(500), nullable=True)
    bio = Column(String(500), nullable=True)
    
    # Account status
    is_active = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Constraints
    __table_args__ = (
        CheckConstraint("primary_language IN ('he', 'en', 'ru')", name='ck_user_primary_language'),
    )
    
    def get_voice_clone_quality(self) -> str:
        """
        Get voice clone quality level based on score.
        
        Returns:
            'excellent' if score > 80
            'good' if score > 60
            'fair' if score > 40
            'fallback' otherwise
        """
        if not self.voice_model_trained or self.voice_quality_score is None:
            return 'fallback'
        
        if self.voice_quality_score > 80:
            return 'excellent'
        elif self.voice_quality_score > 60:
            return 'good'
        elif self.voice_quality_score > 40:
            return 'fair'
        else:
            return 'fallback'
    
    def should_use_voice_clone(self) -> bool:
        """
        Check if voice cloning should be used for this user.
        
        Returns:
            True if voice model trained and quality > 60
        """
        return (
            self.voice_model_trained and 
            self.voice_quality_score is not None and 
            self.voice_quality_score > 60
        )
    
    def set_online(self):
        """Mark user as online"""
        self.is_online = True
        self.last_seen = datetime.utcnow()
    
    def set_offline(self):
        """Mark user as offline"""
        self.is_online = False
        self.last_seen = datetime.utcnow()
    
    def update_voice_model(self, quality_score: int, model_id: str = None):
        """Update voice model training status"""
        self.voice_model_trained = True
        self.voice_quality_score = quality_score
        if model_id:
            self.voice_model_id = model_id
    
    def to_dict(self):
        """Convert to dictionary for JSON response"""
        return {
            "id": self.id,
            "email": self.email,
            "phone": self.phone or self.phone_number,
            "phone_number": self.phone_number or self.phone,
            "full_name": self.full_name,
            "primary_language": self.primary_language,
            "language_code": self.language_code,
            "supported_languages": self.supported_languages,
            "has_voice_sample": self.has_voice_sample,
            "voice_model_trained": self.voice_model_trained,
            "voice_quality_score": self.voice_quality_score,
            "voice_clone_quality": self.get_voice_clone_quality(),
            "is_online": self.is_online,
            "last_seen": self.last_seen.isoformat() if self.last_seen else None,
            "avatar_url": self.avatar_url,
            "bio": self.bio,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
    
    def to_public_dict(self):
        """Convert to public dictionary (no sensitive info)"""
        return {
            "id": self.id,
            "full_name": self.full_name,
            "primary_language": self.primary_language,
            "is_online": self.is_online,
            "avatar_url": self.avatar_url,
            "voice_model_trained": self.voice_model_trained,
        }
    
    def __repr__(self):
        identifier = self.email or self.phone or self.id[:8]
        return f"<User {identifier}>"
