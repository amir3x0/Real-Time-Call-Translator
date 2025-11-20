# Code Guidelines - Real-Time Call Translator

## Table of Contents
1. [General Principles](#general-principles)
2. [Python Backend](#python-backend)
3. [Database Models](#database-models)
4. [API Design](#api-design)
5. [Testing](#testing)
6. [Error Handling](#error-handling)
7. [Security](#security)

---

## General Principles

### DRY (Don't Repeat Yourself)
- Extract common logic into reusable functions
- Use inheritance for shared model attributes
- Create utility functions for repeated operations

### KISS (Keep It Simple, Stupid)
- Write clear, readable code
- Avoid over-engineering
- Prefer simple solutions over complex ones

### SOLID Principles
- **S**ingle Responsibility: One class/function = one purpose
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes must be substitutable
- **I**nterface Segregation: Many specific interfaces > one general
- **D**ependency Inversion: Depend on abstractions, not concretions

---

## Python Backend

### Code Style
Follow **PEP 8** with these specifics:

```python
# Maximum line length: 100 characters
# Indentation: 4 spaces
# Blank lines: 2 before top-level definitions, 1 before method definitions

# ✅ Good
async def get_user_by_email(
    email: str,
    include_deleted: bool = False
) -> User | None:
    """Get user by email address.
    
    Args:
        email: User's email address
        include_deleted: Whether to include soft-deleted users
        
    Returns:
        User object if found, None otherwise
    """
    pass

# ❌ Bad
def getUser(e):
    pass
```

### Type Hints
**Always** use type hints:

```python
from typing import List, Optional, Dict, Any

# Function parameters and returns
async def process_audio(
    chunk: bytes,
    language: str,
    session_id: str
) -> Dict[str, Any]:
    pass

# Variables (when not obvious)
users: List[User] = []
config: Optional[Dict[str, str]] = None
```

### Async/Await
All I/O operations must be async:

```python
# ✅ Good
async def save_user(user: User) -> None:
    async with get_db() as db:
        db.add(user)
        await db.commit()

# ❌ Bad - Blocking I/O
def save_user(user: User):
    db = get_sync_db()
    db.add(user)
    db.commit()
```

### Docstrings
Use Google-style docstrings:

```python
def translate_text(text: str, source: str, target: str) -> str:
    """Translate text from source to target language.
    
    This function uses Google Translate API with caching to improve
    performance for frequently translated phrases.
    
    Args:
        text: The text to translate
        source: Source language code (he, en, ru)
        target: Target language code (he, en, ru)
        
    Returns:
        Translated text string
        
    Raises:
        ValueError: If language codes are invalid
        TranslationError: If translation service fails
        
    Example:
        >>> translate_text("שלום", "he", "en")
        'Hello'
    """
    pass
```

### Import Organization
```python
# 1. Standard library (alphabetical)
import asyncio
import logging
from datetime import datetime
from typing import List, Optional

# 2. Third-party packages (alphabetical)
from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as redis

# 3. Local application imports (alphabetical)
from app.config.settings import settings
from app.config.redis import get_redis
from app.models import User, Call
from app.services.translation import TranslationService
```

### Error Handling
```python
# ✅ Good - Specific exceptions
try:
    user = await get_user(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
except ValueError as e:
    raise HTTPException(status_code=400, detail=str(e))
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise HTTPException(status_code=500, detail="Internal server error")

# ❌ Bad - Catch-all
try:
    user = get_user(user_id)
except:
    pass
```

### Logging
```python
import logging

logger = logging.getLogger(__name__)

# Use appropriate log levels
logger.debug("Detailed debugging information")
logger.info("User logged in: {user_id}")
logger.warning("Translation took longer than expected: {duration}ms")
logger.error("Failed to connect to Redis: {error}")
logger.critical("Database connection lost")

# Include context
logger.info(
    f"Call started: session_id={session_id}, "
    f"participants={len(participants)}, "
    f"languages={languages}"
)
```

---

## Database Models

### Model Structure
```python
from sqlalchemy import Column, String, DateTime, Boolean
from datetime import datetime
import uuid
from .database import Base

class User(Base):
    """User model docstring."""
    __tablename__ = "users"
    
    # Primary key - always UUID as String
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Required fields first
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    
    # Optional fields
    phone = Column(String(20), unique=True, nullable=True)
    
    # Boolean flags
    is_active = Column(Boolean, default=True)
    
    # Timestamps - always include these
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self) -> dict:
        """Convert model to dictionary."""
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
    
    def __repr__(self) -> str:
        return f"<User {self.email}>"
```

### Indexes
```python
# Add indexes to:
# - Foreign keys (always)
# - Frequently queried fields
# - Unique constraints

class CallParticipant(Base):
    call_id = Column(String, ForeignKey("calls.id"), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    joined_at = Column(DateTime, index=True)  # For time-based queries
```

### Foreign Keys
```python
# Always specify ondelete behavior
user_id = Column(
    String,
    ForeignKey("users.id", ondelete="CASCADE"),
    nullable=False,
    index=True
)

# Options:
# CASCADE - Delete related records
# SET NULL - Set to NULL (requires nullable=True)
# RESTRICT - Prevent deletion
```

---

## API Design

### REST Endpoints
```python
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

router = APIRouter(prefix="/api/users", tags=["users"])

class UserCreate(BaseModel):
    """Request model for creating user."""
    email: str
    name: str
    primary_language: str

class UserResponse(BaseModel):
    """Response model for user data."""
    id: str
    email: str
    name: str
    primary_language: str

@router.post(
    "/",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED
)
async def create_user(user: UserCreate) -> UserResponse:
    """Create a new user.
    
    Args:
        user: User creation data
        
    Returns:
        Created user data
        
    Raises:
        HTTPException: 400 if validation fails
        HTTPException: 409 if user already exists
    """
    # Validate
    if user.primary_language not in ["he", "en", "ru"]:
        raise HTTPException(
            status_code=400,
            detail="Invalid language code"
        )
    
    # Create
    db_user = User(**user.dict())
    
    # Save
    async with get_db() as db:
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
    
    return UserResponse(**db_user.to_dict())
```

### HTTP Status Codes
```python
# Use correct status codes
200 - OK (GET, PUT)
201 - Created (POST)
204 - No Content (DELETE)
400 - Bad Request (validation error)
401 - Unauthorized (not authenticated)
403 - Forbidden (authenticated but not allowed)
404 - Not Found
409 - Conflict (duplicate resource)
422 - Unprocessable Entity (validation error)
500 - Internal Server Error
```

### WebSocket
```python
from fastapi import WebSocket, WebSocketDisconnect

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    
    try:
        while True:
            # Receive data
            data = await websocket.receive_bytes()
            
            # Process
            result = await process_audio(data, session_id)
            
            # Send back
            await websocket.send_json(result)
            
    except WebSocketDisconnect:
        logger.info(f"Client disconnected from session {session_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        await websocket.close(code=1011)
```

---

## Testing

### Test Structure
```python
import pytest
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

@pytest.fixture
async def db():
    """Create test database."""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    AsyncSessionLocal = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with AsyncSessionLocal() as session:
        yield session
    
    await engine.dispose()

@pytest.mark.asyncio
async def test_create_user(db):
    """Test user creation."""
    # Arrange
    user = User(
        email="test@example.com",
        name="Test User",
        primary_language="he"
    )
    
    # Act
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    # Assert
    assert user.id is not None
    assert user.email == "test@example.com"
    assert user.created_at is not None
```

### Test Naming
```python
# Pattern: test_<what>_<condition>_<expected>

def test_get_user_with_valid_id_returns_user():
    pass

def test_get_user_with_invalid_id_raises_404():
    pass

def test_translate_text_with_empty_string_raises_400():
    pass
```

---

## Error Handling

### Custom Exceptions
```python
# app/exceptions.py
class TranslationError(Exception):
    """Raised when translation fails."""
    pass

class VoiceCloningError(Exception):
    """Raised when voice cloning fails."""
    pass

# Usage
try:
    translated = await translate(text, "he", "en")
except TranslationError as e:
    logger.error(f"Translation failed: {e}")
    # Fall back to original text
    translated = text
```

### HTTP Exceptions
```python
from fastapi import HTTPException

# Always include detail message
raise HTTPException(
    status_code=404,
    detail="User with id {user_id} not found"
)

# Include extra context when helpful
raise HTTPException(
    status_code=400,
    detail={
        "message": "Invalid language code",
        "allowed_values": ["he", "en", "ru"],
        "provided_value": language_code
    }
)
```

---

## Security

### Never Commit
```
.env files
google-credentials.json
Any API keys
Database passwords
Private keys
```

### Input Validation
```python
from pydantic import BaseModel, validator

class UserCreate(BaseModel):
    email: str
    name: str
    primary_language: str
    
    @validator('email')
    def email_must_be_valid(cls, v):
        if '@' not in v:
            raise ValueError('Invalid email format')
        return v.lower()
    
    @validator('primary_language')
    def language_must_be_supported(cls, v):
        if v not in ['he', 'en', 'ru']:
            raise ValueError('Unsupported language')
        return v
```

### Password Hashing
```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Hash password
hashed = pwd_context.hash(plain_password)

# Verify password
is_valid = pwd_context.verify(plain_password, hashed)
```

### File Paths
```python
import os
from pathlib import Path

# ✅ Good - Validate paths
def save_voice_sample(user_id: str, file_data: bytes):
    # Validate user_id doesn't contain path traversal
    if '..' in user_id or '/' in user_id:
        raise ValueError("Invalid user_id")
    
    # Use safe path construction
    base_dir = Path("/app/data/voice_samples")
    file_path = base_dir / user_id / "sample.wav"
    
    # Ensure directory exists
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write file
    file_path.write_bytes(file_data)

# ❌ Bad - Unsafe path construction
def save_voice_sample(user_id: str, file_data: bytes):
    path = f"/app/data/voice_samples/{user_id}/sample.wav"
    with open(path, 'wb') as f:
        f.write(file_data)
```

---

## Performance

### Database Queries
```python
# ✅ Good - Use specific columns
result = await db.execute(
    select(User.id, User.email, User.name)
    .where(User.is_active == True)
)

# ❌ Bad - Select all columns
result = await db.execute(
    select(User).where(User.is_active == True)
)
```

### Caching
```python
from app.config.redis import get_redis

async def get_translation_cached(text: str, source: str, target: str) -> str:
    """Get translation with caching."""
    cache_key = f"translation:{source}:{target}:{hash(text)}"
    
    # Try cache first
    redis = await get_redis()
    cached = await redis.get(cache_key)
    if cached:
        return cached.decode()
    
    # Translate
    result = await translate(text, source, target)
    
    # Cache for 1 hour
    await redis.setex(cache_key, 3600, result)
    
    return result
```

---

**Remember**: Write code as if the next person to maintain it is a violent psychopath who knows where you live. 😊
