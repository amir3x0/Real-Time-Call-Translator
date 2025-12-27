"""
CallParticipant Model - Per-Participant Call Metadata

Tracks each participant in a call with language, dubbing requirements, and mute status.
"""
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, UniqueConstraint
from datetime import datetime
from typing import Optional
import uuid

from .database import Base


class CallParticipant(Base):
    """Participant in a call"""
    __tablename__ = "call_participants"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # References
    call_id = Column(String(36), ForeignKey('calls.id', ondelete='CASCADE'), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    
    # Language (copied from user at join time)
    participant_language = Column(String(10), nullable=False)
    
    # Timing
    joined_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    left_at = Column(DateTime, nullable=True, index=True)  # NULL = still in call
    
    # Status
    is_muted = Column(Boolean, default=False)
    is_connected = Column(Boolean, default=True)
    
    # Translation settings (set at call initiation)
    dubbing_required = Column(Boolean, default=False)  # TRUE if language != call_language
    use_voice_clone = Column(Boolean, default=True)
    voice_clone_quality = Column(String(20), nullable=True)  # excellent, good, fair, fallback
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Constraints
    __table_args__ = (
        UniqueConstraint('call_id', 'user_id', name='uq_call_user'),
    )
    
    def leave_call(self):
        """Mark participant as left."""
        self.left_at = datetime.utcnow()
        self.is_connected = False
    
    def determine_dubbing_required(self, call_language: str) -> None:
        """Set dubbing_required based on language match."""
        self.dubbing_required = (self.participant_language != call_language)
    
    def set_voice_clone_quality(self, voice_quality_score: Optional[int]) -> None:
        """Set voice_clone_quality based on score."""
        if voice_quality_score is None:
            self.voice_clone_quality = 'fallback'
            self.use_voice_clone = False
        elif voice_quality_score > 80:
            self.voice_clone_quality = 'excellent'
            self.use_voice_clone = True
        elif voice_quality_score > 60:
            self.voice_clone_quality = 'good'
            self.use_voice_clone = True
        elif voice_quality_score > 40:
            self.voice_clone_quality = 'fair'
            self.use_voice_clone = True
        else:
            self.voice_clone_quality = 'fallback'
            self.use_voice_clone = False
    
    def to_dict(self):
        return {
            "id": self.id,
            "call_id": self.call_id,
            "user_id": self.user_id,
            "participant_language": self.participant_language,
            "joined_at": self.joined_at.isoformat() if self.joined_at else None,
            "left_at": self.left_at.isoformat() if self.left_at else None,
            "is_muted": self.is_muted,
            "is_connected": self.is_connected,
            "dubbing_required": self.dubbing_required,
            "use_voice_clone": self.use_voice_clone,
            "voice_clone_quality": self.voice_clone_quality,
        }

    def determine_dubbing_required(self, call_language: str):
        """
        Determine if dubbing is required based on call language.
        Set dubbing_required flag.
        """
        # Dubbing is required if participant language differs from call language
        # (and they are not just dialects of same language, overly simple check for now)
        self.dubbing_required = self.participant_language != call_language
    
    def set_voice_clone_quality(self, user_quality_score: str):
        """Set voice clone quality based on user preference/score"""
        self.voice_clone_quality = user_quality_score or "good"
