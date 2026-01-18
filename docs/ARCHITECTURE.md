# Architecture Documentation

## System Overview

The Real-Time Call Translator uses a client-server architecture with real-time bidirectional communication via WebSockets. The system processes audio streams through a pipeline of speech recognition, translation, and speech synthesis services.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Mobile Clients                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │ User A   │  │ User B   │  │ User C   │  │ User D   │                │
│  │ Hebrew   │  │ English  │  │ Russian  │  │ English  │                │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
│       │             │             │             │                       │
└───────┼─────────────┼─────────────┼─────────────┼───────────────────────┘
        │             │             │             │
        └─────────────┴──────┬──────┴─────────────┘
                             │ WebSocket (Audio + JSON)
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Backend Services                                 │
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │   FastAPI   │◄──►│    Redis    │◄──►│   Worker    │                 │
│  │   Server    │    │   Streams   │    │  (Audio)    │                 │
│  └──────┬──────┘    └─────────────┘    └──────┬──────┘                 │
│         │                                      │                        │
│         ▼                                      ▼                        │
│  ┌─────────────┐              ┌────────────────────────────────┐       │
│  │ PostgreSQL  │              │     Google Cloud Platform      │       │
│  │  Database   │              │  ┌─────┐ ┌─────┐ ┌─────┐      │       │
│  └─────────────┘              │  │ STT │ │Trans│ │ TTS │      │       │
│                               │  └─────┘ └─────┘ └─────┘      │       │
│                               └────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Mobile Client (Flutter)

**Responsibilities:**
- User authentication and session management
- Audio capture (microphone) and playback (speaker)
- WebSocket connection management with reconnection
- Real-time UI updates (captions, transcripts)
- Contact management and call initiation

**Key Components:**

| Component | Purpose |
|-----------|---------|
| `AuthProvider` | Authentication state, JWT token management |
| `CallProvider` | Active call state, WebSocket communication |
| `LobbyProvider` | User presence, incoming call notifications |
| `AudioController` | Microphone recording, speaker playback, jitter buffer |
| `ContactsProvider` | Contact list, friend requests |

**Audio Pipeline:**
```
Microphone → PCM16 (16kHz) → Accumulate 100ms → WebSocket Binary
                                                      │
WebSocket Binary ← Jitter Buffer ← Speaker Playback ◄─┘
```

### 2. FastAPI Server

**Responsibilities:**
- REST API for authentication, calls, contacts, voice
- WebSocket endpoint for real-time communication
- JWT authentication and authorization
- Database operations (SQLAlchemy async)

**Key Modules:**

| Module | Path | Purpose |
|--------|------|---------|
| `api/auth.py` | `/auth/*` | User registration, login, profile |
| `api/calls.py` | `/calls/*` | Call lifecycle management |
| `api/contacts.py` | `/contacts/*` | Contact and friend request management |
| `api/voice.py` | `/voice/*` | Voice sample upload and training |
| `api/websocket/router.py` | `/ws/{session_id}` | WebSocket handling |

### 3. Session Orchestrator

**Location:** `app/services/session/orchestrator.py`

**Responsibilities:**
- Manages WebSocket session lifecycle per participant
- Handles JSON control messages (mute, leave, heartbeat)
- Routes binary audio to Redis streams for processing
- Broadcasts messages to all participants in a call

**Message Loop:**
```python
while connected:
    message = await websocket.receive()
    if message.type == TEXT:
        handle_json_message(message)  # mute, leave, ping
    elif message.type == BINARY:
        push_audio_to_redis(message)  # Audio processing
```

### 4. Audio Worker

**Location:** `app/services/audio/worker.py`

**Responsibilities:**
- Consumes audio chunks from Redis streams
- Coordinates STT, translation, and TTS pipeline
- Manages per-stream context for coherent translations
- Publishes results back via Redis pub/sub

**Processing Pipeline:**
```
Redis Stream → Speech Detection → Chunking → STT → Translation → TTS → Redis Pub/Sub
```

### 5. Translation Pipeline

**Location:** `app/services/translation/`

| Component | Purpose |
|-----------|---------|
| `processor.py` | Batch translation + TTS for accumulated audio |
| `streaming.py` | Low-latency streaming translation for final STT results |
| `tts_cache.py` | LRU cache for TTS audio to reduce API calls |

### 6. GCP Pipeline

**Location:** `app/services/gcp_pipeline.py`

**Responsibilities:**
- Google Cloud Speech-to-Text (STT)
- Google Cloud Translation API
- Google Cloud Text-to-Speech (TTS)
- Connection pooling and error handling

**API Usage:**
```
Audio (PCM16) → STT API → Text
Text (source lang) → Translation API → Text (target lang)
Text (target lang) → TTS API → Audio (PCM16)
```

### 7. Core Infrastructure

**Location:** `app/services/core/`

| Component | Purpose |
|-----------|---------|
| `repositories.py` | Centralized database queries for calls |
| `deduplicator.py` | TTL-based message deduplication |

---

## Data Flow

### Call Initiation Flow

```
1. User A taps "Start Call" with User B
   └─► POST /calls/start {participant_user_ids: ["user_b_id"]}

2. Backend creates Call + CallParticipant records
   └─► Returns {session_id, websocket_url}

3. Backend sends incoming_call notification to User B via Lobby WebSocket
   └─► User B sees incoming call screen

4. User B accepts call
   └─► POST /calls/{call_id}/accept

5. Both users connect to WebSocket
   └─► ws://server/ws/{session_id}?token=...&call_id=...

6. Audio streaming begins bidirectionally
```

