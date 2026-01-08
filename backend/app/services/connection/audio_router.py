"""
Audio Router

Handles audio data routing between call participants:
- Direct passthrough for same-language users
- Translation requests for different-language users
- Audio buffering for improved STT accuracy
"""
from datetime import datetime
from typing import Dict, Any, TYPE_CHECKING
import logging
import asyncio

if TYPE_CHECKING:
    from .models import CallConnection

logger = logging.getLogger(__name__)

# Audio buffer for accumulating chunks before STT
# Key: (session_id, speaker_id, target_user_id) -> bytearray
_audio_buffers: Dict[tuple, bytearray] = {}
_buffer_timers: Dict[tuple, asyncio.TimerHandle] = {}

# Buffer settings - accumulate 0.8 seconds of audio before STT (reduced for lower latency)
BUFFER_DURATION_SEC = 0.8
SAMPLE_RATE = 16000
BYTES_PER_SAMPLE = 2  # 16-bit PCM
MIN_BUFFER_SIZE = int(BUFFER_DURATION_SEC * SAMPLE_RATE * BYTES_PER_SAMPLE)  # ~25600 bytes


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
    - For participants with same language as speaker: immediate passthrough
    - For participants with different language: buffer audio then translate via GCP
    
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
    
    logger.debug(f"[AudioRouter] Received {len(audio_data)} bytes from {speaker_id} ({source_lang_short})")
    
    # Process each recipient
    for conn in connections:
        target_lang_short = conn.participant_language or "en"
        target_lang_full = normalize_language_code(target_lang_short)
        
        # Check if translation is needed (compare short codes for flexibility)
        needs_translation = source_lang_short != target_lang_short
        
        if not needs_translation:
            # Same language - direct passthrough (no buffering needed)
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
            # Different language - accumulate audio in buffer, then translate
            buffer_key = (session_id, speaker_id, conn.user_id)
            
            # Initialize buffer if needed
            if buffer_key not in _audio_buffers:
                _audio_buffers[buffer_key] = bytearray()
            
            # Add audio to buffer
            _audio_buffers[buffer_key].extend(audio_data)
            buffer_size = len(_audio_buffers[buffer_key])
            
            logger.debug(f"[AudioRouter] Buffer for {speaker_id}->{conn.user_id}: {buffer_size}/{MIN_BUFFER_SIZE} bytes")
            
            # Check if buffer is full enough for STT
            if buffer_size >= MIN_BUFFER_SIZE:
                # Extract buffer and process
                audio_to_process = bytes(_audio_buffers[buffer_key])
                _audio_buffers[buffer_key] = bytearray()
                
                logger.info(f"[AudioRouter] Processing {len(audio_to_process)} bytes: {source_lang_full} -> {target_lang_full}")
                
                # Process via GCP in background
                asyncio.create_task(
                    _process_and_send_translation(
                        conn, audio_to_process, source_lang_full, target_lang_full,
                        speaker_id, session_id
                    )
                )
                result["translation_count"] += 1
    
    return result


async def _process_and_send_translation(
    conn: "CallConnection",
    audio_data: bytes,
    source_lang: str,
    target_lang: str,
    speaker_id: str,
    session_id: str
):
    """Process audio through GCP pipeline and send translated audio to recipient."""
    from app.services.gcp_pipeline import process_audio_chunk
    
    try:
        pipeline_result = await process_audio_chunk(
            audio_data,
            source_language_code=source_lang,
            target_language_code=target_lang
        )
        
        if pipeline_result.synthesized_audio and len(pipeline_result.synthesized_audio) > 0:
            logger.info(f"[AudioRouter] Translation success: '{pipeline_result.transcript}' -> '{pipeline_result.translation}'")
            logger.info(f"[AudioRouter] Sending {len(pipeline_result.synthesized_audio)} bytes TTS to {conn.user_id}")
            
            await conn.send_bytes(pipeline_result.synthesized_audio)
        else:
            # No transcript - could be silence, send original audio as fallback
            logger.debug(f"[AudioRouter] No transcript from GCP for {len(audio_data)} bytes, sending original")
            await conn.send_bytes(audio_data)
            
    except Exception as e:
        logger.error(f"[AudioRouter] Translation error for {conn.user_id}: {e}")
        # Fallback: send original audio
        try:
            await conn.send_bytes(audio_data)
        except:
            pass


def clear_audio_buffer(session_id: str, user_id: str = None):
    """Clear audio buffers for a session or specific user."""
    keys_to_remove = []
    for key in _audio_buffers:
        if key[0] == session_id:
            if user_id is None or key[1] == user_id or key[2] == user_id:
                keys_to_remove.append(key)
    
    for key in keys_to_remove:
        del _audio_buffers[key]
        if key in _buffer_timers:
            _buffer_timers[key].cancel()
            del _buffer_timers[key]
    
    logger.debug(f"[AudioRouter] Cleared {len(keys_to_remove)} audio buffers for session {session_id}")


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
