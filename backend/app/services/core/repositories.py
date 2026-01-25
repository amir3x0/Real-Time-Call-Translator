"""
Repository Layer - Centralized database queries.

This module provides a repository pattern for database access,
eliminating duplicated queries across the codebase and providing
a clear separation between business logic and data access.

Usage:
    from app.services.core.repositories import get_call_repository

    # Get target languages for translation
    target_langs = await get_call_repository().get_target_languages(session_id, speaker_id)
    # Returns: {"en-US": ["user2", "user3"], "he-IL": ["user4"]}
"""

import logging
from typing import Dict, List, Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import AsyncSessionLocal
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.config.constants import DEFAULT_PARTICIPANT_LANGUAGE

logger = logging.getLogger(__name__)


class CallRepository:
    """
    Repository for call-related database queries.

    Centralizes all call and participant queries that were previously
    duplicated in audio_worker.py and streaming_translation_processor.py.
    """

    @staticmethod
    async def get_call_by_session_id(session_id: str) -> Optional[Call]:
        """
        Get call by session ID.

        Args:
            session_id: The unique session identifier

        Returns:
            Call object if found, None otherwise
        """
        try:
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(Call).where(Call.session_id == session_id)
                )
                return result.scalar_one_or_none()
        except Exception as e:
            logger.error(f"Error getting call by session_id {session_id}: {e}")
            return None

    @staticmethod
    async def get_connected_participants(
        call_id: int,
        exclude_user_id: Optional[str] = None
    ) -> List[CallParticipant]:
        """
        Get connected participants for a call.

        Args:
            call_id: The call ID (not session_id)
            exclude_user_id: Optional user ID to exclude (typically the speaker)

        Returns:
            List of connected CallParticipant objects
        """
        try:
            async with AsyncSessionLocal() as db:
                stmt = select(CallParticipant).where(
                    and_(
                        CallParticipant.call_id == call_id,
                        CallParticipant.is_connected == True
                    )
                )

                if exclude_user_id:
                    stmt = stmt.where(CallParticipant.user_id != exclude_user_id)

                result = await db.execute(stmt)
                return result.scalars().all()
        except Exception as e:
            logger.error(f"Error getting participants for call {call_id}: {e}")
            return []

    @staticmethod
    async def get_target_languages(
        session_id: str,
        speaker_id: str,
        include_speaker: bool = False
    ) -> Dict[str, List[str]]:
        """
        Get target languages for translation.

        This is the main method used by both audio_worker and
        streaming_translation_processor to determine which languages
        to translate to and who should receive each translation.

        Args:
            session_id: The call session ID
            speaker_id: The user ID of the speaker
            include_speaker: If True, include the speaker in their own language's
                           recipient list. This allows speakers to see their own
                           messages in the chat history. Default False for backwards
                           compatibility.

        Returns:
            Dict mapping language code to list of recipient user IDs.
            Example: {"en-US": ["user2", "user3"], "he-IL": ["user4"]}
            Returns empty dict if call not found or no other participants.
        """
        target_langs_map: Dict[str, List[str]] = {}
        speaker_language: Optional[str] = None

        try:
            async with AsyncSessionLocal() as db:
                # Get call by session_id
                call_result = await db.execute(
                    select(Call).where(Call.session_id == session_id)
                )
                call = call_result.scalar_one_or_none()

                if not call:
                    logger.warning(f"No call found for session {session_id}")
                    return {}

                # If include_speaker, first get the speaker's language
                if include_speaker:
                    speaker_result = await db.execute(
                        select(CallParticipant).where(
                            and_(
                                CallParticipant.call_id == call.id,
                                CallParticipant.user_id == speaker_id
                            )
                        )
                    )
                    speaker_participant = speaker_result.scalar_one_or_none()
                    if speaker_participant:
                        speaker_language = speaker_participant.participant_language or DEFAULT_PARTICIPANT_LANGUAGE

                # Get other connected participants (exclude speaker)
                participants_result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == call.id,
                            CallParticipant.user_id != speaker_id,
                            CallParticipant.is_connected == True
                        )
                    )
                )
                participants = participants_result.scalars().all()

                # Group participants by language
                for p in participants:
                    lang = p.participant_language or DEFAULT_PARTICIPANT_LANGUAGE
                    if lang not in target_langs_map:
                        target_langs_map[lang] = []
                    target_langs_map[lang].append(p.user_id)

                # Include speaker in their own language's recipient list
                # This ensures speakers see their own messages in chat history
                if include_speaker and speaker_language:
                    if speaker_language not in target_langs_map:
                        target_langs_map[speaker_language] = []
                    # Add speaker to their language group (they'll receive their own message)
                    target_langs_map[speaker_language].append(speaker_id)
                    logger.debug(f"Including speaker {speaker_id} in {speaker_language} recipients")

                logger.debug(
                    f"Target languages for {speaker_id} in session {session_id}: "
                    f"{list(target_langs_map.keys())} (include_speaker={include_speaker})"
                )

        except Exception as e:
            logger.error(f"Error getting target languages: {e}")
            import traceback
            traceback.print_exc()

        return target_langs_map

    @staticmethod
    async def get_participant_language(
        session_id: str,
        user_id: str
    ) -> Optional[str]:
        """
        Get the language preference for a specific participant.

        Args:
            session_id: The call session ID
            user_id: The user ID to look up

        Returns:
            Language code (e.g., "en-US") or None if not found
        """
        try:
            async with AsyncSessionLocal() as db:
                # Get call
                call_result = await db.execute(
                    select(Call).where(Call.session_id == session_id)
                )
                call = call_result.scalar_one_or_none()

                if not call:
                    return None

                # Get participant
                participant_result = await db.execute(
                    select(CallParticipant).where(
                        and_(
                            CallParticipant.call_id == call.id,
                            CallParticipant.user_id == user_id
                        )
                    )
                )
                participant = participant_result.scalar_one_or_none()

                if participant:
                    return participant.participant_language or DEFAULT_PARTICIPANT_LANGUAGE

                return None

        except Exception as e:
            logger.error(f"Error getting participant language: {e}")
            return None


# Global singleton instance (lazy initialization)
_call_repository: Optional[CallRepository] = None


def get_call_repository() -> CallRepository:
    """Get or create the global CallRepository instance."""
    global _call_repository
    if _call_repository is None:
        _call_repository = CallRepository()
    return _call_repository
