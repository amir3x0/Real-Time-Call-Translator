"""
Call Orchestrator - WebSocket Session Management

Manages the lifecycle of a WebSocket connection for real-time calls:
- Connection authentication and setup
- Participant info loading from database
- Message loop handling (text/binary)
- Redis Stream publishing for audio processing
- Pub/Sub listener for translation results
- Cleanup on disconnect
"""
import asyncio
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
from app.services.call.lifecycle import CallLifecycleManager
from app.services.rtc_service import publish_audio_chunk
from app.config.redis import get_redis
from app.config.constants import WEBSOCKET_MESSAGE_TIMEOUT_SEC, DEFAULT_CALL_LANGUAGE

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
        
        # Pub/Sub listener task for receiving translation results
        self._pubsub_task: Optional[asyncio.Task] = None
    
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
        
        # 7. Start Pub/Sub listener for translation results (call sessions only)
        if self.session_id != "lobby":
            self._pubsub_task = asyncio.create_task(
                self._listen_for_translations()
            )
            logger.info(f"[WebSocket] Started Pub/Sub listener for session {self.session_id}")
        
        # 8. Run message loop
        try:
            await self._message_loop()
        finally:
            # 9. Cleanup on disconnect
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
            "call_language": DEFAULT_CALL_LANGUAGE,
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
                # Issue 6: Heartbeat Not Validated (Zombie Calls)
                # Wait for message with timeout (> heartbeat interval)
                try:
                    message = await asyncio.wait_for(
                        self.websocket.receive(),
                        timeout=WEBSOCKET_MESSAGE_TIMEOUT_SEC
                    )
                except asyncio.TimeoutError:
                    logger.warning(f"[WebSocket] User {self.user_id} zombie connection timeout - disconnecting")
                    break
                
                # LOG EVERYTHING
                msg_type = message.get('type')
                keys = list(message.keys())
                # Truncate bytes for log clarity if present
                log_msg = f"[WebSocket] RAW RECV: Keys={keys}, Type={msg_type}"
                if "bytes" in message:
                    log_msg += f", BytesLen={len(message['bytes'])}"
                
                logger.info(log_msg)

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
                
            elif msg_type == 'audio':
                # Issue #2 Fix: Base64 fallback removed - binary frames are reliable
                # Previously this caused duplication if client sent both binary AND JSON
                logger.warning(f"[WebSocket] Received deprecated 'audio' JSON message, ignoring (use binary frames)")
            
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
        """
        Handle binary audio data.
        
        Publishes audio to Redis Stream for the Worker to process.
        The Worker handles: STT -> Translation -> TTS -> Pub/Sub
        Results come back via _listen_for_translations()
        """
        if len(audio_data) < 100:
            logger.warning(f"[WebSocket] Audio chunk too small ({len(audio_data)} bytes), skipping")
            return
        
        # Skip audio processing for lobby
        if self.session_id == "lobby":
            return
            
        logger.info(f"[WebSocket] Received {len(audio_data)} bytes from {self.user_id} in session {self.session_id}")

        # Get source language from participant info
        source_lang = self.participant_info.get("participant_language", "he")
        source_lang = _normalize_language_code(source_lang)

        logger.info(f"[WebSocket] 🎙️ Publishing audio: user={self.user_id}, session={self.session_id}, source={source_lang}, {len(audio_data)} bytes")

        # Publish to Redis Stream for Worker processing
        # Phase 3: Worker determines target languages from database for multi-party support
        try:
            result = await publish_audio_chunk(
                session_id=self.session_id,
                chunk=audio_data,
                source_lang=source_lang,
                speaker_id=self.user_id
            )
            logger.debug(f"[WebSocket] Audio published to stream: {result}")
        except Exception as e:
            logger.error(f"[WebSocket] Failed to publish audio: {e}")
    
    async def _handle_disconnect(self) -> None:
        """
        Cleanup when connection ends.
        
        Delegates to specialized managers following SRP:
        - CallLifecycleManager: participant/call state changes
        - connection_manager: WebSocket connection cleanup
        - status_service: user online/offline status (ONLY for lobby disconnect)
        - Pub/Sub listener cleanup
        """
        logger.info(f"[WebSocket] _handle_disconnect called for user {self.user_id}, session {self.session_id}")
        
        # Cancel Pub/Sub listener task if running
        if self._pubsub_task and not self._pubsub_task.done():
            self._pubsub_task.cancel()
            try:
                await self._pubsub_task
            except asyncio.CancelledError:
                pass
            logger.info(f"[WebSocket] Cancelled Pub/Sub listener for session {self.session_id}")
        
        call_ended = False
        
        # Handle call-specific logic BEFORE removing from connection manager
        if self._is_real_call():
            call_id = self.call_info["call_id"]
            call_ended = await self._handle_call_disconnect(call_id)
        
        # Disconnect from connection manager (sends participant_left)
        await connection_manager.disconnect(self.user_id)
        
        # Only mark user as offline when disconnecting from LOBBY
        # (call session disconnect should NOT affect online status - user still has lobby connection)
        if self.session_id == "lobby":
            # Issue D Fix: Use grace period to prevent status flicker
            await status_service.set_user_offline_with_grace(self.user_id, None, connection_manager)
        else:
            logger.info(f"[WebSocket] User {self.user_id} disconnected from call session {self.session_id}, NOT marking offline (lobby still active)")
    
    def _is_real_call(self) -> bool:
        """Check if this is a real call session (not lobby)."""
        return (
            self.session_id != "lobby" 
            and self.call_info is not None 
            and self.call_info.get("call_id") is not None
        )
    
    async def _handle_call_disconnect(self, call_id: str) -> bool:
        """
        Handle disconnect from an active call.
        
        Returns:
            True if the call was ended, False otherwise.
        """
        logger.info(f"[WebSocket] Processing disconnect for call_id={call_id}")
        
        async with AsyncSessionLocal() as db:
            lifecycle = CallLifecycleManager(db)
            
            # Update participant and check if call should end
            participant_updated, call_ended = await lifecycle.handle_participant_disconnect(
                call_id=call_id,
                user_id=self.user_id,
                min_participants=2
            )
            
            if call_ended:
                # Notify remaining participants BEFORE we disconnect
                await self._notify_call_ended()
        
        return call_ended
    
    async def _notify_call_ended(self) -> None:
        """Send call_ended message to remaining participants."""
        await connection_manager.broadcast_to_session(
            self.session_id,
            {"type": "call_ended", "reason": "insufficient_participants"}
        )
        logger.info(f"[WebSocket] Sent call_ended to session {self.session_id}")
    
    async def _get_target_language(self) -> str:
        """
        Get the target language (other participant's language).
        
        In a 2-participant call, this is the language of the other participant.
        """
        if not self.call_info or not self.call_info.get("call_id"):
            return "en"  # Default fallback
        
        try:
            async with AsyncSessionLocal() as db:
                # Get all participants in this call except current user
                result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == self.call_info["call_id"],
                            CallParticipant.user_id != self.user_id
                        )
                    )
                )
                other_participant = result.scalar_one_or_none()
                
                if other_participant:
                    return other_participant.participant_language or "en"
                    
        except Exception as e:
            logger.error(f"[WebSocket] Error getting target language: {e}")
        
        return "en"  # Default fallback
    
    async def _listen_for_translations(self) -> None:
        """
        Listen for translation results from the Worker via Redis Pub/Sub.
        
        The Worker publishes to channel:translation:{session_id}
        """
        channel_name = f"channel:translation:{self.session_id}"
        logger.info(f"[WebSocket][{self.user_id}] Subscribing to {channel_name}")
        
        try:
            redis = await get_redis()
            pubsub = redis.pubsub()
            await pubsub.subscribe(channel_name)
            logger.info(f"[WebSocket][{self.user_id}] ✅ Successfully subscribed to {channel_name}")
            
            message_count = 0
            async for message in pubsub.listen():
                if message["type"] == "message":
                    message_count += 1
                    logger.info(f"[WebSocket][{self.user_id}] 📨 Received Pub/Sub message #{message_count}")
                    try:
                        data = json.loads(message["data"])
                        logger.info(f"[WebSocket][{self.user_id}] Parsed message type: {data.get('type')}, speaker: {data.get('speaker_id')}")
                        await self._handle_translation_result(data)
                    except json.JSONDecodeError as e:
                        logger.error(f"[WebSocket][{self.user_id}] Invalid JSON from Pub/Sub: {e}")
                    except Exception as e:
                        logger.error(f"[WebSocket][{self.user_id}] Error handling translation: {e}")
                        
        except asyncio.CancelledError:
            logger.info(f"[WebSocket][{self.user_id}] Pub/Sub listener cancelled for {self.session_id}")
            raise
        except Exception as e:
            logger.error(f"[WebSocket][{self.user_id}] Pub/Sub error: {e}")
        finally:
            try:
                await pubsub.unsubscribe(channel_name)
                await pubsub.close()
                logger.info(f"[WebSocket][{self.user_id}] Unsubscribed and closed Pub/Sub connection")
            except:
                pass
    
    async def _handle_translation_result(self, data: Dict[str, Any]) -> None:
        """
        Handle translation result from the Worker.

        Forwards the result to the appropriate WebSocket client.

        Message types from Worker:
        - interim_transcript: Real-time interim caption (sent to ALL including speaker)
        - transcription_update: Interim STT result
        - translation: Final translation with TTS audio
        """
        msg_type = data.get("type")
        speaker_id = data.get("speaker_id")
        recipient_ids = data.get("recipient_ids", [])  # Phase 3: NEW!

        logger.info(f"[WebSocket][{self.user_id}] Processing {msg_type} from speaker {speaker_id}")

        # INTERIM TRANSCRIPT: Send to ALL participants including self (for self-preview)
        if msg_type == "interim_transcript":
            await self._forward_interim_transcript(data, speaker_id)
            return

        # Other message types: Don't send back to the speaker
        if speaker_id == self.user_id:
            logger.info(f"[WebSocket][{self.user_id}] Skipping - this is from myself")
            return

        # Phase 3: Only send if this user is in recipient list
        if recipient_ids and self.user_id not in recipient_ids:
            logger.info(f"[WebSocket][{self.user_id}] Skipping - not in recipient list {recipient_ids}")
            return

        logger.info(f"[WebSocket][{self.user_id}] ✅ Forwarding {msg_type} to client")
        
        if msg_type == "transcription_update":
            # Interim transcription - send as JSON
            await self.websocket.send_json({
                "type": "transcription_update",
                "transcript": data.get("transcript", ""),
                "is_final": data.get("is_final", False),
                "speaker_id": speaker_id
            })
            logger.info(f"[WebSocket][{self.user_id}] Sent transcription_update: {data.get('transcript', '')[:50]}")
            
        elif msg_type == "translation":
            # Final translation with TTS audio
            # Send text info as JSON
            translation_msg = {
                "type": "translation",
                "transcript": data.get("transcript", ""),
                "translation": data.get("translation", ""),
                "source_lang": data.get("source_lang", ""),
                "target_lang": data.get("target_lang", ""),
                "speaker_id": speaker_id
            }
            await self.websocket.send_json(translation_msg)
            logger.info(f"[WebSocket][{self.user_id}] Sent translation JSON: '{data.get('transcript', '')}' -> '{data.get('translation', '')}'")
            
            # Send TTS audio as binary if present
            audio_hex = data.get("audio_content")
            if audio_hex:
                try:
                    audio_bytes = bytes.fromhex(audio_hex)
                    await self.websocket.send_bytes(audio_bytes)
                    logger.info(f"[WebSocket][{self.user_id}] ✅ Sent {len(audio_bytes)} bytes TTS audio")
                except Exception as e:
                    logger.error(f"[WebSocket][{self.user_id}] ❌ Failed to send TTS audio: {e}")
            else:
                logger.warning(f"[WebSocket][{self.user_id}] No TTS audio in translation")

    async def _forward_interim_transcript(self, data: Dict[str, Any], speaker_id: str) -> None:
        """
        Forward interim transcript to client.

        Unlike other messages, interim transcripts are sent to ALL participants
        including the speaker (for self-preview / typing indicator).
        """
        # Determine if this is from self (for UI tagging)
        is_self = (speaker_id == self.user_id)

        interim_msg = {
            "type": "interim_transcript",
            "text": data.get("text", ""),
            "speaker_id": speaker_id,
            "is_self": is_self,  # Client uses this to tag as "You" vs speaker name
            "source_lang": data.get("source_lang", ""),
            "is_final": data.get("is_final", False),
            "confidence": data.get("confidence", 0.7),
            "timestamp": data.get("timestamp")
        }

        await self.websocket.send_json(interim_msg)
        tag = "[You]" if is_self else f"[{speaker_id[:8]}]"
        logger.debug(f"[WebSocket][{self.user_id}] Sent interim_transcript {tag}: '{data.get('text', '')[:30]}...'")


def _normalize_language_code(lang: str) -> str:
    """
    Normalize language codes to Google Cloud format.
    
    Examples:
        he -> he-IL
        en -> en-US
        ru -> ru-RU
        he-IL -> he-IL (unchanged)
    """
    if not lang:
        return "en-US"
    
    # Already in full format
    if "-" in lang:
        return lang
    
    # Map short codes to full codes
    lang_map = {
        "he": "he-IL",
        "en": "en-US",
        "ru": "ru-RU",
        "es": "es-ES",
    }
    
    return lang_map.get(lang.lower(), f"{lang}-{lang.upper()}")
