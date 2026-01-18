"""
Translation Processing Module

This module contains all translation-related services:
- TTSCache: LRU cache for TTS audio results
- TranslationProcessor: Consolidated translation + TTS processing
- StreamingTranslationProcessor: Low-latency streaming translation pipeline

Usage:
    from app.services.translation import get_tts_cache, get_streaming_processor
    from app.services.translation.processor import TranslationProcessor, TranslationResult
"""

from app.services.translation.tts_cache import TTSCache, get_tts_cache
from app.services.translation.processor import TranslationProcessor, TranslationResult
from app.services.translation.streaming import (
    StreamingTranslationProcessor,
    StreamContext,
    get_streaming_processor,
)

__all__ = [
    # TTS Cache
    "TTSCache",
    "get_tts_cache",
    # Translation Processor
    "TranslationProcessor",
    "TranslationResult",
    # Streaming Translation
    "StreamingTranslationProcessor",
    "StreamContext",
    "get_streaming_processor",
]
