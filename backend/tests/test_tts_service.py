"""
Tests for the Chatterbox TTS Service

NOTE: Full integration tests require chatterbox-tts and its dependencies (torch, torchaudio).
These basic tests verify the service structure and can run without those dependencies.

For full testing, install dependencies:
    pip install chatterbox-tts torch torchaudio
"""
import pytest
from unittest.mock import Mock, patch


@pytest.mark.asyncio
async def test_service_can_be_imported():
    """Test that the TTS service module can be imported."""
    try:
        from app.services import tts_service
        assert tts_service is not None
        assert hasattr(tts_service, 'ChatterboxTTSService')
        assert hasattr(tts_service, 'get_tts_service')
    except ImportError as e:
        pytest.skip(f"Could not import tts_service: {e}")


@pytest.mark.asyncio
async def test_service_class_structure():
    """Test that the ChatterboxTTSService class has expected methods."""
    try:
        from app.services.tts_service import ChatterboxTTSService
        
        # Check that the class has expected methods
        assert hasattr(ChatterboxTTSService, '__init__')
        assert hasattr(ChatterboxTTSService, 'initialize')
        assert hasattr(ChatterboxTTSService, 'synthesize')
        assert hasattr(ChatterboxTTSService, 'clone_voice')
        assert hasattr(ChatterboxTTSService, '_load_models')
        assert hasattr(ChatterboxTTSService, '_synthesize_sync')
        assert hasattr(ChatterboxTTSService, '_tensor_to_bytes')
        
    except ImportError as e:
        pytest.skip(f"Could not import ChatterboxTTSService: {e}")


def test_service_has_correct_parameters():
    """Test that service methods have correct signatures."""
    try:
        from app.services.tts_service import ChatterboxTTSService
        import inspect
        
        # Check initialize method
        init_sig = inspect.signature(ChatterboxTTSService.initialize)
        assert 'self' in str(init_sig)
        
        # Check synthesize method
        synth_sig = inspect.signature(ChatterboxTTSService.synthesize)
        params = list(synth_sig.parameters.keys())
        assert 'text' in params
        assert 'language' in params
        assert 'audio_prompt_path' in params
        assert 'exaggeration' in params
        assert 'temperature' in params
        assert 'cfg_weight' in params
        
        # Check clone_voice method
        clone_sig = inspect.signature(ChatterboxTTSService.clone_voice)
        params = list(clone_sig.parameters.keys())
        assert 'text' in params
        assert 'reference_audio_path' in params
        assert 'target_language' in params
        
    except ImportError as e:
        pytest.skip(f"Could not import ChatterboxTTSService: {e}")
