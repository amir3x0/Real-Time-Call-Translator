"""
Status Tracking Service - Real-Time Online/Offline Detection

This service provides real-time user status tracking using WebSocket heartbeat
and Redis for fast lookups.
"""
import asyncio
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.redis import get_redis
from app.models.user import User
from app.models.database import AsyncSessionLocal


class StatusService:
    """Service to track and manage user online/offline status."""
    
    HEARTBEAT_INTERVAL = 30  # seconds - clients send heartbeat every 30s
    HEARTBEAT_TTL = 60  # seconds - Redis key TTL
    CLEANUP_INTERVAL = 120  # seconds - how often to cleanup offline users
    
    @staticmethod
    async def set_user_online(user_id: str, db: AsyncSession = None):
        """Mark user as online and update last_seen."""
        redis = await get_redis()
        
        # Set Redis key with TTL
        redis_key = f"online_users:{user_id}"
        await redis.set(redis_key, "1", ex=StatusService.HEARTBEAT_TTL)
        
        # Update database
        if db:
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = True
                user.last_seen = datetime.utcnow()
                await db.commit()
    
    @staticmethod
    async def set_user_offline(user_id: str, db: AsyncSession = None):
        """Mark user as offline."""
        redis = await get_redis()
        
        # Remove Redis key
        redis_key = f"online_users:{user_id}"
        await redis.delete(redis_key)
        
        # Update database
        if db:
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = False
                user.last_seen = datetime.utcnow()
                await db.commit()
    
    @staticmethod
    async def heartbeat(user_id: str):
        """Process heartbeat from client - refresh Redis TTL and update last_seen."""
        redis = await get_redis()
        redis_key = f"online_users:{user_id}"
        
        # Refresh TTL
        await redis.expire(redis_key, StatusService.HEARTBEAT_TTL)
        
        # Update last_seen in database (async, non-blocking)
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.last_seen = datetime.utcnow()
                await db.commit()
    
    @staticmethod
    async def is_user_online(user_id: str) -> bool:
        """Check if user is online by checking Redis."""
        redis = await get_redis()
        redis_key = f"online_users:{user_id}"
        exists = await redis.exists(redis_key)
        return bool(exists)
    
    @staticmethod
    async def get_online_users() -> list[str]:
        """Get list of all currently online user IDs."""
        redis = await get_redis()
        pattern = "online_users:*"
        keys = await redis.keys(pattern)
        # Extract user IDs from keys
        user_ids = [key.decode('utf-8').replace('online_users:', '') for key in keys]
        return user_ids
    
    @staticmethod
    async def cleanup_offline_users():
        """
        Background task to sync Redis state with database.
        Marks users as offline in DB if their Redis key expired.
        """
        while True:
            try:
                redis = await get_redis()
                async with AsyncSessionLocal() as db:
                    # Get all users marked as online in DB
                    result = await db.execute(select(User).where(User.is_online == True))
                    online_users = result.scalars().all()
                    
                    for user in online_users:
                        redis_key = f"online_users:{user.id}"
                        exists = await redis.exists(redis_key)
                        
                        # If Redis key doesn't exist, mark as offline in DB
                        if not exists:
                            user.is_online = False
                            print(f"[StatusService] User {user.id} ({user.phone}) marked offline")
                    
                    await db.commit()
            
            except Exception as e:
                print(f"[StatusService] Cleanup error: {e}")
            
            # Wait before next cleanup
            await asyncio.sleep(StatusService.CLEANUP_INTERVAL)


# Singleton instance
status_service = StatusService()
