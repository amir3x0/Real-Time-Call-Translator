"""
Calls API - Endpoints for call management

Implements:
- Call initiation with validation
- Call termination
- Call history retrieval
- Participant management
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.database import get_db
from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.api.auth import get_current_user
from app.config.settings import settings
from app.services.call_service import (
    call_service,
    CallServiceError,
    ContactNotAuthorizedError,
    UserOfflineError,
    AlreadyInCallError,
    CallNotFoundError,
    InvalidParticipantCountError,
)
from app.services.connection_manager import connection_manager
from app.schemas.call import (
    StartCallRequest,
    StartCallResponse,
    EndCallRequest,
    EndCallResponse,
    JoinCallRequest,
    LeaveCallRequest,
    CallDetailResponse,
    CallHistoryResponse,
    CallHistoryItem,
    ParticipantInfo,
)

router = APIRouter()


@router.post("/calls/start", response_model=StartCallResponse)
async def start_call(
    req: StartCallRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Start a new call.
    
    Validates:
    - Participant count (2-4)
    - Contact relationships (unless skipped)
    - No active calls for any participant
    
    Creates:
    - Call record with caller's language
    - CallParticipant records with dubbing requirements
    """
    try:
        call, participants = await call_service.initiate_call(
            db=db,
            caller_id=current_user.id,
            target_ids=req.participant_user_ids,
            skip_contact_validation=req.skip_contact_validation,
        )
    except ContactNotAuthorizedError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except UserOfflineError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except AlreadyInCallError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except InvalidParticipantCountError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    # Build participant info
    participants_info = []
    for p in participants:
        # Get user info
        result = await db.execute(select(User).where(User.id == p.user_id))
        user = result.scalar_one_or_none()
        
        if user:
            participants_info.append(ParticipantInfo(
                id=p.id,
                user_id=user.id,
                full_name=user.full_name,
                phone=user.phone or user.phone_number,
                primary_language=user.primary_language,
                target_language=p.participant_language,  # Use participant_language for target
                speaking_language=p.participant_language,  # Use participant_language for speaking
                dubbing_required=p.dubbing_required,
                use_voice_clone=p.use_voice_clone,
                voice_clone_quality=p.voice_clone_quality,
            ))
    
    # Mark call as ringing and send notifications to non-caller participants
    await call_service.mark_call_ringing(db, call.id)
    
    # Get caller info for notifications
    caller_result = await db.execute(select(User).where(User.id == current_user.id))
    caller = caller_result.scalar_one_or_none()
    
    # Send WebSocket notifications to all participants except caller
    for participant in participants:
        if participant.user_id != current_user.id:
            await connection_manager.notify_incoming_call(
                user_id=participant.user_id,
                call_id=call.id,
                caller_id=current_user.id,
                caller_name=caller.full_name if caller else "Unknown",
                caller_language=call.call_language
            )
    
    # Build WebSocket URL
    websocket_url = f"ws://{settings.API_HOST}:{settings.API_PORT}/ws/{call.session_id}"
    
    return StartCallResponse(
        call_id=call.id,
        session_id=call.session_id,
        call_language=call.call_language,
        websocket_url=websocket_url,
        participants=participants_info,
    )


