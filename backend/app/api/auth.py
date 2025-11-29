from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel, Field, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.database import get_db
from app.models.user import User
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_access_token,
    decode_token,
)
from app.config.settings import settings

router = APIRouter()


class RegisterRequest(BaseModel):
    phone: str = Field(..., min_length=6, max_length=20)
    full_name: str = Field(..., min_length=1, max_length=255)
    password: str = Field(..., min_length=6)
    primary_language: str = Field(...)

    @validator("primary_language")
    def validate_language(cls, v):
        if v not in ["he", "en", "ru"]:
            raise ValueError("Unsupported language")
        return v


class RegisterResponse(BaseModel):
    user_id: str
    token: str
    message: str


class LoginRequest(BaseModel):
    phone: str
    password: str


class LoginResponse(BaseModel):
    user_id: str
    token: str
    full_name: str
    primary_language: str
    language_code: Optional[str]  # NEW FIELD
    status: str = 'online'  # NEW FIELD: Set to 'online' on login


class UserResponse(BaseModel):
    id: str
    phone: str
    full_name: str
    primary_language: str
    language_code: Optional[str]  # NEW FIELD
    status: Optional[str]  # NEW FIELD: 'online' or 'offline'
    last_seen: Optional[str]  # NEW FIELD
    created_at: Optional[str]


async def get_current_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)) -> User:
    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Authorization header")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Authorization header")
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


@router.post("/auth/register", response_model=RegisterResponse, status_code=201)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check phone uniqueness
    q = await db.execute(select(User).where(User.phone == request.phone))
    existing = q.scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Phone already in use")

    pwd_hash = hash_password(request.password)
    user = User(
        phone=request.phone,
        full_name=request.full_name,
        hashed_password=pwd_hash,
        primary_language=request.primary_language,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(str(user.id))
    return RegisterResponse(user_id=user.id, token=token, message="User registered")


@router.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    q = await db.execute(select(User).where(User.phone == request.phone))
    user = q.scalar_one_or_none()
    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(request.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Update user status to online
    user.is_online = True
    user.last_seen = datetime.utcnow()
    await db.commit()
    
    token = create_access_token(str(user.id))
    return LoginResponse(
        user_id=user.id,
        token=token,
        full_name=user.full_name,
        primary_language=user.primary_language,
        language_code=user.language_code or user.primary_language,
        status='online',
    )


@router.get("/auth/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        phone=current_user.phone,
        full_name=current_user.full_name,
        primary_language=current_user.primary_language,
        language_code=current_user.language_code or current_user.primary_language,
        status='online' if current_user.is_online else 'offline',
        last_seen=current_user.last_seen.isoformat() if current_user.last_seen else None,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )
