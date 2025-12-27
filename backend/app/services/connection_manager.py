"""
WebSocket Connection Manager

Manages WebSocket connections for real-time call communication.
Handles:
- Connection tracking per session
- Message broadcasting
- Audio routing with translation support
"""
import asyncio
from typing import Dict, List, Set, Optional, Any
from fastapi import WebSocket
from datetime import datetime
import json
import logging

logger = logging.getLogger(__name__)


class CallConnection:
    """Represents a single WebSocket connection in a call"""
    
    def __init__(
        self, 
        websocket: WebSocket, 
        user_id: str, 
        session_id: str,
        call_id: Optional[str],
        participant_language: str = "en",
        call_language: str = "en",
        dubbing_required: bool = False,
        use_voice_clone: bool = False,
        voice_clone_quality: Optional[str] = None
    ):
        self.websocket = websocket
        self.user_id = user_id
        self.session_id = session_id
        self.call_id = call_id
        self.participant_language = participant_language
        self.call_language = call_language
        self.dubbing_required = dubbing_required
        self.use_voice_clone = use_voice_clone
        self.voice_clone_quality = voice_clone_quality
        self.connected_at = datetime.utcnow()
        self.is_muted = False
    
    async def send_json(self, data: Dict[str, Any]) -> bool:
        """Send JSON message to this connection"""
        try:
            await self.websocket.send_json(data)
            return True
        except Exception as e:
            logger.error(f"Error sending JSON to {self.user_id}: {e}")
            return False
    
    async def send_bytes(self, data: bytes) -> bool:
        """Send binary data (audio) to this connection"""
        try:
            await self.websocket.send_bytes(data)
            return True
        except Exception as e:
            logger.error(f"Error sending bytes to {self.user_id}: {e}")
            return False


