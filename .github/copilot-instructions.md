# GitHub Copilot Instructions

This file provides instructions to GitHub Copilot for better code suggestions in this repository.

## Project Context

**Real-Time Call Translator** - A multilingual voice translation system with voice cloning.

- **Backend**: Python 3.10 + FastAPI + PostgreSQL + Redis
- **Frontend**: Flutter (iOS/Android) - **Starting Day 4 (21.11.2025)**
- **AI**: Google Cloud (STT, Translate, TTS) + Coqui xTTS
- **Languages**: Hebrew, English, Russian

## Current Status (Week 1 - Day 4 Complete ✅)

**Completed:**
- ✅ GitHub repository setup with branch structure
- ✅ Docker Compose configuration (postgres, redis, backend, pgadmin)
- ✅ All 6 database models created (User, Call, CallParticipant, Contact, VoiceModel, Message)
- ✅ Database tables migrated successfully
- ✅ FastAPI application with health endpoint
- ✅ WebSocket endpoint structure at `/ws/{session_id}`
- ✅ Complete project documentation in `.github/docs/`
- ✅ Flutter project created (mobile/)
- ✅ 9 dependencies configured (provider, http, WebSocket, audio)
- ✅ Dart models created (User, Call, CallParticipant)
- ✅ AppConfig with backend URLs and settings
- ✅ main.dart with Material 3 theme
- ✅ Widget tests passing
- ✅ Flutter analyze: No issues found

**Next Steps:**
- 📋 Day 5 (22.11): Google Cloud Setup
- 📋 Day 6-7: WebSocket & Translation Pipeline

## Code Preferences

### Python
- Use async/await for all I/O operations
- Type hints are mandatory
- SQLAlchemy with async sessions
- FastAPI for REST APIs
- WebSocket for real-time communication

### Database
- PostgreSQL 15 with asyncpg driver
- All models have UUID primary keys (String type)
- Include `created_at` and `updated_at` timestamps
- Add `to_dict()` method for JSON serialization

### Imports
```python
# Standard library
import asyncio
from datetime import datetime

# Third-party
from fastapi import FastAPI, HTTPException
from sqlalchemy import Column, String

# Local
from app.models import User
from app.config import settings
```

### Language Codes
Valid codes: `he` (Hebrew), `en` (English), `ru` (Russian)

### Redis Keys
- Audio streams: `stream:audio:{session_id}`
- User cache: `user:{user_id}`
- Translation cache: `translation:{source_lang}:{target_lang}:{hash}`

## Security
- Never suggest committing `.env` files
- Never suggest committing credentials
- Always validate user inputs
- Use parameterized queries

## Testing
- Use pytest with `@pytest.mark.asyncio`
- Test database operations with in-memory SQLite
- Mock external API calls (Google Cloud)

## Documentation
For detailed guidelines, see:
- [CUSTOM_INSTRUCTIONS.md](CUSTOM_INSTRUCTIONS.md) - Comprehensive project instructions
- [docs/CODE_GUIDELINES.md](docs/CODE_GUIDELINES.md) - Coding standards
- [docs/POSTGRESQL_GUIDE.md](docs/POSTGRESQL_GUIDE.md) - Database management
- [docs/GIT_INSTRUCTIONS.md](docs/GIT_INSTRUCTIONS.md) - Git workflow
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - Contribution guidelines
## Security
- Never suggest committing `.env` files
- Never suggest committing credentials
- Always validate user inputs
- Use parameterized queries

## Testing
- Use pytest with `@pytest.mark.asyncio`
- Test database operations with in-memory SQLite
- Mock external API calls (Google Cloud)

---

For detailed guidelines, see [CUSTOM_INSTRUCTIONS.md](CUSTOM_INSTRUCTIONS.md)
