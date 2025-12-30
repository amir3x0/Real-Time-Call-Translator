import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.main import app
from tests.helpers import create_user, unique_phone
from app.models.database import Base, get_db


## Use conftest's shared async_db fixture to ensure DB is created/cleaned per test


def test_start_call(async_db):
    client = TestClient(app)

    # Register three users
    # Use distinct phone numbers per test to avoid cross-test collisions
    r1 = create_user(client, full_name="Caller", password="pass123", primary_language="en")
    assert r1.status_code == 201
    token1 = r1.json()['token']
    caller_id = r1.json()['user_id']

    r2 = create_user(client, full_name="User2", password="pass123", primary_language="en")
    assert r2.status_code == 201
    user2_id = r2.json()['user_id']

    r3 = create_user(client, full_name="User3", password="pass123", primary_language="en")
    assert r3.status_code == 201
    user3_id = r3.json()['user_id']

    headers = {"Authorization": f"Bearer {token1}"}

    # Add user2 and user3 as contacts first (required for calling)
    client.post("/api/contacts/add", json={"contact_user_id": user2_id}, headers=headers)
    client.post("/api/contacts/add", json={"contact_user_id": user3_id}, headers=headers)
    
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
