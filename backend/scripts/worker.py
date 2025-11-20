import asyncio
import signal
from app.config.redis import get_redis


async def process(data: bytes):
    # Placeholder for real processing (speech -> translate -> tts)
    print("Processing chunk of length:", len(data))


async def run_worker(session_id: str = "testsess"):
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
                    await process(data)
                last_id = msg_id


if __name__ == "__main__":
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        print("Worker stopped manually")
