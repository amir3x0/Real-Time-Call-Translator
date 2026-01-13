"""
TTS Cache for Multi-Party Calls (Phase 3)

Caches identical text+language combinations to reduce GCP TTS API costs.

Example benefit:
- 4-party call with 2 Spanish speakers
- Speaker A says "Hello" -> translated to "Hola"
- Cache stores: ("Hola", "es-ES") -> audio_bytes
- When same "Hola" is needed for 2nd Spanish speaker, cache hit avoids 2nd TTS call
"""
from typing import Optional
import hashlib
import logging

logger = logging.getLogger(__name__)


class TTSCache:
    """LRU cache for TTS audio results."""

    def __init__(self, maxsize: int = 100):
        """
        Initialize TTS cache.

        Args:
            maxsize: Maximum number of cached TTS results (default: 100)
                    Each entry ~50-200KB, so 100 entries ≈ 5-20MB RAM
        """
        self._cache = {}
        self._maxsize = maxsize
        self._access_order = []  # LRU tracking
        self._hits = 0
        self._misses = 0

    def get_cache_key(self, text: str, language: str, voice: Optional[str] = None) -> str:
        """
        Generate cache key for TTS request.

        Args:
            text: Text to synthesize
            language: Target language code (e.g., "es-ES")
            voice: Optional voice name

        Returns:
            16-character hex hash
        """
        key_str = f"{text}|{language}|{voice or 'default'}"
        return hashlib.md5(key_str.encode()).hexdigest()[:16]

    def get(self, text: str, language: str, voice: Optional[str] = None) -> Optional[bytes]:
        """
        Retrieve cached TTS audio.

        Args:
            text: Text that was synthesized
            language: Language code
            voice: Optional voice name

        Returns:
            Audio bytes if cached, None otherwise
        """
        key = self.get_cache_key(text, language, voice)
        if key in self._cache:
            # Move to end (LRU)
            self._access_order.remove(key)
            self._access_order.append(key)
            self._hits += 1
            logger.debug(f"TTS cache HIT for key {key} (text: '{text[:30]}...', lang: {language})")
            return self._cache[key]

        self._misses += 1
        logger.debug(f"TTS cache MISS for key {key}")
        return None

    def put(self, text: str, language: str, audio_bytes: bytes, voice: Optional[str] = None):
        """
        Store TTS audio in cache.

        Args:
            text: Text that was synthesized
            language: Language code
            audio_bytes: TTS audio output
            voice: Optional voice name
        """
        key = self.get_cache_key(text, language, voice)

        # Evict oldest if at capacity
        if len(self._cache) >= self._maxsize and key not in self._cache:
            oldest_key = self._access_order.pop(0)
            del self._cache[oldest_key]
            logger.debug(f"TTS cache evicted oldest entry: {oldest_key}")

        self._cache[key] = audio_bytes
        if key in self._access_order:
            self._access_order.remove(key)
        self._access_order.append(key)

        logger.debug(f"TTS cache PUT for key {key} ({len(audio_bytes)} bytes)")

    def get_stats(self) -> dict:
        """
        Get cache statistics.

        Returns:
            Dict with hits, misses, hit_rate, size
        """
        total = self._hits + self._misses
        hit_rate = (self._hits / total * 100) if total > 0 else 0

        return {
            "hits": self._hits,
            "misses": self._misses,
            "hit_rate_percent": round(hit_rate, 2),
            "cache_size": len(self._cache),
            "max_size": self._maxsize
        }

    def clear(self):
        """Clear all cached entries."""
        self._cache.clear()
        self._access_order.clear()
        logger.info("TTS cache cleared")


# Global singleton instance
_tts_cache = TTSCache(maxsize=100)


def get_tts_cache() -> TTSCache:
    """Get the global TTS cache instance."""
    return _tts_cache
