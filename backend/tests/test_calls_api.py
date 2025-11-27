import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.models.database import Base, get_db


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


def test_start_call(async_db):
    client = TestClient(app)

    # Register three users
    r1 = client.post("/api/auth/register", json={"phone":"052-111-1111","full_name":"Caller","password":"pass123","primary_language":"en"})
    assert r1.status_code == 201
    token1 = r1.json()['token']
    caller_id = r1.json()['user_id']

    r2 = client.post("/api/auth/register", json={"phone":"052-222-2222","full_name":"User2","password":"pass123","primary_language":"en"})
    assert r2.status_code == 201
    user2_id = r2.json()['user_id']

    r3 = client.post("/api/auth/register", json={"phone":"052-333-3333","full_name":"User3","password":"pass123","primary_language":"en"})
    assert r3.status_code == 201
    user3_id = r3.json()['user_id']

    headers = {"Authorization": f"Bearer {token1}"}

    # Start call with user2 and user3
    rcall = client.post("/api/calls/start", json={"participant_user_ids": [user2_id, user3_id]}, headers=headers)
    assert rcall.status_code == 200
    data = rcall.json()
    assert 'session_id' in data
    assert 'websocket_url' in data
    assert len(data['participants']) == 3
    assert any(p['user_id'] == caller_id for p in data['participants'])
    assert any(p['user_id'] == user2_id for p in data['participants'])
    assert any(p['user_id'] == user3_id for p in data['participants'])
