"""
Audio Router

Handles audio data routing between call participants:
- Direct passthrough for same-language users
- Translation requests for different-language users
"""
from datetime import datetime
from typing import Dict, Any, TYPE_CHECKING
import logging

if TYPE_CHECKING:
    from .models import CallConnection

logger = logging.getLogger(__name__)


async def broadcast_audio(
    sessions: Dict[str, Dict[str, "CallConnection"]],
    session_id: str,
    speaker_id: str,
    audio_data: bytes,
    timestamp_ms: int = 0
) -> Dict[str, Any]:
    """
    Broadcast audio data to all participants in a session.
    
    This method handles the routing logic:
    - For participants with same language as call: passthrough
    - For participants with different language: translation needed
    
    Args:
        sessions: Active sessions dictionary
        session_id: ID of the session
        speaker_id: ID of the speaking user
        audio_data: Binary audio data
        timestamp_ms: Timestamp relative to call start
        
    Returns:
        Routing result dict
    """
    if session_id not in sessions:
        return {"status": "error", "message": "Session not found"}
    
    result = {
        "status": "success",
        "speaker_id": speaker_id,
        "timestamp_ms": timestamp_ms,
        "passthrough_count": 0,
        "translation_count": 0
    }
    
    # Get speaker connection
    speaker_conn = sessions[session_id].get(speaker_id)
    if not speaker_conn:
        return {"status": "error", "message": "Speaker not found"}
    
    # Get all other connections
    connections = [
        conn for conn in sessions[session_id].values()
        if conn.user_id != speaker_id and not conn.is_muted
    ]
    
    logger.info(f"[AudioRouter] Broadcasting audio from {speaker_id} to {len(connections)} participants in session {session_id}")
    for c in connections:
        logger.debug(f"Target: {c.user_id}, Muted: {c.is_muted}, Dubbing: {c.dubbing_required}")

    # Group by target language
    translation_requests = set()
    
    for conn in connections:
        # Determine if translation is needed
        source_lang = speaker_conn.participant_language
        target_lang = conn.participant_language
        
        # Debug logging
        if conn.dubbing_required:
            logger.debug(f"User {conn.user_id} requires dubbing from {source_lang} to {target_lang}")
        
        if source_lang == target_lang:
            # Same language - direct passthrough
            await conn.send_bytes(audio_data)
            result["passthrough_count"] += 1
        else:
            # Different language - queue for translation
            # We add to set to avoid duplicate publishing for same language pair
            translation_requests.add((source_lang, target_lang))
            logger.debug(f"Queueing translation: {source_lang} -> {target_lang} for user {conn.user_id}")
    
    # Publish for translation
    from app.services.rtc_service import publish_audio_chunk
    for source_lang, target_lang in translation_requests:
        await publish_audio_chunk(
            session_id=session_id,
            chunk=audio_data,
            source_lang=source_lang,
            target_lang=target_lang,
            speaker_id=speaker_id
        )
        result["translation_count"] += 1
    
    return result


async def broadcast_translation(
    sessions: Dict[str, Dict[str, "CallConnection"]],
    session_id: str,
    translation_data: Dict[str, Any]
) -> int:
    """
    Broadcast translation result to participants who need it.
    
    Args:
        sessions: Active sessions dictionary
        session_id: ID of the session
        translation_data: Translation result data
        
    Returns:
        Number of participants notified
    """
    if session_id not in sessions:
        return 0
        
    sent_count = 0
    target_lang = translation_data.get("target_lang")
    connections = list(sessions[session_id].values())
    
    # Check for self-test (single participant)
    is_self_test = len(connections) == 1
    
    for conn in connections:
        # Send if participant language matches target language
        # OR if it's a self-test, always send so they can hear the translation
        if is_self_test or conn.participant_language == target_lang:
            if await conn.send_json(translation_data):
                sent_count += 1
                
    return sent_count
