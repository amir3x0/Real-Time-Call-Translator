# backend/tests/test_user_model.py
import pytest
from app.models import User, init_db, reset_db

def test_create_user():
    reset_db()
    init_db()
    
    user = User(
        email="test@example.com",
        name="Test User",
        primary_language="he"
    )
    
    # Add assertions
    assert user.email == "test@example.com"
    assert user.primary_language == "he"