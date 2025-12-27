"""
Call Management Service

This service handles all call-related business logic including:
- Call initiation with validation
- Participant setup with dubbing requirements
- Call termination logic
- Call history retrieval
"""
from datetime import datetime
from typing import List, Dict, Optional, Tuple
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
import logging

from app.models.user import User
from app.models.contact import Contact
from app.models.call import Call
from app.models.call_participant import CallParticipant
from app.models.call_transcript import CallTranscript

logger = logging.getLogger(__name__)


class CallServiceError(Exception):
    """Base exception for call service errors"""
    pass


class ContactNotAuthorizedError(CallServiceError):
    """Raised when user tries to call someone not in contacts"""
    pass


class UserOfflineError(CallServiceError):
    """Raised when target user is offline"""
    pass


class AlreadyInCallError(CallServiceError):
    """Raised when user is already in an active call"""
    pass


class CallNotFoundError(CallServiceError):
    """Raised when call is not found"""
    pass


class InvalidParticipantCountError(CallServiceError):
    """Raised when participant count is invalid (must be 2-4)"""
    pass


class CallService:
    """Service for managing calls and call participants"""
    
    # Participant limits
    MIN_PARTICIPANTS = 2
    MAX_PARTICIPANTS = 4
    
    @staticmethod
    async def validate_contact_exists(
        db: AsyncSession,
        caller_id: str,
        target_id: str
    ) -> bool:
        """
        Validate that target is in caller's contacts.
        
        Args:
            db: Database session
            caller_id: ID of the caller
            target_id: ID of the target user
            
        Returns:
            True if contact exists
            
        Raises:
            ContactNotAuthorizedError if contact doesn't exist
        """
        result = await db.execute(
            select(Contact).where(
                and_(
                    Contact.user_id == caller_id,
                    Contact.contact_user_id == target_id,
                    Contact.is_blocked == False
                )
            )
        )
        contact = result.scalar_one_or_none()
        
        if not contact:
            raise ContactNotAuthorizedError(f"User {target_id} not in contacts")
        
        return True
    
    @staticmethod
    async def validate_user_online(
        db: AsyncSession,
        user_id: str
    ) -> User:
        """
        Validate that user is online.
        
        Args:
            db: Database session
            user_id: ID of the user to check
            
        Returns:
            User object if online
            
        Raises:
            UserOfflineError if user is offline
        """
        result = await db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        
        if not user:
            raise UserOfflineError(f"User {user_id} not found")
        
        if not user.is_online:
            raise UserOfflineError(f"User {user_id} is offline")
        
        return user
    
    @staticmethod
    async def validate_not_in_active_call(
        db: AsyncSession,
        user_ids: List[str]
    ) -> bool:
        """
        Validate that none of the users are in an active call.
        
        Args:
            db: Database session
            user_ids: List of user IDs to check
            
        Returns:
            True if no users are in active calls
            
        Raises:
            AlreadyInCallError if any user is in an active call
        """
        # Find active call participants
        result = await db.execute(
            select(CallParticipant).join(Call).where(
                and_(
                    Call.is_active == True,
                    CallParticipant.user_id.in_(user_ids),
                    CallParticipant.left_at.is_(None)
                )
            )
        )
        active_participants = result.scalars().all()
        
        if active_participants:
            user_in_call = active_participants[0].user_id
            raise AlreadyInCallError(f"User {user_in_call} is already in an active call")
        
        return True
    
    @classmethod
    async def initiate_call(
        cls,
        db: AsyncSession,
        caller_id: str,
        target_ids: List[str],
        skip_contact_validation: bool = False
    ) -> Tuple[Call, List[CallParticipant]]:
        """
        Initiate a call between users.
        
        This implements the full call initiation workflow:
        1. Validate contact relationships
        2. Validate users are online
        3. Validate no active calls
        4. Create call with caller's language
        5. Create participants with dubbing requirements
        
        Args:
            db: Database session
            caller_id: ID of the user initiating the call
            target_ids: List of target user IDs
            skip_contact_validation: Skip contact check (for testing)
            
        Returns:
            Tuple of (Call, List[CallParticipant])
            
        Raises:
            InvalidParticipantCountError: If participant count invalid
            ContactNotAuthorizedError: If target not in contacts
            UserOfflineError: If target is offline
            AlreadyInCallError: If any user in active call
        """
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
        
        # Get caller info
        result = await db.execute(select(User).where(User.id == caller_id))
        caller = result.scalar_one_or_none()
        if not caller:
            raise UserOfflineError(f"Caller {caller_id} not found")
        
        # Validate all targets
        target_users = []
        all_user_ids = [caller_id] + target_ids
        
        for target_id in target_ids:
            # Validate contact exists
            if not skip_contact_validation:
                await cls.validate_contact_exists(db, caller_id, target_id)
            
            # Validate user is online (optional - can be relaxed for ringing)
            # target_user = await cls.validate_user_online(db, target_id)
            result = await db.execute(select(User).where(User.id == target_id))
            target_user = result.scalar_one_or_none()
            if not target_user:
                raise UserOfflineError(f"Target user {target_id} not found")
            target_users.append(target_user)
        
        # Validate no active calls
        await cls.validate_not_in_active_call(db, all_user_ids)
        
        # Create the call
        call = Call(
            caller_user_id=caller_id,
            call_language=caller.primary_language,  # IMMUTABLE
            is_active=True,
            status='initiating',  # Will change to 'ringing' when notifications sent
            started_at=datetime.utcnow(),
            participant_count=total_participants,
        )
        db.add(call)
        await db.flush()  # Get call.id
        
        # Create participant records
        participants = []
        
        # Add caller as participant
        caller_participant = await cls._create_participant(
            db, call, caller, is_caller=True
        )
        participants.append(caller_participant)
        
        # Add target participants
        for target_user in target_users:
            participant = await cls._create_participant(
                db, call, target_user, is_caller=False
            )
            participants.append(participant)
        
        await db.commit()
        await db.refresh(call)
        
        return call, participants
    
    @staticmethod
    async def _create_participant(
        db: AsyncSession,
        call: Call,
        user: User,
        is_caller: bool
    ) -> CallParticipant:
        """
        Create a call participant with proper dubbing and voice clone settings.
        
        Args:
            db: Database session
            call: Call object
            user: User object
            is_caller: Whether this is the call initiator
        """
        participant = CallParticipant(
            call_id=call.id,
            user_id=user.id,
            participant_language=user.primary_language,
            joined_at=datetime.utcnow() if is_caller else None,
            is_connected=is_caller,
        )
        
        # Set dubbing requirement based on language match
        try:
            participant.determine_dubbing_required(call.call_language)
            participant.set_voice_clone_quality(user.voice_quality_score)
        except AttributeError as e:
            logger.error(f"Error setting participant properties: {e}")
            # Set defaults
            participant.dubbing_required = (participant.participant_language != call.call_language)
            participant.voice_clone_quality = 'fallback'
            participant.use_voice_clone = False
        
        db.add(participant)
        await db.flush()
        
        return participant
    
    @classmethod
    async def handle_participant_joined(
        cls,
        db: AsyncSession,
        call_id: str,
        user_id: str
    ) -> CallParticipant:
        """
        Handle a participant joining an existing call.
        
        Args:
            db: Database session
            call_id: ID of the call
            user_id: ID of the user joining
            
        Returns:
            Updated CallParticipant
        """
        # Get participant record
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            raise CallNotFoundError(f"Participant {user_id} not found in call {call_id}")
        
        # Update participant status
        participant.joined_at = datetime.utcnow()
        participant.is_connected = True
        participant.left_at = None
        
        # Update call participant count
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        if call:
            call.participant_count += 1
            if call.status != 'ongoing':
                call.status = 'ongoing'
        
        await db.commit()
        await db.refresh(participant)
        
        return participant
    
    @classmethod
    async def handle_participant_left(
        cls,
        db: AsyncSession,
        call_id: str,
        user_id: str
    ) -> Tuple[bool, Optional[Call]]:
        """
        Handle a participant leaving a call.
        
        Args:
            db: Database session
            call_id: ID of the call
            user_id: ID of the user leaving
            
        Returns:
            Tuple of (call_ended: bool, call: Optional[Call])
        """
        # Mark participant as left
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.user_id == user_id
                )
            )
        )
        participant = result.scalar_one_or_none()
        
        if not participant:
            return False, None
        
        participant.leave_call()
        
        # Count active participants
        result = await db.execute(
            select(CallParticipant).where(
                and_(
                    CallParticipant.call_id == call_id,
                    CallParticipant.left_at.is_(None)
                )
            )
        )
        active_participants = result.scalars().all()
        active_count = len(active_participants)
        
        # Get call
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            return False, None
        
        call.participant_count = active_count
        
        # Check if call should end (fewer than 2 participants)
        if active_count < cls.MIN_PARTICIPANTS:
            call.end_call()
            await db.commit()
            return True, call
        
        await db.commit()
        await db.commit()
        return False, call

    @classmethod
    async def force_leave_all_calls(
        cls,
        db: AsyncSession,
        user_id: str
    ) -> List[str]:
        """
        Force user to leave all active calls.
        
        Args:
            db: Database session
            user_id: ID of the user
            
        Returns:
            List of call IDs left
        """
        # Find all active participations
        result = await db.execute(
            select(CallParticipant).join(Call).where(
                and_(
                    Call.is_active == True,
                    CallParticipant.user_id == user_id,
                    CallParticipant.left_at.is_(None)
                )
            )
        )
        active_participants = result.scalars().all()
        
        call_ids = []
        for participant in active_participants:
            call_id = participant.call_id
            call_ids.append(call_id)
            
            # Use handle_participant_left logic
            await cls.handle_participant_left(db, call_id, user_id)
            
        return call_ids
    
    @classmethod
    async def end_call(
        cls,
        db: AsyncSession,
        call_id: str
    ) -> Call:
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
    async def get_call_with_participants(
        cls,
        db: AsyncSession,
        call_id: str
    ) -> Tuple[Optional[Call], List[CallParticipant]]:
        """
        Get call with all participants.
        
        Args:
            db: Database session
            call_id: ID of the call
            
        Returns:
            Tuple of (Call, List[CallParticipant])
        """
        result = await db.execute(select(Call).where(Call.id == call_id))
        call = result.scalar_one_or_none()
        
        if not call:
            return None, []
        
        result = await db.execute(
            select(CallParticipant).where(CallParticipant.call_id == call_id)
        )
        participants = result.scalars().all()
        
        return call, list(participants)
    
    @classmethod
    async def get_user_call_history(
        cls,
        db: AsyncSession,
        user_id: str,
        limit: int = 20
    ) -> List[Dict]:
        """
        Get user's recent call history with transcripts.
        
        Args:
            db: Database session
            user_id: ID of the user
            limit: Maximum number of calls to return
            
        Returns:
            List of call history dictionaries
        """
        # Get calls where user was a participant
        result = await db.execute(
            select(Call).join(CallParticipant).where(
                CallParticipant.user_id == user_id
            ).order_by(Call.started_at.desc()).limit(limit)
        )
        calls = result.scalars().all()
        
        history = []
        
        for call in calls:
            # Get participants
            result = await db.execute(
                select(CallParticipant).where(CallParticipant.call_id == call.id)
            )
            participants = result.scalars().all()
            
            # Get transcripts
            result = await db.execute(
                select(CallTranscript).where(
                    CallTranscript.call_id == call.id
                ).order_by(CallTranscript.timestamp_ms)
            )
            transcripts = result.scalars().all()
            
            # Get participant user info
            participant_info = []
            for p in participants:
                result = await db.execute(select(User).where(User.id == p.user_id))
                user = result.scalar_one_or_none()
                if user:
                    participant_info.append({
                        "user_id": user.id,
                        "full_name": user.full_name,
                        "primary_language": user.primary_language,
                        "dubbing_required": p.dubbing_required,
                    })
            
            call_data = {
                "call_id": call.id,
                "session_id": call.session_id,
                "initiated_at": call.started_at.isoformat() if call.started_at else None,
                "ended_at": call.ended_at.isoformat() if call.ended_at else None,
                "duration_seconds": call.duration_seconds,
                "language": call.call_language,
                "status": call.status.value if call.status else None,
                "participants": participant_info,
                "transcript": [t.to_timeline_dict() for t in transcripts],
            }
            
            history.append(call_data)
        
        return history
    
    @classmethod
    async def add_transcript(
        cls,
        db: AsyncSession,
        call_id: str,
        speaker_user_id: str,
        original_language: str,
        original_text: str,
        timestamp_ms: int,
        translated_text: str = None,
        target_language: str = None,
        tts_method: str = None,
        processing_time_ms: int = None
    ) -> CallTranscript:
        """
        Add a transcript entry to a call.
        
        Args:
            db: Database session
            call_id: ID of the call
            speaker_user_id: ID of the speaker
            original_language: Language of original speech
            original_text: Transcribed text
            timestamp_ms: Timestamp in milliseconds from call start
            translated_text: Translated text (if any)
            target_language: Target language for translation
            tts_method: TTS method used
            processing_time_ms: Processing time
            
        Returns:
            Created CallTranscript
        """
        transcript = CallTranscript.create_transcript(
            call_id=call_id,
            speaker_user_id=speaker_user_id,
            original_language=original_language,
            original_text=original_text,
            timestamp_ms=timestamp_ms,
            translated_text=translated_text,
            target_language=target_language,
            tts_method=tts_method,
            processing_time_ms=processing_time_ms,
        )
        
        db.add(transcript)
        await db.commit()
        await db.refresh(transcript)
        
        return transcript
    
    @classmethod
    async def mark_call_ringing(
        cls,
        db: AsyncSession,
        call_id: str
    ) -> Call:
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
    async def accept_call(
        cls,
        db: AsyncSession,
        call_id: str,
        user_id: str
    ) -> Call:
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
        participant.joined_at = datetime.utcnow()
        participant.is_connected = True
        
        await db.commit()
        await db.refresh(call)
        
        return call
    
    @classmethod
    async def reject_call(
        cls,
        db: AsyncSession,
        call_id: str,
        user_id: str
    ) -> Call:
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
        call.ended_at = datetime.utcnow()
        
        # Update participant
        participant.is_connected = False
        participant.left_at = datetime.utcnow()
        
        await db.commit()
        await db.refresh(call)
        
        return call
    
    @classmethod
    async def get_pending_calls(
        cls,
        db: AsyncSession,
        user_id: str
    ) -> List[Call]:
        """
        Get all pending incoming calls for a user.
        
        Returns calls where:
        - status is 'ringing' or 'initiating'
        - user is a participant but not the caller
        - call was created in last 30 seconds
        
        Args:
            db: Database session
            user_id: ID of the user
            
        Returns:
            List of pending Call objects
        """
        from datetime import timedelta
        
        cutoff_time = datetime.utcnow() - timedelta(seconds=30)
        
        # Get all calls where user is a participant
        result = await db.execute(
            select(Call)
            .join(CallParticipant, Call.id == CallParticipant.call_id)
            .where(
                and_(
                    CallParticipant.user_id == user_id,
                    Call.caller_user_id != user_id,  # Not the caller
                    Call.status.in_(['ringing', 'initiating']),
                    Call.created_at >= cutoff_time
                )
            )
            .order_by(Call.created_at.desc())
        )
        
        return list(result.scalars().all())


# Singleton instance
call_service = CallService()

