
import asyncio
import os
import sys

# Ensure we can import from backend
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from backend.app.db.session import async_session_factory
from sqlalchemy import text

async def reset_calls():
    print("Connecting to database...")
    async with async_session_factory() as session:
        print("Resetting all active calls...")
        await session.execute(text("UPDATE calls SET is_active = false WHERE is_active = true"))
        await session.execute(text("UPDATE users SET is_online = true")) # Ensure users are online
        await session.commit()
        print("Done! All calls marked inactive.")

if __name__ == "__main__":
    # Windows/Selector event loop policy fix if needed
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        
    asyncio.run(reset_calls())
