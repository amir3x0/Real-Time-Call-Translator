"""
Contacts API - Manage user contacts

Endpoints for:
- Searching users
- Adding/removing contacts
- Listing contacts
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.database import get_db
from app.models.user import User
from app.models.contact import Contact
from app.api.auth import get_current_user

router = APIRouter()


# Response Models
class UserSearchResult(BaseModel):
    id: str
    full_name: str
    phone: Optional[str]
    primary_language: str
    is_online: bool


class UserSearchResponse(BaseModel):
    users: List[UserSearchResult]


class ContactResponse(BaseModel):
    id: str
    user_id: str
    contact_user_id: str
    contact_name: Optional[str] = None  # Nickname
    full_name: str
    phone: Optional[str] = None
    primary_language: str
    is_online: bool = False
    is_favorite: bool = False
    is_blocked: bool = False
    added_at: Optional[str] = None


class ContactsListResponse(BaseModel):
    contacts: List[ContactResponse]


class AddContactRequest(BaseModel):
    contact_user_id: str
    contact_name: Optional[str] = None


class AddContactResponse(BaseModel):
    contact_id: str
    message: str


# Endpoints

@router.get("/contacts/search", response_model=UserSearchResponse)
async def search_users(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Search for users by name or phone."""
    result = await db.execute(
        select(User).where(
            (User.full_name.ilike(f"%{q}%")) | (User.phone.ilike(f"%{q}%"))
        ).limit(20)
    )
    users = result.scalars().all()
    
    # Exclude current user
    filtered = [u for u in users if u.id != current_user.id]
    
    return UserSearchResponse(
        users=[
            UserSearchResult(
                id=u.id,
                full_name=u.full_name,
                phone=u.phone,
                primary_language=u.primary_language,
                is_online=u.is_online,
            )
            for u in filtered
        ]
    )


class ContactRequestResponse(BaseModel):
    contact_id: str
    requester: UserSearchResult
    added_at: str


class ContactsListResponse(BaseModel):
    contacts: List[ContactResponse]
    pending_incoming: List[ContactRequestResponse] = []
    pending_outgoing: List[ContactResponse] = []


@router.get("/contacts", response_model=ContactsListResponse)
async def list_contacts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all contacts and valid pending requests."""
    # 1. Accepted Contacts (My friends)
    result = await db.execute(
        select(Contact).where(
            Contact.user_id == current_user.id,
            Contact.status == 'accepted'
        )
    )
    contacts = result.scalars().all()
    
    contact_list = []
    for c in contacts:
        user_result = await db.execute(select(User).where(User.id == c.contact_user_id))
        user = user_result.scalar_one_or_none()
        if not user: continue
        
        contact_list.append(ContactResponse(
            id=c.id,
            user_id=c.user_id,
            contact_user_id=c.contact_user_id,
            contact_name=c.contact_name,
            full_name=user.full_name,
            phone=user.phone,
            primary_language=user.primary_language,
            is_online=user.is_online or False,
            is_favorite=c.is_favorite or False,
            is_blocked=c.is_blocked or False,
            added_at=c.added_at.isoformat() if c.added_at else None,
        ))

    # 2. Incoming Pending Requests (People who added me, but I haven't accepted)
    # They have a record: UserID=THEM, ContactUserID=ME, Status=Pending
    inc_result = await db.execute(
        select(Contact).where(
            Contact.contact_user_id == current_user.id,
            Contact.status == 'pending'
        )
    )
    incoming_requests = inc_result.scalars().all()
    
    incoming_list = []
    for c in incoming_requests:
        user_result = await db.execute(select(User).where(User.id == c.user_id)) # c.user_id is the requester
        user = user_result.scalar_one_or_none()
        if not user: continue
        
        incoming_list.append(ContactRequestResponse(
            contact_id=c.id,
            requester=UserSearchResult(
                id=user.id,
                full_name=user.full_name,
                phone=user.phone,
                primary_language=user.primary_language,
                is_online=user.is_online
            ),
            added_at=c.added_at.isoformat()
        ))

    # 3. Outgoing Pending Requests (I added them, they haven't accepted)
    out_result = await db.execute(
        select(Contact).where(
            Contact.user_id == current_user.id,
            Contact.status == 'pending'
        )
    )
    outgoing_requests = out_result.scalars().all()
    
    outgoing_list = []
    for c in outgoing_requests:
        user_result = await db.execute(select(User).where(User.id == c.contact_user_id))
        user = user_result.scalar_one_or_none()
        if not user: continue
        
        outgoing_list.append(ContactResponse(
            id=c.id,
            user_id=c.user_id,
            contact_user_id=c.contact_user_id,
            contact_name=c.contact_name,
            full_name=user.full_name,
            phone=user.phone,
            primary_language=user.primary_language,
            is_online=user.is_online or False,
            is_favorite=c.is_favorite or False,
            is_blocked=c.is_blocked or False,
            added_at=c.added_at.isoformat() if c.added_at else None,
        ))
    
    return ContactsListResponse(
        contacts=contact_list,
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
    return await _add_contact_request(
        db, current_user, req.contact_user_id, req.contact_name
    )


@router.post("/contacts/add/{contact_user_id}", response_model=AddContactResponse, status_code=201)
async def add_contact_by_path(
    contact_user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Send a Friend Request (path parameter)."""
    return await _add_contact_request(db, current_user, contact_user_id, None)


