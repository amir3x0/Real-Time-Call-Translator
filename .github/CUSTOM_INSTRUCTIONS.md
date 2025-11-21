# Custom GitHub Copilot Instructions - Real-Time Call Translator

## Project Overview
This is a real-time multilingual call translation system with voice cloning capabilities. The system supports Hebrew, English, and Russian languages for 2-4 simultaneous participants in a call.

## Current Project Status (Week 1 - Day 4 Complete ✅)

**Completed (Days 1-4: 18-21 Nov 2025):**
- ✅ GitHub repository with branch structure (main, develop)
- ✅ Docker Compose setup (postgres, redis, backend, pgadmin)
- ✅ All 6 database models created and migrated:
  - User (authentication & profile)
  - Call (call sessions with status tracking)
  - CallParticipant (participant management)
  - Contact (user contacts)
  - VoiceModel (voice cloning models)
  - Message (transcriptions & translations)
- ✅ FastAPI application with health endpoint (`/health`)
- ✅ WebSocket endpoint structure (`/ws/{session_id}`)
- ✅ Complete documentation in `.github/docs/`
- ✅ Flutter project created with 74 files
- ✅ 9 dependencies configured (provider, http, web_socket_channel, flutter_sound, just_audio, permission_handler, shared_preferences, intl)
- ✅ Dart models created (User, Call, CallParticipant) matching backend schema
- ✅ AppConfig with backend URLs, language support, and audio settings
- ✅ main.dart updated with Real-Time Call Translator branding
- ✅ Widget tests passing with green status
- ✅ Flutter analyze: No issues found

**Next Steps (Days 5-7: 22-24 Nov 2025):**
- 📋 Day 5 (22.11): Google Cloud Setup
- 📋 Day 6-7: WebSocket & Translation Pipeline

## Technology Stack

### Backend (Python) - ✅ Infrastructure Ready
- **Framework**: FastAPI 0.104.1
- **Database**: PostgreSQL 15 with SQLAlchemy 2.0 (async)
- **Cache**: Redis 7 for message queuing and caching
- **AI Services**: Google Cloud (Speech-to-Text, Translate, Text-to-Speech)
- **Voice Cloning**: Coqui xTTS v2
- **Real-time**: WebSocket communication
- **Deployment**: Docker & Docker Compose

### Frontend (Flutter) - ✅ Day 4 Complete
- **Framework**: Flutter 3.35+
- **Language**: Dart
- **Platforms**: iOS and Android

## Architecture Principles

### 1. Async-First Approach
- All I/O operations MUST be async/await
- Use `AsyncSession` for database operations
- Use `redis.asyncio` for Redis operations
- WebSocket handlers are async

### 2. Database Models
All models inherit from `Base` and include:
- UUID primary keys (String type)
- `created_at` and `updated_at` timestamps
- `to_dict()` method for JSON serialization
- Proper indexes on foreign keys and frequently queried fields
- Clear `__repr__` for debugging

**Existing Models:**
- `User` - User authentication and profile
- `Call` - Call sessions
- `CallParticipant` - Participants in calls
- `Contact` - User contacts
- `VoiceModel` - Voice cloning models
- `Message` - Call transcriptions and translations

### 3. Code Style & Standards

#### Python
```python
# Import order:
# 1. Standard library
# 2. Third-party packages
# 3. Local imports

# Type hints required
async def get_user(user_id: str) -> User | None:
    pass

# Docstrings for all public functions
async def translate_text(text: str, target_lang: str) -> str:
    """Translate text to target language using Google Translate.
    
    Args:
        text: The text to translate
        target_lang: Target language code (he, en, ru)
    
    Returns:
        Translated text string
    """
    pass
```

#### Naming Conventions
- Variables & Functions: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Private methods: `_snake_case`

### 4. API Endpoints

All endpoints follow REST conventions:
```
GET    /api/resource          - List all
GET    /api/resource/{id}     - Get one
POST   /api/resource          - Create
PUT    /api/resource/{id}     - Update
DELETE /api/resource/{id}     - Delete
```

WebSocket endpoints:
```
WS /ws/{session_id}           - WebSocket connection
```

### 5. Error Handling

```python
from fastapi import HTTPException

# Use appropriate HTTP status codes
raise HTTPException(status_code=404, detail="User not found")
raise HTTPException(status_code=400, detail="Invalid language code")
raise HTTPException(status_code=500, detail="Translation service unavailable")
```

### 6. Language Codes
Supported languages:
- `he` - Hebrew
- `en` - English  
- `ru` - Russian

Always validate language codes against this list.

### 7. Redis Patterns

```python
# Stream for audio chunks
stream_name = f"stream:audio:{session_id}"
await redis.xadd(stream_name, {"data": audio_chunk})

# Cache keys
user_cache_key = f"user:{user_id}"
translation_cache_key = f"translation:{source_lang}:{target_lang}:{hash(text)}"
```

### 8. Security Best Practices

