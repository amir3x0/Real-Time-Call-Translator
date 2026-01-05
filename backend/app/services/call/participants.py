"""
Call Participant Management

Handles participant-related operations:
- Creating participants with dubbing settings
- Joining/leaving calls
- Force-leaving active calls
"""
from datetime import datetime, UTC
from typing import List, Tuple, Optional
import logging

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from .exceptions import CallNotFoundError

logger = logging.getLogger(__name__)


async def create_participant(
    db: AsyncSession,
    call: Call,
    user: User,
    is_caller: bool
) -> CallParticipant:
    """
    Create a call participant with proper dubbing and voice clone settings.
    
    Args:
        db: Database session
        call: Call object
        user: User object
        is_caller: Whether this is the call initiator
        
    Returns:
        Created CallParticipant
    """
    participant = CallParticipant(
        call_id=call.id,
        user_id=user.id,
        participant_language=user.primary_language,
        joined_at=datetime.now(UTC) if is_caller else None,
        is_connected=is_caller,
    )
    
    # Set dubbing requirement based on language match
    try:
        participant.determine_dubbing_required(call.call_language)
        participant.set_voice_clone_quality(user.voice_quality_score)
    except AttributeError as e:
        logger.error(f"Error setting participant properties: {e}")
        # Set defaults
        participant.dubbing_required = (participant.participant_language != call.call_language)
        participant.voice_clone_quality = 'fallback'
        participant.use_voice_clone = False
    
    db.add(participant)
    await db.flush()
    
    return participant


async def handle_participant_joined(
    db: AsyncSession,
    call_id: str,
    user_id: str
) -> CallParticipant:
    """
    Handle a participant joining an existing call.
    
    Args:
        db: Database session
        call_id: ID of the call
        user_id: ID of the user joining
        
    Returns:
        Updated CallParticipant
    """
    result = await db.execute(
        select(CallParticipant).where(
            and_(
                CallParticipant.call_id == call_id,
                CallParticipant.user_id == user_id
            )
        )
    )
    participant = result.scalar_one_or_none()
    
    if not participant:
        raise CallNotFoundError(f"Participant {user_id} not found in call {call_id}")
    
    # Update participant status
    participant.joined_at = datetime.utcnow()
    participant.is_connected = True
    participant.left_at = None
    
    # Update call participant count
    result = await db.execute(select(Call).where(Call.id == call_id))
    call = result.scalar_one_or_none()
    if call:
        call.participant_count += 1
        if call.status != 'ongoing':
            call.status = 'ongoing'
    
    await db.commit()
    await db.refresh(participant)
    
    return participant


async def handle_participant_left(
    db: AsyncSession,
    call_id: str,
    user_id: str,
    min_participants: int = 1
) -> Tuple[bool, Optional[Call]]:
    """
    Handle a participant leaving a call.
    
    Args:
        db: Database session
        call_id: ID of the call
        user_id: ID of the user leaving
        min_participants: Minimum participants before call ends
        
    Returns:
        Tuple of (call_ended: bool, call: Optional[Call])
    """
    # Mark participant as left
    result = await db.execute(
        select(CallParticipant).where(
            and_(
                CallParticipant.call_id == call_id,
                CallParticipant.user_id == user_id
            )
        )
    )
    participant = result.scalar_one_or_none()
    
    if not participant:
        return False, None
    
    participant.leave_call()
    
    # Count active participants
    result = await db.execute(
        select(CallParticipant).where(
            and_(
                CallParticipant.call_id == call_id,
                CallParticipant.left_at.is_(None)
            )
        )
    )
    active_participants = result.scalars().all()
    active_count = len(active_participants)
    
    # Get call
    result = await db.execute(select(Call).where(Call.id == call_id))
    call = result.scalar_one_or_none()
    
    if not call:
        return False, None
    
    call.participant_count = active_count
    
    # Check if call should end (fewer than min participants)
    if active_count < min_participants:
        call.end_call()
        await db.commit()
        return True, call
    
    await db.commit()
    return False, call


async def force_leave_all_calls(
    db: AsyncSession,
    user_id: str
) -> List[str]:
    """
    Force user to leave all active calls.
    
    Args:
        db: Database session
        user_id: ID of the user
        
    Returns:
        List of call IDs left
    """
    # Find all active participations
    result = await db.execute(
        select(CallParticipant).join(Call).where(
            and_(
                Call.is_active == True,
                CallParticipant.user_id == user_id,
                CallParticipant.left_at.is_(None)
            )
        )
    )
    active_participants = result.scalars().all()
    
    call_ids = []
    for participant in active_participants:
        call_id = participant.call_id
        call_ids.append(call_id)
        
        # Use handle_participant_left logic
        await handle_participant_left(db, call_id, user_id)
        
    return call_ids
