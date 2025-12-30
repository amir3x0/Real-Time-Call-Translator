from typing import List, Optional
from pydantic import BaseModel


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
