"""
Contact Model - Contact List Management

Controls who each user can call (authorization layer).
"""
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, UniqueConstraint
from datetime import datetime, UTC
import uuid

from .database import Base


class Contact(Base):
    """Contact relationship between users"""
    __tablename__ = "contacts"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # User who owns this contact entry
    user_id = Column(String(36), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    
    # The user being added as a contact
    contact_user_id = Column(String(36), ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    
    # Custom nickname for the contact (optional)
    contact_name = Column(String(255), nullable=True)
    
    # Status
    is_blocked = Column(Boolean, default=False)
    is_favorite = Column(Boolean, default=False)
    
    # Friendship Status: 'pending', 'accepted'
    status = Column(String(20), default='accepted', nullable=False) # default='accepted' for backward compatibility
    
    # Timestamp
    added_at = Column(DateTime, default=lambda: datetime.now(UTC), nullable=False)
    
    # Constraints
    __table_args__ = (
        UniqueConstraint('user_id', 'contact_user_id', name='uq_user_contact'),
    )
    
    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "contact_user_id": self.contact_user_id,
            "contact_name": self.contact_name,
            "is_blocked": self.is_blocked,
            "is_favorite": self.is_favorite,
            "status": self.status,
            "added_at": self.added_at.isoformat() if self.added_at else None,
        }
