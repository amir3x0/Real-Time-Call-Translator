"""
Call History

Functions for retrieving call history and pending calls.
"""
from datetime import datetime, timedelta, UTC
from typing import List, Dict, Tuple, Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.call_transcript import CallTranscript


async def get_call_with_participants(
    db: AsyncSession,
    call_id: str
) -> Tuple[Optional[Call], List[CallParticipant]]:
    """
    Get call with all participants.
    
    Args:
        db: Database session
        call_id: ID of the call
        
    Returns:
        Tuple of (Call, List[CallParticipant])
    """
    result = await db.execute(select(Call).where(Call.id == call_id))
    call = result.scalar_one_or_none()
    
    if not call:
        return None, []
    
    result = await db.execute(
        select(CallParticipant).where(CallParticipant.call_id == call_id)
    )
    participants = result.scalars().all()
    
    return call, list(participants)


async def get_user_call_history(
    db: AsyncSession,
    user_id: str,
    limit: int = 20
) -> List[Dict]:
    """
    Get user's recent call history with transcripts.
    
    Args:
        db: Database session
        user_id: ID of the user
        limit: Maximum number of calls to return
        
    Returns:
        List of call history dictionaries
    """
    # Get calls where user was a participant
    result = await db.execute(
        select(Call).join(CallParticipant).where(
            CallParticipant.user_id == user_id
        ).order_by(Call.started_at.desc()).limit(limit)
    )
    calls = result.scalars().all()
    
    history = []
    
    for call in calls:
        # Get participants
        result = await db.execute(
            select(CallParticipant).where(CallParticipant.call_id == call.id)
        )
        participants = result.scalars().all()
        
        # Get transcripts
        result = await db.execute(
            select(CallTranscript).where(
                CallTranscript.call_id == call.id
            ).order_by(CallTranscript.timestamp_ms)
        )
        transcripts = result.scalars().all()
        
        # Get participant user info
        participant_info = []
        for p in participants:
            result = await db.execute(select(User).where(User.id == p.user_id))
            user = result.scalar_one_or_none()
            if user:
                participant_info.append({
                    "user_id": user.id,
                    "full_name": user.full_name,
                    "primary_language": user.primary_language,
                    "dubbing_required": p.dubbing_required,
                })
        
        call_data = {
            "call_id": call.id,
            "session_id": call.session_id,
            "initiated_at": call.started_at.isoformat() if call.started_at else None,
            "ended_at": call.ended_at.isoformat() if call.ended_at else None,
            "duration_seconds": call.duration_seconds,
            "language": call.call_language,
            "status": call.status.value if call.status else None,
            "participants": participant_info,
            "transcript": [t.to_timeline_dict() for t in transcripts],
        }
        
        history.append(call_data)
    
    return history


async def get_pending_calls(
    db: AsyncSession,
    user_id: str
) -> List[Call]:
    """
    Get all pending incoming calls for a user.
    
    Returns calls where:
    - status is 'ringing' or 'initiating'
    - user is a participant but not the caller
    - call was created in last 30 seconds
    
    Args:
        db: Database session
        user_id: ID of the user
        
    Returns:
        List of pending Call objects
    """
    cutoff_time = datetime.now(UTC) - timedelta(seconds=30)
    
    result = await db.execute(
        select(Call)
        .join(CallParticipant, Call.id == CallParticipant.call_id)
        .where(
            and_(
                CallParticipant.user_id == user_id,
                Call.caller_user_id != user_id,  # Not the caller
                Call.status.in_(['ringing', 'initiating']),
                Call.created_at >= cutoff_time
            )
        )
        .order_by(Call.created_at.desc())
    )
    
    return list(result.scalars().all())
