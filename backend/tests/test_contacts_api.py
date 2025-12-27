import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.main import app
from tests.helpers import create_user
from app.models.database import Base, get_db
from app.models.user import User


## Use the test DB override from conftest.py (async_db fixture) to ensure isolation


def test_contact_flow(async_db):
    client = TestClient(app)

    # Register two users
    r1 = create_user(client, full_name="User A", password="pass123", primary_language="en")
    assert r1.status_code == 201
    token1 = r1.json()['token']

    r2 = create_user(client, full_name="User B", password="pass123", primary_language="ru")
    assert r2.status_code == 201
    user_b_id = r2.json()['user_id']

    # User A searches for User B
    headers = {"Authorization": f"Bearer {token1}"}
    rsearch = client.get(f"/api/users/search?query=User", headers=headers)
    assert rsearch.status_code == 200
    assert len(rsearch.json()['results']) >= 1

    # User A adds User B as contact
    radd = client.post("/api/contacts/add", json={"contact_user_id": user_b_id}, headers=headers)
    assert radd.status_code == 200 or radd.status_code == 201

    # List contacts
    rlist = client.get("/api/contacts", headers=headers)
    assert rlist.status_code == 200
    assert len(rlist.json()['contacts']) == 1

    # Delete contact
    contact_id = rlist.json()['contacts'][0]['id']
    rdel = client.delete(f"/api/contacts/{contact_id}", headers=headers)
    assert rdel.status_code == 204

    # Confirm deleted
    rlist2 = client.get("/api/contacts", headers=headers)
    assert len(rlist2.json()['contacts']) == 0
