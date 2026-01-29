"""Real-Time Communication Service - Audio stream publishing.

Handles publishing audio chunks to Redis Streams for worker processing.
This is the bridge between WebSocket audio reception and the
translation pipeline worker.

Architecture:
    Mobile App -> WebSocket -> Orchestrator -> rtc_service -> Redis Stream -> Worker
"""

from typing import Any
from app.config.redis import get_redis


async def publish_audio_chunk(
    session_id: str,
    chunk: bytes,
    source_lang: str = "he-IL",
    speaker_id: str = "unknown"
) -> str:
    """
    Publish audio chunk to Redis Stream for worker processing.

    Phase 3 Change: target_lang parameter removed. Worker now determines target
    languages from CallParticipant table to support multi-party calls (3+ participants).
    """
    r = await get_redis()
    # Use a global stream for the worker to consume
    stream_name = "stream:audio:global"

    # Add metadata to the message
    data = {
        b"data": chunk,
        b"session_id": session_id.encode("utf-8"),
        b"source_lang": source_lang.encode("utf-8"),
        b"speaker_id": speaker_id.encode("utf-8")
        # target_lang removed - determined by worker from database
    }

    result = await r.xadd(stream_name, data)
    return result
