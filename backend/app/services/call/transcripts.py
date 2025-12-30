"""
Call Transcripts

Functions for managing call transcripts.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.call_transcript import CallTranscript


async def add_transcript(
    db: AsyncSession,
    call_id: str,
    speaker_user_id: str,
    original_language: str,
    original_text: str,
    timestamp_ms: int,
    translated_text: str = None,
    target_language: str = None,
    tts_method: str = None,
    processing_time_ms: int = None
) -> CallTranscript:
    """
    Add a transcript entry to a call.
    
    Args:
        db: Database session
        call_id: ID of the call
        speaker_user_id: ID of the speaker
        original_language: Language of original speech
        original_text: Transcribed text
        timestamp_ms: Timestamp in milliseconds from call start
        translated_text: Translated text (if any)
        target_language: Target language for translation
        tts_method: TTS method used
        processing_time_ms: Processing time
        
    Returns:
        Created CallTranscript
    """
    transcript = CallTranscript.create_transcript(
        call_id=call_id,
        speaker_user_id=speaker_user_id,
        original_language=original_language,
        original_text=original_text,
        timestamp_ms=timestamp_ms,
        translated_text=translated_text,
        target_language=target_language,
        tts_method=tts_method,
        processing_time_ms=processing_time_ms,
    )
    
    db.add(transcript)
    await db.commit()
    await db.refresh(transcript)
    
    return transcript
