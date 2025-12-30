"""
Connection Manager

Core WebSocket connection management:
- Connection/disconnection handling
- Session tracking
- Message broadcasting
"""
import asyncio
from datetime import datetime
from typing import Dict, List, Optional, Any
import logging

from fastapi import WebSocket

from .models import CallConnection
from .notifications import (
    broadcast_user_status as _broadcast_user_status,
    notify_contact_request as _notify_contact_request,
    notify_incoming_call as _notify_incoming_call,
)
from .audio_router import (
    broadcast_audio as _broadcast_audio,
    broadcast_translation as _broadcast_translation,
)

logger = logging.getLogger(__name__)


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
    
    # === Core Connection Methods ===
    
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
        """Register a new WebSocket connection."""
        async with self._lock:
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
            
            if session_id not in self._sessions:
                self._sessions[session_id] = {}
            
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
        """Remove a user's connection."""
        async with self._lock:
            session_id = self._user_sessions.pop(user_id, None)
            
            if session_id and session_id in self._sessions:
                self._sessions[session_id].pop(user_id, None)
                
                if not self._sessions[session_id]:
                    del self._sessions[session_id]
        
        if session_id:
            logger.info(f"User {user_id} disconnected from session {session_id}")
            
            await self.broadcast_to_session(session_id, {
                "type": "participant_left",
                "user_id": user_id,
                "timestamp": datetime.utcnow().isoformat()
            })
        
        return session_id
    
    # === Broadcast Methods ===
    
    async def broadcast_to_session(
        self, 
        session_id: str, 
        message: Dict[str, Any],
        exclude_user: Optional[str] = None
    ) -> int:
        """Send a JSON message to all participants in a session."""
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
    
    async def send_to_user(self, user_id: str, message: Dict[str, Any]) -> bool:
        """Send a message to a specific user."""
        session_id = self._user_sessions.get(user_id)
        if not session_id:
            return False
        
        conn = self._sessions.get(session_id, {}).get(user_id)
        if not conn:
            return False
        
        return await conn.send_json(message)
    
    # === Notification Methods (delegates to notifications module) ===
    
    async def broadcast_user_status(self, user_id: str, is_online: bool, contact_user_ids: List[str]) -> int:
        return await _broadcast_user_status(self._sessions, user_id, is_online, contact_user_ids)
    
    async def notify_contact_request(self, target_user_id: str, requester_id: str, requester_name: str, request_id: str) -> bool:
        return await _notify_contact_request(self._sessions, self._user_sessions, target_user_id, requester_id, requester_name, request_id)
    
    async def notify_incoming_call(self, user_id: str, call_id: str, caller_id: str, caller_name: str, caller_language: str) -> bool:
        return await _notify_incoming_call(self._sessions, user_id, call_id, caller_id, caller_name, caller_language)
    
    # === Audio Methods (delegates to audio_router module) ===
    
    async def broadcast_audio(self, session_id: str, speaker_id: str, audio_data: bytes, timestamp_ms: int = 0) -> Dict[str, Any]:
        return await _broadcast_audio(self._sessions, session_id, speaker_id, audio_data, timestamp_ms)
    
    async def broadcast_translation(self, session_id: str, translation_data: Dict[str, Any]) -> int:
        return await _broadcast_translation(self._sessions, session_id, translation_data)
    
    # === Mute Control ===
    
    async def set_mute(self, session_id: str, user_id: str, is_muted: bool) -> bool:
        """Set mute status for a user in a session."""
        if session_id not in self._sessions:
            return False
        
        conn = self._sessions[session_id].get(user_id)
        if not conn:
            return False
        
        conn.is_muted = is_muted
        
        await self.broadcast_to_session(session_id, {
            "type": "mute_status_changed",
            "user_id": user_id,
            "is_muted": is_muted,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return True
    
    # === Query Methods ===
    
    def get_session_participants(self, session_id: str) -> List[str]:
        """Get list of user IDs in a session."""
        if session_id not in self._sessions:
            return []
        return list(self._sessions[session_id].keys())
    
    def get_participant_count(self, session_id: str) -> int:
        """Get number of participants in a session."""
        return len(self._sessions.get(session_id, {}))
    
    def is_user_connected(self, user_id: str) -> bool:
        """Check if a user is currently connected to any session."""
        return user_id in self._user_sessions
    
    def get_user_session(self, user_id: str) -> Optional[str]:
        """Get the session ID a user is currently in."""
        return self._user_sessions.get(user_id)
    
    def get_connection(self, user_id: str) -> Optional[CallConnection]:
        """Get a user's connection object."""
        session_id = self._user_sessions.get(user_id)
        if not session_id:
            return None
        return self._sessions.get(session_id, {}).get(user_id)
    
    def get_active_session_count(self) -> int:
        """Get number of active sessions."""
        return len(self._sessions)
    
    def get_total_connections(self) -> int:
        """Get total number of active connections."""
        return len(self._user_sessions)
