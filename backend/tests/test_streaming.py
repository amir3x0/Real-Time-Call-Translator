import asyncio
import json
import sys
import os
import argparse
import time

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.redis import get_redis
from app.services.rtc_service import publish_audio_chunk

async def run_streaming_test(file_path: str):
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    print(f"🎧 Reading audio file: {file_path}")
    with open(file_path, "rb") as f:
        audio_data = f.read()

    print(f"📊 Audio size: {len(audio_data)} bytes")
    
    redis = await get_redis()
    pubsub = redis.pubsub()
    
    session_id = "streaming_test_session"
    channel = f"channel:translation:{session_id}"
    
    await pubsub.subscribe(channel)
    print(f"📡 Listening for results on {channel}...")

    print("🚀 Streaming audio chunks...")
    
    # Simulate streaming by sending small chunks with delay
    chunk_size = 4096 # 256ms of audio at 16kHz 16bit mono
    
    async def listen_loop():
        try:
            async with asyncio.timeout(30):
                async for message in pubsub.listen():
                    if message["type"] == "message":
                        data = json.loads(message["data"])
                        print(f"\n✅ Result Received!")
                        print(f"📝 Transcript: {data.get('transcript')}")
                        print(f"🔄 Translation: {data.get('translation')}")
        except asyncio.TimeoutError:
            print("\n⚠️ Timeout waiting for more results.")

    # Start listener in background
    listener_task = asyncio.create_task(listen_loop())

    # Stream chunks
    for i in range(0, len(audio_data), chunk_size):
        chunk = audio_data[i:i+chunk_size]
        await publish_audio_chunk(
            session_id=session_id,
            chunk=chunk,
            source_lang="en-US",
            target_lang="he-IL",
            speaker_id="stream_tester"
        )
        # Simulate real-time delay (approx)
        # 4096 bytes / 2 bytes per sample / 16000 samples/sec = 0.128 sec
        await asyncio.sleep(0.1)
        print(".", end="", flush=True)
    
    print("\n✅ Finished streaming chunks.")
    await listener_task
    
    await pubsub.unsubscribe(channel)
    await redis.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test streaming translation")
    parser.add_argument("file", help="Path to a 16kHz mono WAV file")
    args = parser.parse_args()
    
    try:
        asyncio.run(run_streaming_test(args.file))
    except KeyboardInterrupt:
        pass
