import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List
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

    async def handle_connection(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        db: AsyncSession
    ):
        """
        Main entry point for handling a WebSocket connection.
        """
        user_id = user.id
        
        # 1. Setup Session (Lobby vs Call logic)
        context = await self._setup_session(session_id, user, db)
        if not context:
            # Error logging is handled in _setup_session
            return

        # 2. Connect & Register
        if not await self._register_connection(websocket, session_id, user, context):
            return

        # 3. Start Message Loop
        await self._message_loop(websocket, session_id, user, context, db)

    async def _setup_session(
        self, 
        session_id: str, 
        user: User, 
        db: AsyncSession
    ) -> Optional[Dict[str, Any]]:
        """
        Performs DB lookups to determine if this is a Lobby or a Call.
        Returns a context dict with call_info, participant_info, etc., or None on failure.
        """
        user_id = user.id
        call_info = None
        participant_info = None
        call_start_time = None

        try:
            if session_id == "lobby":
                # Handle Lobby connection
                call_info = {
                    "call_id": None,
                    "call_language": "en",
                    "is_active": True
                }
                
                participant_info = {
                    "participant_language": user.primary_language,
                    "dubbing_required": False,
                    "use_voice_clone": False,
                    "voice_clone_quality": "fallback"
                }
                
                # Mark user as online and notify contacts
                await self.status_service.set_user_online(user_id, db, self.connection_manager)
                
            else:
                # Handle standard Call connection
                result = await db.execute(select(Call).where(Call.session_id == session_id))
                call = result.scalar_one_or_none()
                
                if not call:
                    logger.warning(f"[Orchestrator] Call session not found: {session_id}")
                    return None
                
                call_info = {
                    "call_id": call.id,
                    "call_language": call.call_language,
                    "is_active": call.is_active
                }
                call_start_time = call.started_at
                
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
                
                participant_info = {
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
                await self.status_service.set_user_online(user_id, db, self.connection_manager)
                
            return {
                "call_info": call_info,
                "participant_info": participant_info,
                "call_start_time": call_start_time
            }

        except Exception as e:
            logger.error(f"[Orchestrator] Database error during session setup: {e}")
            return None

    async def _register_connection(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        context: Dict[str, Any]
    ) -> bool:
        """
        Registers the connection with ConnectionManager and sends initial welcome messages.
        """
        user_id = user.id
        call_info = context["call_info"]
        participant_info = context["participant_info"]

        try:
            await self.connection_manager.connect(
                websocket=websocket,
                session_id=session_id,
                user_id=user_id,
                call_id=call_info["call_id"],
                participant_language=participant_info["participant_language"],
                call_language=call_info["call_language"],
                dubbing_required=participant_info["dubbing_required"],
                use_voice_clone=participant_info["use_voice_clone"],
                voice_clone_quality=participant_info["voice_clone_quality"]
            )
            
            # Send welcome message
            await websocket.send_json({
                "type": "connected",
                "session_id": session_id,
                "call_id": call_info["call_id"],
                "call_language": call_info["call_language"],
                "participant_language": participant_info["participant_language"],
                "dubbing_required": participant_info["dubbing_required"]
            })
            
            # Send initial status of contacts (Lobby only)
            if session_id == "lobby":
                # We need a fresh DB session here or use one passed in. 
                # Since we are inside a method that doesn't have easy access to the exact same 'db' 
                # unless we passed it (which we didn't to this method), let's use a new one for this quick lookup.
                # Actually, strictly speaking, we could pass 'db' to this method too. 
                # But creating a short-lived one is safe here.
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
            
            return True

        except Exception as e:
            logger.error(f"[Orchestrator] Connection registration error: {e}")
            return False

    async def _message_loop(
        self, 
        websocket: WebSocket, 
        session_id: str, 
        user: User, 
        context: Dict[str, Any],
        db: AsyncSession
    ):
        """
        Main message processing loop.
        """
        user_id = user.id
        call_info = context["call_info"]
        
        try:
            while True:
                message = await websocket.receive()
                
                if "text" in message:
                    await self._handle_text_message(message["text"], session_id, user, context)
                elif "bytes" in message:
                    await self._handle_audio_message(message["bytes"], session_id, user, context)
                else:
                    logger.warning(f"[Orchestrator] Unexpected message structure from {user_id}")
                    
        except WebSocketDisconnect:
            logger.info(f"[Orchestrator] User {user_id} disconnected from session {session_id}")
            
        except Exception as e:
            logger.error(f"[Orchestrator] Error during message loop: {e}")
            
        finally:
            await self._cleanup(session_id, user, context)

    async def _handle_text_message(
        self, 
        text_data: str, 
        session_id: str, 
        user: User, 
        context: Dict[str, Any]
    ):
        """
        Handle JSON control messages.
        """
        try:
            data = json.loads(text_data)
            msg_type = data.get('type')
            user_id = user.id
            call_info = context["call_info"]

            if msg_type == 'heartbeat':
                await self.status_service.heartbeat(user_id)
                await self.connection_manager.send_to_user(user_id, {"type": "heartbeat_ack"})

            elif msg_type == 'mute':
                is_muted = data.get('muted', True)
                await self.connection_manager.set_mute(session_id, user_id, is_muted)
                
                # Update DB
                async with AsyncSessionLocal() as db:
                    result = await db.execute(
                        select(CallParticipant).where(
                            and_(
                                CallParticipant.call_id == call_info["call_id"],
                                CallParticipant.user_id == user_id
                            )
                        )
                    )
                    participant = result.scalar_one_or_none()
                    if participant:
                        participant.is_muted = is_muted
                        await db.commit()

                await self.connection_manager.send_to_user(user_id, {
                    "type": "mute_ack", 
                    "muted": is_muted
                })

            elif msg_type == 'leave':
                logger.info(f"[Orchestrator] User {user_id} requested to leave session {session_id}")
                # Raising WebSocketDisconnect to trigger cleanup in the finally block of the loop?
                # Or just break? 'break' is better but we are in a sub-function.
                # Use a custom exception or return a signal?
                # Simplest is to close the socket from here, which raises WebSocketDisconnect in the loop.
                # Wait, 'receive()' raises it. If we close, receive will notice.
                # Actually, just returning here won't stop the loop.
                # Let's emit a signal or raise a control exception.
                raise WebSocketDisconnect("User requested leave")

            elif msg_type == 'ping':
                await self.connection_manager.send_to_user(user_id, {"type": "pong"})

            else:
                logger.warning(f"[Orchestrator] Unknown message type: {msg_type}")

        except json.JSONDecodeError:
            logger.warning("[Orchestrator] Invalid JSON received")

    async def _handle_audio_message(
        self, 
        audio_data: bytes, 
        session_id: str, 
        user: User, 
        context: Dict[str, Any]
    ):
        """
        Handle binary audio data.
        """
        if len(audio_data) == 0:
            return

        user_id = user.id
        call_start_time = context["call_start_time"]
        
        # Calculate timestamp
        timestamp_ms = 0
        if call_start_time:
            elapsed = datetime.utcnow() - call_start_time
            timestamp_ms = int(elapsed.total_seconds() * 1000)
        
        # Broadcast (Future: Pipeline)
        await self.connection_manager.broadcast_audio(
            session_id=session_id,
            speaker_id=user_id,
            audio_data=audio_data,
            timestamp_ms=timestamp_ms
        )

    async def _cleanup(self, session_id: str, user: User, context: Dict[str, Any]):
        """
        Cleanup connection and database state on disconnect.
        """
        user_id = user.id
        call_info = context.get("call_info")
        
        await self.connection_manager.disconnect(user_id)
        
        async with AsyncSessionLocal() as db:
            if session_id != "lobby" and call_info and call_info.get("call_id"):
                # Mark participant as disconnected
                result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == call_info["call_id"],
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
                call_ended, _ = await call_service.handle_participant_left(
                    db, call_info["call_id"], user_id
                )
                
                if call_ended:
                    logger.info(f"[Orchestrator] Call {call_info['call_id']} ended")
                    await self.connection_manager.broadcast_to_session(
                        session_id,
                        {"type": "call_ended", "reason": "insufficient_participants"}
                    )
            
            # Mark user as offline
            await self.status_service.set_user_offline(user_id, db, self.connection_manager)

# Singleton instance
call_orchestrator = CallOrchestrator()
