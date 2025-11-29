"""
Calls API - Endpoints for call management

Implements:
- Call initiation with validation
- Call termination
- Call history retrieval
- Participant management
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
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

router = APIRouter()


# Request/Response Models
class StartCallRequest(BaseModel):
    participant_user_ids: List[str]
    skip_contact_validation: bool = False  # For testing


class ParticipantInfo(BaseModel):
    id: str
    user_id: str
    full_name: str
    phone: Optional[str]
    primary_language: str
    target_language: str
    speaking_language: str
    dubbing_required: bool
    use_voice_clone: bool
    voice_clone_quality: Optional[str]


class StartCallResponse(BaseModel):
    call_id: str
    session_id: str
    call_language: str
    websocket_url: str
    participants: List[ParticipantInfo]


class EndCallRequest(BaseModel):
    call_id: str


class EndCallResponse(BaseModel):
    call_id: str
    status: str
    duration_seconds: Optional[int]
    message: str


class CallHistoryItem(BaseModel):
    call_id: str
    session_id: str
    initiated_at: Optional[str]
    ended_at: Optional[str]
    duration_seconds: Optional[int]
    language: str
    status: Optional[str]
    participant_count: int


class CallHistoryResponse(BaseModel):
    calls: List[CallHistoryItem]


class CallDetailResponse(BaseModel):
    call_id: str
    session_id: str
    call_language: str
    status: str
    is_active: bool
    started_at: Optional[str]
    ended_at: Optional[str]
    duration_seconds: Optional[int]
    participants: List[ParticipantInfo]


class JoinCallRequest(BaseModel):
    call_id: str


class LeaveCallRequest(BaseModel):
    call_id: str


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
                target_language=p.target_language,
                speaking_language=p.speaking_language,
                dubbing_required=p.dubbing_required,
                use_voice_clone=p.use_voice_clone,
                voice_clone_quality=p.voice_clone_quality,
            ))
    
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
                target_language=p.target_language,
                speaking_language=p.speaking_language,
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
