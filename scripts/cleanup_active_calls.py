"""
Cleanup script for stuck/active calls in the database.
This script marks all ACTIVE and PENDING calls as ENDED to allow users to make new calls.
"""
import asyncio
import sys
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_path))

from sqlalchemy import select, update
from app.models.database import AsyncSessionLocal
from app.models.call import Call
from app.models.call_participant import CallParticipant
from datetime import datetime


async def cleanup_active_calls():
    """End all active and pending calls."""
    print("🔍 Searching for active/pending calls...")
    
    async with AsyncSessionLocal() as db:
        # Find all ACTIVE or PENDING calls (is_active=True)
        result = await db.execute(
            select(Call).where(Call.is_active == True)
        )
        calls = result.scalars().all()
        
        if not calls:
            print("✅ No active or pending calls found. Database is clean!")
            return
        
        print(f"📞 Found {len(calls)} stuck call(s):")
        for call in calls:
            print(f"  - Call ID: {call.id}")
            print(f"    Session: {call.session_id}")
            print(f"    Status: {call.status}")
            print(f"    Created: {call.created_at}")
        
        # Update all to ENDED
        await db.execute(
            update(Call)
            .where(Call.is_active == True)
            .values(
                status='ended',
                is_active=False,
                ended_at=datetime.utcnow()
            )
        )
        
        # Update all participants to disconnected
        await db.execute(
            update(CallParticipant)
            .where(CallParticipant.is_connected == True)
            .values(
                is_connected=False,
                left_at=datetime.utcnow()
            )
        )
        
        await db.commit()
        
        print(f"✅ Successfully ended {len(calls)} call(s)")
        print("✅ All participants marked as disconnected")
        print("\n🎉 Database cleaned! You can now make calls.")


async def cleanup_specific_user(user_id: str):
    """End all calls for a specific user."""
    print(f"🔍 Cleaning up calls for user: {user_id}")
    
    async with AsyncSessionLocal() as db:
        # Find all participants for this user
        result = await db.execute(
            select(CallParticipant).where(
                CallParticipant.user_id == user_id,
                CallParticipant.is_connected == True
            )
        )
        participants = result.scalars().all()
        
        if not participants:
            print(f"✅ No active calls found for user {user_id}")
            return
        
        print(f"📞 Found {len(participants)} active participation(s)")
        
        # Get unique call IDs
        call_ids = list(set(p.call_id for p in participants))
        
        # Update calls to ENDED
        await db.execute(
            update(Call)
            .where(Call.id.in_(call_ids))
            .values(
                status='ended',
                is_active=False,
                ended_at=datetime.utcnow()
            )
        )
        
        # Update participants to disconnected
        await db.execute(
            update(CallParticipant)
            .where(
                CallParticipant.user_id == user_id,
                CallParticipant.is_connected == True
            )
            .values(
                is_connected=False,
                left_at=datetime.utcnow()
            )
        )
        
        await db.commit()
        
        print(f"✅ Cleaned up {len(call_ids)} call(s) for user")
        print("🎉 User can now make calls!")


async def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        user_id = sys.argv[1]
        await cleanup_specific_user(user_id)
    else:
        await cleanup_active_calls()


if __name__ == "__main__":
    print("🧹 Call Cleanup Script")
    print("=" * 50)
    asyncio.run(main())
