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


@router.get("/contacts", response_model=ContactsListResponse)
async def list_contacts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all contacts for current user."""
    result = await db.execute(
        select(Contact).where(Contact.user_id == current_user.id)
    )
    contacts = result.scalars().all()
    
    # Join user info for each contact
    contact_list = []
    for c in contacts:
        user_result = await db.execute(
            select(User).where(User.id == c.contact_user_id)
        )
        user = user_result.scalar_one_or_none()
        if not user:
            continue
        
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
    
    return ContactsListResponse(contacts=contact_list)


@router.post("/contacts/add", response_model=AddContactResponse, status_code=201)
async def add_contact_by_body(
    req: AddContactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a contact (JSON body)."""
    return await _add_contact(
        db, current_user, req.contact_user_id, req.contact_name
    )


@router.post("/contacts/add/{contact_user_id}", response_model=AddContactResponse, status_code=201)
async def add_contact_by_path(
    contact_user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Add a contact (path parameter)."""
    return await _add_contact(db, current_user, contact_user_id, None)


async def _add_contact(
    db: AsyncSession,
    current_user: User,
    contact_user_id: str,
    contact_name: Optional[str]
) -> AddContactResponse:
    """Internal helper to add a contact."""
    # Check the contact user exists
    result = await db.execute(select(User).where(User.id == contact_user_id))
    contact_user = result.scalar_one_or_none()
    if not contact_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Prevent adding self
    if contact_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself as a contact")
    
    # Check duplicate
    result = await db.execute(
        select(Contact).where(
            Contact.user_id == current_user.id,
            Contact.contact_user_id == contact_user_id
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Contact already exists")
    
    # Create contact
    contact = Contact(
        user_id=current_user.id,
        contact_user_id=contact_user_id,
        contact_name=contact_name,
    )
    db.add(contact)
    await db.commit()
    await db.refresh(contact)
    
    return AddContactResponse(contact_id=contact.id, message="Contact added successfully")


@router.delete("/contacts/{contact_id}", status_code=204)
async def delete_contact(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a contact."""
    result = await db.execute(
        select(Contact).where(
            Contact.id == contact_id,
            Contact.user_id == current_user.id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    await db.delete(contact)
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
