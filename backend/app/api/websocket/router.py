from fastapi import APIRouter, WebSocket, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
import logging
from typing import Optional

from app.models.user import User
from app.api.deps import get_db, get_current_ws_user
from app.services.session.orchestrator import call_orchestrator

router = APIRouter()
logger = logging.getLogger(__name__)

@router.websocket("/{session_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    session_id: str,
    call_id: Optional[str] = Query(None),
    user: User = Depends(get_current_ws_user),
    db: AsyncSession = Depends(get_db)
):
    """
    WebSocket endpoint for real-time call communication.
    Delegates to CallOrchestrator.
    """
    # If dependency returned None (auth failed), connection is already closed.
    if not user:
        return

    # Accept the connection
    await websocket.accept()
    
    # Hand over to orchestrator
    await call_orchestrator.handle_connection(websocket, session_id, user, db)
