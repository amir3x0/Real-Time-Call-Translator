"""
WebSocket Event Schemas

Pydantic models for type-safe WebSocket event handling.
"""

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel


# =============================================================================
# WebSocket Event Models
# =============================================================================

class WebSocketEventBase(BaseModel):
    """Base model for all WebSocket events."""
    type: str


class HeartbeatEvent(WebSocketEventBase):
    """Client heartbeat to maintain connection."""
    type: Literal["heartbeat"] = "heartbeat"


class MuteEvent(WebSocketEventBase):
    """Mute/unmute audio."""
    type: Literal["mute"] = "mute"
    muted: bool = True


class LeaveEvent(WebSocketEventBase):
    """Client requests to leave the session."""
    type: Literal["leave"] = "leave"


class PingEvent(WebSocketEventBase):
    """Simple ping for latency check."""
    type: Literal["ping"] = "ping"


# =============================================================================
# Session Context Model
# =============================================================================

class SessionContext(BaseModel):
    """
    Type-safe context for a WebSocket session.
    Replaces Dict[str, Any] with proper typing.
    """
    # Call information
    call_id: Optional[int] = None
    call_language: str = "en"
    is_active: bool = True
    
    # Participant information
    participant_language: str
    dubbing_required: bool = False
    use_voice_clone: bool = False
    voice_clone_quality: str = "fallback"
    
    # Timing
    call_start_time: Optional[datetime] = None
    
    class Config:
        arbitrary_types_allowed = True
