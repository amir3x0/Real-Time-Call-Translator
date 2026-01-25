# Real-Time Call Translator - Claude Code Instructions

## Project Overview

Real-time multilingual call translation system with voice cloning capabilities. Supports Hebrew (`he`), English (`en`), and Russian (`ru`) for 2-4 simultaneous participants.

**Team**: Amir Mishayev, Daniel Fraimovich
**Institution**: Braude College - Software Engineering
**Repository**: https://github.com/amir3x0/Real-Time-Call-Translator

## Technology Stack

### Backend (`/backend`)
- **Framework**: FastAPI with async/await patterns
- **Database**: PostgreSQL 15 + SQLAlchemy 2.0 (async)
- **Cache/Queue**: Redis 7 with asyncio
- **AI Services**: Google Cloud (Speech-to-Text, Translate, Text-to-Speech)
- **Voice Cloning**: Coqui xTTS v2
- **Real-time**: WebSocket communication

### Mobile (`/mobile`)
- **Framework**: Flutter 3.35+
- **Language**: Dart
- **State Management**: Provider
- **Platforms**: Android & iOS

## Project Structure

```
backend/
├── app/
│   ├── api/           # REST endpoints and WebSocket routes
│   ├── config/        # Settings, Redis, constants
│   ├── models/        # SQLAlchemy models (User, Call, Contact, etc.)
│   ├── schemas/       # Pydantic schemas
│   └── services/      # Business logic
│       ├── audio/     # Audio processing, chunking, speech detection
│       ├── call/      # Call lifecycle, participants, transcripts
│       ├── connection/# WebSocket connection management
│       ├── session/   # Session orchestration
│       └── translation/ # Translation processor, TTS cache
├── alembic/           # Database migrations
├── scripts/           # Utility scripts
└── tests/             # pytest tests

mobile/
├── lib/
│   ├── config/        # App configuration and theme
│   ├── core/          # Navigation, routes
│   ├── data/
│   │   ├── services/  # API services (auth, call, contact)
│   │   └── websocket/ # WebSocket service
│   ├── models/        # Dart models
│   ├── providers/     # State providers (auth, call, settings)
│   ├── screens/       # UI screens (auth, call, contacts, settings)
│   ├── services/      # Device services (permissions, voice recording)
│   ├── utils/         # Utilities
│   └── widgets/       # Reusable UI components
└── test/              # Flutter tests
```

## Key Coding Standards

### Python Backend

1. **Async-First**: All I/O operations MUST use async/await
   ```python
   async def get_user(user_id: str) -> User | None:
       async with get_db() as db:
           result = await db.execute(select(User).where(User.id == user_id))
           return result.scalar_one_or_none()
   ```

2. **Type Hints**: Required for all function parameters and returns

3. **Import Order**:
   - Standard library
   - Third-party packages
   - Local imports

4. **Naming**:
   - Variables/Functions: `snake_case`
   - Classes: `PascalCase`
   - Constants: `UPPER_SNAKE_CASE`

### Flutter Mobile

1. **State Management**: Use Provider pattern
2. **Audio Settings**: 16kHz mono sample rate, 200ms chunking
3. **Permissions**: Always check microphone permissions before recording
4. **Security**: Never embed API credentials in client code

## Language Codes

Always validate language codes against:
- `he` - Hebrew
- `en` - English
- `ru` - Russian

## WebSocket Message Types

```json
// Audio message
{"type": "audio", "data": "<base64>", "language": "he"}

// Control message
{"type": "control", "action": "mute|unmute|ping"}

// Translation message
{"type": "translation", "original_text": "...", "translated_text": "...", "source_lang": "he", "target_lang": "en"}
```

## Redis Patterns

```python
# Audio stream
stream_name = f"stream:audio:{session_id}"
await redis.xadd(stream_name, {"data": audio_chunk})

# Cache keys
user_cache = f"user:{user_id}"
translation_cache = f"translation:{source}:{target}:{hash(text)}"
```

## Database Models

All models in `backend/app/models/`:
- `User` - Authentication and profile
- `Call` - Call sessions with status tracking
- `CallParticipant` - Participant management
- `Contact` - User contacts
- `VoiceRecording` - Voice samples for cloning
- `CallTranscript` - Transcriptions and translations

## API Conventions

REST endpoints follow standard conventions:
```
GET    /api/resource          - List
GET    /api/resource/{id}     - Get one
POST   /api/resource          - Create
PUT    /api/resource/{id}     - Update
DELETE /api/resource/{id}     - Delete
```

WebSocket: `WS /ws/{session_id}`

## Testing

### Backend
```bash
cd backend
pytest tests/ -v
```

### Mobile
```bash
cd mobile
flutter test
flutter analyze
```

## Environment Variables

Required in `backend/.env`:
- `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_HOST`, `DB_PORT`
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
- `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_PROJECT_ID`

## Security Reminders

- Never commit `.env` or `google-credentials.json` (CRITICAL - only security rule enforced)
- This is a capstone project - other security fixes (password hashing, input validation) are intentionally deferred

## Project-Specific Notes

- **datetime.utcnow()** is the preferred datetime method for this project - do not change to datetime.now(UTC)
- Security hardening is out of scope except for credential exposure prevention

## Performance Targets

- Translation latency (without voice cloning): < 500ms
- Translation latency (with voice cloning): < 1000ms
- Speech recognition accuracy: > 85%

## Git Workflow

- Main branch: `main`
- Feature branches: `feature/feature-name`
- Bugfix branches: `bugfix/bug-name`
- Commit format: `type(scope): description`
  - Types: feat, fix, docs, style, refactor, test, chore

## Running the Project

### Backend
```bash
cd backend
# Using Docker
docker-compose up -d

# Or locally
python -m uvicorn app.main:app --reload
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run
```

## Documentation

Additional docs in `.github/docs/`:
- `CODE_GUIDELINES.md` - Coding standards
- `CONTRIBUTING.md` - Contribution guidelines
- `GIT_INSTRUCTIONS.md` - Git workflow
- `POSTGRESQL_GUIDE.md` - Database management

## AI Collaboration: Clarification-First Approach

### Before Code or Architecture Work
When you receive a request to design, architect, or implement a feature:

1. **STOP before writing code or creating a plan**
2. **Ask clarifying questions** from these categories:
   - Functional requirements (what problem, success metrics, constraints)
   - Architecture considerations (scale, consistency, performance)
   - Code patterns (existing conventions, testing strategy, tooling)
   - Integration points (dependencies, external systems)
3. **Wait for answers** before proceeding to design or implementation
4. **Summarize your understanding** before moving forward

### Preferred Question Style
- Ask 5-8 focused questions, not 20+
- Group related questions together
- Ask "why" questions to understand intent, not just "what"
- Explain WHY each question matters (helps prioritize answers)
- Ask about constraints first (often eliminate options fastest)

### Example Format
Instead of: "Tell me about your system requirements"

Ask:
> Before I design this, I need to understand a few key things:
> 
> **Performance & Scale:** Is this handling 100 users or 100K? Real-time or batch? This affects whether we use caching, message queues, or async patterns.
> 
> **Consistency Model:** Do you need transactions and strong consistency, or is eventual consistency acceptable? Simpler architectures use the latter.
> 
> **Existing Patterns:** Do you have existing services I should match? I can reference them to keep the code cohesive.
> 
> What constraints should I prioritize first?

### Stop Assumptions
- Don't assume scalability needs (ask first)
- Don't assume error handling strategy (ask first)
- Don't assume the tech stack is fixed (ask first)
- Don't assume this is long-term or one-off (ask first)
- Don't build abstractions for hypothetical future needs (ask first)