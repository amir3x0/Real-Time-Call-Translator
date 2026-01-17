"""
Stream Manager - Manages active audio streams and their associated tasks.

This module provides centralized management for audio stream lifecycle,
including queue creation, task tracking, and cleanup.

Usage:
    from app.services.audio.stream_manager import stream_manager

    # Register a new stream
    q = stream_manager.create_stream(session_id, speaker_id)

    # Start processing task
    stream_manager.set_task(session_id, speaker_id, task)

    # Check if stream exists
    if stream_manager.has_stream(session_id, speaker_id):
        stream_manager.push_audio(session_id, speaker_id, audio_data)

    # Cleanup
    stream_manager.remove_stream(session_id, speaker_id)
"""

import asyncio
import queue
import logging
from typing import Dict, Optional
from dataclasses import dataclass

from app.services.metrics import active_streams_gauge

logger = logging.getLogger(__name__)


@dataclass
class StreamInfo:
    """Information about an active stream."""
    session_id: str
    speaker_id: str
    audio_queue: queue.Queue
    task: Optional[asyncio.Task] = None


class StreamManager:
    """
    Manages active audio streams and their associated tasks.

    Provides a centralized place for:
    - Creating and tracking audio queues per stream
    - Managing asyncio tasks for stream processing
    - Cleanup when streams end
    - Metrics tracking

    Thread-safe for queue operations (uses thread-safe Queue).
    """

    def __init__(self):
        self._streams: Dict[str, StreamInfo] = {}

    def _get_key(self, session_id: str, speaker_id: str) -> str:
        """Generate unique key for a stream."""
        return f"{session_id}:{speaker_id}"

    def create_stream(
        self,
        session_id: str,
        speaker_id: str
    ) -> queue.Queue:
        """
        Create a new audio stream.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID

        Returns:
            Queue for pushing audio chunks
        """
        key = self._get_key(session_id, speaker_id)

        if key in self._streams:
            logger.warning(f"Stream {key} already exists, returning existing queue")
            return self._streams[key].audio_queue

        audio_queue = queue.Queue()
        self._streams[key] = StreamInfo(
            session_id=session_id,
            speaker_id=speaker_id,
            audio_queue=audio_queue
        )

        # Update metrics
        active_streams_gauge.set(len(self._streams))

        logger.info(f"Created stream {key}")
        return audio_queue

    def set_task(
        self,
        session_id: str,
        speaker_id: str,
        task: asyncio.Task
    ):
        """
        Associate an asyncio task with a stream.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID
            task: The processing task for this stream
        """
        key = self._get_key(session_id, speaker_id)

        if key not in self._streams:
            logger.warning(f"Cannot set task: stream {key} does not exist")
            return

        self._streams[key].task = task

        # Add done callback for cleanup
        def cleanup_callback(t):
            if key in self._streams:
                self._streams[key].task = None
                logger.debug(f"Task cleanup callback for {key}")

        task.add_done_callback(cleanup_callback)

    def has_stream(self, session_id: str, speaker_id: str) -> bool:
        """Check if a stream exists."""
        key = self._get_key(session_id, speaker_id)
        return key in self._streams

    def push_audio(
        self,
        session_id: str,
        speaker_id: str,
        audio_data: bytes
    ) -> bool:
        """
        Push audio data to a stream's queue.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID
            audio_data: Raw audio bytes

        Returns:
            True if audio was pushed, False if stream doesn't exist
        """
        key = self._get_key(session_id, speaker_id)

        if key not in self._streams:
            return False

        try:
            self._streams[key].audio_queue.put_nowait(audio_data)
            return True
        except queue.Full:
            logger.warning(f"Audio queue full for {key}")
            return False

    def signal_end(self, session_id: str, speaker_id: str):
        """
        Signal end of stream by pushing None to queue.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID
        """
        key = self._get_key(session_id, speaker_id)

        if key in self._streams:
            self._streams[key].audio_queue.put(None)
            logger.debug(f"Signaled end for {key}")

    def remove_stream(self, session_id: str, speaker_id: str):
        """
        Remove a stream and clean up resources.

        Args:
            session_id: Call session ID
            speaker_id: Speaker user ID
        """
        key = self._get_key(session_id, speaker_id)

        if key not in self._streams:
            return

        stream_info = self._streams[key]

        # Cancel task if running
        if stream_info.task and not stream_info.task.done():
            stream_info.task.cancel()

        del self._streams[key]

        # Update metrics
        active_streams_gauge.set(len(self._streams))

        logger.info(f"Removed stream {key}")

    def get_queue(
        self,
        session_id: str,
        speaker_id: str
    ) -> Optional[queue.Queue]:
        """Get the audio queue for a stream."""
        key = self._get_key(session_id, speaker_id)

        if key not in self._streams:
            return None

        return self._streams[key].audio_queue

    async def cancel_all_tasks(self, timeout: float = 1.0):
        """
        Cancel all running tasks (for shutdown).

        Args:
            timeout: Seconds to wait for task cancellation
        """
        tasks = []
        for stream_info in self._streams.values():
            if stream_info.task and not stream_info.task.done():
                stream_info.task.cancel()
                tasks.append(stream_info.task)

        if tasks:
            logger.info(f"Cancelling {len(tasks)} stream tasks...")
            await asyncio.wait(tasks, timeout=timeout)

    def signal_all_end(self):
        """Signal end of all streams (for shutdown)."""
        for stream_info in self._streams.values():
            stream_info.audio_queue.put(None)

    def get_active_count(self) -> int:
        """Get number of active streams."""
        return len(self._streams)

    def get_stats(self) -> dict:
        """Get manager statistics."""
        running_tasks = sum(
            1 for s in self._streams.values()
            if s.task and not s.task.done()
        )
        return {
            "active_streams": len(self._streams),
            "running_tasks": running_tasks
        }


# Global singleton instance
stream_manager = StreamManager()
