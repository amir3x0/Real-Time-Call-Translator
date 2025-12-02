from typing import Any
from app.config.redis import get_redis


async def publish_audio_chunk(
    session_id: str, 
    chunk: bytes,
    source_lang: str = "he-IL",
    target_lang: str = "en-US",
    speaker_id: str = "unknown"
) -> str:
    r = await get_redis()
    # Use a global stream for the worker to consume
    stream_name = "stream:audio:global"
    
    # Add metadata to the message
    data = {
        b"data": chunk,
        b"session_id": session_id.encode("utf-8"),
        b"source_lang": source_lang.encode("utf-8"),
        b"target_lang": target_lang.encode("utf-8"),
        b"speaker_id": speaker_id.encode("utf-8")
    }
    
    result = await r.xadd(stream_name, data)
    return result
