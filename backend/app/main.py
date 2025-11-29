"""
Real-Time Call Translator Backend - Main Application

This is the entry point for the FastAPI application.
It handles:
- REST API endpoints (auth, contacts, calls, voice)
- WebSocket connections for real-time call communication
- Background tasks for cleanup and status tracking
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
import json
import asyncio
import logging
from datetime import datetime
from typing import Optional

from app.api import router as api_router
from app.config.redis import get_redis, close_redis
from app.services.rtc_service import publish_audio_chunk
from app.services.status_service import status_service
from app.services.connection_manager import connection_manager
from app.services.voice_training_service import voice_training_service
from app.services.call_service import call_service
from app.models.database import get_db, AsyncSessionLocal, Base, engine
from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.contact import Contact
from app.models.call_transcript import CallTranscript
from app.models.voice_recording import VoiceRecording
from sqlalchemy import select, and_

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Real-Time Call Translator Backend",
    description="Multi-party voice call translation with voice cloning",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup."""
    logger.info("🚀 Starting Real-Time Call Translator Backend...")
    
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Database tables created")
    
    # Ensure redis connection is established
    await get_redis()
    logger.info("✅ Redis connected")
    
    # Start background cleanup task
    asyncio.create_task(status_service.cleanup_offline_users())
    logger.info("✅ Background cleanup task started")
    
    # Start voice training worker
    await voice_training_service.start_worker()
    logger.info("✅ Voice training worker started")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    logger.info("🛑 Shutting down...")
    await voice_training_service.stop_worker()
    await close_redis()


# Include REST API routes
app.include_router(api_router, prefix="/api")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": "Real-Time Call Translator",
        "version": "1.0.0",
        "status": "running"
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "active_sessions": connection_manager.get_active_session_count(),
        "total_connections": connection_manager.get_total_connections()
    }


