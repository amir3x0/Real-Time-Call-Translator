import uuid
from typing import Optional

from fastapi.testclient import TestClient


def unique_phone(prefix: str = '052') -> str:
    # Create a unique phone like '052-xxx-xxxx'
    suffix = uuid.uuid4().hex[:7]
    return f"{prefix}-{suffix[:3]}-{suffix[3:]}"


def create_user(client: TestClient, phone: Optional[str] = None, full_name: str = 'Test User', password: str = 'pass123', primary_language: str = 'en'):
    if phone is None:
        phone = unique_phone()
    payload = {
        'phone': phone,
        'full_name': full_name,
        'password': password,
        'primary_language': primary_language,
    }
    r = client.post('/api/auth/register', json=payload)
    return r
