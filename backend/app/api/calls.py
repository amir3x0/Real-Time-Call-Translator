from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import uuid4

from app.models.database import get_db
from app.models.user import User
from app.models.call import Call, CallStatus
from app.models.call_participant import CallParticipant
from app.api.auth import get_current_user
from app.config.settings import settings

router = APIRouter()


class StartCallRequest(BaseModel):
    participant_user_ids: List[str]


class ParticipantInfo(BaseModel):
    id: str
    user_id: str
    full_name: str
    phone: str
    target_language: str
    speaking_language: str


class StartCallResponse(BaseModel):
    session_id: str
    websocket_url: str
    participants: List[ParticipantInfo]


@router.post("/calls/start", response_model=StartCallResponse)
async def start_call(req: StartCallRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Validate participant IDs
    # Dedupe and ensure we include the caller
    participant_ids = list(dict.fromkeys(req.participant_user_ids))
    if current_user.id in participant_ids:
        # Already included, ensure not duplicated
        participant_ids = [pid for pid in participant_ids if pid != current_user.id]
    # Total participants including caller
    total = 1 + len(participant_ids)
    if total < 2 or total > 4:
        raise HTTPException(status_code=400, detail="Call must include 2-4 participants including caller")

    # Validate all participant users exist
    users = []
    for pid in participant_ids:
        q = await db.execute(select(User).where(User.id == pid))
        u = q.scalar_one_or_none()
        if not u:
            raise HTTPException(status_code=404, detail=f"Participant user {pid} not found")
        users.append(u)

    # Create Call
    session_id = str(uuid4())
    new_call = Call(session_id=session_id, status=CallStatus.INITIATING, created_by=current_user.id, current_participants=total, max_participants=4)
    db.add(new_call)
    await db.commit()
    await db.refresh(new_call)

    # Create CallParticipant entries for caller and others
    participants_info = []

    # Helper to get participant info
    async def create_participant_for_user(user_obj):
        cp = CallParticipant(
            call_id=new_call.id,
            user_id=user_obj.id,
            target_language=user_obj.primary_language,
            speaking_language=user_obj.primary_language,
            is_muted=False,
        )
        db.add(cp)
        await db.commit()
        await db.refresh(cp)
        return cp, user_obj

    # Caller
    caller_cp, caller_user = await create_participant_for_user(current_user)
    participants_info.append(ParticipantInfo(
        id=caller_cp.id,
        user_id=caller_user.id,
        full_name=caller_user.full_name,
        phone=caller_user.phone,
        target_language=caller_user.primary_language,
        speaking_language=caller_user.primary_language,
    ))

    # Others
    for u in users:
        cp, user_obj = await create_participant_for_user(u)
        participants_info.append(ParticipantInfo(
            id=cp.id,
            user_id=user_obj.id,
            full_name=user_obj.full_name,
            phone=user_obj.phone,
            target_language=user_obj.primary_language,
            speaking_language=user_obj.primary_language,
        ))

    websocket_url = f"ws://{settings.API_HOST}:{settings.API_PORT}/ws/{session_id}"
    return StartCallResponse(session_id=session_id, websocket_url=websocket_url, participants=participants_info)
