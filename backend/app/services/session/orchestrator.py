"""
Call Orchestrator - WebSocket Session Management

Manages the lifecycle of a WebSocket connection for real-time calls:
- Connection authentication and setup
- Participant info loading from database
- Message loop handling (text/binary)
- Cleanup on disconnect
"""
import json
import logging
from datetime import datetime, UTC
from typing import Optional, Dict, Any, Tuple

from fastapi import WebSocket
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import AsyncSessionLocal
from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.contact import Contact
from app.services.auth_service import decode_token
from app.services.status_service import status_service
from app.services.connection import connection_manager
from app.services.call import call_service

logger = logging.getLogger(__name__)


class CallOrchestrator:
    """
    Orchestrates a single WebSocket call session.
    
    Usage:
        orchestrator = CallOrchestrator(websocket, session_id, token)
        await orchestrator.run()
    """
    
    def __init__(
        self,
        websocket: WebSocket,
        session_id: str,
        token: Optional[str] = None,
        call_id: Optional[str] = None
    ):
        self.websocket = websocket
        self.session_id = session_id
        self.token = token
        self.call_id = call_id
        
        # Will be set during authentication
        self.user_id: Optional[str] = None
        self.call_info: Optional[Dict[str, Any]] = None
        self.participant_info: Optional[Dict[str, Any]] = None
        self.call_start_time: Optional[datetime] = None
    
    async def run(self) -> None:
        """
        Main entry point - runs the full WebSocket session lifecycle.
        """
        # 1. Accept connection
        await self.websocket.accept()
        
        # 2. Authenticate
        if not await self._authenticate():
            return
        
        # 3. Load participant info
        if not await self._load_participant_info():
            return
        
        # 4. Register with connection manager
        if not await self._register_connection():
            return
        
        # 5. Send welcome message
        await self._send_welcome()
        
        # 6. Send initial status (lobby only)
        if self.session_id == "lobby":
            await self._send_initial_contact_status()
        
        # 7. Run message loop
        try:
            await self._message_loop()
        finally:
            # 8. Cleanup on disconnect
            await self._handle_disconnect()
    
    async def _authenticate(self) -> bool:
        """Validate JWT token and extract user_id."""
        if not self.token:
            logger.warning(f"[WebSocket] Missing token for session {self.session_id}")
            await self.websocket.close(code=1008, reason="Missing token")
            return False
        
        payload = decode_token(self.token)
        if not payload or not payload.get("sub"):
            logger.warning(f"[WebSocket] Invalid token for session {self.session_id}")
            await self.websocket.close(code=1008, reason="Invalid token")
            return False
        
        self.user_id = payload.get("sub")
        logger.info(f"[WebSocket] Connection attempt: user_id={self.user_id}, session_id={self.session_id}")
        return True
    
    async def _load_participant_info(self) -> bool:
        """Load call and participant info from database."""
        try:
            async with AsyncSessionLocal() as db:
                # Get user info
                from app.services.user_service import user_service
                user = await user_service.get_by_id(db, self.user_id)
                
                if not user:
                    await self.websocket.close(code=1008, reason="User not found")
                    return False
                
                if self.session_id == "lobby":
                    return await self._setup_lobby_connection(user, db)
                else:
                    return await self._setup_call_connection(user, db)
                    
        except Exception as e:
            logger.error(f"[WebSocket] Database error during connection: {e}")
            await self.websocket.close(code=1011, reason="Database error")
            return False
    
    async def _setup_lobby_connection(self, user: User, db: AsyncSession) -> bool:
        """Setup connection for lobby (presence/status updates)."""
        self.call_info = {
            "call_id": None,
            "call_language": "en",
            "is_active": True
        }
        
        self.participant_info = {
            "participant_language": user.primary_language,
            "dubbing_required": False,
            "use_voice_clone": False,
            "voice_clone_quality": "fallback"
        }
        
        # Mark user as online and notify contacts
        await status_service.set_user_online(self.user_id, db, connection_manager)
        return True
    
    async def _setup_call_connection(self, user: User, db: AsyncSession) -> bool:
        """Setup connection for an actual call session."""
        # Find call by session_id
        result = await db.execute(select(Call).where(Call.session_id == self.session_id))
        call = result.scalar_one_or_none()
        
        if not call:
            await self.websocket.close(code=1008, reason="Call session not found")
            return False
        
        self.call_info = {
            "call_id": call.id,
            "call_language": call.call_language,
            "is_active": call.is_active
        }
        self.call_start_time = call.started_at
        
        # Get participant record
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call.id,
                    CallParticipant.user_id == self.user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            await self.websocket.close(code=1008, reason="Not a participant in this call")
            return False
        
        self.participant_info = {
            "participant_language": participant.participant_language,
            "dubbing_required": participant.dubbing_required,
            "use_voice_clone": participant.use_voice_clone,
            "voice_clone_quality": participant.voice_clone_quality
        }
        
        # Update participant as connected
        participant.is_connected = True
        participant.joined_at = datetime.utcnow()
        await db.commit()
        
        # Mark user as online and notify contacts
        await status_service.set_user_online(self.user_id, db, connection_manager)
        return True
    
    async def _register_connection(self) -> bool:
        """Register with the connection manager."""
        try:
            await connection_manager.connect(
                websocket=self.websocket,
                session_id=self.session_id,
                user_id=self.user_id,
                call_id=self.call_info["call_id"],
                participant_language=self.participant_info["participant_language"],
                call_language=self.call_info["call_language"],
                dubbing_required=self.participant_info["dubbing_required"],
                use_voice_clone=self.participant_info["use_voice_clone"],
                voice_clone_quality=self.participant_info["voice_clone_quality"]
            )
            return True
        except Exception as e:
            logger.error(f"[WebSocket] ConnectionManager error: {e}")
            await self.websocket.close(code=1011, reason="Connection manager error")
            return False
    
    async def _send_welcome(self) -> None:
        """Send welcome message with call info."""
        await self.websocket.send_json({
            "type": "connected",
            "session_id": self.session_id,
            "call_id": self.call_info["call_id"],
            "call_language": self.call_info["call_language"],
            "participant_language": self.participant_info["participant_language"],
            "dubbing_required": self.participant_info["dubbing_required"]
        })
    
    async def _send_initial_contact_status(self) -> None:
        """Send initial online status of contacts (lobby only)."""
        try:
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(Contact).join(User, Contact.contact_user_id == User.id)
                    .where(
                        and_(
                            Contact.user_id == self.user_id,
                            User.is_online == True
                        )
                    )
                )
                online_contacts = result.scalars().all()
                
                for contact in online_contacts:
                    await self.websocket.send_json({
                        "type": "user_status_changed",
                        "user_id": contact.contact_user_id,
                        "is_online": True
                    })
        except Exception as e:
            logger.error(f"[WebSocket] Error sending initial status: {e}")
    
    async def _message_loop(self) -> None:
        """Main message receive loop."""
        from fastapi import WebSocketDisconnect
        
        try:
            while True:
                message = await self.websocket.receive()
                
                if "text" in message:
                    await self._handle_text_message(message["text"])
                elif "bytes" in message:
                    await self._handle_binary_message(message["bytes"])
                else:
                    logger.warning(f"[WebSocket] Unexpected message structure from {self.user_id}: {message.keys()}")
        
        except WebSocketDisconnect:
            logger.info(f"[WebSocket] User {self.user_id} disconnected from session {self.session_id}")
        except Exception as e:
            logger.error(f"[WebSocket] Error during session: {e}")
    
    async def _handle_text_message(self, text: str) -> None:
        """Handle JSON text messages."""
        try:
            data = json.loads(text)
            msg_type = data.get('type')
            
            if msg_type == 'heartbeat':
                await status_service.heartbeat(self.user_id)
                await self.websocket.send_json({"type": "heartbeat_ack"})
            
            elif msg_type == 'mute':
                await self._handle_mute(data)
            
            elif msg_type == 'leave':
                logger.info(f"[WebSocket] User {self.user_id} requested to leave session {self.session_id}")
                raise Exception("User requested leave")  # Exit message loop
            
            elif msg_type == 'ping':
                await self.websocket.send_json({"type": "pong"})
            
            else:
                logger.warning(f"[WebSocket] Unknown message type: {msg_type}")
        
        except json.JSONDecodeError:
            logger.warning("[WebSocket] Invalid JSON received")
    
    async def _handle_mute(self, data: Dict[str, Any]) -> None:
        """Handle mute toggle message."""
        is_muted = data.get('muted', True)
        await connection_manager.set_mute(self.session_id, self.user_id, is_muted)
        
        # Update database
        if self.call_info and self.call_info.get("call_id"):
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == self.call_info["call_id"],
                            CallParticipant.user_id == self.user_id
                        )
                    )
                )
                participant = result.scalar_one_or_none()
                if participant:
                    participant.is_muted = is_muted
                    await db.commit()
        
        await self.websocket.send_json({
            "type": "mute_ack",
            "muted": is_muted
        })
    
    async def _handle_binary_message(self, audio_data: bytes) -> None:
        """Handle binary audio data."""
        logger.debug(f"[WebSocket] Received {len(audio_data)} bytes from {self.user_id}")
        
        if len(audio_data) > 0:
            # Calculate timestamp from call start
            timestamp_ms = 0
            if self.call_start_time:
                elapsed = datetime.now(UTC) - self.call_start_time
                timestamp_ms = int(elapsed.total_seconds() * 1000)
            
            # Broadcast audio to other participants
            result = await connection_manager.broadcast_audio(
                session_id=self.session_id,
                speaker_id=self.user_id,
                audio_data=audio_data,
                timestamp_ms=timestamp_ms
            )
            
            logger.debug(f"[WebSocket] Audio routed: {result}")
    
    async def _handle_disconnect(self) -> None:
        """Cleanup when connection ends."""
        await connection_manager.disconnect(self.user_id)
        
        async with AsyncSessionLocal() as db:
            # Only update CallParticipant if this was a real call (not lobby)
            if self.session_id != "lobby" and self.call_info and self.call_info.get("call_id"):
                # Mark participant as disconnected
                result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == self.call_info["call_id"],
                            CallParticipant.user_id == self.user_id
                        )
                    )
                )
                participant = result.scalar_one_or_none()
                if participant:
                    participant.is_connected = False
                    participant.left_at = datetime.utcnow()
                    await db.commit()
                
                # Check if call should end (fewer than 2 participants)
                call_ended, _ = await call_service.handle_participant_left(
                    db, self.call_info["call_id"], self.user_id
                )
                
                if call_ended:
                    logger.info(f"[WebSocket] Call {self.call_info['call_id']} ended - fewer than 2 participants")
                    
                    # Notify remaining participants that call ended
                    await connection_manager.broadcast_to_session(
                        self.session_id,
                        {"type": "call_ended", "reason": "insufficient_participants"}
                    )
            
            # Mark user as offline and notify contacts
            await status_service.set_user_offline(self.user_id, db, connection_manager)
