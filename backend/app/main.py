from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import json
import asyncio
import logging

from app.api import router as api_router
from app.config.redis import get_redis, close_redis
from app.services.rtc_service import publish_audio_chunk
from app.services.status_service import status_service
from app.models.database import get_db

app = FastAPI(title="Real-Time Call Translator Backend")

logger = logging.getLogger(__name__)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    # Ensure redis connection is established on startup
    await get_redis()
    
    # Start background cleanup task
    asyncio.create_task(status_service.cleanup_offline_users())


@app.on_event("shutdown")
async def shutdown_event():
    await close_redis()


app.include_router(api_router, prefix="/api")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.websocket("/ws/{session_id}")
async def ws_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    
    # Extract user_id from session_id or query params
    # For now, we'll use a query parameter: ?user_id=xxx
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
            # Receive message (can be text or bytes)
            message = await websocket.receive()
            
            # Handle heartbeat messages (text)
            if "text" in message:
                data = json.loads(message["text"])
                if data.get('type') == 'heartbeat':
                    # Process heartbeat - refresh status
                    await status_service.heartbeat(user_id)
                    # Log heartbeat for observability
                    logger.info(f"Heartbeat received: user_id=%s session_id=%s", user_id, session_id)
                    # Send acknowledgment
                    await websocket.send_json({"type": "heartbeat_ack"})
                    continue
            
            # Handle audio data (bytes)
            if "bytes" in message:
                audio_data = message["bytes"]
                # Publish to Redis stream as a chunk of audio
                await publish_audio_chunk(session_id, audio_data)
    
    except WebSocketDisconnect:
        pass
    finally:
        # Mark user as offline when WebSocket disconnects
        async for db in get_db():
            await status_service.set_user_offline(user_id, db)
            break
