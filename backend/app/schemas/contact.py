from typing import List, Optional
from pydantic import BaseModel


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


class AddContactRequest(BaseModel):
    contact_user_id: str
    contact_name: Optional[str] = None


class AddContactResponse(BaseModel):
    contact_id: str
    message: str


class ContactRequestResponse(BaseModel):
    contact_id: str
    requester: UserSearchResult
    added_at: str


class ContactsListResponse(BaseModel):
    contacts: List[ContactResponse]
    pending_incoming: List[ContactRequestResponse] = []
    pending_outgoing: List[ContactResponse] = []
