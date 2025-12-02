import asyncio
import json
import sys
import os
import argparse

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.redis import get_redis
from app.services.rtc_service import publish_audio_chunk

async def run_translation_test(file_path: str):
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    print(f"🎧 Reading audio file: {file_path}")
    with open(file_path, "rb") as f:
        audio_data = f.read()

    print(f"📊 Audio size: {len(audio_data)} bytes")
    
    # NOTE: The GCP pipeline expects LINEAR16 (PCM) 16kHz mono audio.
    # If the file is not in this format, transcription might fail or produce garbage.
    
    redis = await get_redis()
    pubsub = redis.pubsub()
    
    session_id = "real_test_session"
    channel = f"channel:translation:{session_id}"
    
    await pubsub.subscribe(channel)
    print(f"📡 Listening for results on {channel}...")

    # Publish the whole file as one chunk for simplicity in this test
    # In a real stream, we'd chunk it.
    print("🚀 Sending audio to translation pipeline...")
    await publish_audio_chunk(
        session_id=session_id,
        chunk=audio_data,
        source_lang="en-US",
        target_lang="he-IL",
        speaker_id="tester"
    )

    print("⏳ Waiting for translation...")
    
    try:
        async with asyncio.timeout(30): # Give it 30 seconds
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    print("\n✅ Translation Received!")
                    print(f"📝 Transcript: {data.get('transcript')}")
                    print(f"🔄 Translation: {data.get('translation')}")
                    
                    audio_hex = data.get("audio_content")
                    if audio_hex:
                        output_file = "output_hebrew.mp3"
                        with open(output_file, "wb") as out_f:
                            out_f.write(bytes.fromhex(audio_hex))
                        print(f"🔊 Audio saved to: {os.path.abspath(output_file)}")
                    else:
                        print("⚠️ No audio content received.")
                    
                    break
    except asyncio.TimeoutError:
        print("\n❌ Timeout waiting for translation.")
        print("Check the worker logs for errors.")
    finally:
        await pubsub.unsubscribe(channel)
        await redis.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test real translation with an audio file")
    parser.add_argument("file", help="Path to a 16kHz mono WAV file")
    args = parser.parse_args()
    
    try:
        asyncio.run(run_translation_test(args.file))
    except KeyboardInterrupt:
        pass
