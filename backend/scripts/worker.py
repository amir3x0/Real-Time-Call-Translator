import asyncio
import signal
from typing import Optional

from app.config.redis import get_redis
from app.services.gcp_pipeline import process_audio_chunk


async def process(
    data: bytes,
    *,
    source_language: str,
    target_language: str,
    voice_name: Optional[str] = None,
):
    """Send audio through Google Cloud pipeline and log the response."""
    try:
        result = await process_audio_chunk(
            data,
            source_language_code=source_language,
            target_language_code=target_language,
            voice_name=voice_name,
        )
        if not result.transcript:
            print("GCP pipeline returned no transcript.")
            return

        print("Transcript:", result.transcript)
        print("Translation:", result.translation)
        print("Synthesized bytes:", len(result.synthesized_audio))
    except Exception as exc:  # pylint: disable=broad-except
        print("Failed to process chunk via GCP:", exc)


async def run_worker(
    session_id: str = "testsess",
    *,
    source_language: str = "he-IL",
    target_language: str = "en-US",
    voice_name: Optional[str] = None,
):
    r = await get_redis()
    stream = f"stream:audio:{session_id}"
    last_id = "0-0"
    running = True

    def stop(*args):
        nonlocal running
        running = False

    loop = asyncio.get_running_loop()
    loop.add_signal_handler(signal.SIGTERM, stop)
    loop.add_signal_handler(signal.SIGINT, stop)

    while running:
        res = await r.xread({stream: last_id}, count=10, block=1000)
        if not res:
            continue
        for sname, messages in res:
            for msg_id, msg_fields in messages:
                data = msg_fields.get(b"data") or msg_fields.get("data")
                if data:
                    await process(
                        data,
                        source_language=source_language,
                        target_language=target_language,
                        voice_name=voice_name,
                    )
                last_id = msg_id


if __name__ == "__main__":
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        print("Worker stopped manually")
