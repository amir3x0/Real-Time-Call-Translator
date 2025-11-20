from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from app.api import router as api_router
from app.config.redis import get_redis, close_redis
from app.services.rtc_service import publish_audio_chunk

app = FastAPI(title="Real-Time Call Translator Backend")

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
    try:
        while True:
            # Receive raw bytes over the WebSocket
            data = await websocket.receive_bytes()
            # Publish to Redis stream as a chunk of audio
            # In the future, we could validate or add metadata
            await publish_audio_chunk(session_id, data)
    except WebSocketDisconnect:
        return
