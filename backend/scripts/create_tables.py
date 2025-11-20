import asyncio
from app.models.database import engine, Base, init_db
from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.contact import Contact
from app.models.voice_model import VoiceModel
from app.models.message import Message


async def create_tables():
    """Create all database tables"""
    print("Creating database tables...")
    print("Tables to create:")
    print("  - users")
    print("  - calls")
    print("  - call_participants")
    print("  - contacts")
    print("  - voice_models")
    print("  - messages")
    
    await init_db()
    
    print("✅ All tables created successfully!")
    print("\nDatabase schema ready for Real-Time Call Translator")


if __name__ == "__main__":
    asyncio.run(create_tables())
