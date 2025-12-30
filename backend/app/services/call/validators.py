"""
Call Validators

Validation methods for call operations:
- Contact relationship validation
- Online status validation
- Active call detection
"""
from typing import List

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.contact import Contact
from app.models.call import Call
from app.models.call_participant import CallParticipant
from .exceptions import ContactNotAuthorizedError, UserOfflineError, AlreadyInCallError


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
    from app.services.user_service import user_service
    user = await user_service.get_by_id(db, user_id)
    
    if not user:
        raise UserOfflineError(f"User {user_id} not found")
    
    if not user.is_online:
        raise UserOfflineError(f"User {user_id} is offline")
    
    return user


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
