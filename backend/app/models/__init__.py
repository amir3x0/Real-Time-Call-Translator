"""
Database Models Package

This module exports all SQLAlchemy models for the Real-Time Call Translation system.

Tables:
1. users - User management with voice cloning status
2. contacts - Contact list management
3. voice_recordings - Voice sample storage for xTTS training
4. calls - Call session management
5. call_participants - Per-participant call metadata
6. call_transcripts - Call history and transcription
"""

from .database import (
    engine,
    AsyncSessionLocal,
    Base,
    init_db,
    reset_db,
    get_db,
)

from .user import User
from .contact import Contact
from .voice_recording import VoiceRecording
from .call import Call, CallStatus
from .call_participant import CallParticipant
from .call_transcript import CallTranscript

__all__ = [
    # Database utilities
    "engine",
    "AsyncSessionLocal",
    "Base",
    "init_db",
    "reset_db",
    "get_db",
    
    # Models
    "User",
    "Contact",
    "VoiceRecording",
    "Call",
    "CallStatus",
    "CallParticipant",
    "CallTranscript",
]
