import asyncio
import redis.asyncio as redis
import os

async def test_redis():
    host = '127.0.0.1'
    port = 6379
    # Try without password first
    print(f"Attempting to connect to {host}:{port} without password...")
    try:
        r = redis.Redis(host=host, port=port, socket_connect_timeout=2)
        await r.ping()
        print("✅ Connected successfully WITHOUT password!")
        return
    except Exception as e:
        print(f"❌ Failed without password: {e}")

    # Try with password from env if available (simulated)
    # We don't know the password in .env, but let's try a common one or just report failure
    print("\nIf you have a password set in .env but your Redis server doesn't require one (or vice versa), that's the issue.")

if __name__ == "__main__":
    asyncio.run(test_redis())
