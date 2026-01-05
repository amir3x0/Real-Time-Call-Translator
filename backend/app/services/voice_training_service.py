"""
Voice Training Service - Manages voice sample processing and model training

This service handles:
- Voice sample quality assessment
- Queueing recordings for processing
- Voice model training with Chatterbox (voice cloning)
- Training status tracking
"""
import os
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime, UTC
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

# Import models - these will be resolved at runtime
from app.models.database import AsyncSessionLocal
from app.models.voice_recording import VoiceRecording
from app.models.user import User
from app.config.settings import settings


class VoiceTrainingService:
    """
    Service for managing voice sample processing and model training.
    
    This is a singleton service that handles all voice training operations.
    """
    
    # Minimum requirements for training
    MIN_SAMPLES_FOR_TRAINING = 2
    MIN_QUALITY_SCORE = 40
    
    # Processing queue (in production, use Redis)
    _processing_queue: List[str] = []
    _training_queue: List[str] = []
    
    async def process_recording(self, db: AsyncSession, recording_id: str) -> None:
        """
        Process a single voice recording (Business Logic).
        """
        result = await db.execute(
            select(VoiceRecording).where(VoiceRecording.id == recording_id)
        )
        recording = result.scalar_one_or_none()
        
        if not recording:
            return
        
        # Mock quality assessment (in production, analyze audio)
        # Generate a score between 60-95 for demo purposes
        import random
        quality_score = random.randint(60, 95)
        
        recording.quality_score = quality_score
        recording.is_processed = True
        recording.processed_at = datetime.utcnow()
        
        await db.commit()
        
        # Remove from local queue if present (thread-safety note: this simple list isn't thread-safe in high load)
        if recording_id in self._processing_queue:
            self._processing_queue.remove(recording_id)

    async def _process_recording_background(self, recording_id: str) -> None:
        """Background wrapper for processing."""
        await asyncio.sleep(0.5)  # Simulate processing time
        async with AsyncSessionLocal() as db:
            await self.process_recording(db, recording_id)

    async def queue_recording_for_processing(self, recording_id: str) -> Dict[str, Any]:
        """
        Queue a voice recording for quality assessment and processing.
        """
        self._processing_queue.append(recording_id)
        
        # In development/mock mode, process immediately
        asyncio.create_task(self._process_recording_background(recording_id))
        
        return {
            "status": "queued",
            "recording_id": recording_id,
            "queue_position": len(self._processing_queue)
        }
    
    async def train_user_model(self, db: AsyncSession, user_id: str) -> None:
        """
        Train voice model for a user (Business Logic).
        """
        # Get processed recordings with good quality
        result = await db.execute(
            select(VoiceRecording).where(
                VoiceRecording.user_id == user_id,
                VoiceRecording.is_processed == True,
                VoiceRecording.quality_score >= self.MIN_QUALITY_SCORE
            ).order_by(VoiceRecording.quality_score.desc())
        )
        recordings = result.scalars().all()
        
        if len(recordings) < self.MIN_SAMPLES_FOR_TRAINING:
            # Not enough samples
            if user_id in self._training_queue:
                self._training_queue.remove(user_id)
            return
        
        # Mark top samples as used for training
        for recording in recordings[:2]:
            recording.used_for_training = True
        
        # Get user and update status
        # Using Lazy Import to avoid circular dependency if user_service imports this service
        from app.services.user_service import user_service
        user = await user_service.get_by_id(db, user_id)
        
        if user:
            # Calculate average quality score from training samples
            avg_quality = sum(r.quality_score for r in recordings[:2]) // 2
            
            user.voice_model_trained = True
            user.voice_quality_score = avg_quality
            user.has_voice_sample = True
        
        await db.commit()
        
        # Remove from queue
        if user_id in self._training_queue:
            self._training_queue.remove(user_id)

    async def _train_user_model_background(self, user_id: str) -> None:
        """Background wrapper for training."""
        await asyncio.sleep(2)  # Simulate training time
        async with AsyncSessionLocal() as db:
            await self.train_user_model(db, user_id)

    async def queue_training_for_user(self, user_id: str) -> Dict[str, Any]:
        """
        Queue a user for voice model training.
        """
        if user_id in self._training_queue:
            return {
                "status": "already_queued",
                "user_id": user_id,
                "queue_position": self._training_queue.index(user_id) + 1
            }
        
        self._training_queue.append(user_id)
        
        # In development/mock mode, train immediately
        asyncio.create_task(self._train_user_model_background(user_id))
        
        return {
            "status": "queued",
            "user_id": user_id,
            "queue_position": len(self._training_queue)
        }
    
    async def get_user_training_status(self, user_id: str, db: AsyncSession) -> Dict[str, Any]:
        """
        Get detailed training status for a user.
        """
        # Get user
        from app.services.user_service import user_service
        user = await user_service.get_by_id(db, user_id)
        
        if not user:
            return {"error": "User not found"}
        
        # Get all recordings
        result = await db.execute(
            select(VoiceRecording).where(VoiceRecording.user_id == user_id)
        )
        recordings = result.scalars().all()
        
        total_recordings = len(recordings)
        processed_recordings = len([r for r in recordings if r.is_processed])
        quality_recordings = len([
            r for r in recordings 
            if r.is_processed and r.quality_score and r.quality_score >= self.MIN_QUALITY_SCORE
        ])
        
        samples_needed = max(0, self.MIN_SAMPLES_FOR_TRAINING - quality_recordings)
        ready_for_training = quality_recordings >= self.MIN_SAMPLES_FOR_TRAINING
        
        return {
            "user_id": user_id,
            "has_voice_sample": user.has_voice_sample,
            "voice_model_trained": user.voice_model_trained,
            "voice_quality_score": user.voice_quality_score,
            "voice_model_id": f"model_{user_id}" if user.voice_model_trained else None,
            "total_recordings": total_recordings,
            "processed_recordings": processed_recordings,
            "quality_recordings": quality_recordings,
            "ready_for_training": ready_for_training,
            "samples_needed": samples_needed
        }
    
    async def retrain_voice_model(self, user_id: str, db: AsyncSession) -> Dict[str, Any]:
        """
        Force retrain voice model for a user.
        """
        # Get user
        from app.services.user_service import user_service
        user = await user_service.get_by_id(db, user_id)
        
        if not user:
            return {"error": "User not found"}
        
        # Reset training status
        user.voice_model_trained = False
        user.voice_quality_score = None
        
        # Reset recordings training flags
        result = await db.execute(
            select(VoiceRecording).where(VoiceRecording.user_id == user_id)
        )
        recordings = result.scalars().all()
        
        for recording in recordings:
            recording.used_for_training = False
        
        await db.commit()
    
        # Queue for retraining
        return await self.queue_training_for_user(user_id)
        
    async def save_recording(
        self,
        user_id: str,
        file_path: str,
        language: str,
        text_content: str,
        file_size: int,
        audio_format: str,
        db: AsyncSession
    ) -> VoiceRecording:
        """
        Create a new voice recording record and queue for processing.
        """
        recording = VoiceRecording(
            user_id=user_id,
            language=language,
            text_content=text_content,
            file_path=file_path,
            file_size_bytes=file_size,
            audio_format=audio_format,
            is_processed=False,
            used_for_training=False,
        )
        
        db.add(recording)
        
        # Update user's has_voice_sample flag
        from app.services.user_service import user_service
        user = await user_service.get_by_id(db, user_id)
        if user:
            user.has_voice_sample = True
        
        await db.commit()
        await db.refresh(recording)
        
        # Queue recording for processing
        await self.queue_recording_for_processing(recording.id)
        
        return recording

    async def get_user_recordings(self, user_id: str, db: AsyncSession) -> List[VoiceRecording]:
        """
        List all voice recordings for a user.
        """
        result = await db.execute(
            select(VoiceRecording)
            .where(VoiceRecording.user_id == user_id)
            .order_by(VoiceRecording.created_at.desc())
        )
        return result.scalars().all()

    async def delete_recording(self, recording_id: str, user_id: str, db: AsyncSession) -> bool:
        """
        Delete a voice recording and its file.
        """
        result = await db.execute(
            select(VoiceRecording).where(
                VoiceRecording.id == recording_id,
                VoiceRecording.user_id == user_id
            )
        )
        recording = result.scalar_one_or_none()
        
        if not recording:
            return False
        
        # Delete file
        if os.path.exists(recording.file_path):
            try:
                os.remove(recording.file_path)
            except Exception:
                pass
        
        # Delete record
        await db.delete(recording)
        await db.commit()
        
        # Update user's has_voice_sample if no more recordings
        result = await db.execute(
            select(VoiceRecording).where(VoiceRecording.user_id == user_id)
        )
        remaining = result.scalars().all()
        
        if len(remaining) == 0:
            from app.services.user_service import user_service
            user = await user_service.get_by_id(db, user_id)
            if user:
                user.has_voice_sample = False
                await db.commit()
        
        return True


    async def start_worker(self) -> None:
        """
        Start the background worker for processing voice recordings and training.
        
        In production, this would connect to a job queue (e.g., Celery, Redis Queue).
        For now, it just initializes the service.
        """
        # Initialize any background tasks if needed
        pass
    
    async def stop_worker(self) -> None:
        """
        Stop the background worker.
        
        Gracefully shuts down any running tasks.
        """
        # Cleanup any running tasks
        self._processing_queue.clear()
        self._training_queue.clear()


# Singleton instance
voice_training_service = VoiceTrainingService()

