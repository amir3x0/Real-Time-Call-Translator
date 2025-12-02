import asyncio
import logging
import sys
import os

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.audio_worker import run_worker

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    try:
        asyncio.run(run_worker())
    except KeyboardInterrupt:
        print("Worker stopped manually")
