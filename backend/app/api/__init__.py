from fastapi import APIRouter, UploadFile, File
from app.services.rtc_service import publish_audio_chunk

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