@app.websocket("/ws/{session_id}")
async def ws_endpoint(
    websocket: WebSocket,
    session_id: str,
    user_id: Optional[str] = Query(None),
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
        user_id: User ID (required)
        call_id: Call ID (optional, will look up from session_id if not provided)
    
    Message Types (JSON):
        - heartbeat: Refresh connection status
        - mute: Toggle mute status
        - leave: Leave the call
    
    Binary Messages:
        - Raw audio data to be broadcast to other participants
    """
    await websocket.accept()
    
    # Validate user_id
    if not user_id:
        await websocket.close(code=1008, reason="Missing user_id")
        return
    
    logger.info(f"[WebSocket] Connection attempt: user_id={user_id}, session_id={session_id}")
    
    # Get participant and call information from database
    participant_info = None
    call_info = None
    call_start_time = None
    
    try:
        async with AsyncSessionLocal() as db:
            # Get user info
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            
            if not user:
                await websocket.close(code=1008, reason="User not found")
                return
            
            # Find call by session_id
            result = await db.execute(select(Call).where(Call.session_id == session_id))
            call = result.scalar_one_or_none()
            
            if not call:
                await websocket.close(code=1008, reason="Call session not found")
                return
            
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
                await websocket.close(code=1008, reason="Not a participant in this call")
                return
            
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
            
            # Mark user as online
            await status_service.set_user_online(user_id, db)
    
    except Exception as e:
        logger.error(f"[WebSocket] Database error during connection: {e}")
        await websocket.close(code=1011, reason="Database error")
        return
    
    # Connect to call session via ConnectionManager
    try:
        await connection_manager.connect(
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
    except Exception as e:
        logger.error(f"[WebSocket] ConnectionManager error: {e}")
        await websocket.close(code=1011, reason="Connection manager error")
        return
    
    # Send welcome message with call info
    await websocket.send_json({
        "type": "connected",
        "session_id": session_id,
        "call_id": call_info["call_id"],
        "call_language": call_info["call_language"],
        "participant_language": participant_info["participant_language"],
        "dubbing_required": participant_info["dubbing_required"]
    })
    
    try:
        while True:
            # Receive message (can be text or bytes)
            message = await websocket.receive()
            
            # Handle text messages (JSON)
            if "text" in message:
                try:
                    data = json.loads(message["text"])
                    msg_type = data.get('type')
                    
                    if msg_type == 'heartbeat':
                        # Process heartbeat - refresh status
                        await status_service.heartbeat(user_id)
                        await websocket.send_json({"type": "heartbeat_ack"})
                    
                    elif msg_type == 'mute':
                        # Toggle mute status
                        is_muted = data.get('muted', True)
                        await connection_manager.set_mute(session_id, user_id, is_muted)
                        
                        # Update database
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
                        
                        await websocket.send_json({
                            "type": "mute_ack",
                            "muted": is_muted
                        })
                    
                    elif msg_type == 'leave':
                        # User wants to leave the call
                        logger.info(f"[WebSocket] User {user_id} requested to leave session {session_id}")
                        break
                    
                    elif msg_type == 'ping':
                        # Simple ping/pong
                        await websocket.send_json({"type": "pong"})
                    
                    else:
                        logger.warning(f"[WebSocket] Unknown message type: {msg_type}")
                
                except json.JSONDecodeError:
                    logger.warning("[WebSocket] Invalid JSON received")
            
            # Handle binary messages (audio data)
            elif "bytes" in message:
                audio_data = message["bytes"]
                
                # Calculate timestamp from call start
                timestamp_ms = 0
                if call_start_time:
                    elapsed = datetime.utcnow() - call_start_time
                    timestamp_ms = int(elapsed.total_seconds() * 1000)
                
                # Broadcast audio to other participants
                result = await connection_manager.broadcast_audio(
                    session_id=session_id,
                    speaker_id=user_id,
                    audio_data=audio_data,
                    timestamp_ms=timestamp_ms
                )
                
                # Also publish to Redis for any workers (e.g., recording)
                await publish_audio_chunk(session_id, audio_data)
                
                # Log routing result (debug level)
                logger.debug(f"[WebSocket] Audio routed: {result}")
    
    except WebSocketDisconnect:
        logger.info(f"[WebSocket] User {user_id} disconnected from session {session_id}")
    
    except Exception as e:
        logger.error(f"[WebSocket] Error during session: {e}")
    
    finally:
        # Cleanup on disconnect
        await connection_manager.disconnect(user_id)
        
        # Update database
        async with AsyncSessionLocal() as db:
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
            
            # Check if call should end (fewer than 2 participants)
            call_ended, _ = await call_service.handle_participant_left(
                db, call_info["call_id"], user_id
            )
            
            if call_ended:
                logger.info(f"[WebSocket] Call {call_info['call_id']} ended - fewer than 2 participants")
                
                # Notify remaining participants that call ended
                await connection_manager.broadcast_to_session(
                    session_id,
                    {"type": "call_ended", "reason": "insufficient_participants"}
                )
            
            # Mark user as offline
            await status_service.set_user_offline(user_id, db)


# Legacy WebSocket endpoint for backwards compatibility
@app.websocket("/ws/legacy/{session_id}")
async def ws_legacy_endpoint(websocket: WebSocket, session_id: str):
    """
    Legacy WebSocket endpoint (simplified).
    
    This is kept for backwards compatibility with older clients.
    """
    await websocket.accept()
    
    user_id = websocket.query_params.get("user_id")
    
    if not user_id:
        await websocket.close(code=1008, reason="Missing user_id")
        return
    
    # Mark user as online
    async for db in get_db():
        await status_service.set_user_online(user_id, db)
        break
    
    try:
        while True:
            message = await websocket.receive()
            
            if "text" in message:
                data = json.loads(message["text"])
                if data.get('type') == 'heartbeat':
                    await status_service.heartbeat(user_id)
                    await websocket.send_json({"type": "heartbeat_ack"})
            
            if "bytes" in message:
                audio_data = message["bytes"]
                await publish_audio_chunk(session_id, audio_data)
    
    except WebSocketDisconnect:
        pass
    finally:
        async for db in get_db():
            await status_service.set_user_offline(user_id, db)
            break
