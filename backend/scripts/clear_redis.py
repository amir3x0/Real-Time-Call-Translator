import asyncio
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config.redis import get_redis

async def clear_redis():
    print("🧹 Clearing Redis...")
    redis = await get_redis()
    await redis.flushall()
    print("✅ Redis cleared.")
    await redis.close()

if __name__ == "__main__":
    asyncio.run(clear_redis())
