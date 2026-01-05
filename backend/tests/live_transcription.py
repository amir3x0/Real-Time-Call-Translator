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

LANGUAGES = {
    '1': {'name': 'English', 'code': 'en-US'},
    '2': {'name': 'Hebrew', 'code': 'iw-IL'},
    '3': {'name': 'Russian', 'code': 'ru-RU'},
    '4': {'name': 'Spanish', 'code': 'es-ES'},
}

def get_language_choice(prompt):
    print(f"\n{prompt}:")
    for key, lang in LANGUAGES.items():
        print(f"  {key}. {lang['name']}")
    
    while True:
        choice = input("Select language (1-4): ").strip()
        if choice in LANGUAGES:
            return LANGUAGES[choice]['code']
        print("Invalid choice, try again.")

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

    # Output stream for playback
    output_stream = p.open(format=FORMAT,
                           channels=CHANNELS,
                           rate=RATE,
                           output=True)

    def fix_rtl(text):
        if not text: return ""
        # Naive Hebrew detection and reversal for visual display
        if any("\u0590" <= c <= "\u05FF" for c in text):
            return text[::-1]
        return text

    async def listen_loop():
        print(f"📡 Listening for results on {channel}...")
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    msg_type = data.get("type", "translation")
                    
                    transcript = data.get('transcript', '')
                    translation = data.get('translation', '')
                    is_final = data.get('is_final', True) # Default to True for backward compat
                    
                    # Fix RTL for terminal display
                    transcript_display = fix_rtl(transcript)
                    translation_display = fix_rtl(translation)
                    
                    if msg_type == "transcription_update" or not is_final:
                        # Print interim in-place
                        print(f"\r⏳ Interim: {transcript_display} | 🔄 {translation_display}          ", end="", flush=True)
                    else:
                        # Final result
                        print(f"\r🗣️  You said: {transcript_display}          ") # Clear line
                        print(f"🔄 Translated: {translation_display}")

                        # Play audio if available
                        audio_hex = data.get('audio_content')
                        if audio_hex:
                            try:
                                audio_bytes = bytes.fromhex(audio_hex)
                                # Run in executor to avoid blocking the event loop
                                loop = asyncio.get_running_loop()
                                await loop.run_in_executor(None, output_stream.write, audio_bytes)
                            except Exception as e:
                                print(f"Audio playback error: {e}")
        except Exception as e:
            print(f"Listener error: {e}")
            import traceback
            traceback.print_exc()

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
        output_stream.stop_stream()
        output_stream.close()
        p.terminate()
        await pubsub.unsubscribe(channel)
        await redis.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Live Transcription & Translation')
    parser.add_argument('--source', help='Source language code (e.g. en-US)')
    parser.add_argument('--target', help='Target language code (e.g. he-IL)')
    args = parser.parse_args()

    try:
        if args.source and args.target:
            s_lang = args.source
            t_lang = args.target
        else:
            s_lang = get_language_choice("Choose microphone (source) language")
            t_lang = get_language_choice("Choose translation (target) language")

        asyncio.run(live_transcription(s_lang, t_lang))
    except KeyboardInterrupt:
        pass