async def _add_contact_request(
    db: AsyncSession,
    current_user: User,
    contact_user_id: str,
    contact_name: Optional[str]
) -> AddContactResponse:
    """Internal helper to create a friend request."""
    # Check target exists
    result = await db.execute(select(User).where(User.id == contact_user_id))
    contact_user = result.scalar_one_or_none()
    if not contact_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if contact_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself")
    
    # Check if ANY relationship exists (pending or accepted) in EITHER direction
    # 1. Did I already add them?
    forward_check = await db.execute(
        select(Contact).where(
            Contact.user_id == current_user.id,
            Contact.contact_user_id == contact_user_id
        )
    )
    existing_forward = forward_check.scalar_one_or_none()
    
    # 2. Did they already add me?
    reverse_check = await db.execute(
        select(Contact).where(
            Contact.user_id == contact_user_id,
            Contact.contact_user_id == current_user.id
        )
    )
    existing_reverse = reverse_check.scalar_one_or_none()

    if existing_forward:
        if existing_forward.status == 'accepted':
            raise HTTPException(status_code=409, detail="Already in contacts")
        else:
            raise HTTPException(status_code=409, detail="Request already sent")
            
    if existing_reverse:
        if existing_reverse.status == 'accepted':
            # Create the missing forward link automatically if they are already my contact?
            # For now, just say "They are your contact"
            raise HTTPException(status_code=409, detail="User is already your contact (Friendship exists)")
        else:
            # They sent ME a request, so I should ACCEPT it instead of adding new
            # We can auto-accept here, or tell user to accept.
            # Let's guide them to accept.
            raise HTTPException(status_code=409, detail="They sent you a request! Please accept it.")

    # Create Pending Request
    contact = Contact(
        user_id=current_user.id,
        contact_user_id=contact_user_id,
        contact_name=contact_name,
        status='pending'
    )
    db.add(contact)
    await db.commit()
    await db.refresh(contact)
    
    # Notify target user
    from app.services.connection_manager import connection_manager
    await connection_manager.notify_contact_request(
        target_user_id=contact_user_id,
        requester_id=current_user.id,
        requester_name=current_user.full_name,
        request_id=contact.id
    )
    
    return AddContactResponse(contact_id=contact.id, message="Friend request sent")


@router.post("/contacts/{request_id}/accept", status_code=200)
async def accept_contact_request(
    request_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Accept a friend request. Creates mutual contact link."""
    # Find the request where I am the CONTACT_USER_ID
    # The ID passed is the 'Contact' table ID from the incoming request list.
    result = await db.execute(
        select(Contact).where(
            Contact.id == request_id, 
            Contact.contact_user_id == current_user.id,
            Contact.status == 'pending'
        )
    )
    incoming_request = result.scalar_one_or_none()
    
    if not incoming_request:
        raise HTTPException(status_code=404, detail="Friend request not found")
        
    requester_id = incoming_request.user_id
    
    # 1. Update status to accepted
    incoming_request.status = 'accepted'
    
    # 2. Create reverse link (Me -> Them) if not exists
    reverse_check = await db.execute(
        select(Contact).where(
            Contact.user_id == current_user.id,
            Contact.contact_user_id == requester_id
        )
    )
    existing_reverse = reverse_check.scalar_one_or_none()
    
    if not existing_reverse:
        reverse_contact = Contact(
            user_id=current_user.id,
            contact_user_id=requester_id,
            status='accepted'
        )
        db.add(reverse_contact)
    else:
        existing_reverse.status = 'accepted'
        
    await db.commit()
    return {"message": "Friend request accepted"}


@router.post("/contacts/{request_id}/reject", status_code=200)
async def reject_contact_request(
    request_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reject (delete) a friend request."""
    result = await db.execute(
        select(Contact).where(
            Contact.id == request_id,
            Contact.contact_user_id == current_user.id
        )
    )
    request = result.scalar_one_or_none()
    
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")
        
    await db.delete(request)
    await db.commit()
    return {"message": "Friend request rejected"}


@router.delete("/contacts/{contact_id}", status_code=204)
async def delete_contact(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a contact (Unfriend). Removes mutual link."""
    # Find the record
    result = await db.execute(
        select(Contact).where(
            Contact.id == contact_id,
            Contact.user_id == current_user.id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    other_user_id = contact.contact_user_id
    
    # Delete my record
    await db.delete(contact)
    
    # Delete reverse record (Them -> Me)
    reverse_result = await db.execute(
        select(Contact).where(
            Contact.user_id == other_user_id,
            Contact.contact_user_id == current_user.id
        )
    )
    reverse_contact = reverse_result.scalar_one_or_none()
    if reverse_contact:
        await db.delete(reverse_contact)
        
    await db.commit()
    return None


@router.patch("/contacts/{contact_id}/favorite")
async def toggle_favorite(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle favorite status for a contact."""
    result = await db.execute(
        select(Contact).where(
            Contact.id == contact_id,
            Contact.user_id == current_user.id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    contact.is_favorite = not contact.is_favorite
    await db.commit()
    
    return {"is_favorite": contact.is_favorite}


@router.patch("/contacts/{contact_id}/block")
async def toggle_block(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Toggle block status for a contact."""
    result = await db.execute(
        select(Contact).where(
            Contact.id == contact_id,
            Contact.user_id == current_user.id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    contact.is_blocked = not contact.is_blocked
    await db.commit()
    
    return {"is_blocked": contact.is_blocked}
