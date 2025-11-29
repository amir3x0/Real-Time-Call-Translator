"""
Status Tracking Service - Real-Time Online/Offline Detection

This service provides real-time user status tracking using:
- Redis for fast presence lookups (with TTL-based expiration)
- Database for persistent status storage
- WebSocket heartbeats to maintain online status

How it works:
1. When user connects via WebSocket → set_user_online() is called
2. Client sends heartbeat every 30s → heartbeat() refreshes Redis TTL
3. If heartbeat stops (disconnect/crash) → Redis key expires after 60s
4. Background cleanup task syncs Redis state with database
"""
import asyncio
import logging
from datetime import datetime
from typing import List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.redis import get_redis
from app.models.user import User
from app.models.database import AsyncSessionLocal

logger = logging.getLogger(__name__)


class StatusService:
    """Service to track and manage user online/offline status."""
    
    HEARTBEAT_INTERVAL = 30  # seconds - clients send heartbeat every 30s
    HEARTBEAT_TTL = 60  # seconds - Redis key TTL (expires if no heartbeat)
    CLEANUP_INTERVAL = 120  # seconds - how often to sync Redis → DB
    
    @staticmethod
    async def set_user_online(user_id: str, db: AsyncSession = None):
        """
        Mark user as online.
        
        Called when:
        - User connects via WebSocket
        - User logs in
        """
        redis = await get_redis()
        
        # Set Redis key with TTL
        redis_key = f"online:{user_id}"
        await redis.set(redis_key, "1", ex=StatusService.HEARTBEAT_TTL)
        logger.info(f"User {user_id} marked online (Redis)")
        
        # Update database
        if db:
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = True
                user.last_seen = datetime.utcnow()
                await db.commit()
                logger.info(f"User {user_id} ({user.full_name}) marked online (DB)")
    
    @staticmethod
    async def set_user_offline(user_id: str, db: AsyncSession = None):
        """
        Mark user as offline.
        
        Called when:
        - User disconnects from WebSocket
        - User logs out
        - Heartbeat times out
        """
        redis = await get_redis()
        
        # Remove Redis key
        redis_key = f"online:{user_id}"
        await redis.delete(redis_key)
        logger.info(f"User {user_id} marked offline (Redis)")
        
        # Update database
        if db:
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if user:
                user.is_online = False
                user.last_seen = datetime.utcnow()
                await db.commit()
                logger.info(f"User {user_id} ({user.full_name}) marked offline (DB)")
    
    @staticmethod
    async def heartbeat(user_id: str):
        """
        Process heartbeat from client.
        
        Called every HEARTBEAT_INTERVAL seconds from WebSocket.
        Refreshes the Redis TTL to keep user online.
        """
        redis = await get_redis()
        redis_key = f"online:{user_id}"
        
        # Refresh TTL
        await redis.expire(redis_key, StatusService.HEARTBEAT_TTL)
        
        # Update last_seen in database
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
        redis_key = f"online:{user_id}"
        exists = await redis.exists(redis_key)
        return bool(exists)
    
    @staticmethod
    async def get_online_users() -> List[str]:
        """Get list of all currently online user IDs."""
        redis = await get_redis()
        pattern = "online:*"
        keys = await redis.keys(pattern)
        # Extract user IDs from keys
        user_ids = [key.decode('utf-8').replace('online:', '') for key in keys]
        return user_ids
    
    @staticmethod
    async def cleanup_offline_users():
        """
        Background task to sync Redis state with database.
        
        Runs continuously and:
        1. Finds users marked online in DB
        2. Checks if their Redis key exists
        3. If not, marks them offline in DB
        
        This catches cases where WebSocket disconnect wasn't handled.
        """
        logger.info("Starting status cleanup background task")
        
        while True:
            try:
                redis = await get_redis()
                async with AsyncSessionLocal() as db:
                    # Get all users marked as online in DB
                    result = await db.execute(select(User).where(User.is_online == True))
                    online_users = result.scalars().all()
                    
                    for user in online_users:
                        redis_key = f"online:{user.id}"
                        exists = await redis.exists(redis_key)
                        
                        # If Redis key doesn't exist, mark as offline in DB
                        if not exists:
                            user.is_online = False
                            user.last_seen = datetime.utcnow()
                            logger.info(f"Cleanup: User {user.id} ({user.full_name}) marked offline")
                    
                    await db.commit()
            
            except Exception as e:
                logger.error(f"Status cleanup error: {e}")
            
            # Wait before next cleanup
            await asyncio.sleep(StatusService.CLEANUP_INTERVAL)


# Singleton instance
status_service = StatusService()
