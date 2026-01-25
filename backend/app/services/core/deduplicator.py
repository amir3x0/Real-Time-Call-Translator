"""
Deduplication Utilities - TTL-based deduplication mechanisms.

This module provides reusable deduplication mechanisms for:
- Message IDs (Redis stream processing)
- Transcript publishing (prevent duplicate translations from both pipelines)
- Audio content (prevent processing duplicate audio chunks)

Usage:
    from app.services.core.deduplicator import (
        get_message_deduplicator,
        get_transcript_publish_deduplicator,
        get_audio_content_deduplicator,
    )

    # Message deduplication
    if get_message_deduplicator().is_duplicate(message_id):
        return  # Skip duplicate

    # Transcript publish deduplication (streaming-first mode)
    if not get_transcript_publish_deduplicator().should_publish(session_id, speaker_id, transcript):
        return  # Already published by other pipeline

    # Audio content deduplication
    if get_audio_content_deduplicator().is_duplicate_audio(audio_data):
        return  # Skip duplicate audio chunk
"""

import hashlib
import logging
import threading
import time
from typing import Dict, Optional
from dataclasses import dataclass, field

from app.config.constants import (
    MESSAGE_DEDUP_TTL_SEC,
    TRANSCRIPT_PUBLISH_DEDUP_TTL_SEC,
    AUDIO_CONTENT_DEDUP_TTL_SEC,
)

logger = logging.getLogger(__name__)


@dataclass
class MessageDeduplicator:
    """
    TTL-based message deduplication.

    Tracks processed message IDs with expiration to prevent
    duplicate processing of the same message. Commonly used in:
    - Redis stream message processing
    - WebSocket message handling
    - Event-driven architectures

    Attributes:
        ttl_seconds: How long to remember processed message IDs
    """

    ttl_seconds: float = MESSAGE_DEDUP_TTL_SEC
    _processed: Dict[str, float] = field(default_factory=dict)

    def is_duplicate(self, message_id: str) -> bool:
        """
        Check if message was already processed.

        Automatically cleans up expired entries on each call.

        Args:
            message_id: Unique message identifier

        Returns:
            True if this message was already processed (duplicate),
            False if this is a new message (first time seeing it)
        """
        now = time.time()

        # Cleanup expired entries (lazy cleanup)
        expired = [
            mid for mid, ts in self._processed.items()
            if now - ts > self.ttl_seconds
        ]
        for mid in expired:
            del self._processed[mid]

        # Check if already processed
        if message_id in self._processed:
            return True

        # Mark as processed
        self._processed[message_id] = now
        return False

    def mark_processed(self, message_id: str):
        """
        Explicitly mark a message as processed.

        Use this when you want to mark a message without checking
        for duplicates (e.g., after successful processing).

        Args:
            message_id: Unique message identifier
        """
        self._processed[message_id] = time.time()

    def clear(self):
        """Clear all tracked messages."""
        self._processed.clear()

    def get_stats(self) -> dict:
        """
        Get deduplication statistics.

        Returns:
            Dict with tracked_count and oldest_age_seconds
        """
        now = time.time()
        if not self._processed:
            return {"tracked_count": 0, "oldest_age_seconds": 0}

        oldest_ts = min(self._processed.values())
        return {
            "tracked_count": len(self._processed),
            "oldest_age_seconds": round(now - oldest_ts, 2)
        }


