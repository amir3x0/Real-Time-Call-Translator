from typing import Any
from app.config.redis import get_redis


async def publish_audio_chunk(session_id: str, chunk: bytes) -> str:
    r = await get_redis()
    stream_name = f"stream:audio:{session_id}"
    # xadd expects mapping of strings; we store raw bytes under b'data' key
    # redis-py handles bytes automatically; use a field name 'data'
    result = await r.xadd(stream_name, {b"data": chunk})
    return result
