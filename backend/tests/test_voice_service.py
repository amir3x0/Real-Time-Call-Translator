import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.voice_training_service import voice_training_service
from app.models.voice_recording import VoiceRecording
from app.models.user import User

# Mark all tests in this file as async
pytestmark = pytest.mark.asyncio

async def test_process_recording_logic():
    """
    Test that process_recording business logic works with injected DB session.
    """
    # Mock DB Session
    mock_db = AsyncMock()
    
    # Mock DB Result for getting recording
    mock_recording = VoiceRecording(
        id="rec_123",
        user_id="user_123",
        is_processed=False
    )
    
    # Setup mock execute result
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_recording
    mock_db.execute.return_value = mock_result
    
    # Call the method
    await voice_training_service.process_recording(mock_db, "rec_123")
    
    # Verify changes
    assert mock_recording.is_processed is True
    assert mock_recording.quality_score is not None
    assert mock_recording.quality_score >= 60
    
    # Verify commit was called
    mock_db.commit.assert_called_once()


async def test_train_user_model_logic():
    """
    Test that train_user_model works with injected DB session.
    """
    mock_db = AsyncMock()
    user_id = "user_123"
    
    # Mock processed recordings
    mock_recs = [
        VoiceRecording(id="r1", user_id=user_id, quality_score=90, is_processed=True),
        VoiceRecording(id="r2", user_id=user_id, quality_score=85, is_processed=True)
    ]
    
    # Mock result for recordings query
    mock_result_recs = MagicMock()
    mock_result_recs.scalars.return_value.all.return_value = mock_recs
    
    # Mock user service to return a user
    mock_user = User(id=user_id, voice_model_trained=False)
    
    with patch("app.services.user_service.user_service.get_by_id", new_callable=AsyncMock) as mock_get_user:
        mock_get_user.return_value = mock_user
        
        # Setup execute side effects (first call for recordings)
        # We need to be careful since multiple execute calls happen?
        # Simpler approach: mock_db.execute returns the recordings result
        mock_db.execute.return_value = mock_result_recs

        # Call the method
        await voice_training_service.train_user_model(mock_db, user_id)
        
        # Verify user update
        assert mock_user.voice_model_trained is True
        assert mock_user.voice_quality_score == 87 # (90+85)//2
        
        # Verify commit
        mock_db.commit.assert_called_once()
