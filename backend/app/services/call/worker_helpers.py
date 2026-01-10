"""
Call Transcripts - Extended

Additional helper functions for saving transcripts from the audio worker.
"""
from datetime import datetime
from typing import Optional
from sqlalchemy import select

from app.models.call import Call
from app.models.call_transcript import CallTranscript
from app.models.database import AsyncSessionLocal


async def get_call_id_from_session(session_id: str) -> Optional[str]:
    """
    Get call_id from session_id.
    
    Args:
        session_id: WebSocket session ID
        
    Returns:
        call_id if found, None otherwise
    """
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(Call.id).where(Call.session_id == session_id)
        )
        return result.scalar_one_or_none()


async def save_transcript_from_worker(
    session_id: str,
    speaker_id: str,
    original_language: str,
    original_text: str,
    translated_text: str,
    timestamp_ms: Optional[int] = None
) -> None:
    """
    Save transcript from audio worker.
    
    This is called by the audio worker after processing a translation.
    It looks up the call_id and saves the transcript to the database.
    
    Args:
        session_id: WebSocket session ID
        speaker_id: ID of the speaker
        original_language: Language of original speech
        original_text: Transcribed text
        translated_text: Translated text
        timestamp_ms: Timestamp in milliseconds (optional, will calculate if None)
    """
    # Get call_id
    call_id = await get_call_id_from_session(session_id)
    if not call_id:
        # No call record found - this might be a test session
        return
    
    # Calculate timestamp if not provided
    if timestamp_ms is None:
        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(Call.started_at).where(Call.id == call_id)
            )
            call_start = result.scalar_one_or_none()
            if call_start:
                delta = datetime.utcnow() - call_start
                timestamp_ms = int(delta.total_seconds() * 1000)
            else:
                timestamp_ms = 0
    
    # Save transcript
    from app.services.call.transcripts import add_transcript
    async with AsyncSessionLocal() as db:
        await add_transcript(
            db=db,
            call_id=call_id,
            speaker_user_id=speaker_id,
            original_language=original_language,
            original_text=original_text,
            translated_text=translated_text,
            timestamp_ms=timestamp_ms
        )

