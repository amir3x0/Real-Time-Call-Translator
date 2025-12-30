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
    token2 = r2.json()['token']

    # User A searches for User B
    headers_a = {"Authorization": f"Bearer {token1}"}
    rsearch = client.get(f"/api/contacts/search?q=User", headers=headers_a)
    assert rsearch.status_code == 200
    assert len(rsearch.json()['users']) >= 1

    # User A adds User B as contact (sends request)
    radd = client.post("/api/contacts/add", json={"contact_user_id": user_b_id}, headers=headers_a)
    assert radd.status_code == 200 or radd.status_code == 201

    # User B checks pending requests
    headers_b = {"Authorization": f"Bearer {token2}"}
    rlist_b = client.get("/api/contacts", headers=headers_b)
    assert rlist_b.status_code == 200
    incoming = rlist_b.json()['pending_incoming']
    assert len(incoming) == 1
    request_id = incoming[0]['contact_id']

    # User B accepts the request
    raccept = client.post(f"/api/contacts/{request_id}/accept", headers=headers_b)
    assert raccept.status_code == 200

    # User A lists contacts (should now be friends)
    rlist_a = client.get("/api/contacts", headers=headers_a)
    assert rlist_a.status_code == 200
    contacts = rlist_a.json()['contacts']
    assert len(contacts) == 1
    assert contacts[0]['contact_user_id'] == user_b_id

    # Delete contact
    contact_id = contacts[0]['id']
    rdel = client.delete(f"/api/contacts/{contact_id}", headers=headers_a)
    assert rdel.status_code == 204

    # Confirm deleted
    rlist_a2 = client.get("/api/contacts", headers=headers_a)
    assert len(rlist_a2.json()['contacts']) == 0
