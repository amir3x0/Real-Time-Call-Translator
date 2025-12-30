"""
Voice Recording API - Endpoints for voice sample management

Implements:
- Voice sample upload
- Voice sample status
- Voice model training trigger
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import os
import uuid
from datetime import datetime

from app.models.database import get_db
from app.models.user import User
from app.models.voice_recording import VoiceRecording
from app.api.auth import get_current_user
from app.config.settings import settings
from app.services.voice_training_service import voice_training_service

router = APIRouter()

# Voice upload directory - use settings for consistent path
VOICE_UPLOAD_DIR = settings.VOICE_SAMPLES_DIR


# Request/Response Models
class VoiceRecordingResponse(BaseModel):
    id: str
    user_id: str
    language: str
    text_content: str
    file_path: str
    quality_score: Optional[int]
    is_processed: bool
    used_for_training: bool
    created_at: Optional[str]


class VoiceRecordingsListResponse(BaseModel):
    recordings: List[VoiceRecordingResponse]
    total: int


class VoiceStatusResponse(BaseModel):
    has_voice_sample: bool
    voice_model_trained: bool
    voice_quality_score: Optional[int]
    voice_clone_quality: str
    recordings_count: int
    processed_count: int
    training_ready: bool


class TrainVoiceModelRequest(BaseModel):
    recording_ids: Optional[List[str]] = None  # If None, use best 2 samples


class TrainVoiceModelResponse(BaseModel):
    message: str
    status: str
    recordings_used: int


@router.post("/voice/upload", response_model=VoiceRecordingResponse)
async def upload_voice_sample(
    file: UploadFile = File(...),
    language: str = Form(...),
    text_content: str = Form(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Upload a voice sample for voice cloning.
    
    Requirements:
    - Audio file (wav, mp3, ogg)
    - Duration: 15-30 seconds
    - Language must be valid (he, en, ru)
    """
    # Validate language
    if language not in ['he', 'en', 'ru']:
        raise HTTPException(status_code=400, detail="Invalid language. Must be 'he', 'en', or 'ru'")
    
    # Validate file type
    allowed_types = ['audio/wav', 'audio/mpeg', 'audio/ogg', 'audio/x-wav', 'audio/mp3']
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # Create upload directory if not exists
    os.makedirs(VOICE_UPLOAD_DIR, exist_ok=True)
    
    # Generate unique filename
    file_ext = file.filename.split('.')[-1] if '.' in file.filename else 'wav'
    unique_filename = f"{current_user.id}_{uuid.uuid4()}.{file_ext}"
    file_path = os.path.join(VOICE_UPLOAD_DIR, unique_filename)
    
    # Save file
    try:
        import aiofiles
        async with aiofiles.open(file_path, 'wb') as f:
            while content := await file.read(1024 * 1024):  # Read in 1MB chunks
                await f.write(content)
        
        file_size = os.path.getsize(file_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")
    
    # Create database record
    recording = await voice_training_service.save_recording(
        user_id=current_user.id,
        file_path=file_path,
        language=language,
        text_content=text_content,
        file_size=file_size,
        audio_format=file_ext,
        db=db
    )
    
    return VoiceRecordingResponse(
        id=recording.id,
        user_id=recording.user_id,
        language=recording.language,
        text_content=recording.text_content,
        file_path=recording.file_path,
        quality_score=recording.quality_score,
        is_processed=recording.is_processed,
        used_for_training=recording.used_for_training,
        created_at=recording.created_at.isoformat() if recording.created_at else None,
    )


@router.get("/voice/recordings", response_model=VoiceRecordingsListResponse)
async def list_voice_recordings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    List all voice recordings for current user.
    """
    recordings = await voice_training_service.get_user_recordings(current_user.id, db)
    
    items = [
        VoiceRecordingResponse(
            id=r.id,
            user_id=r.user_id,
            language=r.language,
            text_content=r.text_content,
            file_path=r.file_path,
            quality_score=r.quality_score,
            is_processed=r.is_processed,
            used_for_training=r.used_for_training,
            created_at=r.created_at.isoformat() if r.created_at else None,
        )
        for r in recordings
    ]
    
    return VoiceRecordingsListResponse(recordings=items, total=len(items))


@router.get("/voice/status", response_model=VoiceStatusResponse)
async def get_voice_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get voice cloning status for current user.
    """
    # Count recordings
    recordings = await voice_training_service.get_user_recordings(current_user.id, db)
    
    total_count = len(recordings)
    processed_count = len([r for r in recordings if r.is_processed])
    
    # Training is ready if we have at least 2 processed samples
    training_ready = processed_count >= 2 and not current_user.voice_model_trained
    
    return VoiceStatusResponse(
        has_voice_sample=current_user.has_voice_sample,
        voice_model_trained=current_user.voice_model_trained,
        voice_quality_score=current_user.voice_quality_score,
        voice_clone_quality=current_user.get_voice_clone_quality(),
        recordings_count=total_count,
        processed_count=processed_count,
        training_ready=training_ready,
    )


@router.post("/voice/train", response_model=TrainVoiceModelResponse)
async def train_voice_model(
    req: TrainVoiceModelRequest = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Trigger voice model training.
    
    This endpoint queues the user for voice model training using
    the voice training background worker.
    """
    # Check if user has enough processed recordings
    # Using service to get status which includes readiness check logic
    status = await voice_training_service.get_user_training_status(current_user.id, db)
    
    if status.get("ready_for_training", False) is False:
         raise HTTPException(
            status_code=400,
            detail="Need at least 2 processed voice samples with quality score >= 40 for training"
        )
    
    # Queue for training via background worker
    result = await voice_training_service.queue_training_for_user(current_user.id)
    
    if result.get("status") == "already_queued":
         return TrainVoiceModelResponse(
            message="Voice model training already in queue",
            status="pending",
            recordings_used=status.get("quality_recordings", 0),
        )

    return TrainVoiceModelResponse(
        message="Voice model training queued",
        status="pending",
        recordings_used=status.get("quality_recordings", 0),
    )


class TrainingStatusResponse(BaseModel):
    user_id: str
    has_voice_sample: bool
    voice_model_trained: bool
    voice_quality_score: Optional[int]
    voice_model_id: Optional[str]
    total_recordings: int
    processed_recordings: int
    quality_recordings: int
    ready_for_training: bool
    samples_needed: int


@router.get("/voice/training-status", response_model=TrainingStatusResponse)
async def get_training_status(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get detailed voice model training status for current user.
    """
    status = await voice_training_service.get_user_training_status(current_user.id, db)
    
    if "error" in status:
        raise HTTPException(status_code=404, detail=status["error"])
    
    return TrainingStatusResponse(**status)


@router.post("/voice/retrain")
async def retrain_voice_model(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Force retrain voice model for current user.
    
    This resets the training status and queues for retraining.
    """
    result = await voice_training_service.retrain_voice_model(current_user.id, db)
    
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    
    return result


@router.delete("/voice/recordings/{recording_id}")
async def delete_voice_recording(
    recording_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Delete a voice recording.
    """
    success = await voice_training_service.delete_recording(recording_id, current_user.id, db)
    
    if not success:
        raise HTTPException(status_code=404, detail="Recording not found")
    
    return {"message": "Recording deleted"}

