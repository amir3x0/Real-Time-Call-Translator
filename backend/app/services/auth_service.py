"""
Auth Service - Simple authentication for capstone project

Note: This uses plain text passwords for simplicity (capstone project).
In production, use proper password hashing (bcrypt, argon2, etc.)
"""
from datetime import datetime, timedelta
from typing import Optional

from jose import jwt

from app.config.settings import settings


def hash_password(password: str) -> str:
    """Store password as-is (no encryption for capstone project)."""
    return password


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Simple password comparison."""
    return plain_password == hashed_password


def create_access_token(subject: str, expires_delta: Optional[timedelta] = None) -> str:
    if expires_delta is None:
        expires_delta = timedelta(days=settings.JWT_EXP_DAYS)
    expire = datetime.utcnow() + expires_delta
    to_encode = {"sub": subject, "exp": int(expire.timestamp())}
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except Exception:
        return None