@dataclass
class TranscriptPublishDeduplicator:
    """
    Prevents duplicate translation publishes from streaming and batch pipelines.

    When both streaming and batch pipelines produce translations for the same
    audio, this ensures only the first one gets published. Uses a combination
    of session_id, speaker_id, and normalized transcript as the key.

    Thread-safe: Protected by a lock for concurrent access.

    Attributes:
        ttl_seconds: How long to remember published transcripts
    """

    ttl_seconds: float = TRANSCRIPT_PUBLISH_DEDUP_TTL_SEC
    _published: Dict[str, float] = field(default_factory=dict)
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def should_publish(self, session_id: str, speaker_id: str, transcript: str) -> bool:
        """
        Check if this transcript should be published.

        Returns True if this is the first publish attempt for this transcript,
        False if another pipeline already published it.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID
            transcript: The transcript text

        Returns:
            True if OK to publish (first attempt),
            False if already published by other pipeline
        """
        # Normalize transcript for comparison
        normalized = transcript.strip().lower()
        key = f"{session_id}:{speaker_id}:{normalized}"
        now = time.time()

        with self._lock:
            # Cleanup expired entries
            expired = [
                k for k, ts in self._published.items()
                if now - ts > self.ttl_seconds
            ]
            for k in expired:
                del self._published[k]

            # Check if already published
            if key in self._published:
                logger.debug(f"Transcript already published: '{transcript[:30]}...'")
                return False

            # Mark as published
            self._published[key] = now
            return True

    def clear(self):
        """Clear all tracked transcripts."""
        with self._lock:
            self._published.clear()

    def get_stats(self) -> dict:
        """Get deduplication statistics."""
        with self._lock:
            return {"tracked_count": len(self._published)}


@dataclass
class AudioContentDeduplicator:
    """
    Prevents processing duplicate audio chunks.

    Uses a hash of the audio content to detect duplicates, regardless of
    the message ID. This catches cases where the same audio is sent
    multiple times with different message IDs (reconnection, retry, etc).

    Attributes:
        ttl_seconds: How long to remember processed audio hashes
    """

    ttl_seconds: float = AUDIO_CONTENT_DEDUP_TTL_SEC
    _processed: Dict[str, float] = field(default_factory=dict)

    def is_duplicate_audio(self, audio_data: bytes) -> bool:
        """
        Check if this audio chunk was already processed.

        Uses a hash of the first 1KB + length as a fingerprint for efficiency.

        Args:
            audio_data: Raw audio bytes

        Returns:
            True if this audio was already processed (duplicate),
            False if this is new audio
        """
        # Create fingerprint from first 1KB + length
        # This is faster than hashing the entire chunk while still being unique
        fingerprint = hashlib.md5(
            audio_data[:1024] + len(audio_data).to_bytes(4, 'big')
        ).hexdigest()

        now = time.time()

        # Cleanup expired entries
        expired = [
            k for k, ts in self._processed.items()
            if now - ts > self.ttl_seconds
        ]
        for k in expired:
            del self._processed[k]

        # Check if already processed
        if fingerprint in self._processed:
            return True

        # Mark as processed
        self._processed[fingerprint] = now
        return False

    def clear(self):
        """Clear all tracked audio hashes."""
        self._processed.clear()

    def get_stats(self) -> dict:
        """Get deduplication statistics."""
        return {"tracked_count": len(self._processed)}


# Global singleton instances (lazy initialization)
_message_deduplicator: Optional[MessageDeduplicator] = None
_transcript_publish_deduplicator: Optional[TranscriptPublishDeduplicator] = None
_audio_content_deduplicator: Optional[AudioContentDeduplicator] = None


def get_message_deduplicator() -> MessageDeduplicator:
    """Get or create the global MessageDeduplicator instance."""
    global _message_deduplicator
    if _message_deduplicator is None:
        _message_deduplicator = MessageDeduplicator()
    return _message_deduplicator


def get_transcript_publish_deduplicator() -> TranscriptPublishDeduplicator:
    """Get or create the global TranscriptPublishDeduplicator instance."""
    global _transcript_publish_deduplicator
    if _transcript_publish_deduplicator is None:
        _transcript_publish_deduplicator = TranscriptPublishDeduplicator()
    return _transcript_publish_deduplicator


def get_audio_content_deduplicator() -> AudioContentDeduplicator:
    """Get or create the global AudioContentDeduplicator instance."""
    global _audio_content_deduplicator
    if _audio_content_deduplicator is None:
        _audio_content_deduplicator = AudioContentDeduplicator()
    return _audio_content_deduplicator
