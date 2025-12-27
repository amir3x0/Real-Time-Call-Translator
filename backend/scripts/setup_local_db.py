import asyncio
import asyncpg
from app.config.settings import settings
import sys

# Force settings for local setup if not set
DB_USER = "postgres" # Force using postgres user for local setup simplicity
DB_HOST = "localhost"

async def setup_db():
    print(f"🔌 Connecting to PostgreSQL at {DB_HOST} as {DB_USER}...")
    
    try:
        # Connect to default 'postgres' database to create the new one
        sys_conn = await asyncpg.connect(
            user=DB_USER,
            password=settings.DB_PASSWORD,
            database='postgres',
            host=DB_HOST,
            port=settings.DB_PORT
        )
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        print("\nPlease ensure:")
        print("1. PostgreSQL is running")
        print("2. You updated DB_PASSWORD in .env")
        print("3. You are using the 'postgres' user (we will use this for local dev)")
        return

    try:
        # Check if database exists
        exists = await sys_conn.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", settings.DB_NAME)
        
        if not exists:
            print(f"📦 Creating database '{settings.DB_NAME}'...")
            await sys_conn.execute(f'CREATE DATABASE "{settings.DB_NAME}"')
            print("✅ Database created!")
        else:
            print(f"✅ Database '{settings.DB_NAME}' already exists.")
            
    finally:
        await sys_conn.close()

if __name__ == "__main__":
    # We need to run this with the project root in PYTHONPATH
    try:
        asyncio.run(setup_db())
    except ImportError:
        print("Error: Please run this from the backend directory with PYTHONPATH set.")
