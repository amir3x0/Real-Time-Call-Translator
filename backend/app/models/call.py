"""
Call Model - Call Session Management

Tracks each call session (who called, language, duration, status).
"""
from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey
from datetime import datetime, UTC
import uuid

from .database import Base


class Call(Base):
    """Call session model"""
    __tablename__ = "calls"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Session ID for WebSocket routing
    session_id = Column(String(36), unique=True, nullable=False, index=True, default=lambda: str(uuid.uuid4()))
    
    # Caller (initiator)
    caller_user_id = Column(String(36), ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    
    # Call language (always = caller's primary_language, immutable)
    call_language = Column(String(10), nullable=False, default='he')
    
    # Status
    is_active = Column(Boolean, default=True, index=True)
    status = Column(String(20), nullable=False, default='ongoing')  # ongoing, ended, missed
    
    # Timing
    started_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)
    ended_at = Column(DateTime, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    
    # Participant tracking
    participant_count = Column(Integer, default=1)
    
    # Timestamps
    created_at = Column(DateTime, default=lambda: datetime.utcnow(), nullable=False)
    
    def end_call(self):
        """End the call session."""
        self.is_active = False
        self.status = 'ended'
        self.ended_at = datetime.now(UTC)
        if self.started_at:
            delta = self.ended_at - self.started_at
            self.duration_seconds = int(delta.total_seconds())
    
    def to_dict(self):
        return {
            "id": self.id,
            "session_id": self.session_id,
            "caller_user_id": self.caller_user_id,
            "call_language": self.call_language,
            "is_active": self.is_active,
            "status": self.status,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "ended_at": self.ended_at.isoformat() if self.ended_at else None,
            "duration_seconds": self.duration_seconds,
            "participant_count": self.participant_count,
        }
