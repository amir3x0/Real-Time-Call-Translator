"""
Connection Models

Data classes representing WebSocket connections.
"""
from datetime import datetime
from typing import Dict, Any, Optional
import logging

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class CallConnection:
    """Represents a single WebSocket connection in a call."""
    
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
        """Send JSON message to this connection."""
        try:
            await self.websocket.send_json(data)
            return True
        except Exception as e:
            logger.error(f"Error sending JSON to {self.user_id}: {e}")
            return False
    
    async def send_bytes(self, data: bytes) -> bool:
        """Send binary data (audio) to this connection."""
        try:
            await self.websocket.send_bytes(data)
            return True
        except Exception as e:
            logger.error(f"Error sending bytes to {self.user_id}: {e}")
            return False
