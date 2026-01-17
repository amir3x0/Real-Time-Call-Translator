"""
Message Deduplicator - TTL-based deduplication utility.

This module provides a reusable message deduplication mechanism that
tracks processed message IDs with automatic expiration to prevent
duplicate processing.

Usage:
    from app.services.core.deduplicator import message_deduplicator

    if message_deduplicator.is_duplicate(message_id):
        return  # Skip duplicate

    # Process message...
"""

import time
from typing import Dict
from dataclasses import dataclass, field

from app.config.constants import MESSAGE_DEDUP_TTL_SEC


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


# Global singleton instance
message_deduplicator = MessageDeduplicator()
