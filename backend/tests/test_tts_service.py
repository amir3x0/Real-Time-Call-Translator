"""
Tests for the Chatterbox TTS Service
"""
import pytest
from unittest.mock import Mock, patch, AsyncMock
import torch


@pytest.fixture
def mock_chatterbox_models():
    """Mock the Chatterbox TTS models."""
    with patch('app.services.tts_service.ChatterboxTTS') as mock_tts, \
         patch('app.services.tts_service.ChatterboxMultilingualTTS') as mock_mtl_tts:
        
        # Setup mock models
        mock_model = Mock()
        mock_model.sr = 24000
        mock_mtl_model = Mock()
        mock_mtl_model.sr = 24000
        
        mock_tts.from_pretrained.return_value = mock_model
        mock_mtl_tts.from_pretrained.return_value = mock_mtl_model
        
        # Mock generate method to return dummy audio tensor
        dummy_audio = torch.zeros(1, 24000)  # 1 second of silence
        mock_mtl_model.generate.return_value = dummy_audio
        
        yield {
            'tts': mock_tts,
            'mtl_tts': mock_mtl_tts,
            'model': mock_model,
            'mtl_model': mock_mtl_model
        }


@pytest.mark.asyncio
async def test_tts_service_initialization(mock_chatterbox_models):
    """Test that the TTS service initializes correctly."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Verify models were loaded
    assert service._model is not None
    assert service._multilingual_model is not None
    assert service.sample_rate == 24000
    
    # Verify from_pretrained was called
    mock_chatterbox_models['tts'].from_pretrained.assert_called_once_with(device="cpu")
    mock_chatterbox_models['mtl_tts'].from_pretrained.assert_called_once_with(device="cpu")


@pytest.mark.asyncio
async def test_synthesize_basic_text(mock_chatterbox_models):
    """Test basic text-to-speech synthesis."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Synthesize text
    text = "Hello, this is a test."
    audio_bytes = await service.synthesize(text, language="en")
    
    # Verify audio was generated
    assert audio_bytes is not None
    assert len(audio_bytes) > 0
    
    # Verify generate was called with correct parameters
    mock_chatterbox_models['mtl_model'].generate.assert_called_once()
    call_args = mock_chatterbox_models['mtl_model'].generate.call_args
    assert call_args[0][0] == text
    assert call_args[1]['lang'] == "en"


@pytest.mark.asyncio
async def test_synthesize_with_voice_cloning(mock_chatterbox_models):
    """Test synthesis with voice cloning from reference audio."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Synthesize with voice cloning
    text = "שלום, זה מבחן"  # Hebrew text
    reference_path = "/path/to/reference.wav"
    audio_bytes = await service.synthesize(
        text,
        language="he",
        audio_prompt_path=reference_path
    )
    
    # Verify audio was generated
    assert audio_bytes is not None
    assert len(audio_bytes) > 0
    
    # Verify generate was called with audio_prompt_path
    call_args = mock_chatterbox_models['mtl_model'].generate.call_args
    assert call_args[1]['audio_prompt_path'] == reference_path
    assert call_args[1]['lang'] == "he"


@pytest.mark.asyncio
async def test_synthesize_with_custom_parameters(mock_chatterbox_models):
    """Test synthesis with custom exaggeration and temperature."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Synthesize with custom parameters
    audio_bytes = await service.synthesize(
        "Test text",
        language="en",
        exaggeration=0.8,
        temperature=1.5,
        cfg_weight=0.3,
        seed=42
    )
    
    # Verify parameters were passed correctly
    call_args = mock_chatterbox_models['mtl_model'].generate.call_args
    assert call_args[1]['exaggeration'] == 0.8
    assert call_args[1]['temperature'] == 1.5
    assert call_args[1]['cfg_weight'] == 0.3
    assert call_args[1]['seed'] == 42


@pytest.mark.asyncio
async def test_clone_voice(mock_chatterbox_models):
    """Test the clone_voice convenience method."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Clone voice for cross-language synthesis
    text = "Привет, это тест"  # Russian text
    reference_path = "/path/to/english_speaker.wav"
    audio_bytes = await service.clone_voice(
        text,
        reference_audio_path=reference_path,
        target_language="ru"
    )
    
    # Verify audio was generated
    assert audio_bytes is not None
    
    # Verify cfg_weight was set to 0.0 for cross-language cloning
    call_args = mock_chatterbox_models['mtl_model'].generate.call_args
    assert call_args[1]['cfg_weight'] == 0.0
    assert call_args[1]['lang'] == "ru"
    assert call_args[1]['audio_prompt_path'] == reference_path


@pytest.mark.asyncio
async def test_get_tts_service_singleton(mock_chatterbox_models):
    """Test that get_tts_service returns a singleton instance."""
    from app.services.tts_service import get_tts_service, _tts_service
    
    # Reset singleton
    import app.services.tts_service as tts_module
    tts_module._tts_service = None
    
    # Get service twice
    service1 = await get_tts_service()
    service2 = await get_tts_service()
    
    # Verify they're the same instance
    assert service1 is service2
    
    # Verify models were loaded only once
    assert mock_chatterbox_models['tts'].from_pretrained.call_count == 1
    assert mock_chatterbox_models['mtl_tts'].from_pretrained.call_count == 1


@pytest.mark.asyncio
async def test_multiple_languages(mock_chatterbox_models):
    """Test synthesis in multiple supported languages."""
    from app.services.tts_service import ChatterboxTTSService
    
    service = ChatterboxTTSService(device="cpu")
    await service.initialize()
    
    # Test Hebrew, English, and Russian
    languages_and_texts = [
        ("he", "שלום עולם"),
        ("en", "Hello world"),
        ("ru", "Привет мир")
    ]
    
    for lang, text in languages_and_texts:
        audio_bytes = await service.synthesize(text, language=lang)
        assert audio_bytes is not None
        assert len(audio_bytes) > 0
        
        # Verify correct language was used
        last_call = mock_chatterbox_models['mtl_model'].generate.call_args
        assert last_call[1]['lang'] == lang


@pytest.mark.asyncio
async def test_initialization_failure_handling():
    """Test handling of initialization failures."""
    from app.services.tts_service import ChatterboxTTSService
    
    with patch('app.services.tts_service.ChatterboxTTS') as mock_tts:
        # Make initialization fail
        mock_tts.from_pretrained.side_effect = Exception("Model loading failed")
        
        service = ChatterboxTTSService(device="cpu")
        
        # Verify exception is raised
        with pytest.raises(Exception) as exc_info:
            await service.initialize()
        
        assert "Model loading failed" in str(exc_info.value)