class ConnectionManager:
    """
    Manages all WebSocket connections across call sessions.
    
    Provides methods for:
    - Connecting/disconnecting users
    - Broadcasting messages within sessions
    - Routing audio between participants with translation support
    """
    
    def __init__(self):
        # session_id -> {user_id: CallConnection}
        self._sessions: Dict[str, Dict[str, CallConnection]] = {}
        # user_id -> session_id (for quick lookup)
        self._user_sessions: Dict[str, str] = {}
        # Lock for thread-safe operations
        self._lock = asyncio.Lock()
    
    async def connect(
        self, 
        websocket: WebSocket, 
        session_id: str,
        user_id: str,
        call_id: Optional[str] = None,
        participant_language: str = "en",
        call_language: str = "en",
        dubbing_required: bool = False,
        use_voice_clone: bool = False,
        voice_clone_quality: Optional[str] = None
    ) -> CallConnection:
        """
        Register a new WebSocket connection.
        
        Args:
            websocket: The WebSocket connection
            session_id: Call session ID
            user_id: ID of the connecting user
            call_id: ID of the call
            participant_language: User's language code
            call_language: Call's base language
            dubbing_required: Whether translation is needed
            use_voice_clone: Whether to use voice cloning
            voice_clone_quality: Quality level of voice clone
            
        Returns:
            CallConnection object
        """
        async with self._lock:
            # Create connection object
            conn = CallConnection(
                websocket=websocket,
                user_id=user_id,
                session_id=session_id,
                call_id=call_id,
                participant_language=participant_language,
                call_language=call_language,
                dubbing_required=dubbing_required,
                use_voice_clone=use_voice_clone,
                voice_clone_quality=voice_clone_quality
            )
            
            # Initialize session room if needed
            if session_id not in self._sessions:
                self._sessions[session_id] = {}
            
            # Add to session room
            self._sessions[session_id][user_id] = conn
            self._user_sessions[user_id] = session_id
        
        logger.info(f"User {user_id} connected to session {session_id}")
        
        # Notify other participants
        await self.broadcast_to_session(session_id, {
            "type": "participant_joined",
            "user_id": user_id,
            "language": participant_language,
            "timestamp": datetime.utcnow().isoformat()
        }, exclude_user=user_id)
        
        return conn
    
    async def disconnect(self, user_id: str) -> Optional[str]:
        """
        Remove a user's connection.
        
        Args:
            user_id: ID of the disconnecting user
            
        Returns:
            session_id if the user was in a session, None otherwise
        """
        async with self._lock:
            session_id = self._user_sessions.pop(user_id, None)
            
            if session_id and session_id in self._sessions:
                self._sessions[session_id].pop(user_id, None)
                
                # Clean up empty sessions
                if not self._sessions[session_id]:
                    del self._sessions[session_id]
        
        if session_id:
            logger.info(f"User {user_id} disconnected from session {session_id}")
            
            # Notify other participants
            await self.broadcast_to_session(session_id, {
                "type": "participant_left",
                "user_id": user_id,
                "timestamp": datetime.utcnow().isoformat()
            })
        
        return session_id
    
    async def broadcast_user_status(
        self,
        user_id: str,
        is_online: bool,
        contact_user_ids: List[str]
    ) -> int:
        """
        Broadcast user status change to all their contacts.
        
        Args:
            user_id: ID of the user whose status changed
            is_online: New online status
            contact_user_ids: List of contact user IDs to notify
            
        Returns:
            Number of contacts notified
        """
        if not contact_user_ids:
            return 0
        
        notification = {
            "type": "user_status_changed",
            "user_id": user_id,
            "is_online": is_online,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        notified_count = 0
        # Find all connections for contact users
        for contact_user_id in contact_user_ids:
            # Find user's active connection (could be in any session)
            for session_id, connections in self._sessions.items():
                for conn in connections.values():
                    if conn.user_id == contact_user_id:
                        try:
                            await conn.send_json(notification)
                            notified_count += 1
                            logger.debug(f"Notified user {contact_user_id} about {user_id} status: {is_online}")
                        except Exception as e:
                            logger.error(f"Error notifying user {contact_user_id}: {e}")
        
        return notified_count
    
    async def notify_contact_request(
        self,
        target_user_id: str,
        requester_id: str,
        requester_name: str,
        request_id: str
    ) -> bool:
        """
        Notify a user of a new contact request.
        """
        notification = {
            "type": "contact_request",
            "request_id": request_id,
            "requester_id": requester_id,
            "requester_name": requester_name,
            "timestamp": datetime.utcnow().isoformat()
        }
        return await self.send_to_user(target_user_id, notification)
    
    async def notify_incoming_call(
        self,
        user_id: str,
        call_id: str,
        caller_id: str,
        caller_name: str,
        caller_language: str
    ) -> bool:
        """
        Send incoming call notification to user via WebSocket if connected.
        
        Args:
            user_id: ID of the user to notify
            call_id: ID of the incoming call
            caller_id: ID of the caller
            caller_name: Name of the caller
            caller_language: Language of the call
            
        Returns:
            True if notification was sent, False if user not connected
        """
        # Find user's active connection (could be in any session)
        sent_any = False
        for session_id, connections in self._sessions.items():
            for conn in connections.values():
                if conn.user_id == user_id:
                    # Send notification
                    notification = {
                        "type": "incoming_call",
                        "call_id": call_id,
                        "caller_id": caller_id,
                        "caller_name": caller_name,
                        "call_language": caller_language,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                    try:
                        await conn.send_json(notification)
                        logger.info(f"Sent incoming call notification to user {user_id} in session {session_id}")
                        sent_any = True
                    except Exception as e:
                        logger.error(f"Error sending incoming call notification: {e}")
        
        if not sent_any:
            logger.debug(f"User {user_id} not connected, cannot send incoming call notification")
        
        return sent_any
    
    async def broadcast_to_session(
        self, 
        session_id: str, 
        message: Dict[str, Any],
        exclude_user: Optional[str] = None
    ) -> int:
        """
        Send a JSON message to all participants in a session.
        
        Args:
            session_id: ID of the session
            message: JSON message to send
            exclude_user: Optional user_id to exclude from broadcast
            
        Returns:
            Number of successful sends
        """
        if session_id not in self._sessions:
            return 0
        
        sent_count = 0
        connections = list(self._sessions[session_id].values())
        
        for conn in connections:
            if exclude_user and conn.user_id == exclude_user:
                continue
            
            if await conn.send_json(message):
                sent_count += 1
        
        return sent_count
    
    async def broadcast_translation(
        self,
        session_id: str,
        translation_data: Dict[str, Any]
    ) -> int:
        """
        Broadcast translation result to participants who need it.
        """
        if session_id not in self._sessions:
            return 0
            
        sent_count = 0
        target_lang = translation_data.get("target_lang")
        connections = list(self._sessions[session_id].values())
        
        # Check for self-test (single participant)
        is_self_test = len(connections) == 1
        
        for conn in connections:
            # Send if participant language matches target language
            # OR if it's the speaker (maybe for confirmation?) - usually no
            # We only send to those who need this language
            # SPECIAL CASE: If self-test, always send the result so they can hear the translation
            if is_self_test or conn.participant_language == target_lang:
                if await conn.send_json(translation_data):
                    sent_count += 1
                    
        return sent_count
    
    async def broadcast_audio(
        self,
        session_id: str,
        speaker_id: str,
        audio_data: bytes,
        timestamp_ms: int = 0
    ) -> Dict[str, Any]:
        """
        Broadcast audio data to all participants in a session.
        
        This method handles the routing logic:
        - For participants with same language as call: passthrough
        - For participants with different language: translation needed
        
        Args:
            session_id: ID of the session
            speaker_id: ID of the speaking user
            audio_data: Binary audio data
            timestamp_ms: Timestamp relative to call start
            
        Returns:
            Routing result dict
        """
        if session_id not in self._sessions:
            return {"status": "error", "message": "Session not found"}
        
        result = {
            "status": "success",
            "speaker_id": speaker_id,
            "timestamp_ms": timestamp_ms,
            "passthrough_count": 0,
            "translation_count": 0
        }
        
        # Get speaker connection
        speaker_conn = self._sessions[session_id].get(speaker_id)
        if not speaker_conn:
            return {"status": "error", "message": "Speaker not found"}
        
        # Get all other connections
        connections = [
            conn for conn in self._sessions[session_id].values()
            if conn.user_id != speaker_id and not conn.is_muted
        ]
        
        logger.info(f"[ConnectionManager] Broadcasting audio from {speaker_id} to {len(connections)} participants in session {session_id}")
        for c in connections:
             logger.debug(f"Target: {c.user_id}, Muted: {c.is_muted}, Dubbing: {c.dubbing_required}")

        # Group by target language
        translation_requests = set()
        
        for conn in connections:
            # Debug logging
            if conn.dubbing_required:
                logger.debug(f"User {conn.user_id} requires dubbing from {speaker_conn.participant_language} to {conn.participant_language}")
            
            # FORCE PASSTHROUGH FOR DEBUGGING
            # if conn.dubbing_required:
            #     # Add to set of needed translations (source -> target)
            #     translation_requests.add((speaker_conn.participant_language, conn.participant_language))
            # else:
            #     # Same language - passthrough
            await conn.send_bytes(audio_data)
            result["passthrough_count"] += 1
        
        # Publish for translation
        from app.services.rtc_service import publish_audio_chunk
        for source_lang, target_lang in translation_requests:
             await publish_audio_chunk(
                 session_id=session_id,
                 chunk=audio_data,
                 source_lang=source_lang,
                 target_lang=target_lang,
                 speaker_id=speaker_id
             )
             result["translation_count"] += 1
        
        return result
    
    async def set_mute(self, session_id: str, user_id: str, is_muted: bool) -> bool:
        """
        Set mute status for a user in a session.
        
        Args:
            session_id: ID of the session
            user_id: ID of the user
            is_muted: Mute status
            
        Returns:
            True if successful
        """
        if session_id not in self._sessions:
            return False
        
        conn = self._sessions[session_id].get(user_id)
        if not conn:
            return False
        
        conn.is_muted = is_muted
        
        # Notify other participants
        await self.broadcast_to_session(session_id, {
            "type": "mute_status_changed",
            "user_id": user_id,
            "is_muted": is_muted,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return True
    
    async def send_to_user(
        self,
        user_id: str,
        message: Dict[str, Any]
    ) -> bool:
        """
        Send a message to a specific user.
        
        Args:
            user_id: ID of the target user
            message: JSON message to send
            
        Returns:
            True if sent successfully
        """
        session_id = self._user_sessions.get(user_id)
        if not session_id:
            return False
        
        conn = self._sessions.get(session_id, {}).get(user_id)
        if not conn:
            return False
        
        return await conn.send_json(message)
    
    def get_session_participants(self, session_id: str) -> List[str]:
        """Get list of user IDs in a session"""
        if session_id not in self._sessions:
            return []
        return list(self._sessions[session_id].keys())
    
    def get_participant_count(self, session_id: str) -> int:
        """Get number of participants in a session"""
        return len(self._sessions.get(session_id, {}))
    
    def is_user_connected(self, user_id: str) -> bool:
        """Check if a user is currently connected to any session"""
        return user_id in self._user_sessions
    
    def get_user_session(self, user_id: str) -> Optional[str]:
        """Get the session ID a user is currently in"""
        return self._user_sessions.get(user_id)
    
    def get_connection(self, user_id: str) -> Optional[CallConnection]:
        """Get a user's connection object"""
        session_id = self._user_sessions.get(user_id)
        if not session_id:
            return None
        return self._sessions.get(session_id, {}).get(user_id)
    
    def get_active_session_count(self) -> int:
        """Get number of active sessions"""
        return len(self._sessions)
    
    def get_total_connections(self) -> int:
        """Get total number of active connections"""
        return len(self._user_sessions)


# Singleton instance
connection_manager = ConnectionManager()
