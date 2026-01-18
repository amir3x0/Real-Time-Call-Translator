import asyncio
import json
from unittest.mock import MagicMock, AsyncMock, patch
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.audio.worker import process_stream_message
from app.services.connection_manager import ConnectionManager, CallConnection
from app.services.rtc_service import publish_audio_chunk

async def test_worker_processing():
    print("Testing worker processing...")
    
    # Mock Redis
    mock_redis = AsyncMock()
    
    # Mock GCP pipeline
    with patch('app.services.audio.worker.process_audio_chunk') as mock_process:
        # Setup mock return
        mock_result = MagicMock()
        mock_result.transcript = "Hello"
        mock_result.translation = "Shalom"
        mock_result.synthesized_audio = b"audio_bytes"
        mock_process.return_value = mock_result
        
        # Test data
        stream_key = "stream:audio:session1"
        message_id = "1-0"
        data = {
            b"data": b"raw_audio",
            b"source_lang": b"en-US",
            b"target_lang": b"he-IL",
            b"speaker_id": b"user1"
        }
        
        # Run processing
        await process_stream_message(mock_redis, stream_key, message_id, data)
        
        # Verify GCP call
        mock_process.assert_called_once()
        
        # Verify Redis publish
        expected_channel = "channel:translation:session1"
        mock_redis.publish.assert_called_once()
        args = mock_redis.publish.call_args[0]
        assert args[0] == expected_channel
        payload = json.loads(args[1])
        assert payload["transcript"] == "Hello"
        assert payload["translation"] == "Shalom"
        assert payload["session_id"] == "session1"
        
        print("✅ Worker processing test passed")

async def test_connection_manager_broadcast():
    print("Testing connection manager broadcast...")
    
    cm = ConnectionManager()
    
    # Setup session
    session_id = "session1"
    cm._sessions[session_id] = {}
    
    # Add speaker
    speaker = MagicMock(spec=CallConnection)
    speaker.user_id = "user1"
    speaker.participant_language = "en-US"
    speaker.is_muted = False
    cm._sessions[session_id]["user1"] = speaker
    
    # Add listener needing translation
    listener = MagicMock(spec=CallConnection)
    listener.user_id = "user2"
    listener.participant_language = "he-IL"
    listener.dubbing_required = True
    listener.is_muted = False
    listener.send_bytes = AsyncMock()
    cm._sessions[session_id]["user2"] = listener
    
    # Mock publish_audio_chunk
    with patch('app.services.rtc_service.publish_audio_chunk') as mock_publish:
        mock_publish.return_value = "1-0"
        
        # Broadcast audio
        await cm.broadcast_audio(
            session_id,
            "user1",
            b"audio_data",
            0
        )
        
        # Verify publish called
        mock_publish.assert_called_once()
        kwargs = mock_publish.call_args[1]
        assert kwargs["session_id"] == session_id
        assert kwargs["source_lang"] == "en-US"
        assert kwargs["target_lang"] == "he-IL"
        
        print("✅ Connection manager broadcast test passed")

async def main():
    await test_worker_processing()
    await test_connection_manager_broadcast()

if __name__ == "__main__":
    asyncio.run(main())
