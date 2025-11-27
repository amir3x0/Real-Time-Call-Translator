import asyncio
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.models.database import Base, get_db
from app.models.user import User


@pytest.fixture
async def async_db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async def _get_test_db():
        async with AsyncSessionLocal() as session:
            yield session

    app.dependency_overrides[get_db] = _get_test_db
    yield
    app.dependency_overrides.clear()


def test_register_and_login(async_db):
    client = TestClient(app)

    # Register
    payload = {
        "phone": "052-111-2222",
        "full_name": "Test User",
        "password": "password123",
        "primary_language": "he",
    }
    r = client.post("/api/auth/register", json=payload)
    assert r.status_code == 201
    data = r.json()
    assert "user_id" in data
    assert "token" in data

    # Login
    r2 = client.post("/api/auth/login", json={"phone": payload["phone"], "password": payload["password"]})
    assert r2.status_code == 200
    data2 = r2.json()
    assert data2["full_name"] == "Test User"

    # Me
    token = data2["token"]
    headers = {"Authorization": f"Bearer {token}"}
    r3 = client.get("/api/auth/me", headers=headers)
    assert r3.status_code == 200
    me = r3.json()
    assert me["phone"] == payload["phone"]
    assert me["full_name"] == payload["full_name"]
