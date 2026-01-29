"""REST API Router Configuration.

Aggregates all API endpoint routers and provides common endpoints.
All routes are prefixed with /api when mounted in main.py.

Routers included:
- auth: User registration, login, authentication
- contacts: Contact management (add, search, accept/reject)
- calls: Call initiation, history, participant management
- voice: Voice sample upload and training status
"""

from fastapi import APIRouter, UploadFile, File
from app.services.rtc_service import publish_audio_chunk
from app.api import auth
from app.api import contacts
from app.api import calls
from app.api import voice

router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.post("/sessions/{session_id}/chunk")
async def post_audio_chunk(session_id: str, file: UploadFile = File(...)):
    # Accept a small audio chunk via multipart/form-data for testing
    data = await file.read()
    await publish_audio_chunk(session_id, data)
    return {"status": "ok", "len": len(data)}


# Include auth, contacts, calls, voice routers
router.include_router(auth.router)
router.include_router(contacts.router)
router.include_router(calls.router)
router.include_router(voice.router)
