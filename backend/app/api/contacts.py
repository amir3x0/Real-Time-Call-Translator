"""
Contacts API - Manage user contacts

Endpoints for:
- Searching users
- Adding/removing contacts
- Listing contacts
"""
from typing import List, Optional, Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.database import get_db
from app.models.user import User
from app.models.contact import Contact
from app.api.auth import get_current_user
from app.services.user_service import user_service
from app.services.contact_service import (
    contact_service,
    ContactNotFoundError,
    UserNotFoundError,
    SelfAddError,
    ContactAlreadyExistsError,
    RequestAlreadySentError,
    RequestNotFoundError
)
from app.schemas.contact import (
    UserSearchResult,
    UserSearchResponse,
    ContactResponse,
    ContactsListResponse,
    AddContactRequest,
    AddContactResponse,
    ContactRequestResponse,
)

router = APIRouter()


@router.get("/contacts/search", response_model=UserSearchResponse)
async def search_users(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Search for users by name or phone."""
    users = await user_service.search(db, q, limit=20, exclude_ids=[current_user.id])
    
    return UserSearchResponse(
        users=[
            UserSearchResult(
                id=u.id,
                full_name=u.full_name,
                phone=u.phone,
                primary_language=u.primary_language,
                is_online=u.is_online,
            )
            for u in users
        ]
    )


@router.get("/contacts", response_model=ContactsListResponse)
async def list_contacts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all contacts and valid pending requests."""
    categorized = await contact_service.get_user_contacts(db, current_user.id)
    
    # Helper to format contact response
    # Now takes (Contact, User) tuple, no DB query needed!
    def format_contact_tuple(contact: Contact, user: User) -> ContactResponse:
        return ContactResponse(
            id=contact.id,
            user_id=contact.user_id,
            contact_user_id=contact.contact_user_id,
            contact_name=contact.contact_name,
            full_name=user.full_name,
            phone=user.phone,
            primary_language=user.primary_language,
            is_online=user.is_online or False,
            is_favorite=contact.is_favorite or False,
            is_blocked=contact.is_blocked or False,
            added_at=contact.added_at.isoformat() if contact.added_at else None,
        )

    # Helper to format request response (Incoming)
    def format_request_incoming_tuple(contact: Contact, user: User) -> ContactRequestResponse:
        # User is the Requester
        return ContactRequestResponse(
            contact_id=contact.id,
            requester=UserSearchResult(
                id=user.id,
                full_name=user.full_name,
                phone=user.phone,
                primary_language=user.primary_language,
                is_online=user.is_online
            ),
            added_at=contact.added_at.isoformat()
        )

    # Build lists using the tuples directly
    contacts_list = [format_contact_tuple(c, u) for c, u in categorized["contacts"]]
    incoming_list = [format_request_incoming_tuple(c, u) for c, u in categorized["pending_incoming"]]
    outgoing_list = [format_contact_tuple(c, u) for c, u in categorized["pending_outgoing"]]
    
    return ContactsListResponse(
        contacts=contacts_list,
        pending_incoming=incoming_list,
        pending_outgoing=outgoing_list
    )


@router.post("/contacts/add", response_model=AddContactResponse, status_code=201)
async def add_contact_by_body(
    req: AddContactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send a Friend Request (Add contact as pending)."""
    response = await _handle_add_contact(db, current_user, req.contact_user_id, req.contact_name)
    await db.commit()
    return response


@router.post("/contacts/add/{contact_user_id}", response_model=AddContactResponse, status_code=201)
async def add_contact_by_path(
    contact_user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send a Friend Request (path parameter)."""
    response = await _handle_add_contact(db, current_user, contact_user_id, None)
    await db.commit()
    return response


async def _handle_add_contact(
    db: AsyncSession,
    current_user: User,
    contact_user_id: str,
    contact_name: Optional[str]
) -> AddContactResponse:
    try:
        contact = await contact_service.send_friend_request(
            db, current_user, contact_user_id, contact_name
        )
        return AddContactResponse(contact_id=contact.id, message="Friend request sent")
    except UserNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except SelfAddError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except (ContactAlreadyExistsError, RequestAlreadySentError) as e:
        raise HTTPException(status_code=409, detail=str(e))


@router.post("/contacts/{request_id}/accept", status_code=200)
async def accept_contact_request(
    request_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Accept a friend request. Creates mutual contact link."""
    try:
        await contact_service.accept_request(db, request_id, current_user.id)
        await db.commit()
        return {"message": "Friend request accepted"}
    except RequestNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/contacts/{request_id}/reject", status_code=200)
async def reject_contact_request(
    request_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reject (delete) a friend request."""
    try:
        await contact_service.reject_request(db, request_id, current_user.id)
        await db.commit()
        return {"message": "Friend request rejected"}
    except RequestNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/contacts/{contact_id}", status_code=204)
async def delete_contact(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a contact (Unfriend). Removes mutual link."""
    try:
        await contact_service.remove_contact(db, contact_id, current_user.id)
        await db.commit()
        return None
    except ContactNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/contacts/{contact_id}/favorite")
async def toggle_favorite(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle favorite status for a contact."""
    try:
        is_favorite = await contact_service.toggle_favorite(db, contact_id, current_user.id)
        await db.commit()
        return {"is_favorite": is_favorite}
    except ContactNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/contacts/{contact_id}/block")
async def toggle_block(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle block status for a contact."""
    try:
        is_blocked = await contact_service.toggle_block(db, contact_id, current_user.id)
        await db.commit()
        return {"is_blocked": is_blocked}
    except ContactNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
