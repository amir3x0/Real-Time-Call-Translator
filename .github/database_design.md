# Real-Time Call Translation System - Database Design & Logic

**Project:** Multi-party Voice Call Translation with Voice Cloning  
**Status:** Complete Schema Definition  
**Date:** November 29, 2025  
**Language:** Hebrew/English  

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Database Schema](#database-schema)
3. [Core Logic & Workflows](#core-logic--workflows)
4. [Implementation Guide](#implementation-guide)
5. [SQL Setup](#sql-setup)
6. [Code Examples](#code-examples)

---

## System Overview

### Project Goal

Build a real-time multi-party voice call system where:
- Participants can speak in different languages
- Audio is automatically translated and transmitted
- Voice is cloned per user for personalization
- Calls are tracked and transcribed for history

### Key Principles

1. **Language-Based Translation:** Call language is determined by the caller's primary language
2. **Smart Dubbing:** Only participants with different languages need translation
3. **Voice Personalization:** Each user gets their own voice clone for outgoing audio
4. **Participant Limits:** 2-4 concurrent participants per call
5. **Call Persistence:** Calls remain active as long as 2+ participants are in them
6. **Complete History:** All calls and transcripts are stored indefinitely

---

## Database Schema

### Table 1: `users` - User Management

**Purpose:** Store user profiles, authentication, language preferences, and voice cloning status

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20),
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    
    -- Primary language (determines call language when user initiates)
    primary_language VARCHAR(10) NOT NULL DEFAULT 'he',
    
    -- Online status tracking
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Voice cloning attributes
    has_voice_sample BOOLEAN DEFAULT FALSE,
    voice_model_trained BOOLEAN DEFAULT FALSE,
    voice_quality_score INTEGER,  -- 1-100 (set after xTTS training)
    
    -- Profile metadata
    avatar_url VARCHAR(500),
    bio VARCHAR(500),
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint: Only valid languages
    CHECK (primary_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_users_is_online ON users(is_online);
CREATE INDEX idx_users_email ON users(email);

**Key Fields:**
- `primary_language`: Immutable language of the user (set at registration, never changes)
- `is_online`: Real-time status (updated when user connects/disconnects via WebSocket)
- `voice_model_trained`: TRUE only after successful xTTS training with 2-3 voice samples
- `voice_quality_score`: 1-100 range. >80 = use voice clone, <80 = fallback to Google TTS

---

### Table 2: `contacts` - Contact List Management

**Purpose:** Control who each user can call (authorization layer)

CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Optional: Custom name for contact
    contact_name VARCHAR(255),
    
    -- Timestamps
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Blocking (future feature)
    is_blocked BOOLEAN DEFAULT FALSE,
    
    -- Uniqueness: Each user can only have one contact record per contact
    UNIQUE(user_id, contact_user_id),
    
    -- Self-reference prevention
    CHECK (user_id != contact_user_id)
);

CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_contacts_contact_user_id ON contacts(contact_user_id);

**Business Logic:**
- Before initiating a call: Verify `Contact.exists(caller_id, target_id)`
- If contact doesn't exist: Reject the call initiation
- Allows for future permission models (group calls, public profiles, etc.)

---

### Table 3: `voice_recordings` - Voice Sample Storage

**Purpose:** Store raw voice samples used for training voice cloning models

CREATE TABLE voice_recordings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Language of this recording
    language VARCHAR(10) NOT NULL,
    
    -- Text the user read (for reference and training)
    text_content TEXT NOT NULL,
    
    -- File storage
    file_path VARCHAR(500) NOT NULL,  -- e.g., /uploads/voice/user_1_sample_1.wav
    file_size_bytes INTEGER,
    
    -- Quality assessment
    quality_score INTEGER,  -- 1-100 (assessed after upload)
    
    -- Processing status
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP,
    
    -- xTTS training flag
    used_for_training BOOLEAN DEFAULT FALSE,
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint
    CHECK (language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_voice_recordings_user_id ON voice_recordings(user_id);
CREATE INDEX idx_voice_recordings_used_for_training ON voice_recordings(used_for_training);

**Workflow:**
1. User uploads 2-3 voice samples (each ~15-30 seconds)
2. Each sample is stored in `voice_recordings` with `is_processed = FALSE`
3. Backend processes samples (quality check, noise reduction)
4. Set `is_processed = TRUE` and `quality_score`
5. Select best 2 samples and set `used_for_training = TRUE`
6. Feed to xTTS: Train voice model
7. After successful training: Update `users.voice_model_trained = TRUE` and `voice_quality_score`

---

### Table 4: `calls` - Call Session Management

**Purpose:** Track each call session (who called, language, duration, status)

CREATE TABLE calls (
    id SERIAL PRIMARY KEY,
    
    -- Caller (initiator)
    caller_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    
    -- Call language (always = caller's primary_language)
    call_language VARCHAR(10) NOT NULL,
    
    -- Active/inactive state
    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) NOT NULL DEFAULT 'ongoing',
    
    -- Timing
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    
    -- Participant count (updated dynamically)
    participant_count INTEGER DEFAULT 1,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CHECK (call_language IN ('he', 'en', 'ru')),
    CHECK (status IN ('ongoing', 'ended', 'missed'))
);

CREATE INDEX idx_calls_caller_user_id ON calls(caller_user_id);
CREATE INDEX idx_calls_is_active ON calls(is_active);
CREATE INDEX idx_calls_status ON calls(status);

**Business Logic:**
- `call_language` is IMMUTABLE (set at creation, never changes)
- `is_active = TRUE` while call has 2+ participants
- `is_active = FALSE` triggers when participant count drops below 2
- `duration_seconds` calculated ONLY when call ends: `(ended_at - started_at).total_seconds()`

---

### Table 5: `call_participants` - Per-Participant Call Metadata

**Purpose:** Track each participant in a call with language, dubbing requirements, and mute status

CREATE TABLE call_participants (
    id SERIAL PRIMARY KEY,
    call_id INTEGER NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Participant's language (from users.primary_language at join time)
    participant_language VARCHAR(10) NOT NULL,
    
    -- Timing
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP,  -- NULL = still in call
    
    -- Mute state (prevents audio streaming to this user)
    is_muted BOOLEAN DEFAULT FALSE,
    
    -- *** CRITICAL: Dubbing requirement (set at call initiation) ***
    -- TRUE if participant_language != call.call_language
    -- FALSE if participant_language == call.call_language
    dubbing_required BOOLEAN DEFAULT FALSE,
    
    -- *** Voice cloning preference ***
    -- TRUE = try to use xTTS with user's voice clone
    -- FALSE = use Google TTS (fallback)
    use_voice_clone BOOLEAN DEFAULT TRUE,
    
    -- Quality of user's voice clone
    voice_clone_quality VARCHAR(20),  -- 'excellent', 'good', 'fair', 'fallback'
    
    -- Notes
    notes TEXT,
    
    -- Uniqueness: One participant record per user per call
    UNIQUE(call_id, user_id),
    
    -- Constraint
    CHECK (participant_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_call_participants_call_id ON call_participants(call_id);
CREATE INDEX idx_call_participants_user_id ON call_participants(user_id);
CREATE INDEX idx_call_participants_left_at ON call_participants(left_at);

**Critical Fields:**
- `dubbing_required`: Determines audio routing (passthrough vs. translate+TTS)
- `use_voice_clone`: Determines which TTS engine to use
- `left_at`: NULL = active participant, NOT NULL = has left but call may continue

---

### Table 6: `call_transcripts` - Call History & Transcription

**Purpose:** Store complete word-by-word record of all calls for history and debugging

CREATE TABLE call_transcripts (
    id SERIAL PRIMARY KEY,
    call_id INTEGER NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    speaker_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    
    -- Original language of speaker
    original_language VARCHAR(10) NOT NULL,
    
    -- Original text (from STT)
    original_text TEXT NOT NULL,
    
    -- Translated text (if needed)
    translated_text TEXT,
    
    -- Timestamp relative to call start (milliseconds)
    timestamp_ms INTEGER,
    
    -- Audio file reference (if needed for playback)
    audio_file_path VARCHAR(500),
    
    -- Record creation time
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint
    CHECK (original_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_call_transcripts_call_id ON call_transcripts(call_id);
CREATE INDEX idx_call_transcripts_speaker_user_id ON call_transcripts(speaker_user_id);

**Workflow:**
1. Every time a participant speaks, create ONE record per listener group (or per language pair)
2. Store `original_text` (what was actually said)
3. Store `translated_text` (if translation occurred)
4. Use `timestamp_ms` to reconstruct timeline

---

## Core Logic & Workflows

### Workflow 1: User Registration & Voice Cloning

#### Phase 1a: Registration
User Action: Sign up
  ↓
Input: email, password, full_name, phone_number, primary_language
  ↓
Database:
  - Create users record
  - Set primary_language (immutable)
  - Set is_online = FALSE
  - Set voice_model_trained = FALSE

#### Phase 1b: Voice Sample Upload
User Action: Upload voice samples
  ↓
For each sample:
  - Input: audio file, text read, language
  - Validate: Audio length 15-30 seconds
  - Store: voice_recordings record
  - Set: is_processed = FALSE
  ↓
Backend Processing:
  - Analyze audio quality
  - Set quality_score (1-100)
  - Set is_processed = TRUE
  ↓
Selection:
  - Pick best 2 samples
  - Set used_for_training = TRUE

#### Phase 1c: Voice Model Training
Backend Task (xTTS):
  - Fetch voice_recordings WHERE used_for_training = TRUE
  - Train Coqui xTTS model
  - Generate voice_model_id (reference for future synthesis)
  ↓
Database Update:
  - users.voice_model_trained = TRUE
  - users.voice_quality_score = 85 (example: 1-100 scale)

---

### Workflow 2: Call Initiation & Participant Setup

#### Phase 2a: Pre-Call Validation
Caller Action: Initiate call to target user
  ↓
Validation Checks:
  ✓ Check: Contact exists?
    SELECT * FROM contacts 
    WHERE user_id = caller_id AND contact_user_id = target_id
    If NOT found → Reject with error "Contact not authorized"
  
  ✓ Check: Target is online?
    SELECT is_online FROM users WHERE id = target_id
    If is_online = FALSE → Reject with error "User offline"
  
  ✓ Check: No duplicate active call?
    SELECT * FROM calls 
    WHERE is_active = TRUE 
    AND call_id IN (
      SELECT call_id FROM call_participants WHERE user_id IN (caller_id, target_id)
    )
    If found → Reject with error "Already in call"

#### Phase 2b: Call Creation
Create calls record:
  - caller_user_id = caller_id
  - call_language = users[caller_id].primary_language  -- IMMUTABLE
  - is_active = TRUE
  - status = 'ongoing'
  - started_at = NOW()
  ↓
Insert call_id into database

#### Phase 2c: Participant Setup
For each participant (caller + target):
  participant = CallParticipant(
    call_id = newly_created_call.id,
    user_id = participant_id,
    participant_language = users[participant_id].primary_language,
    
    -- CRITICAL: Set dubbing_required based on language match
    dubbing_required = (participant_language != call_language),
    
    -- Voice clone availability
    use_voice_clone = users[participant_id].voice_model_trained,
    voice_clone_quality = 
      'excellent' if users[participant_id].voice_quality_score > 80 else
      'good' if users[participant_id].voice_quality_score > 60 else
      'fallback',
    
    joined_at = NOW()
  )

Example 1 (Same Language):
  Caller: Hebrew speaker, primary_language = 'he'
  Target: Hebrew speaker, primary_language = 'he'
  Result: 
    - Target's dubbing_required = FALSE (no translation needed)
    - Target receives audio directly (passthrough)

Example 2 (Different Language):
  Caller: Hebrew speaker, primary_language = 'he'
  Target: English speaker, primary_language = 'en'
  Result:
    - Target's dubbing_required = TRUE (needs translation)
    - Target receives translated + synthesized audio

---

### Workflow 3: Real-Time Audio Processing & Routing

#### Phase 3a: Audio Ingestion
User speaks into microphone
  ↓
Client sends audio chunk (WebSocket)
  ↓
Backend receives:
  - call_id
  - speaker_id
  - audio_buffer (PCM data)
  ↓
Fetch call & participant data:
  - call = Call.get_by_id(call_id)
  - speaker = User.get_by_id(speaker_id)
  - participants = CallParticipant.filter(call_id=call_id, user_id != speaker_id)

#### Phase 3b: Voice Cloning (Speaker → System)
Step 1: Apply Speaker's Voice Clone
  If speaker.voice_model_trained AND speaker.voice_quality_score > 60:
    cloned_audio = xTTS_apply_voice_clone(
      input_audio=audio_buffer,
      user_id=speaker_id,
      language=speaker.primary_language
    )
    quality_status = "voice_clone_applied"
  Else:
    cloned_audio = audio_buffer  -- Use original voice
    quality_status = "original_voice"

Result: cloned_audio now sounds like the speaker's trained voice

#### Phase 3c: Speech-to-Text (System Processing)
Step 2: Convert Audio → Text
  original_text = speech_to_text(
    audio=cloned_audio,
    language=speaker.primary_language
  )

Example:
  Input: Hebrew audio (cloned)
  Output: "שלום, איך אתה?"

#### Phase 3d: Per-Participant Audio Routing
Step 3: For each listener, determine audio path

FOR EACH participant IN participants WHERE is_muted = FALSE:
  
  CASE 1: Participant speaks same language as speaker (dubbing_required = FALSE)
  ─────────────────────────────────────────────────────────────
    Path: Passthrough (Direct Audio)
    
    send_audio_to_listener(
      listener_id=participant.user_id,
      audio=cloned_audio,  -- Send cloned audio directly
      format='opus'
    )
    
    Transcript:
      CREATE call_transcripts(
        call_id, speaker_user_id, 
        original_language=speaker.primary_language,
        original_text="שלום, איך אתה?",
        translated_text=NULL,  -- No translation
        timestamp_ms=current_time_in_call
      )
  
  
  CASE 2: Participant speaks different language (dubbing_required = TRUE)
  ──────────────────────────────────────────────────────────────────────
    Path: Translate → Synthesize → Send
    
    Step 2a: Translate Text
      translated_text = translate(
        text=original_text,
        from_lang=speaker.primary_language,
        to_lang=participant.participant_language
      )
      Result: "Hello, how are you?"
    
    Step 2b: Choose TTS Engine
      If participant.use_voice_clone AND participant.voice_clone_quality != 'fallback':
        synthesized_audio = xTTS_synthesize(
          text=translated_text,
          language=participant.participant_language,
          voice_model_id=participant.user_id,
          quality_level=participant.voice_clone_quality
        )
        synthesis_method = "xTTS_voice_clone"
      Else:
        synthesized_audio = google_tts_synthesize(
          text=translated_text,
          language=participant.participant_language
        )
        synthesis_method = "google_tts_fallback"
    
    Step 2c: Send to Listener
      send_audio_to_listener(
        listener_id=participant.user_id,
        audio=synthesized_audio,
        format='opus'
      )
    
    Transcript:
      CREATE call_transcripts(
        call_id, speaker_user_id,
        original_language=speaker.primary_language,
        original_text="שלום, איך אתה?",
        translated_text="Hello, how are you?",
        timestamp_ms=current_time_in_call
      )

#### Phase 3e: Mute Handling
Step 4: Respect Mute Status
  IF participant.is_muted = TRUE:
    Do NOT send audio to this listener
    (Listener can hear but speaker cannot be heard by muted participant)

---

### Workflow 4: Call Termination & History

#### Phase 4a: Participant Leaves
User Action: Hang up / disconnect
  ↓
Database Update:
  UPDATE call_participants
  SET left_at = NOW()
  WHERE call_id = call_id AND user_id = user_id
  ↓
Count active participants (left_at IS NULL):
  active_count = SELECT COUNT(*) FROM call_participants
                 WHERE call_id = call_id AND left_at IS NULL

#### Phase 4b: Call Termination Logic
CONDITION: active_count < 2 (fewer than 2 people in call)
  ↓
THEN:
  UPDATE calls
  SET is_active = FALSE,
      status = 'ended',
      ended_at = NOW(),
      duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))
  WHERE id = call_id
  ↓
  Notify remaining participants: Call ended

CONDITION: active_count >= 2 (still 2+ people)
  ↓
  THEN: Call continues, no action needed

#### Phase 4c: Call History Persistence
After call ends:
  - All call_transcripts records remain (permanent history)
  - All call_participants records remain
  - calls record marked as 'ended'
  ↓
User can later query:
  - SELECT * FROM calls WHERE caller_user_id = user_id AND status = 'ended'
  - SELECT * FROM call_transcripts WHERE call_id = ? ORDER BY timestamp_ms
  - Full conversation replay available

---

## Implementation Guide

### Prerequisites

**Database Setup:**
- PostgreSQL 12+
- Python 3.9+
- SQLAlchemy ORM

**Python Dependencies:**
pip install sqlalchemy psycopg2-binary
pip install alembic  # For schema migrations

**Audio Processing:**
pip install openai-whisper  # STT
pip install google-cloud-texttospeech  # Google TTS fallback
pip install coqui-tts  # xTTS for voice cloning
pip install pydub  # Audio processing

---

### Database Connection

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DATABASE_URL = "postgresql://user:password@localhost/realtime_translation"
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

---

### Schema Initialization

from sqlalchemy.orm import declarative_base

Base = declarative_base()

# Import all models
from models import User, Contact, VoiceRecording, Call, CallParticipant, CallTranscript

# Create all tables
Base.metadata.create_all(bind=engine)

---

## SQL Setup

### Complete SQL Schema

-- ===== TABLE 1: users =====
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20),
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    primary_language VARCHAR(10) NOT NULL DEFAULT 'he',
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    has_voice_sample BOOLEAN DEFAULT FALSE,
    voice_model_trained BOOLEAN DEFAULT FALSE,
    voice_quality_score INTEGER,
    avatar_url VARCHAR(500),
    bio VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (primary_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_users_is_online ON users(is_online);
CREATE INDEX idx_users_email ON users(email);

-- ===== TABLE 2: contacts =====
CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_name VARCHAR(255),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_blocked BOOLEAN DEFAULT FALSE,
    UNIQUE(user_id, contact_user_id),
    CHECK (user_id != contact_user_id)
);

CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_contacts_contact_user_id ON contacts(contact_user_id);

-- ===== TABLE 3: voice_recordings =====
CREATE TABLE voice_recordings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL,
    text_content TEXT NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size_bytes INTEGER,
    quality_score INTEGER,
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP,
    used_for_training BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_voice_recordings_user_id ON voice_recordings(user_id);
CREATE INDEX idx_voice_recordings_used_for_training ON voice_recordings(used_for_training);

-- ===== TABLE 4: calls =====
CREATE TABLE calls (
    id SERIAL PRIMARY KEY,
    caller_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    call_language VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) NOT NULL DEFAULT 'ongoing',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    participant_count INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (call_language IN ('he', 'en', 'ru')),
    CHECK (status IN ('ongoing', 'ended', 'missed'))
);

CREATE INDEX idx_calls_caller_user_id ON calls(caller_user_id);
CREATE INDEX idx_calls_is_active ON calls(is_active);
CREATE INDEX idx_calls_status ON calls(status);

-- ===== TABLE 5: call_participants =====
CREATE TABLE call_participants (
    id SERIAL PRIMARY KEY,
    call_id INTEGER NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    participant_language VARCHAR(10) NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP,
    is_muted BOOLEAN DEFAULT FALSE,
    dubbing_required BOOLEAN DEFAULT FALSE,
    use_voice_clone BOOLEAN DEFAULT TRUE,
    voice_clone_quality VARCHAR(20),
    notes TEXT,
    UNIQUE(call_id, user_id),
    CHECK (participant_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_call_participants_call_id ON call_participants(call_id);
CREATE INDEX idx_call_participants_user_id ON call_participants(user_id);
CREATE INDEX idx_call_participants_left_at ON call_participants(left_at);

-- ===== TABLE 6: call_transcripts =====
CREATE TABLE call_transcripts (
    id SERIAL PRIMARY KEY,
    call_id INTEGER NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    speaker_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    original_language VARCHAR(10) NOT NULL,
    original_text TEXT NOT NULL,
    translated_text TEXT,
    timestamp_ms INTEGER,
    audio_file_path VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (original_language IN ('he', 'en', 'ru'))
);

CREATE INDEX idx_call_transcripts_call_id ON call_transcripts(call_id);
CREATE INDEX idx_call_transcripts_speaker_user_id ON call_transcripts(speaker_user_id);

---

## Code Examples

### Example 1: User Registration Flow

from sqlalchemy.orm import Session
from models import User
import hashlib

def register_user(
    db: Session,
    email: str,
    full_name: str,
    password: str,
    phone_number: str,
    primary_language: str = 'he'
) -> User:
    """Register new user with voice cloning capabilities"""
    
    # Hash password
    hashed_password = hashlib.sha256(password.encode()).hexdigest()
    
    # Create user
    user = User(
        email=email,
        full_name=full_name,
        hashed_password=hashed_password,
        phone_number=phone_number,
        primary_language=primary_language,
        is_online=False,
        has_voice_sample=False,
        voice_model_trained=False
    )
    
    db.add(user)
    db.commit()
    db.refresh(user)
    
    return user


# Usage
user = register_user(
    db=db,
    email="user@example.com",
    full_name="יוסי כהן",
    password="secure_password",
    phone_number="972501234567",
    primary_language='he'
)

---

### Example 2: Call Initiation with Participant Setup

from sqlalchemy.orm import Session
from datetime import datetime
from models import Call, CallParticipant, Contact, User

def initiate_call(
    db: Session,
    caller_id: int,
    target_id: int
) -> Call:
    """
    Initiate call between two users.
    Returns Call object or raises exception if validation fails.
    """
    
    # VALIDATION 1: Check contact exists
    contact = db.query(Contact).filter(
        Contact.user_id == caller_id,
        Contact.contact_user_id == target_id
    ).first()
    
    if not contact:
        raise PermissionError("Target user not in contacts")
    
    # VALIDATION 2: Check target is online
    target = db.query(User).filter(User.id == target_id).first()
    if not target.is_online:
        raise ValueError("Target user is offline")
    
    # VALIDATION 3: Check no active call exists
    active_calls = db.query(Call).filter(
        Call.is_active == True,
        Call.id.in_(
            db.query(CallParticipant.call_id).filter(
                CallParticipant.user_id.in_([caller_id, target_id])
            )
        )
    ).all()
    
    if active_calls:
        raise RuntimeError("Already in an active call")
    
    # Get caller's language
    caller = db.query(User).filter(User.id == caller_id).first()
    
    # CREATE CALL
    call = Call(
        caller_user_id=caller_id,
        call_language=caller.primary_language,  # IMMUTABLE
        is_active=True,
        status='ongoing',
        started_at=datetime.now()
    )
    
    db.add(call)
    db.flush()  # Get call.id without committing
    
    # ADD PARTICIPANTS
    for participant_id in [caller_id, target_id]:
        user = db.query(User).filter(User.id == participant_id).first()
        
        # Determine if dubbing needed
        dubbing_needed = (user.primary_language != call.call_language)
        
        # Determine voice clone quality
        if user.voice_model_trained and user.voice_quality_score > 80:
            voice_quality = 'excellent'
        elif user.voice_model_trained and user.voice_quality_score > 60:
            voice_quality = 'good'
        else:
            voice_quality = 'fallback'
        
        participant = CallParticipant(
            call_id=call.id,
            user_id=participant_id,
            participant_language=user.primary_language,
            dubbing_required=dubbing_needed,
            use_voice_clone=user.voice_model_trained,
            voice_clone_quality=voice_quality,
            joined_at=datetime.now()
        )
        
        db.add(participant)
    
    db.commit()
    db.refresh(call)
    
    return call


# Usage
try:
    call = initiate_call(db, caller_id=1, target_id=2)
    print(f"Call initiated: {call.id}, Language: {call.call_language}")
except Exception as e:
    print(f"Call failed: {e}")

---

### Example 3: Real-Time Audio Routing

from sqlalchemy.orm import Session
from models import Call, CallParticipant, CallTranscript, User
from datetime import datetime
from typing import List, Dict
import asyncio

async def process_incoming_audio(
    db: Session,
    call_id: int,
    speaker_id: int,
    audio_buffer: bytes,
    current_time_ms: int
) -> Dict[str, any]:
    """
    Process incoming audio from speaker and route to all listeners.
    Returns routing information for logging/debugging.
    """
    
    # Fetch call and speaker info
    call = db.query(Call).filter(Call.id == call_id).first()
    if not call or not call.is_active:
        raise ValueError("Call not active")
    
    speaker = db.query(User).filter(User.id == speaker_id).first()
    
    # STEP 1: Apply voice cloning (speaker's voice)
    if speaker.voice_model_trained and speaker.voice_quality_score > 60:
        cloned_audio = apply_voice_clone(audio_buffer, speaker_id)
        voice_status = "cloned"
    else:
        cloned_audio = audio_buffer
        voice_status = "original"
    
    # STEP 2: STT - Convert to text
    original_text = speech_to_text(cloned_audio, speaker.primary_language)
    
    # STEP 3: Route to each listener
    participants = db.query(CallParticipant).filter(
        CallParticipant.call_id == call_id,
        CallParticipant.user_id != speaker_id,
        CallParticipant.is_muted == False,
        CallParticipant.left_at.is_(None)
    ).all()
    
    routing_results = []
    
    for participant in participants:
        
        if not participant.dubbing_required:
            # CASE 1: Passthrough (same language)
            audio_to_send = cloned_audio
            translated_text = None
            synthesis_method = "passthrough"
            
        else:
            # CASE 2: Translate + Synthesize
            translated_text = translate(
                original_text,
                from_lang=speaker.primary_language,
                to_lang=participant.participant_language
            )
            
            if participant.use_voice_clone and participant.voice_clone_quality != 'fallback':
                audio_to_send = xTTS_synthesize(
                    translated_text,
                    participant.participant_language,
                    participant.user_id
                )
                synthesis_method = "xTTS"
            else:
                audio_to_send = google_tts_synthesize(
                    translated_text,
                    participant.participant_language
                )
                synthesis_method = "google_tts"
        
        # Send audio via WebSocket
        await send_audio_to_listener(
            participant.user_id,
            audio_to_send
        )
        
        # Record routing
        routing_results.append({
            'listener_id': participant.user_id,
            'dubbing_required': participant.dubbing_required,
            'synthesis_method': synthesis_method
        })
    
    # STEP 4: Save transcript
    transcript = CallTranscript(
        call_id=call_id,
        speaker_user_id=speaker_id,
        original_language=speaker.primary_language,
        original_text=original_text,
        translated_text=translated_text if participants[0].dubbing_required else None,
        timestamp_ms=current_time_ms
    )
    
    db.add(transcript)
    db.commit()
    
    return {
        'status': 'success',
        'voice_status': voice_status,
        'listeners_reached': len(routing_results),
        'routing': routing_results
    }


# Usage (in WebSocket handler)
@app.websocket("/ws/call/{call_id}")
async def websocket_call(websocket: WebSocket, call_id: int):
    await websocket.accept()
    
    speaker_id = websocket.scope.get('user_id')
    start_time = datetime.now()
    
    while True:
        audio_chunk = await websocket.receive_bytes()
        elapsed_ms = (datetime.now() - start_time).total_seconds() * 1000
        
        try:
            result = await process_incoming_audio(
                db=db,
                call_id=call_id,
                speaker_id=speaker_id,
                audio_buffer=audio_chunk,
                current_time_ms=int(elapsed_ms)
            )
        except Exception as e:
            await websocket.send_json({'error': str(e)})

---

### Example 4: Call Termination Logic

from sqlalchemy.orm import Session
from models import Call, CallParticipant
from datetime import datetime

def handle_participant_left(
    db: Session,
    call_id: int,
    user_id: int
) -> bool:
    """
    Handle participant leaving call.
    Returns True if call ended, False if call continues.
    """
    
    # Mark participant as left
    participant = db.query(CallParticipant).filter(
        CallParticipant.call_id == call_id,
        CallParticipant.user_id == user_id
    ).first()
    
    if not participant:
        return False
    
    participant.left_at = datetime.now()
    
    # Count active participants (still in call)
    active_count = db.query(CallParticipant).filter(
        CallParticipant.call_id == call_id,
        CallParticipant.left_at.is_(None)
    ).count()
    
    # Check if call should end
    if active_count < 2:
        # End call
        call = db.query(Call).filter(Call.id == call_id).first()
        call.is_active = False
        call.status = 'ended'
        call.ended_at = datetime.now()
        call.duration_seconds = int(
            (call.ended_at - call.started_at).total_seconds()
        )
        
        db.commit()
        return True
    else:
        # Call continues
        db.commit()
        return False


# Usage
call_ended = handle_participant_left(db, call_id=1, user_id=2)
if call_ended:
    print("Call terminated")
else:
    print("Call continues")

---

### Example 5: Retrieving Call History

from sqlalchemy.orm import Session
from models import Call, CallTranscript
from datetime import datetime

def get_user_call_history(
    db: Session,
    user_id: int,
    limit: int = 20
) -> List[Dict]:
    """Get user's recent calls with transcripts"""
    
    calls = db.query(Call).filter(
        Call.caller_user_id == user_id
    ).order_by(
        Call.started_at.desc()
    ).limit(limit).all()
    
    history = []
    
    for call in calls:
        # Get participants
        participants = db.query(CallParticipant).filter(
            CallParticipant.call_id == call.id
        ).all()
        
        # Get transcripts
        transcripts = db.query(CallTranscript).filter(
            CallTranscript.call_id == call.id
        ).order_by(
            CallTranscript.timestamp_ms
        ).all()
        
        call_data = {
            'call_id': call.id,
            'initiated_at': call.started_at,
            'ended_at': call.ended_at,
            'duration_seconds': call.duration_seconds,
            'language': call.call_language,
            'participant_count': len(participants),
            'transcript': [
                {
                    'speaker_id': t.speaker_user_id,
                    'original_text': t.original_text,
                    'translated_text': t.translated_text,
                    'timestamp_ms': t.timestamp_ms
                }
                for t in transcripts
            ]
        }
        
        history.append(call_data)
    
    return history


# Usage
history = get_user_call_history(db, user_id=1, limit=10)
for call in history:
    print(f"Call {call['call_id']}: {call['duration_seconds']}s")
    for line in call['transcript']:
        print(f"  [{line['timestamp_ms']}ms] {line['original_text']}")

---

## Summary

| Component | Purpose | Key Tables |
|-----------|---------|-----------|
| **User Management** | Registration, language selection, voice training | `users`, `voice_recordings` |
| **Contact Authorization** | Control call permissions | `contacts` |
| **Call Session** | Track active calls and metadata | `calls`, `call_participants` |
| **Real-Time Routing** | Dynamic audio path based on language | `call_participants.dubbing_required` |
| **History & Transcripts** | Permanent record of all communications | `call_transcripts` |

---

## Key Takeaways

✅ **Language-Based Design:** Call language immutable, set by caller  
✅ **Smart Dubbing:** Only applied when languages differ  
✅ **Voice Personalization:** Each user gets trained voice clone  
✅ **Flexible TTS:** Fallback from xTTS to Google TTS available  
✅ **Call Persistence:** Remains active until <2 participants  
✅ **Complete History:** All transcripts stored indefinitely  
✅ **Proper Indexing:** Performance optimized for queries  

---

**Document Version:** 1.0  
**Last Updated:** November 29, 2025  
**Author:** Database Architecture Team