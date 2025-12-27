import asyncio
import json
import sys
import os
import logging

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.redis import get_redis
from app.services.rtc_service import publish_audio_chunk

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def verify_e2e():
    print("🚀 Starting E2E Verification...", flush=True)
    
    redis = await get_redis()
    pubsub = redis.pubsub()
    
    session_id = "e2e_test_session"
    channel = f"channel:translation:{session_id}"
    
    # Subscribe to translation channel
    await pubsub.subscribe(channel)
    print(f"Listening on {channel}...", flush=True)
    
    # Publish mock audio
    mock_audio = b'\x00' * 32000
    
    print("Publishing mock audio chunk...", flush=True)
    await publish_audio_chunk(
        session_id=session_id,
        chunk=mock_audio,
        source_lang="en-US",
        target_lang="es-ES",
        speaker_id="tester"
    )
    
    print("Waiting for translation response (timeout 10s)...", flush=True)
    
    try:
        async with asyncio.timeout(10):
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    print("✅ Received translation!", flush=True)
                    print(f"Transcript: {data.get('transcript')}", flush=True)
                    print(f"Translation: {data.get('translation')}", flush=True)
                    break
    except asyncio.TimeoutError:
        print("❌ Timeout waiting for translation. Is the worker running?", flush=True)
        print("Check worker logs for errors (e.g. GCP credentials).", flush=True)
    except Exception as e:
        print(f"❌ Error: {e}", flush=True)
    finally:
        await pubsub.unsubscribe(channel)
        await redis.close()

if __name__ == "__main__":
    try:
        asyncio.run(verify_e2e())
    except KeyboardInterrupt:
        pass
