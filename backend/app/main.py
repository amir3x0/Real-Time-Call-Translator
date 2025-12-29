"""
Real-Time Call Translator Backend - Main Application

This is the entry point for the FastAPI application.
It handles:
- REST API endpoints (auth, contacts, calls, voice)
- WebSocket connections for real-time call communication
- Background tasks for cleanup and status tracking
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
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
from app.models.database import Base, engine

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# =============================================================================
# Background Tasks
# =============================================================================

class BackgroundTaskManager:
    """Manages background tasks with proper lifecycle control."""
    
    def __init__(self):
        self._cleanup_task: Optional[asyncio.Task] = None
        self._translation_task: Optional[asyncio.Task] = None
        self._running = False
    
    async def start(self) -> None:
        """Start all background tasks."""
        self._running = True
        
        # Start background cleanup task
        self._cleanup_task = asyncio.create_task(
            status_service.cleanup_offline_users(),
            name="cleanup_offline_users"
        )
        logger.info("✅ Background cleanup task started")
        
        # Start voice training worker
        await voice_training_service.start_worker()
        logger.info("✅ Voice training worker started")
        
        # Start translation subscription
        self._translation_task = asyncio.create_task(
            subscribe_to_translations(),
            name="translation_subscription"
        )
        logger.info("✅ Translation subscription started")
    
    async def stop(self) -> None:
        """Stop all background tasks gracefully."""
        self._running = False
        
        # Cancel cleanup task
        if self._cleanup_task and not self._cleanup_task.done():
            self._cleanup_task.cancel()
            try:
                await self._cleanup_task
            except asyncio.CancelledError:
                pass
            logger.info("✅ Cleanup task stopped")
        
        # Cancel translation task
        if self._translation_task and not self._translation_task.done():
            self._translation_task.cancel()
            try:
                await self._translation_task
            except asyncio.CancelledError:
                pass
            logger.info("✅ Translation subscription stopped")
        
        # Stop voice training worker
        await voice_training_service.stop_worker()
        logger.info("✅ Voice training worker stopped")


# Global task manager instance
_task_manager = BackgroundTaskManager()


async def subscribe_to_translations() -> None:
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
    except asyncio.CancelledError:
        # Clean shutdown
        await pubsub.punsubscribe("channel:translation:*")
        raise
    except Exception as e:
        logger.error(f"Translation subscription error: {e}")


# =============================================================================
# Lifespan Context Manager
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Modern lifespan context manager for startup/shutdown.
    
    Replaces deprecated @app.on_event("startup") and @app.on_event("shutdown").
    """
    # --- STARTUP ---
    logger.info("🚀 Starting Real-Time Call Translator Backend...")
    
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Database tables created")
    
    # Ensure redis connection is established
    await get_redis()
    logger.info("✅ Redis connected")
    
    # Start background tasks
    await _task_manager.start()
    
    logger.info("🎉 All services started successfully")
    
    yield  # Application runs here
    
    # --- SHUTDOWN ---
    logger.info("🛑 Shutting down...")
    
    # Stop background tasks
    await _task_manager.stop()
    
    # Close Redis connection
    await close_redis()
    
    logger.info("✅ Shutdown complete")


# =============================================================================
# Application Setup
# =============================================================================

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


# =============================================================================
# Routes
# =============================================================================

# Include REST API routes
app.include_router(api_router, prefix="/api")

# Include WebSocket routes
from app.api.websocket.router import router as ws_router
app.include_router(ws_router, prefix="/ws", tags=["websockets"])


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
