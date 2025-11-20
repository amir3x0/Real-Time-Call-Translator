# backend/tests/test_user_model.py
import pytest
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.models import Base, User


@pytest.mark.asyncio
async def test_create_user():
    """Create an in-memory SQLite DB, create tables and insert a User."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with AsyncSessionLocal() as session:
        user = User(email="test@example.com", name="Test User", primary_language="he")
        session.add(user)
        await session.commit()
        assert user.email == "test@example.com"
        assert user.primary_language == "he"