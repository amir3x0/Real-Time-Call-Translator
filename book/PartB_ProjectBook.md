# Real-Time Call Translator
## Part B - Final Project Book

**Project Title:** Real-Time Multilingual Call Translation System with Voice Cloning

**Authors:**
- Amir Mishayev
- Daniel Fraimovich

**Institution:** Braude College of Engineering
**Department:** Software Engineering
**Submission Date:** January 2026

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Architecture](#2-system-architecture)
3. [Implementation Details](#3-implementation-details)
4. [Database Design](#4-database-design)
5. [Testing and Quality Assurance](#5-testing-and-quality-assurance)
6. [Conclusions and Future Work](#6-conclusions-and-future-work)

**Appendices:**
- [Appendix 1: User Guide](#appendix-1-user-guide)
- [Appendix 2: Maintenance Guide](#appendix-2-maintenance-guide)

---

## 1. Introduction

### 1.1 Problem Statement

In today's globalized world, real-time multilingual communication remains a significant challenge. Traditional phone calls are limited to participants who share a common language, creating barriers in personal, business, and emergency communication scenarios. Existing translation solutions require manual intervention, introduce significant delays, or lack the natural conversational flow necessary for effective communication.

Israel's diverse population, comprising speakers of Hebrew, English, Russian, Arabic, and other languages, exemplifies this challenge. Families with immigrant grandparents, international business calls, and emergency services all encounter language barriers that current technology inadequately addresses.

### 1.2 Project Goals

This project aims to develop a real-time multilingual call translation system that:

1. **Real-time Translation**: Translate speech between Hebrew, English, and Russian with minimal latency (<500ms for text, <1000ms for voice)
2. **Multi-party Support**: Enable calls with 2-4 simultaneous participants, each potentially speaking different languages
3. **Natural Communication**: Provide interim captions for immediate feedback while processing full translations
4. **Voice Preservation**: Implement voice cloning infrastructure to maintain speaker identity across translations
5. **Mobile-First**: Deliver a native mobile experience for Android and iOS platforms

### 1.3 Scope

**In Scope:**
- Three languages: Hebrew (he), English (en), Russian (ru)
- 2-4 participant calls
- Real-time speech recognition and translation
- Mobile application (Android primary, iOS secondary)
- Contact management and call history
- User authentication and profiles

**Out of Scope:**
- Additional languages beyond he/en/ru
- Video calling features
- Desktop or web clients
- End-to-end encryption (deferred to future work)

### 1.4 Technology Overview

The system comprises three main components:

| Component | Technology | Purpose |
|-----------|------------|---------|
| Backend | FastAPI (Python 3.11) | API services, WebSocket handling, translation orchestration |
| Mobile | Flutter (Dart) | Cross-platform mobile application |
| AI Services | Google Cloud Platform | Speech-to-Text, Translation, Text-to-Speech |

Additional infrastructure includes PostgreSQL for data persistence, Redis for caching and real-time audio streaming, and Docker for containerized deployment.

---

## 2. System Architecture

### 2.1 High-Level Architecture

The system follows a client-server architecture with the mobile application communicating with a centralized backend that orchestrates AI services.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MOBILE CLIENT                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │   Flutter   │  │   Audio     │  │  WebSocket  │                 │
│  │     UI      │  │  Recording  │  │   Client    │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS / WSS
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BACKEND SERVER                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │   FastAPI   │  │  WebSocket  │  │   Audio     │                 │
│  │    REST     │  │   Router    │  │   Worker    │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘                 │
│         │                │                │                         │
│         ▼                ▼                ▼                         │
│  ┌─────────────────────────────────────────────────────┐           │
│  │              SERVICE LAYER                           │           │
│  │  Session │ Connection │ Translation │ Call          │           │
│  └─────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
         │                                        │
         ▼                                        ▼
┌─────────────────┐                    ┌─────────────────────────────┐
│   PostgreSQL    │                    │     Google Cloud Platform    │
│   + Redis       │                    │  ┌─────┐ ┌─────┐ ┌─────┐   │
│                 │                    │  │ STT │ │Trans│ │ TTS │   │
└─────────────────┘                    │  └─────┘ └─────┘ └─────┘   │
                                       └─────────────────────────────┘
```

### 2.2 Component Details

#### 2.2.1 Backend Server (FastAPI)

The backend is built with FastAPI 0.104.1, leveraging Python's async/await patterns for efficient I/O handling. Key components:

- **REST API Layer** (`/backend/app/api/`): Handles authentication, user management, contacts, and call initiation
- **WebSocket Router**: Manages real-time bidirectional communication during calls
- **Audio Worker**: Processes incoming audio chunks, coordinates with GCP services
- **Service Layer**: Business logic for sessions, translations, and call management

#### 2.2.2 Mobile Client (Flutter)

The Flutter application provides a native experience on Android and iOS:

- **Provider Pattern**: State management using `ChangeNotifier` providers
- **WebSocket Integration**: Real-time communication for audio and captions
- **Audio Recording**: 16kHz mono PCM capture with 200ms chunking
- **RTL Support**: Full Hebrew right-to-left layout support

#### 2.2.3 Google Cloud Platform Services

Three primary GCP APIs power the translation pipeline:

| Service | Purpose | Configuration |
|---------|---------|---------------|
| Speech-to-Text | Convert audio to text | Streaming recognition, language-specific models |
| Cloud Translation | Translate between languages | Neural Machine Translation v3 |
| Text-to-Speech | Generate audio from translated text | WaveNet voices, SSML support |

### 2.3 Communication Flow

#### REST API Communication

Standard request-response for non-real-time operations:

```
POST /api/auth/login        - User authentication
GET  /api/contacts          - Retrieve contact list
POST /api/calls/initiate    - Start a new call
GET  /api/calls/{id}/history - Call transcript history
```

#### WebSocket Communication

Real-time bidirectional messaging during active calls:

```json
// Client → Server: Audio chunk
{
  "type": "audio",
  "data": "<base64_encoded_pcm>",
  "language": "he"
}

// Server → Client: Translation result
{
  "type": "translation",
  "original_text": "שלום",
  "translated_text": "Hello",
  "source_lang": "he",
  "target_lang": "en",
  "speaker_id": "user-uuid"
}

// Server → Client: Interim caption
{
  "type": "interim",
  "text": "שלום, מה...",
  "language": "he",
  "speaker_id": "user-uuid"
}
```

### 2.4 Audio Pipeline

The audio processing pipeline is optimized for low-latency translation:

```
┌──────────────────────────────────────────────────────────────────┐
│                      AUDIO PIPELINE                               │
│                                                                   │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐       │
│  │ Capture │───▶│ Chunk   │───▶│ Speech  │───▶│ Redis   │       │
│  │ 16kHz   │    │ 200ms   │    │ Detect  │    │ Stream  │       │
│  │ Mono    │    │ Buffers │    │ (FFT)   │    │         │       │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘       │
│                                                    │              │
│                    ┌───────────────────────────────┘              │
│                    ▼                                              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    DUAL-STREAM PROCESSING                    │ │
│  │                                                              │ │
│  │  Stream 1: Interim (Fast)     Stream 2: Batch (Accurate)    │ │
│  │  ┌─────────────────────┐      ┌─────────────────────┐       │ │
│  │  │ Real-time STT       │      │ Pause-based STT     │       │ │
│  │  │ → Interim captions  │      │ → Full translation  │       │ │
│  │  │ → Immediate display │      │ → Audio synthesis   │       │ │
│  │  └─────────────────────┘      └─────────────────────┘       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**

1. **16kHz Mono PCM**: Optimal balance between quality and bandwidth for speech
2. **200ms Chunks**: Small enough for low latency, large enough for reliable transmission
3. **FFT Speech Detection**: Filters silence to reduce unnecessary API calls
4. **Dual-Stream Processing**: Interim captions provide immediate feedback while batch processing ensures translation accuracy

### 2.5 Package/Deployment Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DOCKER COMPOSE DEPLOYMENT                        │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │    postgres     │  │      redis      │  │     adminer     │     │
│  │    Port: 5433   │  │   Port: 6379    │  │   Port: 8080    │     │
│  │                 │  │                 │  │   (Dev Only)    │     │
│  │  PostgreSQL 15  │  │    Redis 7      │  │                 │     │
│  │  + pgvector     │  │   alpine        │  │                 │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│           │                   │                                      │
│           └─────────┬─────────┘                                      │
│                     │                                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      backend                                 │   │
│  │                    Port: 8000                                │   │
│  │                                                              │   │
│  │   FastAPI + Uvicorn                                         │   │
│  │   - REST API endpoints                                      │   │
│  │   - WebSocket router                                        │   │
│  │   - GCP service integration                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                     │                                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      worker                                  │   │
│  │                    Port: 8001                                │   │
│  │                                                              │   │
│  │   Audio Processing Worker                                   │   │
│  │   - Redis stream consumer                                   │   │
│  │   - Translation pipeline                                    │   │
│  │   - Prometheus metrics (/metrics)                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD PLATFORM                             │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │  Speech-to-Text │  │   Translation   │  │  Text-to-Speech │     │
│  │     API v2      │  │     API v3      │  │      API        │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Vertex AI (Gemini 1.5 Flash)              │   │
│  │                    Context Resolution Service                │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Implementation Details

### 3.1 Backend Structure

The backend follows a layered architecture with clear separation of concerns:

```
backend/
├── app/
│   ├── api/                    # API Layer
│   │   ├── auth.py            # Authentication endpoints
│   │   ├── calls.py           # Call management
│   │   ├── contacts.py        # Contact operations
│   │   ├── users.py           # User profile
│   │   └── websocket_routes.py # WebSocket handling
│   │
│   ├── config/                 # Configuration
│   │   ├── settings.py        # Pydantic settings
│   │   ├── redis_client.py    # Redis connection
│   │   └── constants.py       # App constants
│   │
│   ├── models/                 # SQLAlchemy Models
│   │   ├── user.py            # User entity
│   │   ├── call.py            # Call session
│   │   ├── call_participant.py # Participants
│   │   ├── call_transcript.py # Transcriptions
│   │   ├── contact.py         # Contacts
│   │   └── voice_recording.py # Voice samples
│   │
│   ├── schemas/                # Pydantic Schemas
│   │   ├── auth.py            # Auth DTOs
│   │   ├── call.py            # Call DTOs
│   │   └── user.py            # User DTOs
│   │
│   └── services/               # Business Logic
│       ├── audio/             # Audio processing
│       │   ├── audio_chunker.py
│       │   ├── audio_worker.py
│       │   └── speech_detector.py
│       │
│       ├── call/              # Call management
│       │   ├── call_service.py
│       │   └── participant_service.py
│       │
│       ├── connection/        # WebSocket management
│       │   └── connection_manager.py
│       │
│       ├── session/           # Session orchestration
│       │   └── session_orchestrator.py
│       │
│       └── translation/       # Translation pipeline
│           ├── translation_processor.py
│           ├── tts_cache.py
│           └── context_resolver.py
│
├── alembic/                    # Database Migrations
├── tests/                      # pytest Tests
└── main.py                     # Application Entry
```

### 3.2 Key Backend Components

#### 3.2.1 Authentication Service (`/app/api/auth.py`)

Handles user registration, login, and session management:

- Phone number-based registration
- JWT token generation and validation
- Password verification (simplified for capstone)
- Session refresh mechanism

#### 3.2.2 Connection Manager (`/app/services/connection/connection_manager.py`)

Manages WebSocket connections for real-time communication:

- Connection pooling per session
- Participant tracking
- Message broadcasting to session participants
- Graceful disconnection handling

#### 3.2.3 Translation Processor (`/app/services/translation/translation_processor.py`)

Orchestrates the translation pipeline:

```python
async def process_audio(audio_chunk: bytes, source_lang: str) -> TranslationResult:
    # 1. Speech-to-Text
    text = await speech_to_text(audio_chunk, source_lang)

    # 2. Context Resolution (if needed)
    if needs_context_resolution(text):
        text = await resolve_context(text, conversation_history)

    # 3. Translation
    translations = {}
    for target_lang in target_languages:
        translations[target_lang] = await translate(text, source_lang, target_lang)

    # 4. Text-to-Speech (cached)
    audio_outputs = {}
    for lang, translated_text in translations.items():
        audio_outputs[lang] = await text_to_speech(translated_text, lang)

    return TranslationResult(text, translations, audio_outputs)
```

#### 3.2.4 Audio Worker (`/app/services/audio/audio_worker.py`)

Background worker processing audio from Redis streams:

- Consumes audio chunks from `stream:audio:{session_id}`
- Performs speech detection using FFT analysis
- Triggers translation pipeline on speech detection
- Publishes results back to participants

### 3.3 Mobile Structure

The Flutter application follows a feature-based organization:

```
mobile/lib/
├── config/                     # App Configuration
│   ├── app_config.dart        # API URLs, timeouts
│   ├── app_theme.dart         # Theme definitions
│   └── constants.dart         # App constants
│
├── core/                       # Core Utilities
│   ├── navigation.dart        # Route definitions
│   └── routes.dart            # Named routes
│
├── data/                       # Data Layer
│   ├── services/              # API Services
│   │   ├── auth_service.dart  # Authentication
│   │   ├── call_api_service.dart # Call operations
│   │   ├── contact_service.dart  # Contacts
│   │   └── voice_service.dart    # Voice recording
│   │
│   └── websocket/             # WebSocket
│       └── websocket_service.dart
│
├── models/                     # Data Models
│   ├── user.dart
│   ├── call.dart
│   ├── contact.dart
│   ├── participant.dart
│   └── interim_caption.dart
│
├── providers/                  # State Management
│   ├── auth_provider.dart     # Auth state
│   ├── call_provider.dart     # Active call state
│   ├── lobby_provider.dart    # Global WebSocket
│   ├── contacts_provider.dart # Contacts state
│   └── settings_provider.dart # App settings
│
├── screens/                    # UI Screens
│   ├── auth/                  # Login, Register
│   ├── call/                  # Active call UI
│   ├── contacts/              # Contact list
│   └── settings/              # Settings
│
└── widgets/                    # Reusable Components
    ├── caption_display.dart
    ├── participant_tile.dart
    └── call_controls.dart
```

### 3.4 Key Mobile Components

#### 3.4.1 Call Provider (`/lib/providers/call_provider.dart`)

Central state management for active calls:

- Manages WebSocket connection lifecycle
- Handles audio recording start/stop
- Processes incoming translations and captions
- Tracks participant states (mute, speaking, etc.)

#### 3.4.2 WebSocket Service (`/lib/data/websocket/websocket_service.dart`)

Handles real-time communication:

- Connection establishment with authentication
- Message serialization/deserialization
- Automatic reconnection on disconnect
- Event stream for providers

#### 3.4.3 Lobby Provider (`/lib/providers/lobby_provider.dart`)

Manages global WebSocket for out-of-call events:

- Incoming call notifications
- Contact request notifications
- User online/offline status updates

### 3.5 Key Algorithms

#### 3.5.1 Speech Detection (FFT Analysis)

```python
def detect_speech(audio_chunk: bytes, threshold: float = 0.02) -> bool:
    """
    Detect speech using FFT magnitude analysis.

    Args:
        audio_chunk: Raw PCM audio bytes
        threshold: Energy threshold for speech detection

    Returns:
        True if speech detected, False otherwise
    """
    # Convert bytes to numpy array
    samples = np.frombuffer(audio_chunk, dtype=np.int16)

    # Normalize to [-1, 1]
    normalized = samples.astype(np.float32) / 32768.0

    # Compute FFT
    fft_result = np.fft.rfft(normalized)
    magnitudes = np.abs(fft_result)

    # Focus on speech frequencies (300Hz - 3400Hz)
    speech_band = magnitudes[speech_freq_start:speech_freq_end]

    # Calculate energy
    energy = np.mean(speech_band ** 2)

    return energy > threshold
```

#### 3.5.2 Pause-Based Chunking

The system uses pause detection to segment continuous speech into translatable units:

1. Monitor audio energy levels continuously
2. When energy drops below threshold for >400ms, mark as pause
3. Segment audio at pause boundaries
4. Send complete segments for translation
5. Maintain interim captions during speech

#### 3.5.3 Context Resolution

For ambiguous translations, Vertex AI (Gemini 1.5 Flash) provides context resolution:

```python
async def resolve_context(text: str, history: list[str]) -> str:
    """
    Resolve ambiguous text using conversation context.

    Uses Gemini to understand pronouns, references, and
    context-dependent meanings.
    """
    prompt = f"""
    Given the conversation history:
    {history[-5:]}  # Last 5 exchanges

    Resolve any ambiguous references in:
    "{text}"

    Return the clarified text.
    """

    response = await vertex_ai.generate(prompt)
    return response.text
```

---

## 4. Database Design

### 4.1 Entity-Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DATABASE SCHEMA                               │
│                                                                      │
│  ┌─────────────────────┐         ┌─────────────────────┐           │
│  │        User         │         │        Call         │           │
│  ├─────────────────────┤         ├─────────────────────┤           │
│  │ id (PK)             │────┐    │ id (PK)             │           │
│  │ phone (UNIQUE)      │    │    │ session_id (UNIQUE) │           │
│  │ full_name           │    │    │ caller_user_id (FK)─┼───────┐   │
│  │ password            │    │    │ call_language       │       │   │
│  │ primary_language    │    │    │ is_active           │       │   │
│  │ theme_preference    │    │    │ status              │       │   │
│  │ is_online           │    │    │ started_at          │       │   │
│  │ last_seen           │    │    │ ended_at            │       │   │
│  │ has_voice_sample    │    │    │ duration_seconds    │       │   │
│  │ voice_model_trained │    │    │ participant_count   │       │   │
│  │ voice_quality_score │    │    │ created_at          │       │   │
│  │ created_at          │    │    └─────────────────────┘       │   │
│  │ updated_at          │    │              │                    │   │
│  └─────────────────────┘    │              │                    │   │
│           │                  │              │                    │   │
│           │                  │              ▼                    │   │
│           │                  │    ┌─────────────────────┐       │   │
│           │                  │    │  CallParticipant    │       │   │
│           │                  │    ├─────────────────────┤       │   │
│           │                  │    │ id (PK)             │       │   │
│           │                  ├───▶│ call_id (FK)        │       │   │
│           │                  │    │ user_id (FK)────────┼───────┤   │
│           │                  │    │ participant_language│       │   │
│           │                  │    │ joined_at           │       │   │
│           │                  │    │ left_at             │       │   │
│           │                  │    │ is_muted            │       │   │
│           │                  │    │ is_connected        │       │   │
│           │                  │    │ dubbing_required    │       │   │
│           │                  │    │ use_voice_clone     │       │   │
│           │                  │    │ voice_clone_quality │       │   │
│           │                  │    └─────────────────────┘       │   │
│           │                  │              │                    │   │
│           │                  │              ▼                    │   │
│           │                  │    ┌─────────────────────┐       │   │
│           │                  │    │   CallTranscript    │       │   │
│           │                  │    ├─────────────────────┤       │   │
│           │                  │    │ id (PK)             │       │   │
│           │                  │    │ call_id (FK)        │       │   │
│           │                  └───▶│ speaker_user_id(FK) │◀──────┘   │
│           │                       │ original_language   │           │
│           │                       │ original_text       │           │
│           │                       │ translated_text     │           │
│           │                       │ timestamp_ms        │           │
│           │                       │ created_at          │           │
│           │                       └─────────────────────┘           │
│           │                                                          │
│           │    ┌─────────────────────┐                              │
│           │    │      Contact        │                              │
│           │    ├─────────────────────┤                              │
│           ├───▶│ id (PK)             │                              │
│           │    │ user_id (FK)        │                              │
│           └───▶│ contact_user_id(FK) │                              │
│                │ contact_name        │                              │
│                │ is_blocked          │                              │
│                │ is_favorite         │                              │
│                │ status              │                              │
│                │ added_at            │                              │
│                └─────────────────────┘                              │
│           │                                                          │
│           │    ┌─────────────────────┐                              │
│           │    │   VoiceRecording    │                              │
│           │    ├─────────────────────┤                              │
│           └───▶│ id (PK)             │                              │
│                │ user_id (FK)        │                              │
│                │ language            │                              │
│                │ text_content        │                              │
│                │ file_path           │                              │
│                │ file_size_bytes     │                              │
│                │ quality_score       │                              │
│                │ is_processed        │                              │
│                │ used_for_training   │                              │
│                │ created_at          │                              │
│                └─────────────────────┘                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Key Relationships

| Relationship | Type | Description |
|--------------|------|-------------|
| User → Call | 1:N | One user can initiate many calls |
| Call → CallParticipant | 1:N | One call has 2-4 participants |
| User → CallParticipant | 1:N | One user can be in many calls |
| Call → CallTranscript | 1:N | One call has many transcript entries |
| User → Contact | 1:N | One user has many contacts |
| User → VoiceRecording | 1:N | One user can have multiple voice samples |

### 4.3 Key Constraints

1. **Unique Constraints**:
   - `users.phone`: Each phone number is unique
   - `calls.session_id`: Each session has a unique identifier
   - `(contacts.user_id, contacts.contact_user_id)`: No duplicate contact relationships
   - `(call_participants.call_id, call_participants.user_id)`: User can only join a call once

2. **Foreign Key Actions**:
   - `ON DELETE CASCADE`: Participants and transcripts deleted with call
   - `ON DELETE SET NULL`: Call retains record if user deleted

3. **Indexes**:
   - `users.phone`: Fast login lookup
   - `users.is_online`: Quick online user queries
   - `calls.session_id`: WebSocket routing
   - `calls.is_active`: Active call filtering
   - `call_participants.left_at`: Active participant filtering

---

## 5. Testing and Quality Assurance

### 5.1 Testing Strategy

The project employs a multi-layered testing approach:

| Layer | Framework | Coverage Focus |
|-------|-----------|----------------|
| Unit Tests | pytest | Individual functions and classes |
| Integration Tests | pytest-asyncio | Database and Redis operations |
| Mobile Tests | flutter_test | Widget and provider tests |
| Manual Testing | N/A | End-to-end call scenarios |

### 5.2 Backend Testing

#### Test Structure

```
backend/tests/
├── conftest.py              # pytest fixtures
├── test_auth.py             # Authentication tests
├── test_calls.py            # Call management tests
├── test_contacts.py         # Contact operations
├── test_translation.py      # Translation pipeline
└── test_websocket.py        # WebSocket handling
```

#### Key Fixtures

```python
@pytest.fixture
async def db_session():
    """Provide isolated database session for each test."""
    async with async_session() as session:
        yield session
        await session.rollback()

@pytest.fixture
def fake_redis():
    """Provide fakeredis instance for testing."""
    return fakeredis.FakeAsyncRedis()

@pytest.fixture
async def test_user(db_session):
    """Create a test user."""
    user = User(
        phone="+1234567890",
        full_name="Test User",
        password="testpass",
        primary_language="en"
    )
    db_session.add(user)
    await db_session.commit()
    return user
```

#### Running Tests

```bash
cd backend
pytest tests/ -v --asyncio-mode=auto
```

### 5.3 Mobile Testing

#### Test Structure

```
mobile/test/
├── providers/
│   ├── auth_provider_test.dart
│   └── call_provider_test.dart
├── services/
│   └── websocket_service_test.dart
└── widgets/
    └── caption_display_test.dart
```

#### Running Tests

```bash
cd mobile
flutter test
flutter analyze  # Static analysis
```

### 5.4 Manual Test Scenarios

| Scenario | Steps | Expected Result |
|----------|-------|-----------------|
| Two-party call | User A calls User B, both speak | Both see translations of each other |
| Multi-party call | User A creates call, invites B and C | All three see translations from others |
| Language switching | User changes language mid-call | Future translations use new language |
| Reconnection | Disconnect and reconnect during call | Call resumes without data loss |
| Incoming call | User B receives call while app is open | Notification shown, can accept/reject |

### 5.5 Code Quality Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| Black | Python formatting | `black backend/` |
| isort | Import sorting | `isort backend/` |
| mypy | Type checking | `mypy backend/` |
| flutter_lints | Dart linting | Automatic in IDE |

---

## 6. Conclusions and Future Work

### 6.1 Goals Achievement

| Goal | Status | Notes |
|------|--------|-------|
| Real-time translation (he, en, ru) | ✅ Complete | Latency <500ms for text |
| Multi-party calls (2-4 participants) | ✅ Complete | Tested with 4 simultaneous users |
| Interim captions | ✅ Complete | Immediate feedback during speech |
| Voice cloning | ⚠️ Partial | Infrastructure ready, training pipeline pending |
| Mobile application | ✅ Complete | Android fully functional, iOS builds successfully |

### 6.2 Technical Achievements

1. **Low-Latency Pipeline**: Achieved <500ms text translation latency through optimized audio chunking and parallel processing

2. **Dual-Stream Architecture**: Successfully implemented interim captions alongside batch translation for optimal user experience

3. **Scalable WebSocket Design**: Connection manager handles multiple concurrent sessions efficiently

4. **Context-Aware Translation**: Integrated Vertex AI for improved translation accuracy in conversational context

5. **Hebrew RTL Support**: Full bidirectional text support in mobile UI

### 6.3 Challenges Encountered

1. **Audio Latency Optimization**: Initial prototype had 2+ second delays. Solved through smaller chunks (200ms), FFT-based speech detection, and Redis streaming.

2. **Hebrew Speech Recognition**: Google STT required specific model configuration for Hebrew. Added language-specific model selection.

3. **WebSocket Stability**: Mobile WebSocket connections were unstable on poor networks. Implemented automatic reconnection with exponential backoff.

4. **Multi-participant Sync**: Ensuring all participants receive translations simultaneously required careful message ordering.

### 6.4 Lessons Learned

1. **Start with Audio Pipeline**: The audio processing pipeline is the foundation. Get it right early.

2. **Test with Real Languages**: Synthetic test data doesn't capture real-world speech patterns, especially for Hebrew.

3. **Mobile-First Considerations**: Network variability on mobile requires robust error handling and graceful degradation.

4. **API Cost Management**: GCP API calls add up quickly. Implemented caching and speech detection to reduce unnecessary calls.

### 6.5 Future Enhancements

#### Short-Term (Next Semester)
- Complete voice cloning integration with Coqui xTTS
- Add push notifications for incoming calls when app is backgrounded
- Implement call history and transcript viewing

#### Medium-Term (6-12 months)
- Support additional languages (Arabic, French, Spanish)
- Web client for desktop users
- End-to-end encryption for call audio

#### Long-Term (1-2 years)
- Custom speech recognition models for improved accuracy
- Real-time video translation (lip sync)
- Enterprise features (call recording, analytics)

### 6.6 Conclusion

The Real-Time Call Translator project successfully demonstrates the feasibility of multilingual real-time voice communication. By leveraging modern cloud AI services and optimized audio processing, the system achieves sub-second translation latency while maintaining natural conversational flow.

The modular architecture allows for future expansion to additional languages and features. While voice cloning infrastructure is in place, full integration remains as future work, providing a clear path for continued development.

This project contributes to breaking down language barriers in an increasingly connected world, enabling more natural communication across linguistic boundaries.

---

# Appendix 1: User Guide

## 1. Installation and Setup

### 1.1 System Requirements

| Platform | Minimum Requirements |
|----------|---------------------|
| Android | Android 8.0 (API 26) or higher, 2GB RAM |
| iOS | iOS 13.0 or higher, iPhone 6s or newer |

### 1.2 Installation

**Android:**
1. Download the APK file from the provided link
2. Open the file (you may need to enable "Install from unknown sources" in Settings → Security)
3. Follow the installation prompts
4. Grant the requested permissions

**iOS:**
1. Install via TestFlight (beta) or App Store (when available)
2. Follow the on-screen instructions

### 1.3 Required Permissions

The app requires the following permissions:

| Permission | Purpose |
|------------|---------|
| Microphone | Record your voice during calls |
| Internet | Connect to translation servers |
| Notifications | Receive incoming call alerts |

**[Screenshot 1: Permission request dialog]**

---

## 2. Registration and Login

### 2.1 Creating an Account

1. Open the app and tap "Register"
2. Enter your phone number (with country code)
3. Enter your full name
4. Create a password (minimum 6 characters)
5. Select your primary language (Hebrew, English, or Russian)
6. Tap "Register" to create your account

**[Screenshot 2: Registration form]**

### 2.2 Logging In

1. Open the app
2. Enter your phone number
3. Enter your password
4. Tap "Login"

**[Screenshot 3: Login screen]**

### 2.3 Selecting Your Language

Your primary language determines:
- The language you speak during calls
- Which translations you receive
- The app interface language

To change your language:
1. Go to Settings
2. Tap "Language"
3. Select your preferred language
4. Changes take effect immediately

---

## 3. Managing Contacts

### 3.1 Adding a Contact

1. From the main screen, tap the "+" button
2. Enter the phone number of the person you want to add
3. Tap "Send Request"
4. Wait for the person to accept your request

**[Screenshot 4: Add contact dialog]**

### 3.2 Accepting Contact Requests

1. Open the app
2. You'll see a notification badge on "Contacts"
3. Tap "Contacts" and then "Requests"
4. Tap "Accept" or "Reject" for each request

**[Screenshot 5: Contact request pending]**

### 3.3 Viewing Your Contacts

Your contacts are displayed on the main screen:
- **Green dot**: Contact is online
- **Gray dot**: Contact is offline
- **Star icon**: Favorite contact

**[Screenshot 6: Home/contacts screen]**

---

## 4. Making Calls

### 4.1 Starting a Call

1. Find the contact you want to call
2. Tap on their name
3. The call will connect automatically
4. Wait for the other person to accept

### 4.2 Receiving a Call

When someone calls you:
1. A notification appears with the caller's name
2. Tap "Accept" to answer or "Decline" to reject
3. The call screen appears when connected

**[Screenshot 7: Incoming call notification]**

### 4.3 During a Call

**[Screenshot 8: Active call screen]**

The call screen shows:
- **Participant names**: Who is in the call
- **Captions area**: Real-time translations appear here
- **Control buttons**: Mute, speaker, end call

### 4.4 Call Controls

| Button | Function |
|--------|----------|
| Mute | Turn your microphone on/off |
| Speaker | Switch between earpiece and speaker |
| End Call | Leave the call |

---

## 5. Understanding Translations

### 5.1 How It Works

1. You speak in your language
2. The app transcribes your speech
3. Your words are translated for other participants
4. They see the translation as text captions
5. The same process happens when they speak

### 5.2 Caption Display

**[Screenshot 9: Call with captions visible]**

Captions show:
- Speaker name and their language flag
- Original text (what they said)
- Translated text (in your language)

### 5.3 Interim vs Final Captions

- **Gray text**: Interim caption (still being processed)
- **White text**: Final translation (complete)

---

## 6. Multi-Participant Calls

### 6.1 Adding Participants

During a call:
1. Tap the "Add" button
2. Select a contact from your list
3. They will receive a call invitation
4. Up to 4 people can be in a call

**[Screenshot 10: Multi-participant call]**

### 6.2 Managing Participants

- Each participant's audio is translated to all other languages
- You see translations only in your language
- If someone leaves, the call continues with remaining participants

---

## 7. Settings

### 7.1 Accessing Settings

Tap the gear icon in the top right corner of the main screen.

**[Screenshot 11: Settings screen]**

### 7.2 Available Settings

| Setting | Options | Description |
|---------|---------|-------------|
| Theme | Light / Dark | Change app appearance |
| Language | he / en / ru | Change your primary language |
| Notifications | On / Off | Enable/disable call alerts |

### 7.3 Changing Theme

1. Go to Settings
2. Tap "Theme"
3. Select "Light" or "Dark"
4. Changes apply immediately

---

## 8. Troubleshooting

### 8.1 Common Issues

| Problem | Solution |
|---------|----------|
| No sound during call | Check microphone permission, ensure not muted |
| Translations not appearing | Check internet connection |
| Call not connecting | Ensure contact is online |
| App crashes | Update to latest version, restart device |

### 8.2 Getting Help

If you experience issues:
1. Check this troubleshooting guide
2. Restart the app
3. Check your internet connection
4. Contact support at [support email]

---

# Appendix 2: Maintenance Guide

## 1. Development Environment Setup

### 1.1 Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| Python | 3.11+ | Backend runtime |
| Node.js | 18+ | Build tools |
| Flutter | 3.0+ | Mobile development |
| Docker | 24+ | Container runtime |
| Docker Compose | 2.0+ | Multi-container orchestration |

### 1.2 Backend Setup

```bash
# Clone repository
git clone https://github.com/amir3x0/Real-Time-Call-Translator.git
cd Real-Time-Call-Translator/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or: venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env
# Edit .env with your configuration
```

### 1.3 Mobile Setup

```bash
cd mobile

# Install Flutter dependencies
flutter pub get

# Verify setup
flutter doctor

# Run on connected device
flutter run
```

---

## 2. Backend Deployment

### 2.1 Docker Compose Configuration

The `docker-compose.yml` defines all services:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    ports:
      - "5433:5432"
    environment:
      POSTGRES_USER: rtct_user
      POSTGRES_PASSWORD: SecurePass123
      POSTGRES_DB: rtct_db

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis

  worker:
    build: .
    command: python -m app.services.audio.audio_worker
    depends_on:
      - redis
```

### 2.2 Starting Services

```bash
cd backend

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backend

# Stop services
docker-compose down
```

### 2.3 Environment Variables

Required variables in `.env`:

```bash
# Database
DB_USER=rtct_user
DB_PASSWORD=SecurePass123
DB_NAME=rtct_db
DB_HOST=postgres
DB_PORT=5432

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=/app/google-credentials.json
GOOGLE_PROJECT_ID=your-project-id

# Security
JWT_SECRET_KEY=your-secret-key-here
DEBUG=false
```

### 2.4 Database Migrations

```bash
# Generate new migration
alembic revision --autogenerate -m "Description"

# Apply migrations
alembic upgrade head

# Rollback one version
alembic downgrade -1
```

---

## 3. Mobile Build and Release

### 3.1 Android Release Build

```bash
cd mobile

# Generate release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Generate App Bundle (for Play Store)
flutter build appbundle --release
```

### 3.2 Android Signing

1. Create keystore:
```bash
keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

2. Configure `android/key.properties`:
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=release
storeFile=../release-key.jks
```

### 3.3 iOS Build

```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for archive and upload
open ios/Runner.xcworkspace
```

---

## 4. Google Cloud Platform Configuration

### 4.1 Service Account Setup

1. Go to Google Cloud Console
2. Navigate to IAM & Admin → Service Accounts
3. Create new service account with roles:
   - Cloud Speech-to-Text User
   - Cloud Translation API User
   - Cloud Text-to-Speech User
   - Vertex AI User
4. Generate JSON key
5. Place as `google-credentials.json` in backend directory

### 4.2 API Enablement

Enable these APIs in GCP Console:
- Cloud Speech-to-Text API
- Cloud Translation API
- Cloud Text-to-Speech API
- Vertex AI API

### 4.3 Credentials File

The `google-credentials.json` file should contain:

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "service-account@project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

**CRITICAL**: Never commit this file to git. It's in `.gitignore`.

---

## 5. Monitoring and Logs

### 5.1 Prometheus Metrics

The worker exposes metrics at `http://localhost:8001/metrics`:

```
# Audio processing metrics
audio_chunks_processed_total
translation_latency_seconds
speech_detection_accuracy

# Call metrics
active_calls_count
participants_per_call
```

### 5.2 Log Locations

| Service | Log Location |
|---------|--------------|
| Backend | `docker logs backend` |
| Worker | `docker logs worker` |
| PostgreSQL | `docker logs postgres` |
| Redis | `docker logs redis` |

### 5.3 Log Format

```
2026-01-29 10:30:45.123 | INFO | [session_id] Message here
2026-01-29 10:30:45.456 | ERROR | [session_id] Error details
```

---

## 6. Common Issues and Troubleshooting

### 6.1 Database Connection Issues

**Symptom**: `Connection refused` errors

**Solutions**:
1. Verify PostgreSQL is running: `docker ps`
2. Check connection settings in `.env`
3. Ensure correct port mapping (5433:5432)
4. Run migrations: `alembic upgrade head`

### 6.2 Redis Connectivity

**Symptom**: `Redis connection failed`

**Solutions**:
1. Verify Redis is running: `docker ps`
2. Check REDIS_HOST and REDIS_PORT in `.env`
3. Test connection: `redis-cli -h localhost -p 6379 ping`

### 6.3 GCP Quota and Billing

**Symptom**: `RESOURCE_EXHAUSTED` errors

**Solutions**:
1. Check API quotas in GCP Console
2. Request quota increase if needed
3. Implement request throttling
4. Enable billing alerts

### 6.4 WebSocket Disconnections

**Symptom**: Frequent connection drops

**Solutions**:
1. Check server logs for error details
2. Verify client reconnection logic
3. Increase ping/pong timeout
4. Check for proxy/firewall issues

### 6.5 Translation Latency

**Symptom**: Translations appear slowly

**Solutions**:
1. Check GCP API response times
2. Verify Redis stream processing
3. Review audio chunk sizes
4. Enable TTS caching

---

## 7. Backup and Recovery

### 7.1 Database Backup

```bash
# Create backup
docker exec postgres pg_dump -U rtct_user rtct_db > backup.sql

# Restore backup
docker exec -i postgres psql -U rtct_user rtct_db < backup.sql
```

### 7.2 Redis Data

Redis data is ephemeral (audio streams). No backup needed for normal operation.

### 7.3 Voice Recordings

Voice recordings are stored in `backend/voice_recordings/`. Backup this directory for voice cloning data.

---

## 8. Security Considerations

### 8.1 Credentials Management

| Credential | Storage | Rotation |
|------------|---------|----------|
| GCP Service Account | File (not in git) | Annual |
| JWT Secret | Environment variable | On compromise |
| Database Password | Environment variable | Quarterly |

### 8.2 Production Checklist

- [ ] Change all default passwords
- [ ] Enable HTTPS for all endpoints
- [ ] Set `DEBUG=false`
- [ ] Configure firewall rules
- [ ] Enable GCP audit logging
- [ ] Set up monitoring alerts

---

*End of Part B Project Book*
