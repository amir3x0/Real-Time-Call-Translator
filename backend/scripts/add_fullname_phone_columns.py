import os
import asyncio
import asyncpg
from app.config.settings import settings

async def add_columns():
    conn = await asyncpg.connect(
        user=settings.DB_USER,
        password=settings.DB_PASSWORD,
        database=settings.DB_NAME,
        host=settings.DB_HOST,
        port=settings.DB_PORT,
    )
    try:
        # Add phone column if not exists
        await conn.execute(
            """
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='phone') THEN
                    ALTER TABLE users ADD COLUMN phone VARCHAR(20) UNIQUE;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='full_name') THEN
                    ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
                END IF;
            END
            $$;
            """
        )
        print("✅ Added missing `phone` and `full_name` columns if they didn't exist.")
    finally:
        await conn.close()

if __name__ == '__main__':
    asyncio.run(add_columns())
