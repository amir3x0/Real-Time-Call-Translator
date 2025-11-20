# GitHub Copilot Instructions

This file provides instructions to GitHub Copilot for better code suggestions in this repository.

## Project Context

**Real-Time Call Translator** - A multilingual voice translation system with voice cloning.

- **Backend**: Python 3.10 + FastAPI + PostgreSQL + Redis
- **Frontend**: Flutter (iOS/Android)
- **AI**: Google Cloud (STT, Translate, TTS) + Coqui xTTS
- **Languages**: Hebrew, English, Russian

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

---

For detailed guidelines, see [CUSTOM_INSTRUCTIONS.md](CUSTOM_INSTRUCTIONS.md)
