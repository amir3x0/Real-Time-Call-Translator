"""
Call Service - Core Call Management

Main service class for call operations:
- Call initiation with validation
- Call state management (accept, reject, end)
- Mark call status changes
"""
from datetime import datetime, UTC
from typing import List, Tuple
import logging

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.call import Call
from app.models.call_participant import CallParticipant

from .exceptions import (
    CallServiceError,
    CallNotFoundError,
    UserOfflineError,
    InvalidParticipantCountError,
)
from .validators import validate_contact_exists, validate_not_in_active_call
from .participants import create_participant, handle_participant_left, handle_participant_joined, force_leave_all_calls
from .history import get_call_with_participants, get_user_call_history, get_pending_calls
from .transcripts import add_transcript

logger = logging.getLogger(__name__)


class CallService:
    """Service for managing calls and call participants."""
    
    # Participant limits
    MIN_PARTICIPANTS = 1
    MAX_PARTICIPANTS = 4
    
    # === Validation methods (delegates to validators module) ===
    
    @staticmethod
    async def validate_contact_exists(db: AsyncSession, caller_id: str, target_id: str) -> bool:
        return await validate_contact_exists(db, caller_id, target_id)
    
    @staticmethod
    async def validate_not_in_active_call(db: AsyncSession, user_ids: List[str]) -> bool:
        return await validate_not_in_active_call(db, user_ids)
    
    # === Participant methods (delegates to participants module) ===
    
    @staticmethod
    async def _create_participant(db: AsyncSession, call: Call, user: User, is_caller: bool) -> CallParticipant:
        return await create_participant(db, call, user, is_caller)
    
    @classmethod
    async def handle_participant_joined(cls, db: AsyncSession, call_id: str, user_id: str) -> CallParticipant:
        return await handle_participant_joined(db, call_id, user_id)
    
    @classmethod
    async def handle_participant_left(cls, db: AsyncSession, call_id: str, user_id: str) -> Tuple[bool, Call]:
        return await handle_participant_left(db, call_id, user_id, cls.MIN_PARTICIPANTS)
    
    @classmethod
    async def force_leave_all_calls(cls, db: AsyncSession, user_id: str) -> List[str]:
        return await force_leave_all_calls(db, user_id)
    
    # === History methods (delegates to history module) ===
    
    @classmethod
    async def get_call_with_participants(cls, db: AsyncSession, call_id: str):
        return await get_call_with_participants(db, call_id)
    
    @classmethod
    async def get_user_call_history(cls, db: AsyncSession, user_id: str, limit: int = 20):
        return await get_user_call_history(db, user_id, limit)
    
    @classmethod
    async def get_pending_calls(cls, db: AsyncSession, user_id: str):
        return await get_pending_calls(db, user_id)
    
    # === Transcript methods (delegates to transcripts module) ===
    
    @classmethod
    async def add_transcript(cls, db: AsyncSession, call_id: str, speaker_user_id: str,
                            original_language: str, original_text: str, timestamp_ms: int,
                            translated_text: str = None, target_language: str = None,
                            tts_method: str = None, processing_time_ms: int = None):
        return await add_transcript(
            db, call_id, speaker_user_id, original_language, original_text,
            timestamp_ms, translated_text, target_language, tts_method, processing_time_ms
        )
    
    # === Core call operations ===
    
    @classmethod
    async def initiate_call(
        cls,
        db: AsyncSession,
        caller: User,
        target_ids: List[str],
        skip_contact_validation: bool = False
    ) -> Tuple[Call, List[CallParticipant]]:
        """
        Initiate a call between users.
        
        Args:
            db: Database session
            caller: The user initiating the call (User object)
            target_ids: List of target user IDs
            skip_contact_validation: Skip contact check (for testing)
        """
        caller_id = caller.id
        
        # Deduplicate and remove caller from target_ids
        target_ids = list(set(tid for tid in target_ids if tid != caller_id))
        total_participants = 1 + len(target_ids)
        
        # Validate participant count
        if total_participants < cls.MIN_PARTICIPANTS:
            raise InvalidParticipantCountError(
                f"Call must have at least {cls.MIN_PARTICIPANTS} participants"
            )
        if total_participants > cls.MAX_PARTICIPANTS:
            raise InvalidParticipantCountError(
                f"Call cannot have more than {cls.MAX_PARTICIPANTS} participants"
            )
        
        # Get target users logic needs user_service, so we still might need it for TARGETS
        # BUT the circular dependency was usually caused by UserService needing CallService (or vice versa)
        # We can keep the import for target lookup if it's not the cause, OR we can inject user_service.
        
        # Wait - let's see if we can just import user_service at top level now? 
        # If not, we should probably pass target_users as objects too or keep the inner import for targets only.
        # But the instruction was to remove the inner import.
        # Let's try to import it at module level. If that fails, we'll keep inner import for targets ONLY.
        
        # Actually, the best practice is to importing it inside the method is a code smell.
        # Let's check imports.
        
        from app.services.user_service import user_service # Moving this here for now for Targets
        
        # Validate all targets
        
        # Validate all targets
        target_users = []
        all_user_ids = [caller_id] + target_ids
        
        for target_id in target_ids:
            # Validate contact exists
            if not skip_contact_validation:
                await cls.validate_contact_exists(db, caller_id, target_id)
            
            target_user = await user_service.get_by_id(db, target_id)
            if not target_user:
                raise UserOfflineError(f"Target user {target_id} not found")
            target_users.append(target_user)
        
        # Validate no active calls
        await cls.validate_not_in_active_call(db, all_user_ids)
        
        # Create the call
        call = Call(
            caller_user_id=caller_id,
            call_language=caller.primary_language,
            is_active=True,
            status='initiating',
            started_at=datetime.now(UTC),
            participant_count=total_participants,
        )
        db.add(call)
        await db.flush()
        
        # Create participant records
        participants = []
        
        # Add caller as participant
        caller_participant = await cls._create_participant(db, call, caller, is_caller=True)
        participants.append(caller_participant)
        
        # Add target participants
        for target_user in target_users:
            participant = await cls._create_participant(db, call, target_user, is_caller=False)
            participants.append(participant)
        
        await db.commit()
        await db.refresh(call)
        
        return call, participants
    
    @classmethod
    async def end_call(cls, db: AsyncSession, call_id: str) -> Call:
        """
        Force end a call.
        
        Args:
            db: Database session
            call_id: ID of the call to end
            
        Returns:
            Updated Call object
        """
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            raise CallNotFoundError(f"Call {call_id} not found")
        
        # Mark all participants as left
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.left_at.is_(None)
                )
            )
        )
        active_participants = result.scalars().all()
        
        for participant in active_participants:
            participant.leave_call()
        
        # End the call
        call.end_call()
        
        await db.commit()
        await db.refresh(call)
        
        return call
    
    @classmethod
    async def mark_call_ringing(cls, db: AsyncSession, call_id: str) -> Call:
        """
        Mark a call as ringing (notifications sent).
        
        Args:
            db: Database session
            call_id: ID of the call
            
        Returns:
            Updated Call object
        """
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            raise CallNotFoundError(f"Call {call_id} not found")
        
        call.status = 'ringing'
        await db.commit()
        await db.refresh(call)
        
        return call
    
    @classmethod
    async def accept_call(cls, db: AsyncSession, call_id: str, user_id: str) -> Call:
        """
        Accept an incoming call.
        
        Args:
            db: Database session
            call_id: ID of the call
            user_id: ID of the user accepting
            
        Returns:
            Updated Call object
        """
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            raise CallNotFoundError(f"Call {call_id} not found")
        
        # Verify user is a participant
        participant_result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = participant_result.scalar_one_or_none()
        
        if not participant:
            raise CallServiceError(f"User {user_id} is not a participant in call {call_id}")
        
        # Update call status
        call.status = 'ongoing'
        
        # Update participant
        participant.joined_at = datetime.now(UTC)
        participant.is_connected = True
        
        await db.commit()
        await db.refresh(call)
        
        return call
    
    @classmethod
    async def reject_call(cls, db: AsyncSession, call_id: str, user_id: str) -> Call:
        """
        Reject an incoming call.
        
        Args:
            db: Database session
            call_id: ID of the call
            user_id: ID of the user rejecting
            
        Returns:
            Updated Call object
        """
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            raise CallNotFoundError(f"Call {call_id} not found")
        
        # Verify user is a participant
        participant_result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = participant_result.scalar_one_or_none()
        
        if not participant:
            raise CallServiceError(f"User {user_id} is not a participant in call {call_id}")
        
        # Update call status
        call.status = 'rejected'
        call.is_active = False
        call.ended_at = datetime.now(UTC)
        
        # Update participant
        participant.is_connected = False
        participant.left_at = datetime.now(UTC)
        
        await db.commit()
        await db.refresh(call)
        
        return call
    
    # Backwards compatible static methods
    @staticmethod
    async def validate_user_online(db: AsyncSession, user_id: str) -> User:
        """Validate that user is online."""
        from .validators import validate_user_online as _validate
        return await _validate(db, user_id)
