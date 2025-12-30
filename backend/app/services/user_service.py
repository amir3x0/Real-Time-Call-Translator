from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.user import User


class UserService:
    """
    Service for centralized User retrieval and management.
    Eliminates duplicated select(User) queries across the app.
    """
    
    @staticmethod
    async def get_by_id(db: AsyncSession, user_id: str) -> Optional[User]:
        """
        Get user by ID.
        Returns None if not found (caller handles 404).
        """
        result = await db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()
    
    @staticmethod
    async def get_by_phone(db: AsyncSession, phone: str) -> Optional[User]:
        """
        Get user by phone number.
        """
        result = await db.execute(select(User).where(User.phone == phone))
        return result.scalar_one_or_none()

    @staticmethod
    async def get_or_fail(db: AsyncSession, user_id: str, error_message: str = "User not found") -> User:
        """
        Get user or raise generic Exception (to be caught/wrapped by caller).
        Useful when existence is mandatory.
        NOTE: Ideally calls should raise specific ServiceErrors or return None.
        Here we return raw User, caller decides on HTTP Exception.
        """
        user = await UserService.get_by_id(db, user_id)
        if not user:
            # We avoid raising HTTPException here to keep service layer clean of HTTP concerns.
            # But for quick refactoring, returning None is safer.
            return None
        return user

    @staticmethod
    async def search(db: AsyncSession, query: str, limit: int = 20, exclude_ids: list[str] = None) -> list[User]:
        """
        Search users by name or phone.
        Optional: exclude_ids list to filter out users (e.g. self).
        """
        stmt = select(User).where(
            (User.full_name.ilike(f"%{query}%")) | (User.phone.ilike(f"%{query}%"))
        )
        
        if exclude_ids:
            stmt = stmt.where(User.id.not_in(exclude_ids))
            
        result = await db.execute(stmt.limit(limit))
        return result.scalars().all()


user_service = UserService()