- Never commit `.env` files
- Never commit `google-credentials.json`
- Always hash passwords before storing
- Validate all user inputs
- Use parameterized queries (SQLAlchemy handles this)
- Sanitize file paths before accessing files

### 9. Testing

```python
import pytest

@pytest.mark.asyncio
async def test_create_user():
    """Test user creation with all required fields."""
    # Arrange
    user_data = {...}
    
    # Act
    user = await create_user(user_data)
    
    # Assert
    assert user.email == user_data["email"]
```

### 10. Database Migrations

When adding new fields:
1. Update the model in `backend/app/models/`
2. Update `__init__.py` to export the model
3. Run `create_tables.py` to create tables
4. Update any relevant API endpoints
5. Write tests for new functionality

## Project-Specific Guidelines

### Audio Processing
- Audio chunks: 100-500ms recommended
- Format: 16kHz, mono, 16-bit PCM
- Use Redis Streams for audio queue
- Process in order to maintain conversation flow

### Translation Pipeline
```
1. Receive Audio Chunk (WebSocket)
2. Queue in Redis Stream
3. Speech-to-Text (Google)
4. Translation (Google Translate)
5. Text-to-Speech (Google TTS or xTTS)
6. Send to Recipients (WebSocket)
```

### Voice Cloning
- Minimum 10 seconds of voice sample
- Store samples in `/app/data/voice_samples/`
- Train models in `/app/data/models/`
- Fall back to Google TTS if cloning fails
- Update `VoiceModel.training_status` during training

### WebSocket Messages

```json
// Audio message
{
  "type": "audio",
  "data": "<base64_encoded_audio>",
  "language": "he"
}

// Control message
{
  "type": "control",
  "action": "mute|unmute|ping"
}

// Translation message
{
  "type": "translation",
  "original_text": "שלום",
  "translated_text": "Hello",
  "source_lang": "he",
  "target_lang": "en"
}
```

### Environment Variables

Required in `.env`:
```env
DB_USER=translator_admin
DB_PASSWORD=<secure_password>
DB_NAME=call_translator
DB_HOST=postgres
DB_PORT=5432

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<secure_password>

GOOGLE_APPLICATION_CREDENTIALS=/app/config/google-credentials.json
GOOGLE_PROJECT_ID=<your_project_id>
```

## Common Patterns

### Database Query
```python
from app.models import get_db, User
from sqlalchemy import select

async def get_user_by_email(email: str) -> User | None:
    async with get_db() as db:
        result = await db.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()
```

### Redis Operation
```python
from app.config.redis import get_redis

async def cache_translation(key: str, value: str, ttl: int = 3600):
    redis = await get_redis()
    await redis.setex(key, ttl, value)
```

### FastAPI Endpoint
```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

class CreateUserRequest(BaseModel):
    email: str
    name: str
    primary_language: str

@router.post("/users")
async def create_user(request: CreateUserRequest):
    # Validate
    if request.primary_language not in ["he", "en", "ru"]:
        raise HTTPException(400, "Invalid language")
    
    # Create user
    user = User(**request.dict())
    
    # Save to database
    async with get_db() as db:
        db.add(user)
        await db.commit()
        await db.refresh(user)
    
    return user.to_dict()
```

## Performance Targets

- Translation latency (without voice cloning): < 500ms
- Translation latency (with voice cloning): < 1000ms
- Speech recognition accuracy: > 85%
- System uptime: > 95%

## Documentation Standards

- Update README.md for major features
- Add docstrings to all public functions
- Comment complex algorithms
- Keep API documentation in sync with code

## Git Workflow

- Main branch: `main` (production-ready)
- Development branch: `develop`
- Feature branches: `feature/feature-name`
- Bugfix branches: `bugfix/bug-name`
- Commit message format: `type(scope): description`
  - Types: feat, fix, docs, style, refactor, test, chore

## When Generating Code

1. **Always use type hints** for function parameters and return types
2. **Always use async/await** for I/O operations
3. **Always add docstrings** to functions
4. **Always handle errors** gracefully with appropriate HTTP status codes
5. **Always validate inputs** before processing
6. **Prefer existing patterns** from the codebase
7. **Keep functions focused** - one responsibility per function
8. **Test your code** - write unit tests for new features

## Project Timeline Reference

We are currently in **Week 1, Day 4** of a 10-week project:
- **Week 1-2**: Infrastructure & Google APIs ✅ (Days 1-3 Complete)
- Week 3-4: WebSocket & Translation Pipeline
- Week 5: Flutter UI
- Week 6: Voice Cloning
- Week 7: Testing
- Week 8: Documentation
- Week 9: Presentation
- Week 10: Final Submission

## Contact & Support

- **Team**: Amir Mishayev, Daniel Fraimovich
- **Institution**: Braude College - Software Engineering
- **Project Code**: 25-2-D-5
- **Repository**: https://github.com/amir3x0/Real-Time-Call-Translator

---

**Remember**: This project aims to break language barriers while preserving voice identity. Every line of code should contribute to making real-time multilingual communication seamless and natural.
