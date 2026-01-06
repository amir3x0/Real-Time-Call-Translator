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


# Language code mapping for GCP API
LANGUAGE_CODE_MAP = {
    "he": "he-IL",
    "en": "en-US", 
    "ru": "ru-RU",
    "he-IL": "he-IL",
    "en-US": "en-US",
    "ru-RU": "ru-RU",
}


def normalize_language_code(lang: str) -> str:
    """Convert short language codes to full BCP-47 codes for GCP."""
    if not lang:
        return "en-US"
    return LANGUAGE_CODE_MAP.get(lang, lang if "-" in lang else f"{lang}-{lang.upper()}")


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
    - For participants with same language as speaker: passthrough
    - For participants with different language: translation via GCP
    
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
        "translation_count": 0,
        "errors": []
    }
    
    # Get speaker connection
    speaker_conn = sessions[session_id].get(speaker_id)
    if not speaker_conn:
        return {"status": "error", "message": "Speaker not found"}
    
    # Get all other connections (excluding speaker, excluding muted)
    connections = [
        conn for conn in sessions[session_id].values()
        if conn.user_id != speaker_id and not conn.is_muted
    ]
    
    # Self-test mode: if only speaker is in session, send back to themselves for testing
    is_self_test = len(sessions[session_id]) == 1
    if is_self_test:
        connections = [speaker_conn]
        logger.info(f"[AudioRouter] Self-test mode: echoing back to speaker {speaker_id}")
    
    if not connections:
        logger.debug(f"[AudioRouter] No recipients for audio from {speaker_id}")
        return result
    
    # Normalize speaker's language code
    source_lang_short = speaker_conn.participant_language or "en"
    source_lang_full = normalize_language_code(source_lang_short)
    
    logger.info(f"[AudioRouter] Broadcasting {len(audio_data)} bytes from {speaker_id} ({source_lang_short}) to {len(connections)} participants")
    
    # Import GCP pipeline
    from app.services.gcp_pipeline import process_audio_chunk
    
    # Process each recipient
    for conn in connections:
        target_lang_short = conn.participant_language or "en"
        target_lang_full = normalize_language_code(target_lang_short)
        
        logger.debug(f"[AudioRouter] Target {conn.user_id}: {target_lang_short} ({target_lang_full})")
        
        # Check if translation is needed (compare short codes for flexibility)
        needs_translation = source_lang_short != target_lang_short
        
        if not needs_translation:
            # Same language - direct passthrough
            try:
                success = await conn.send_bytes(audio_data)
                if success:
                    result["passthrough_count"] += 1
                else:
                    result["errors"].append(f"Passthrough failed for {conn.user_id}")
            except Exception as e:
                logger.error(f"[AudioRouter] Passthrough failed for {conn.user_id}: {e}")
                result["errors"].append(str(e))
        else:
            # Different language - Process via GCP
            try:
                logger.info(f"[AudioRouter] Translating: {source_lang_full} -> {target_lang_full}")
                pipeline_result = await process_audio_chunk(
                    audio_data,
                    source_language_code=source_lang_full,
                    target_language_code=target_lang_full
                )
                
                if pipeline_result.synthesized_audio and len(pipeline_result.synthesized_audio) > 0:
                    logger.info(f"[AudioRouter] Sending {len(pipeline_result.synthesized_audio)} bytes TTS audio to {conn.user_id}")
                    logger.info(f"[AudioRouter] Transcript: '{pipeline_result.transcript}' -> '{pipeline_result.translation}'")
                    
                    success = await conn.send_bytes(pipeline_result.synthesized_audio)
                    if success:
                        result["translation_count"] += 1
                    else:
                        result["errors"].append(f"Send failed for {conn.user_id}")
                else:
                    # No transcript (silence or noise) - optionally forward original audio
                    logger.debug(f"[AudioRouter] No transcript from GCP, forwarding original audio")
                    await conn.send_bytes(audio_data)
                    result["passthrough_count"] += 1

            except Exception as e:
                logger.error(f"[AudioRouter] Translation failed for {conn.user_id}: {e}")
                result["errors"].append(f"Translation error: {str(e)}")
                # Fallback: send original audio so call doesn't go silent
                try:
                    await conn.send_bytes(audio_data)
                    result["passthrough_count"] += 1
                except:
                    pass
    
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
