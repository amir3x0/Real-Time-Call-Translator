"""
WebSocket Router - Real-time Call Communication Endpoint

This is the thin routing layer that delegates to CallOrchestrator
for all WebSocket session management.
"""
from typing import Optional
import logging

from fastapi import APIRouter, WebSocket, Query

from app.services.session import CallOrchestrator

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/{session_id}")
async def websocket_connect(
    websocket: WebSocket,
    session_id: str,
    token: str = Query(...),
    call_id: Optional[str] = Query(None)
):
    """
    WebSocket endpoint for real-time call communication.
    
    This endpoint handles:
    - Connection establishment with participant info
    - Heartbeat messages for status tracking
    - Audio data routing to other participants
    - Control messages (mute, etc.)
    
    Query Parameters:
        session_id: Call session ID (path parameter)
        token: JWT Token (required)
        call_id: Call ID (optional, will look up from session_id if not provided)
    
    Message Types (JSON):
        - heartbeat: Refresh connection status
        - mute: Toggle mute status
        - leave: Leave the call
    
    Binary Messages:
        - Raw audio data to be broadcast to other participants
    """
    orchestrator = CallOrchestrator(
        websocket=websocket,
        session_id=session_id,
        token=token,
        call_id=call_id
    )
    await orchestrator.run()


@router.websocket("/lobby")
async def websocket_lobby(
    websocket: WebSocket,
    token: str = Query(...)
):
    """
    WebSocket endpoint for lobby status updates.
    """
    logger.info(f"[WS Router] New connection attempt to LOBBY with token prefix {token[:10] if token else 'None'}")
    orchestrator = CallOrchestrator(
        websocket=websocket,
        session_id="lobby",
        token=token
    )
    await orchestrator.run()
