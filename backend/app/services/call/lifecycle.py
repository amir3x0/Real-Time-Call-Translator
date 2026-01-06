"""
Call Lifecycle Management - SRP-compliant call state transitions.

Single Responsibility: Managing call lifecycle state changes
(participant leaving, call ending, etc.)
"""
import logging
from datetime import datetime
from typing import Tuple, Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.call import Call
from app.models.call_participant import CallParticipant

logger = logging.getLogger(__name__)


class CallLifecycleManager:
    """
    Manages call lifecycle state transitions.
    
    Single Responsibility: Handle state changes when participants
    join/leave calls and determine when calls should end.
    """
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def mark_participant_disconnected(
        self,
        call_id: str,
        user_id: str
    ) -> bool:
        """
        Mark a participant as disconnected from the call.
        
        Returns:
            True if participant was found and updated, False otherwise.
        """
        result = await self.db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            logger.warning(f"[Lifecycle] Participant not found: user={user_id}, call={call_id}")
            return False
        
        participant.is_connected = False
        participant.left_at = datetime.utcnow()
        await self.db.commit()
        
        logger.info(f"[Lifecycle] Participant {user_id} marked as disconnected from call {call_id}")
        return True
    
    async def count_active_participants(self, call_id: str) -> int:
        """
        Count participants who haven't left the call yet.
        
        Returns:
            Number of active participants (left_at is NULL).
        """
        result = await self.db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.left_at.is_(None)
                )
            )
        )
        active_participants = result.scalars().all()
        count = len(active_participants)
        
        logger.info(f"[Lifecycle] Call {call_id} has {count} active participants")
        return count
    
    async def should_end_call(
        self,
        call_id: str,
        min_participants: int = 2
    ) -> bool:
        """
        Check if call should end due to insufficient participants.
        
        Args:
            call_id: The call to check
            min_participants: Minimum required participants (default: 2)
            
        Returns:
            True if call should end, False otherwise.
        """
        active_count = await self.count_active_participants(call_id)
        return active_count < min_participants
    
    async def end_call(self, call_id: str) -> bool:
        """
        Mark call as ended in the database.
        
        Returns:
            True if call was ended, False if already ended or not found.
        """
        result = await self.db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            logger.warning(f"[Lifecycle] Call not found: {call_id}")
            return False
        
        if not call.is_active:
            logger.info(f"[Lifecycle] Call {call_id} already ended")
            return False
        
        call.end_call()
        await self.db.commit()
        
        logger.info(f"[Lifecycle] Call {call_id} marked as ended")
        return True
    
    async def handle_participant_disconnect(
        self,
        call_id: str,
        user_id: str,
        min_participants: int = 2
    ) -> Tuple[bool, bool]:
        """
        Handle a participant disconnecting from a call.
        
        This is a convenience method that combines:
        1. Mark participant as disconnected
        2. Check if call should end
        3. End call if needed
        
        Args:
            call_id: The call ID
            user_id: The disconnecting user's ID
            min_participants: Minimum required participants
            
        Returns:
            Tuple of (participant_updated: bool, call_ended: bool)
        """
        # Step 1: Mark participant as disconnected
        participant_updated = await self.mark_participant_disconnected(call_id, user_id)
        
        if not participant_updated:
            return False, False
        
        # Step 2: Check if call should end
        if await self.should_end_call(call_id, min_participants):
            # Step 3: End the call
            call_ended = await self.end_call(call_id)
            return True, call_ended
        
        return True, False
