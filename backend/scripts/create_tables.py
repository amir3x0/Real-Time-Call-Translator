import asyncio
from app.models.database import engine, Base, init_db
from app.models.user import User


async def create_tables():
    """Create all database tables"""
    print("Creating database tables...")
    await init_db()
    print("✅ All tables created successfully!")


if __name__ == "__main__":
    asyncio.run(create_tables())
