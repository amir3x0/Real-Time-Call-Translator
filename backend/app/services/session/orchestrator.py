"""
Call Session Orchestrator

Orchestrates the lifecycle of WebSocket call sessions with type-safe
event handling and proper resource management.
"""

import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, Callable, Awaitable, Literal
from pydantic import BaseModel, Field
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.contact import Contact
from app.services.connection_manager import connection_manager
from app.services.status_service import status_service
from app.services.call_service import call_service
from app.models.database import AsyncSessionLocal

logger = logging.getLogger(__name__)


# =============================================================================
# Pydantic Models for WebSocket Events
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


# =============================================================================
# Call Orchestrator
# =============================================================================

class CallOrchestrator:
    """
    Orchestrates the lifecycle of a WebSocket call session.
    
    Handles:
    - Session setup (Lobby vs Call)
    - Connection registration
    - Message loop processing (Text/Audio)
    - Cleanup on disconnect
    """

    def __init__(self):
        self.connection_manager = connection_manager
        self.status_service = status_service
        
        # Handler registry for message types
        self._handlers: Dict[str, Callable[..., Awaitable[None]]] = {
            "heartbeat": self._handle_heartbeat,
            "mute": self._handle_mute,
            "leave": self._handle_leave,
            "ping": self._handle_ping,
        }

    # -------------------------------------------------------------------------
    # Main Entry Point
    # -------------------------------------------------------------------------

    async def handle_connection(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        db: AsyncSession
    ) -> None:
        """
        Main entry point for handling a WebSocket connection.
        """
        # 1. Setup Session (Lobby vs Call logic)
        context = await self._setup_session(session_id, user, db)
        if not context:
            return

        # 2. Connect & Register
        if not await self._register_connection(websocket, session_id, user, context, db):
            return

        # 3. Start Message Loop
        await self._message_loop(websocket, session_id, user, context, db)

    # -------------------------------------------------------------------------
    # Session Setup
    # -------------------------------------------------------------------------

    async def _setup_session(
        self, 
        session_id: str, 
        user: User, 
        db: AsyncSession
    ) -> Optional[SessionContext]:
        """
        Performs DB lookups to determine if this is a Lobby or a Call.
        Returns a SessionContext or None on failure.
        """
        user_id = user.id

        try:
            if session_id == "lobby":
                return await self._setup_lobby_session(user, db)
            else:
                return await self._setup_call_session(session_id, user, db)

        except Exception as e:
            logger.error(f"[Orchestrator] Database error during session setup: {e}")
            return None

    async def _setup_lobby_session(
        self, 
        user: User, 
        db: AsyncSession
    ) -> SessionContext:
        """Setup context for lobby connection."""
        await self.status_service.set_user_online(user.id, db, self.connection_manager)
        
        return SessionContext(
            call_id=None,
            call_language="en",
            is_active=True,
            participant_language=user.primary_language,
            dubbing_required=False,
            use_voice_clone=False,
            voice_clone_quality="fallback"
        )

    async def _setup_call_session(
        self, 
        session_id: str, 
        user: User, 
        db: AsyncSession
    ) -> Optional[SessionContext]:
        """Setup context for call connection."""
        user_id = user.id
        
        # Get call record
        result = await db.execute(select(Call).where(Call.session_id == session_id))
        call = result.scalar_one_or_none()
        
        if not call:
            logger.warning(f"[Orchestrator] Call session not found: {session_id}")
            return None
        
        # Get participant record
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call.id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            logger.warning(f"[Orchestrator] User {user_id} not a participant in call {call.id}")
            return None
        
        # Update participant as connected
        participant.is_connected = True
        participant.joined_at = datetime.utcnow()
        await db.commit()
        
        # Mark user as online
        await self.status_service.set_user_online(user_id, db, self.connection_manager)
        
        return SessionContext(
            call_id=call.id,
            call_language=call.call_language,
            is_active=call.is_active,
            participant_language=participant.participant_language,
            dubbing_required=participant.dubbing_required,
            use_voice_clone=participant.use_voice_clone,
            voice_clone_quality=participant.voice_clone_quality,
            call_start_time=call.started_at
        )

    # -------------------------------------------------------------------------
    # Connection Registration
    # -------------------------------------------------------------------------

    async def _register_connection(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        context: SessionContext,
        db: AsyncSession
    ) -> bool:
        """
        Registers the connection with ConnectionManager and sends initial messages.
        """
        user_id = user.id

        try:
            await self.connection_manager.connect(
                websocket=websocket,
                session_id=session_id,
                user_id=user_id,
                call_id=context.call_id,
                participant_language=context.participant_language,
                call_language=context.call_language,
                dubbing_required=context.dubbing_required,
                use_voice_clone=context.use_voice_clone,
                voice_clone_quality=context.voice_clone_quality
            )
            
            # Send welcome message
            await websocket.send_json({
                "type": "connected",
                "session_id": session_id,
                "call_id": context.call_id,
                "call_language": context.call_language,
                "participant_language": context.participant_language,
                "dubbing_required": context.dubbing_required
            })
            
            # Send initial status of contacts (Lobby only)
            if session_id == "lobby":
                await self._send_online_contacts_status(websocket, user_id)
            
            return True

        except Exception as e:
            logger.error(f"[Orchestrator] Connection registration error: {e}")
            return False

    async def _send_online_contacts_status(
        self, 
        websocket: WebSocket, 
        user_id: int
    ) -> None:
        """Send status of online contacts to the user."""
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(Contact).join(User, Contact.contact_user_id == User.id)
                .where(
                    and_(
                        Contact.user_id == user_id,
                        User.is_online == True
                    )
                )
            )
            online_contacts = result.scalars().all()
            
            for contact in online_contacts:
                await websocket.send_json({
                    "type": "user_status_changed",
                    "user_id": contact.contact_user_id,
                    "is_online": True
                })

    # -------------------------------------------------------------------------
    # Message Loop
    # -------------------------------------------------------------------------

    async def _message_loop(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        context: SessionContext,
        db: AsyncSession
    ) -> None:
        """Main message processing loop."""
        user_id = user.id
        
        try:
            while True:
                message = await websocket.receive()
                
                if "text" in message:
                    await self._handle_text_message(
                        message["text"], session_id, user, context
                    )
                elif "bytes" in message:
                    await self._handle_audio_message(
                        message["bytes"], session_id, user, context
                    )
                else:
                    logger.warning(f"[Orchestrator] Unexpected message structure from {user_id}")
                    
        except WebSocketDisconnect:
            logger.info(f"[Orchestrator] User {user_id} disconnected from session {session_id}")
            
        except Exception as e:
            logger.error(f"[Orchestrator] Error during message loop: {e}")
            
        finally:
            await self._cleanup(session_id, user, context)

    # -------------------------------------------------------------------------
    # Text Message Handling
    # -------------------------------------------------------------------------

    async def _handle_text_message(
        self, 
        text_data: str, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """
        Handle JSON control messages using handler registry pattern.
        """
        try:
            data = json.loads(text_data)
            msg_type = data.get('type')
            
            handler = self._handlers.get(msg_type)
            if handler:
                await handler(data, session_id, user, context)
            else:
                logger.warning(f"[Orchestrator] Unknown message type: {msg_type}")

        except json.JSONDecodeError:
            logger.warning("[Orchestrator] Invalid JSON received")

    async def _handle_heartbeat(
        self, 
        data: dict, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Handle heartbeat message."""
        await self.status_service.heartbeat(user.id)
        await self.connection_manager.send_to_user(user.id, {"type": "heartbeat_ack"})

    async def _handle_mute(
        self, 
        data: dict, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Handle mute/unmute message."""
        event = MuteEvent(**data)
        user_id = user.id
        
        await self.connection_manager.set_mute(session_id, user_id, event.muted)
        
        # Update DB
        await self._update_participant_mute_status(context.call_id, user_id, event.muted)
        
        await self.connection_manager.send_to_user(user_id, {
            "type": "mute_ack", 
            "muted": event.muted
        })

    async def _update_participant_mute_status(
        self, 
        call_id: Optional[int], 
        user_id: int, 
        is_muted: bool
    ) -> None:
        """Update participant mute status in database."""
        if call_id is None:
            return
            
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(CallParticipant).where(
                    and_(
                        CallParticipant.call_id == call_id,
                        CallParticipant.user_id == user_id
                    )
                )
            )
            participant = result.scalar_one_or_none()
            if participant:
                participant.is_muted = is_muted
                await db.commit()

    async def _handle_leave(
        self, 
        data: dict, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Handle leave request."""
        logger.info(f"[Orchestrator] User {user.id} requested to leave session {session_id}")
        raise WebSocketDisconnect("User requested leave")

    async def _handle_ping(
        self, 
        data: dict, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Handle ping message."""
        await self.connection_manager.send_to_user(user.id, {"type": "pong"})

    # -------------------------------------------------------------------------
    # Audio Message Handling
    # -------------------------------------------------------------------------

    async def _handle_audio_message(
        self, 
        audio_data: bytes, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Handle binary audio data."""
        if len(audio_data) == 0:
            return

        user_id = user.id
        
        # Calculate timestamp
        timestamp_ms = 0
        if context.call_start_time:
            elapsed = datetime.utcnow() - context.call_start_time
            timestamp_ms = int(elapsed.total_seconds() * 1000)
        
        # Broadcast audio
        await self.connection_manager.broadcast_audio(
            session_id=session_id,
            speaker_id=user_id,
            audio_data=audio_data,
            timestamp_ms=timestamp_ms
        )

    # -------------------------------------------------------------------------
    # Cleanup
    # -------------------------------------------------------------------------

    async def _cleanup(
        self, 
        session_id: str, 
        user: User, 
        context: SessionContext
    ) -> None:
        """Cleanup connection and database state on disconnect."""
        user_id = user.id
        
        await self.connection_manager.disconnect(user_id)
        
        async with AsyncSessionLocal() as db:
            if session_id != "lobby" and context.call_id:
                await self._cleanup_call_participant(db, context.call_id, user_id, session_id)
            
            # Mark user as offline
            await self.status_service.set_user_offline(user_id, db, self.connection_manager)

    async def _cleanup_call_participant(
        self, 
        db: AsyncSession, 
        call_id: int, 
        user_id: int, 
        session_id: str
    ) -> None:
        """Cleanup participant state when leaving a call."""
        # Mark participant as disconnected
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        if participant:
            participant.is_connected = False
            participant.left_at = datetime.utcnow()
            await db.commit()
        
        # Check if call should end
        call_ended, _ = await call_service.handle_participant_left(db, call_id, user_id)
        
        if call_ended:
            logger.info(f"[Orchestrator] Call {call_id} ended")
            await self.connection_manager.broadcast_to_session(
                session_id,
                {"type": "call_ended", "reason": "insufficient_participants"}
            )


# Singleton instance
call_orchestrator = CallOrchestrator()