### Audio Processing Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Mobile    │────►│   FastAPI   │────►│    Redis    │
│ (Audio PCM) │     │ (WebSocket) │     │  (Stream)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Mobile    │◄────│   FastAPI   │◄────│   Worker    │
│ (Playback)  │     │  (Pub/Sub)  │     │ (STT+Trans) │
└─────────────┘     └─────────────┘     └─────────────┘
```

### Interim Captions Flow (Real-time Typing Effect)

```
Audio → Streaming STT → Partial Results (every ~150ms)
                              │
                              ▼
                     interim_transcript message
                              │
                              ▼
                     Mobile UI (typing indicator)
                              │
                              ▼
                     Final Result → Full transcript + translation
```

---

## Database Schema

### Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│    User     │       │ CallParticipant │       │    Call     │
├─────────────┤       ├─────────────────┤       ├─────────────┤
│ id (PK)     │◄──┐   │ id (PK)         │   ┌──►│ id (PK)     │
│ phone       │   │   │ call_id (FK)────┼───┘   │ session_id  │
│ full_name   │   │   │ user_id (FK)────┼───┐   │ caller_id   │
│ password    │   │   │ language        │   │   │ is_active   │
│ language    │   └───┼─────────────────┤   │   │ status      │
│ is_online   │       │ is_muted        │   │   │ started_at  │
│ has_voice   │       │ is_connected    │   │   │ ended_at    │
└──────┬──────┘       └─────────────────┘   │   └─────────────┘
       │                                     │
       │  ┌─────────────────┐               │
       │  │    Contact      │               │
       │  ├─────────────────┤               │
       └──┤ user_id (FK)    │               │
          │ contact_id (FK)─┼───────────────┘
          │ contact_name    │
          │ status          │
          │ is_blocked      │
          └─────────────────┘

┌─────────────────┐       ┌─────────────────┐
│ CallTranscript  │       │ VoiceRecording  │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ call_id (FK)    │       │ user_id (FK)    │
│ speaker_id (FK) │       │ language        │
│ original_text   │       │ file_path       │
│ translated_text │       │ quality_score   │
│ timestamp_ms    │       │ is_processed    │
└─────────────────┘       └─────────────────┘
```

---

## Key Dependencies

### Backend

| Package | Version | Purpose |
|---------|---------|---------|
| fastapi | 0.109+ | Web framework |
| uvicorn | 0.27+ | ASGI server |
| sqlalchemy | 2.0+ | ORM (async) |
| asyncpg | 0.29+ | PostgreSQL async driver |
| redis | 5.0+ | Redis async client |
| google-cloud-speech | 2.23+ | Speech-to-Text |
| google-cloud-translate | 3.15+ | Translation |
| google-cloud-texttospeech | 2.16+ | Text-to-Speech |
| pyjwt | 2.8+ | JWT authentication |
| python-jose | 3.3+ | JWT handling |
| numpy | 1.26+ | Audio processing |

### Mobile

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | 3.35+ | Framework |
| provider | 6.1+ | State management |
| http | 1.2+ | REST API calls |
| web_socket_channel | 2.4+ | WebSocket |
| record | 5.1+ | Audio recording |
| flutter_sound | 9.6+ | Audio playback |
| shared_preferences | 2.2+ | Local storage |

---

## Deployment Topology

### Development

```
┌─────────────────────────────────────────────┐
│              Docker Compose                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │PostgreSQL│ │  Redis  │ │ Backend │       │
│  │  :5433   │ │  :6379  │ │  :8000  │       │
│  └─────────┘ └─────────┘ └─────────┘       │
│                           ┌─────────┐       │
│                           │ Worker  │       │
│                           └─────────┘       │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ Flutter Device  │
│ (Android/iOS)   │
└─────────────────┘
```

### Production (Recommended)

```
┌─────────────────────────────────────────────────────────┐
│                    Cloud Provider                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Load        │  │ API Server  │  │ Audio       │     │
│  │ Balancer    │──│ (multiple)  │──│ Workers     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│         │                │                │             │
│         ▼                ▼                ▼             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ PostgreSQL  │  │ Redis       │  │ GCP APIs    │     │
│  │ (managed)   │  │ (managed)   │  │             │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## Performance Characteristics

### Latency Targets

| Operation | Target | Actual |
|-----------|--------|--------|
| Speech-to-Text | <500ms | 200-400ms |
| Translation | <200ms | 100-150ms |
| Text-to-Speech | <300ms | 150-250ms |
| **End-to-end** | <2000ms | **1000-1500ms** |

### Audio Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Sample Rate | 16 kHz | Optimal for speech recognition |
| Bit Depth | 16-bit | Standard PCM quality |
| Channels | Mono | Voice only, saves bandwidth |
| Chunk Size | 100ms | Balance latency vs overhead |
| Jitter Buffer | 1-8 chunks | Smooth playback |

### Scaling Considerations

- **Horizontal Scaling**: API servers are stateless; scale behind load balancer
- **Worker Scaling**: Audio workers consume from Redis; add workers for throughput
- **Database**: Connection pooling (10 + 20 overflow)
- **Redis**: Streams provide ordered message queues per call session
- **GCP APIs**: Rate limits apply; implement request batching if needed

---

## Security Considerations

### Authentication
- JWT tokens with HS256 signing
- 7-day token expiration
- Token required for all authenticated endpoints

### Data Protection
- Passwords stored as-is (capstone scope; use bcrypt in production)
- No end-to-end encryption (audio passes through server)
- GCP credentials stored in file, not in environment

### Network
- CORS configured for specific origins
- WebSocket authentication via query parameter token
- HTTPS recommended for production

### Recommendations for Production
1. Use bcrypt for password hashing
2. Implement rate limiting
3. Add request validation/sanitization
4. Use secrets manager for credentials
5. Enable TLS for all connections
6. Implement audit logging
