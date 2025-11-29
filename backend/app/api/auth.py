"""
Auth API - User registration and login

Simplified authentication for capstone project.
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.database import get_db
from app.models.user import User
from app.services.auth_service import create_access_token, decode_token
from app.config.settings import settings

router = APIRouter()


class RegisterRequest(BaseModel):
    phone: str = Field(..., min_length=6, max_length=20)
    full_name: str = Field(..., min_length=1, max_length=255)
    password: str = Field(..., min_length=4)
    primary_language: str = Field(default="he")

    @field_validator("primary_language")
    @classmethod
    def validate_language(cls, v):
        if v not in ["he", "en", "ru"]:
            raise ValueError("Unsupported language. Use: he, en, ru")
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


class UserResponse(BaseModel):
    id: str
    phone: str
    full_name: str
    primary_language: str
    is_online: bool
    has_voice_sample: bool
    voice_model_trained: bool
    created_at: Optional[str]


async def get_current_user(
    authorization: Optional[str] = Header(None), 
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get current authenticated user from JWT token."""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Missing Authorization header"
        )
    
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid Authorization header"
        )
    
    payload = decode_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid or expired token"
        )
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid token payload"
        )
    
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="User not found"
        )
    
    return user


@router.post("/auth/register", response_model=RegisterResponse, status_code=201)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user."""
    # Check phone uniqueness
    result = await db.execute(select(User).where(User.phone == request.phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Phone number already registered")

    # Create user (password stored as plain text for capstone)
    user = User(
        phone=request.phone,
        full_name=request.full_name,
        password=request.password,  # Plain text for simplicity
        primary_language=request.primary_language,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(str(user.id))
    return RegisterResponse(
        user_id=user.id, 
        token=token, 
        message="User registered successfully"
    )


@router.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with phone and password."""
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=401, detail="Invalid phone or password")
    
    # Simple password comparison (capstone project)
    if user.password != request.password:
        raise HTTPException(status_code=401, detail="Invalid phone or password")
    
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
    )


@router.get("/auth/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    """Get current user's profile."""
    return UserResponse(
        id=current_user.id,
        phone=current_user.phone,
        full_name=current_user.full_name,
        primary_language=current_user.primary_language,
        is_online=current_user.is_online,
        has_voice_sample=current_user.has_voice_sample,
        voice_model_trained=current_user.voice_model_trained,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )


@router.post("/auth/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Logout - mark user as offline."""
    current_user.is_online = False
    current_user.last_seen = datetime.utcnow()
    await db.commit()
    return {"message": "Logged out successfully"}


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    primary_language: Optional[str] = None
    
    @field_validator("primary_language")
    @classmethod
    def validate_language(cls, v):
        if v is not None and v not in ["he", "en", "ru"]:
            raise ValueError("Unsupported language. Use: he, en, ru")
        return v


@router.patch("/auth/profile", response_model=UserResponse)
async def update_profile(
    request: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update user profile (name and/or language)."""
    if request.full_name is not None:
        current_user.full_name = request.full_name
    
    if request.primary_language is not None:
        current_user.primary_language = request.primary_language
    
    current_user.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(current_user)
    
    return UserResponse(
        id=current_user.id,
        phone=current_user.phone,
        full_name=current_user.full_name,
        primary_language=current_user.primary_language,
        is_online=current_user.is_online,
        has_voice_sample=current_user.has_voice_sample,
        voice_model_trained=current_user.voice_model_trained,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )
