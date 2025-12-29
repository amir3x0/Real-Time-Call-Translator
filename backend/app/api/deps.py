from typing import Optional, AsyncGenerator
from fastapi import WebSocket, Query, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import logging

from app.models.database import AsyncSessionLocal
from app.models.user import User
from app.services.auth_service import decode_token

logger = logging.getLogger(__name__)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency for getting async database session.
    """
    async with AsyncSessionLocal() as db:
        try:
            yield db
        finally:
            # session is closed automatically by context manager
            pass

async def get_current_ws_user(
    websocket: WebSocket,
    session_id: str,
    token: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """
    WebSocket dependency to authenticate user via JWT token.
    If authentication fails, closes the connection with code 1008.
    """
    # Accept the connection temporarily to handle errors gracefully if needed, 
    # but strictly speaking, we check token before full acceptance logic in router usually.
    # However, common pattern is to validate token before accepting OR accept then close.
    # In main.py, it did `await websocket.accept()` FIRST.
    # Let's keep the logic consistent: The dependency itself doesn't accept, 
    # but the router will accept. Wait, if I want to reject inside dependency, 
    # I might need to accept to send a close frame properly, or just close.
    # FastAPI WebSocket dependency usually just returns value or raises exception/closes.
    
    if not token:
        logger.warning(f"[WebSocket] Missing token for session {session_id}")
        await websocket.close(code=1008, reason="Missing token")
        return None

    # Decode token
    payload = decode_token(token)
    if not payload or not payload.get("sub"):
        logger.warning(f"[WebSocket] Invalid token for session {session_id}")
        await websocket.close(code=1008, reason="Invalid token")
        return None
        
    user_id = payload.get("sub")
    
    # Get user from DB
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        logger.warning(f"[WebSocket] User not found: {user_id}")
        await websocket.close(code=1008, reason="User not found")
        return None
        
    return user
