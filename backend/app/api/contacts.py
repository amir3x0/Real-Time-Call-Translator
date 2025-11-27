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


class UserSearchResult(BaseModel):
    id: str
    full_name: str
    phone: str
    primary_language: str


class UserSearchResponse(BaseModel):
    results: List[UserSearchResult]


class AddContactRequest(BaseModel):
    contact_user_id: str


class AddContactResponse(BaseModel):
    contact_id: str
    message: str


class ContactResponse(BaseModel):
    id: str
    user_id: str
    full_name: str
    phone: str
    primary_language: str
    added_at: str


class ContactsListResponse(BaseModel):
    contacts: List[ContactResponse]


@router.get("/users/search", response_model=UserSearchResponse)
async def search_users(query: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    q = await db.execute(
        select(User).where(
            (User.full_name.ilike(f"%{query}%")) | (User.phone.ilike(f"%{query}%"))
        ).limit(20)
    )
    results = q.scalars().all()
    # Exclude current user
    filtered = [u for u in results if u.id != current_user.id]
    mapped = [UserSearchResult(id=u.id, full_name=u.full_name, phone=u.phone, primary_language=u.primary_language) for u in filtered]
    return UserSearchResponse(results=mapped)


@router.post("/contacts/add", response_model=AddContactResponse)
async def add_contact(req: AddContactRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Check the contact exists
    q = await db.execute(select(User).where(User.id == req.contact_user_id))
    contact_user = q.scalar_one_or_none()
    if not contact_user:
        raise HTTPException(status_code=404, detail="User to add not found")
    # Prevent adding self
    if contact_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot add yourself as a contact")
    # Check duplicate
    q2 = await db.execute(select(Contact).where(Contact.user_id == current_user.id, Contact.contact_user_id == contact_user.id))
    existing = q2.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Contact already added")
    # Create contact
    contact = Contact(user_id=current_user.id, contact_user_id=contact_user.id)
    db.add(contact)
    await db.commit()
    await db.refresh(contact)
    return AddContactResponse(contact_id=contact.id, message="Contact added")


@router.get("/contacts", response_model=ContactsListResponse)
async def list_contacts(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    q = await db.execute(select(Contact).where(Contact.user_id == current_user.id))
    contacts = q.scalars().all()
    # Join user info for each contact
    results = []
    for c in contacts:
        q2 = await db.execute(select(User).where(User.id == c.contact_user_id))
        u = q2.scalar_one_or_none()
        if not u:
            continue
        results.append(ContactResponse(
            id=c.id,
            user_id=c.contact_user_id,
            full_name=u.full_name,
            phone=u.phone,
            primary_language=u.primary_language,
            added_at=c.created_at.isoformat() if c.created_at else None,
        ))
    return ContactsListResponse(contacts=results)


@router.delete("/contacts/{contact_id}", status_code=204)
async def delete_contact(contact_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    q = await db.execute(select(Contact).where(Contact.id == contact_id, Contact.user_id == current_user.id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404, detail="Contact not found")
    await db.delete(c)
    await db.commit()
    return None
