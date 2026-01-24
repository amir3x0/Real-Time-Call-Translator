"""
Translation Processing Module

This module contains all translation-related services:
- TTSCache: LRU cache for TTS audio results
- TranslationProcessor: Consolidated translation + TTS processing

Usage:
    from app.services.translation import get_tts_cache
    from app.services.translation.processor import TranslationProcessor, TranslationResult
"""

from app.services.translation.tts_cache import TTSCache, get_tts_cache
from app.services.translation.processor import TranslationProcessor, TranslationResult

__all__ = [
    # TTS Cache
    "TTSCache",
    "get_tts_cache",
    # Translation Processor
    "TranslationProcessor",
    "TranslationResult",
]
