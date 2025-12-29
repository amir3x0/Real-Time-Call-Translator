"""
Real-Time Call Translator Backend - Main Application

This is the entry point for the FastAPI application.
It handles:
- REST API endpoints (auth, contacts, calls, voice)
- WebSocket connections for real-time call communication
- Background tasks for cleanup and status tracking
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import json
import asyncio
import logging
from datetime import datetime

from app.api import router as api_router
from app.config.redis import get_redis, close_redis
from app.services.rtc_service import publish_audio_chunk
from app.services.status_service import status_service
from app.services.connection_manager import connection_manager
from app.services.voice_training_service import voice_training_service
from app.models.database import Base, engine

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
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
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
    
    # Start translation subscription
    asyncio.create_task(subscribe_to_translations())
    logger.info("✅ Translation subscription started")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    logger.info("🛑 Shutting down...")
    await voice_training_service.stop_worker()
    await close_redis()


# Include REST API routes
app.include_router(api_router, prefix="/api")

# Include WebSocket routes
from app.api.websocket.router import router as ws_router
app.include_router(ws_router, prefix="/ws", tags=["websockets"])


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
