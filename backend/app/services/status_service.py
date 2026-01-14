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
from datetime import datetime, UTC
from typing import List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.redis import get_redis
from app.models.user import User
from app.models.contact import Contact
from app.models.database import AsyncSessionLocal

logger = logging.getLogger(__name__)


class StatusService:
    """Service to track and manage user online/offline status."""
    
    HEARTBEAT_INTERVAL = 30  # seconds - clients send heartbeat every 30s
    HEARTBEAT_TTL = 60  # seconds - Redis key TTL (expires if no heartbeat)
    CLEANUP_INTERVAL = 120  # seconds - how often to sync Redis → DB
    OFFLINE_GRACE_PERIOD = 5.0  # Issue D Fix: seconds to wait before marking offline
    
    # Issue D Fix: Track pending offline tasks to prevent status flicker
    _pending_offline_tasks: dict = {}  # user_id -> asyncio.Task
    
    @staticmethod
    async def get_user_contacts(user_id: str, db: AsyncSession) -> List[str]:
        """Get list of contact user IDs for a user."""
        result1 = await db.execute(
            select(Contact.contact_user_id).where(Contact.user_id == user_id)
        )
        outgoing =  [row[0] for row in result1.all()]
        result2 = await db.execute(
            select(Contact.user_id).where(Contact.contact_user_id == user_id)
        )
        incoming =  [row[0] for row in result2.all()]
        return list(set(outgoing + incoming))


    
    @staticmethod
    async def set_user_online(user_id: str, db: AsyncSession = None, connection_manager=None):
        """
        Mark user as online.
        
        Called when:
        - User connects via WebSocket
        - User logs in
        """
        # Issue D Fix: Cancel any pending offline task (user reconnected!)
        if user_id in StatusService._pending_offline_tasks:
            StatusService._pending_offline_tasks[user_id].cancel()
            del StatusService._pending_offline_tasks[user_id]
            logger.info(f"User {user_id} reconnected - cancelled pending offline")
        
        redis = await get_redis()
        
        # Set Redis key with TTL
        redis_key = f"online:{user_id}"
        await redis.set(redis_key, "1", ex=StatusService.HEARTBEAT_TTL)
        logger.info(f"User {user_id} marked online (Redis)")
        
        # Update database and notify contacts
        contact_user_ids = []
        if db:
            from app.services.user_service import user_service
            user = await user_service.get_by_id(db, user_id)
            if user:
                user.is_online = True
                user.last_seen = datetime.utcnow()
                await db.commit()
                logger.info(f"User {user_id} ({user.full_name}) marked online (DB)")
                
                # Get contacts to notify
                contact_user_ids = await StatusService.get_user_contacts(user_id, db)
        
        # Broadcast status change to contacts via WebSocket
        if connection_manager and contact_user_ids:
            notified = await connection_manager.broadcast_user_status(
                user_id=user_id,
                is_online=True,
                contact_user_ids=contact_user_ids
            )
            logger.info(f"Notified {notified} contacts about user {user_id} going online")
    
    @staticmethod
    async def set_user_offline(user_id: str, db: AsyncSession = None, connection_manager=None):
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
        
        # Update database and notify contacts
        contact_user_ids = []
        if db:
            from app.services.user_service import user_service
            user = await user_service.get_by_id(db, user_id)
            if user:
                user.is_online = False
                user.last_seen = datetime.utcnow()
                await db.commit()
                logger.info(f"User {user_id} ({user.full_name}) marked offline (DB)")
                
                # Get contacts to notify
                contact_user_ids = await StatusService.get_user_contacts(user_id, db)
        
        # Broadcast status change to contacts via WebSocket
        if connection_manager and contact_user_ids:
            notified = await connection_manager.broadcast_user_status(
                user_id=user_id,
                is_online=False,
                contact_user_ids=contact_user_ids
            )
            logger.info(f"Notified {notified} contacts about user {user_id} going offline")
    
    @staticmethod
    async def set_user_offline_with_grace(user_id: str, db: AsyncSession = None, connection_manager=None):
        """
        Issue D Fix: Mark user as offline AFTER grace period.
        
        This prevents status flicker when user switches sockets
        (e.g., disconnecting from lobby to join call).
        
        If user reconnects within OFFLINE_GRACE_PERIOD seconds,
        set_user_online() cancels the pending offline task.
        """
        # Cancel any existing pending task for this user
        if user_id in StatusService._pending_offline_tasks:
            StatusService._pending_offline_tasks[user_id].cancel()
        
        async def delayed_offline():
            try:
                await asyncio.sleep(StatusService.OFFLINE_GRACE_PERIOD)
                # User didn't reconnect within grace period - actually mark offline
                async with AsyncSessionLocal() as db_session:
                    await StatusService.set_user_offline(user_id, db_session, connection_manager)
            except asyncio.CancelledError:
                logger.debug(f"User {user_id} offline cancelled (reconnected in time)")
            finally:
                if user_id in StatusService._pending_offline_tasks:
                    del StatusService._pending_offline_tasks[user_id]
        
        # Schedule the delayed offline task
        task = asyncio.create_task(delayed_offline())
        StatusService._pending_offline_tasks[user_id] = task
        logger.info(f"User {user_id} scheduled for offline in {StatusService.OFFLINE_GRACE_PERIOD}s")
    
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
            from app.services.user_service import user_service
            user = await user_service.get_by_id(db, user_id)
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
                    # Keeping this raw query as it's a specific bulk fetch for cleanup service
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
