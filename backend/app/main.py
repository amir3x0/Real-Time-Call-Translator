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
from app.services.connection_manager import connection_manager
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

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include REST API routes
app.include_router(api_router, prefix="/api")

# Include WebSocket routes
app.include_router(ws_router)


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
