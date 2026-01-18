"""
Contact Service - Manage user contacts & friend requests

Encapsulates logic for:
- Sending/Accepting/Rejecting friend requests
- Managing contact lists (blocking, favorites)
- Validating contact relationships
"""
from typing import List, Optional, Tuple, Dict, Any
from datetime import datetime, UTC
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_

from app.models.contact import Contact
from app.models.user import User
from app.services.user_service import user_service
from app.services.connection import connection_manager

# === Exceptions ===

class ContactError(Exception):
    """Base exception for contact operations."""
    pass

class ContactNotFoundError(ContactError):
    pass

class UserNotFoundError(ContactError):
    pass

class SelfAddError(ContactError):
    pass

class ContactAlreadyExistsError(ContactError):
    pass

class RequestAlreadySentError(ContactError):
    pass

class RequestNotFoundError(ContactError):
    pass


class ContactService:
    """Service for managing contacts and friend requests."""

    async def get_user_contacts(self, db: AsyncSession, user_id: str) -> Dict[str, List[Any]]:
        """
        Get all contacts for a user, categorized.
        Returns: {
            "contacts": [(Contact, User)...],
            "pending_incoming": [(Contact, User)...],
            "pending_outgoing": [(Contact, User)...]
        }
        """
        # 1. Accepted Contacts (My friends) - Join to get friend's details
        stmt = select(Contact, User).join(
            User, Contact.contact_user_id == User.id
        ).where(
            Contact.user_id == user_id,
            Contact.status == 'accepted'
        )
        result = await db.execute(stmt)
        contacts = result.all() # List of (Contact, User)
        
        # 2. Incoming Pending Requests (People who added me) - Join to get requester's details
        stmt_inc = select(Contact, User).join(
            User, Contact.user_id == User.id
        ).where(
            Contact.contact_user_id == user_id,
            Contact.status == 'pending'
        )
        inc_result = await db.execute(stmt_inc)
        incoming_requests = inc_result.all() # List of (Contact, User)
        
        # 3. Outgoing Pending Requests (I added them) - Join to get target's details
        stmt_out = select(Contact, User).join(
            User, Contact.contact_user_id == User.id
        ).where(
            Contact.user_id == user_id,
            Contact.status == 'pending'
        )
        out_result = await db.execute(stmt_out)
        outgoing_requests = out_result.all() # List of (Contact, User)
        
        return {
            "contacts": contacts,
            "pending_incoming": incoming_requests,
            "pending_outgoing": outgoing_requests
        }

    async def send_friend_request(
        self, 
        db: AsyncSession, 
        requester: User, 
        contact_user_id: str, 
        contact_name: Optional[str] = None
    ) -> Contact:
        """
        Send a friend request to a user.
        Raises specific exceptions for validation failures.
        """
        # Check target exists
        contact_user = await user_service.get_by_id(db, contact_user_id)
        if not contact_user:
            raise UserNotFoundError(f"User {contact_user_id} not found")
        
        if contact_user.id == requester.id:
            raise SelfAddError("Cannot add yourself")
        
        # Check existing relationships (forward and reverse)
        # 1. Did I already add them?
        forward_check = await db.execute(
            select(Contact).where(
                Contact.user_id == requester.id,
                Contact.contact_user_id == contact_user_id
            )
        )
        existing_forward = forward_check.scalar_one_or_none()
        
        # 2. Did they already add me?
        reverse_check = await db.execute(
            select(Contact).where(
                Contact.user_id == contact_user_id,
                Contact.contact_user_id == requester.id
            )
        )
        existing_reverse = reverse_check.scalar_one_or_none()

        if existing_forward:
            if existing_forward.status == 'accepted':
                raise ContactAlreadyExistsError("Already in contacts")
            else:
                raise RequestAlreadySentError("Request already sent")
                
        if existing_reverse:
            if existing_reverse.status == 'accepted':
                raise ContactAlreadyExistsError("User is already your contact (Friendship exists)")
            else:
                # They sent request, guide to accept
                raise ContactAlreadyExistsError("They sent you a request! Please accept it.")

        # Create Pending Request
        contact = Contact(
            user_id=requester.id,
            contact_user_id=contact_user_id,
            contact_name=contact_name,
            status='pending'
        )
        db.add(contact)
        await db.flush()
        
        # Notify target user via WebSocket
        await connection_manager.notify_contact_request(
            target_user_id=contact_user_id,
            requester_id=requester.id,
            requester_name=requester.full_name,
            request_id=contact.id
        )
        
        return contact

    async def accept_request(self, db: AsyncSession, request_id: str, current_user_id: str) -> None:
        """
        Accept a friend request.
        """
        # Find the request where I am the CONTACT_USER_ID
        result = await db.execute(
            select(Contact).where(
                Contact.id == request_id, 
                Contact.contact_user_id == current_user_id,
                Contact.status == 'pending'
            )
        )
        incoming_request = result.scalar_one_or_none()
        
        if not incoming_request:
            raise RequestNotFoundError("Friend request not found")
            
        requester_id = incoming_request.user_id
        
        # 1. Update status to accepted
        incoming_request.status = 'accepted'
        
        # 2. Create reverse link (Me -> Them) if not exists
        reverse_check = await db.execute(
            select(Contact).where(
                Contact.user_id == current_user_id,
                Contact.contact_user_id == requester_id
            )
        )
        existing_reverse = reverse_check.scalar_one_or_none()
        
        if not existing_reverse:
            reverse_contact = Contact(
                user_id=current_user_id,
                contact_user_id=requester_id,
                status='accepted'
            )
            db.add(reverse_contact)
        else:
            existing_reverse.status = 'accepted'

    async def reject_request(self, db: AsyncSession, request_id: str, current_user_id: str) -> None:
        """
        Reject (delete) a friend request.
        """
        result = await db.execute(
            select(Contact).where(
                Contact.id == request_id,
                Contact.contact_user_id == current_user_id
            )
        )
        request = result.scalar_one_or_none()
        
        if not request:
            raise RequestNotFoundError("Request not found")
            
        await db.delete(request)

    async def remove_contact(self, db: AsyncSession, contact_id: str, current_user_id: str) -> None:
        """
        Remove a contact (unfriend). Deletes both directions.
        """
        # Find the record
        result = await db.execute(
            select(Contact).where(
                Contact.id == contact_id,
                Contact.user_id == current_user_id
            )
        )
        contact = result.scalar_one_or_none()
        if not contact:
            raise ContactNotFoundError("Contact not found")
        
        other_user_id = contact.contact_user_id
        
        # Delete my record
        await db.delete(contact)
        
        # Delete reverse record (Them -> Me)
        reverse_result = await db.execute(
            select(Contact).where(
                Contact.user_id == other_user_id,
                Contact.contact_user_id == current_user_id
            )
        )
        reverse_contact = reverse_result.scalar_one_or_none()
        if reverse_contact:
            await db.delete(reverse_contact)

    async def toggle_favorite(self, db: AsyncSession, contact_id: str, current_user_id: str) -> bool:
        """Toggle favorite status. Returns new status."""
        result = await db.execute(
            select(Contact).where(
                Contact.id == contact_id,
                Contact.user_id == current_user_id
            )
        )
        contact = result.scalar_one_or_none()
        if not contact:
            raise ContactNotFoundError("Contact not found")
        
        contact.is_favorite = not contact.is_favorite
        return contact.is_favorite

    async def toggle_block(self, db: AsyncSession, contact_id: str, current_user_id: str) -> bool:
        """Toggle block status. Returns new status."""
        result = await db.execute(
            select(Contact).where(
                Contact.id == contact_id,
                Contact.user_id == current_user_id
            )
        )
        contact = result.scalar_one_or_none()
        if not contact:
            raise ContactNotFoundError("Contact not found")
        
        contact.is_blocked = not contact.is_blocked
        return contact.is_blocked


# Singleton
contact_service = ContactService()
