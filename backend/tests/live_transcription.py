import asyncio
import json
import sys
import os
import pyaudio
import argparse

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.redis import get_redis
from app.services.rtc_service import publish_audio_chunk

# Audio configuration
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

async def live_transcription(source_lang="en-US", target_lang="he-IL"):
    print(f"🎤 Starting Live Transcription ({source_lang} -> {target_lang})")
    print("Press Ctrl+C to stop.")
    
    redis = await get_redis()
    pubsub = redis.pubsub()
    
    session_id = "live_demo_session"
    channel = f"channel:translation:{session_id}"
    
    await pubsub.subscribe(channel)
    
    # PyAudio setup
    p = pyaudio.PyAudio()
    stream = p.open(format=FORMAT,
                    channels=CHANNELS,
                    rate=RATE,
                    input=True,
                    frames_per_buffer=CHUNK)

    def fix_rtl(text):
        if not text: return ""
        # Check for Hebrew characters
        if any("\u0590" <= c <= "\u05FF" for c in text):
            return text[::-1]
        return text

    async def listen_loop():
        print(f"📡 Listening for results on {channel}...")
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    transcript = data.get('transcript')
                    translation = data.get('translation')
                    
                    # Fix RTL for terminal display
                    translation_display = fix_rtl(translation)
                    
                    print(f"\n🗣️  You said: {transcript}")
                    print(f"🔄 Translated: {translation_display}")
        except Exception as e:
            print(f"Listener error: {e}")

    async def record_loop():
        print("🔴 Recording... Speak now!")
        loop = asyncio.get_running_loop()
        
        while True:
            try:
                # Read audio chunk (blocking, so run in executor)
                data = await loop.run_in_executor(None, stream.read, CHUNK)
                
                # Calculate volume (RMS) to see if mic is working
                import audioop
                rms = audioop.rms(data, 2)
                # Simple volume bar
                bars = "|" * (rms // 500)
                if len(bars) > 0:
                    print(f"\r🎤 {bars[:20]}", end="", flush=True)
                
                await publish_audio_chunk(
                    session_id=session_id,
                    chunk=data,
                    source_lang=source_lang,
                    target_lang=target_lang,
                    speaker_id="live_user"
                )
            except Exception as e:
                print(f"Recording error: {e}")
                break

    # Run both tasks
    try:
        listener = asyncio.create_task(listen_loop())
        recorder = asyncio.create_task(record_loop())
        
        await asyncio.gather(listener, recorder)
    except asyncio.CancelledError:
        pass
    finally:
        print("\nStopping...")
        stream.stop_stream()
        stream.close()
        p.terminate()
        await pubsub.unsubscribe(channel)
        await redis.close()

if __name__ == "__main__":
    try:
        asyncio.run(live_transcription())
    except KeyboardInterrupt:
        pass