@router.post("/calls/end", response_model=EndCallResponse)
async def end_call(
    req: EndCallRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    End a call.
    
    Can be called by any participant in the call.
    """
    try:
        call = await call_service.end_call(db, req.call_id)
    except CallNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return EndCallResponse(
        call_id=call.id,
        status=call.status.value if call.status else "ended",
        duration_seconds=call.duration_seconds,
        message="Call ended successfully",
    )


@router.post("/calls/{call_id}/join")
async def join_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Join an existing call.
    
    Called when a participant accepts the call invitation.
    """
    try:
        participant = await call_service.handle_participant_joined(
            db, call_id, current_user.id
        )
    except CallNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {
        "message": "Joined call successfully",
        "participant_id": participant.id,
        "call_id": call_id,
    }


@router.post("/calls/{call_id}/leave")
async def leave_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Leave an active call.
    
    If fewer than 2 participants remain, the call ends.
    """
    try:
        call_ended, call = await call_service.handle_participant_left(
            db, call_id, current_user.id
        )
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    return {
        "message": "Left call successfully",
        "call_ended": call_ended,
        "call_id": call_id,
    }


@router.get("/calls/{call_id}", response_model=CallDetailResponse)
async def get_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get call details with participants.
    """
    call, participants = await call_service.get_call_with_participants(db, call_id)
    
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    
    # Build participant info
    participants_info = []
    for p in participants:
        result = await db.execute(select(User).where(User.id == p.user_id))
        user = result.scalar_one_or_none()
        
        if user:
            participants_info.append(ParticipantInfo(
                id=p.id,
                user_id=user.id,
                full_name=user.full_name,
                phone=user.phone or user.phone_number,
                primary_language=user.primary_language,
                target_language=p.participant_language,  # Use participant_language for target
                speaking_language=p.participant_language,  # Use participant_language for speaking
                dubbing_required=p.dubbing_required,
                use_voice_clone=p.use_voice_clone,
                voice_clone_quality=p.voice_clone_quality,
            ))
    
    return CallDetailResponse(
        call_id=call.id,
        session_id=call.session_id,
        call_language=call.call_language,
        status=call.status.value if call.status else "unknown",
        is_active=call.is_active,
        started_at=call.started_at.isoformat() if call.started_at else None,
        ended_at=call.ended_at.isoformat() if call.ended_at else None,
        duration_seconds=call.duration_seconds,
        participants=participants_info,
    )


@router.get("/calls/history", response_model=CallHistoryResponse)
async def get_call_history(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get user's call history.
    """
    history = await call_service.get_user_call_history(db, current_user.id, limit)
    
    items = []
    for h in history:
        items.append(CallHistoryItem(
            call_id=h["call_id"],
            session_id=h["session_id"],
            initiated_at=h.get("initiated_at"),
            ended_at=h.get("ended_at"),
            duration_seconds=h.get("duration_seconds"),
            language=h.get("language", "he"),
            status=h.get("status"),
            participant_count=len(h.get("participants", [])),
        ))
    
    return CallHistoryResponse(calls=items)


@router.post("/calls/{call_id}/mute")
async def toggle_mute(
    call_id: str,
    muted: bool = True,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Toggle mute status for current user in a call.
    """
    result = await db.execute(
        select(CallParticipant).where(
            CallParticipant.call_id == call_id,
            CallParticipant.user_id == current_user.id
        )
    )
    participant = result.scalar_one_or_none()
    
    if not participant:
        raise HTTPException(status_code=404, detail="Not a participant in this call")
    
    participant.is_muted = muted
    await db.commit()
    
    return {
        "message": "Mute toggled",
        "is_muted": muted,
    }


# Legacy endpoint for backwards compatibility
@router.get("/calls/pending", response_model=List[CallDetailResponse])
async def get_pending_calls(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get all pending incoming calls for current user.
    Returns calls where:
    - status is 'ringing' or 'initiating'
    - user is a participant but not the caller
    - call was created in last 30 seconds
    """
    try:
        pending_calls = await call_service.get_pending_calls(db, current_user.id)
        
        # Build response for each call
        result = []
        for call in pending_calls:
            # Get participants
            participants_result = await db.execute(
                select(CallParticipant).where(CallParticipant.call_id == call.id)
            )
            participants = participants_result.scalars().all()
            
            # Build participant info
            participants_info = []
            for p in participants:
                user_result = await db.execute(select(User).where(User.id == p.user_id))
                user = user_result.scalar_one_or_none()
                
                if user:
                    participants_info.append(ParticipantInfo(
                        id=p.id,
                        user_id=user.id,
                        full_name=user.full_name,
                        phone=user.phone or user.phone_number,
                        primary_language=user.primary_language,
                        target_language=p.participant_language,
                        speaking_language=p.participant_language,
                        dubbing_required=p.dubbing_required,
                        use_voice_clone=p.use_voice_clone,
                        voice_clone_quality=p.voice_clone_quality,
                    ))
            
            result.append(CallDetailResponse(
                call_id=call.id,
                session_id=call.session_id,
                call_language=call.call_language,
                status=call.status,
                is_active=call.is_active,
                started_at=call.started_at.isoformat() if call.started_at else None,
                ended_at=call.ended_at.isoformat() if call.ended_at else None,
                duration_seconds=call.duration_seconds,
                participants=participants_info,
            ))
        
        return result
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calls/{call_id}/accept")
async def accept_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Accept an incoming call."""
    try:
        call = await call_service.accept_call(db, call_id, current_user.id)
        
        # Get participants for response
        participants_result = await db.execute(
            select(CallParticipant).where(CallParticipant.call_id == call.id)
        )
        participants = participants_result.scalars().all()
        
        participants_info = []
        for p in participants:
            user_result = await db.execute(select(User).where(User.id == p.user_id))
            user = user_result.scalar_one_or_none()
            
            if user:
                participants_info.append(ParticipantInfo(
                    id=p.id,
                    user_id=user.id,
                    full_name=user.full_name,
                    phone=user.phone or user.phone_number,
                    primary_language=user.primary_language,
                    target_language=p.participant_language,
                    speaking_language=p.participant_language,
                    dubbing_required=p.dubbing_required,
                    use_voice_clone=p.use_voice_clone,
                    voice_clone_quality=p.voice_clone_quality,
                ))
        
        return CallDetailResponse(
            call_id=call.id,
            session_id=call.session_id,
            call_language=call.call_language,
            status=call.status,
            is_active=call.is_active,
            started_at=call.started_at.isoformat() if call.started_at else None,
            ended_at=call.ended_at.isoformat() if call.ended_at else None,
            duration_seconds=call.duration_seconds,
            participants=participants_info,
        )
    except CallNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calls/{call_id}/reject")
async def reject_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reject an incoming call."""
    try:
        call = await call_service.reject_call(db, call_id, current_user.id)
        
        return {
            "status": "rejected",
            "call_id": call.id,
            "message": "Call rejected successfully"
        }
    except CallNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except CallServiceError as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calls/start_legacy", response_model=StartCallResponse)
async def start_call_legacy(
    req: StartCallRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Legacy call start endpoint - same as /calls/start but always skips contact validation.
    """
    req.skip_contact_validation = True
    return await start_call(req, db, current_user)


@router.post("/calls/debug/reset_state")
async def reset_user_call_state(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Debug endpoint: Force leave all active calls for current user.
    Use this if you get 'Already in an active call' errors.
    """
    try:
        call_ids = await call_service.force_leave_all_calls(db, current_user.id)
        return {
            "message": f"Reset successful. Left {len(call_ids)} calls.",
            "calls_left": call_ids
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
