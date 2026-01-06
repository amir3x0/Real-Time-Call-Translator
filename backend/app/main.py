"""
Real-Time Call Translator Backend - Main Application

This is the entry point for the FastAPI application.
It handles:
- REST API endpoints (auth, contacts, calls, voice)
- WebSocket connections for real-time call communication
- Background tasks for cleanup and status tracking
"""
from contextlib import asynccontextmanager
import json
import asyncio
import logging
from datetime import datetime, UTC

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import router as api_router
from app.api.websocket import router as ws_router
from app.config.redis import get_redis, close_redis
from app.services.status_service import status_service
from app.services.connection import connection_manager
from app.services.voice_training_service import voice_training_service
from app.models.database import Base, engine

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def subscribe_to_translations():
    """Background task to listen for translation results from worker."""
    redis = await get_redis()
    pubsub = redis.pubsub()
    await pubsub.psubscribe("channel:translation:*")
    
    logger.info("✅ Subscribed to translation channels")
    
    try:
        async for message in pubsub.listen():
            if message["type"] == "pmessage":
                try:
                    data = json.loads(message["data"])
                    session_id = data.get("session_id")
                    if session_id:
                        await connection_manager.broadcast_translation(session_id, data)
                except Exception as e:
                    logger.error(f"Error processing translation message: {e}")
    except Exception as e:
        logger.error(f"Translation subscription error: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    
    Handles startup and shutdown events using the modern FastAPI pattern.
    """
    # === STARTUP ===
    logger.info("🚀 Starting Real-Time Call Translator Backend...")
    
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Database tables created")
    
    # Log configuration for debugging
    from app.config.settings import settings
    from app.models.database import DATABASE_URL
    logger.info(f"🔧 Configuration Check:")
    logger.info(f"   DB_HOST={settings.DB_HOST}, DB_PORT={settings.DB_PORT}, DB_USER={settings.DB_USER}")
    logger.info(f"   REDIS_HOST={settings.REDIS_HOST}, REDIS_PORT={settings.REDIS_PORT}")
    logger.info(f"   DATABASE_URL={DATABASE_URL}")
    
    # Ensure redis connection is established
    await get_redis()
    logger.info("✅ Redis connected")
    
    # Start background cleanup task
    asyncio.create_task(status_service.cleanup_offline_users())
    logger.info("✅ Background cleanup task started")
    
    # Start voice training worker
    await voice_training_service.start_worker()
    logger.info("✅ Voice training worker started")
    
    # Start translation subscription
    asyncio.create_task(subscribe_to_translations())
    logger.info("✅ Translation subscription started")
    
    yield  # Application runs here
    
    # === SHUTDOWN ===
    logger.info("🛑 Shutting down...")
    await voice_training_service.stop_worker()
    await close_redis()


app = FastAPI(
    title="Real-Time Call Translator Backend",
    description="Multi-party voice call translation with voice cloning",
    version="1.0.0",
    lifespan=lifespan
)

from app.config.settings import settings

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include REST API routes
app.include_router(api_router, prefix="/api")

# Include WebSocket routes
app.include_router(ws_router, prefix="/ws")


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
        "timestamp": datetime.now(UTC).isoformat(),
        "active_sessions": connection_manager.get_active_session_count(),
        "total_connections": connection_manager.get_total_connections()
    }


@app.get("/debug/audio-test")
async def debug_audio_test():
    """
    Debug endpoint to test the full audio pipeline without WebSocket.
    
    Tests: GCP STT -> Translate -> TTS
    """
    from app.services.gcp_pipeline import process_audio_chunk, PipelineResult
    import base64
    
    # Generate 1 second of silence (for testing connectivity, not actual speech)
    # In production, you'd send actual audio
    test_audio = b'\x00' * 32000  # 1 second at 16kHz, 16-bit
    
    try:
        result = await process_audio_chunk(
            test_audio,
            source_language_code="en-US",
            target_language_code="he-IL"
        )
        
        return {
            "status": "success",
            "transcript": result.transcript or "(silence - no speech detected)",
            "translation": result.translation or "(no translation)",
            "tts_audio_size": len(result.synthesized_audio) if result.synthesized_audio else 0,
            "message": "Pipeline working correctly" if result.transcript else "Pipeline works but no speech in test audio"
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "message": "Check GCP credentials and project configuration"
        }


@app.get("/debug/connections")
async def debug_connections():
    """Debug endpoint to see all active connections."""
    sessions_info = {}
    
    # Access internal sessions dict (for debugging only)
    for session_id, connections in connection_manager._sessions.items():
        sessions_info[session_id] = {
            "participant_count": len(connections),
            "participants": [
                {
                    "user_id": conn.user_id,
                    "language": conn.participant_language,
                    "is_muted": conn.is_muted,
                    "connected_at": conn.connected_at.isoformat()
                }
                for conn in connections.values()
            ]
        }
    
    return {
        "total_sessions": connection_manager.get_active_session_count(),
        "total_connections": connection_manager.get_total_connections(),
        "sessions": sessions_info
    }

