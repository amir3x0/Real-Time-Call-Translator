# Transcription Pipeline Fix Plan

## Executive Summary

The real-time call translator has **critical thread-safety and race condition bugs** that cause transcription to stop working when speakers alternate. This document details each problem and its fix.

---

## Current Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            MOBILE CLIENT                                     │
│  Speaker A (Amir)                              Speaker B (Daniel)            │
│       │                                              │                       │
│       └──────────────── WebSocket ──────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND: CallOrchestrator                            │
│                                                                              │
│  Receives binary audio frames → Publishes to Redis Stream                   │
│  Subscribes to Redis Pub/Sub → Forwards results back to mobile              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         REDIS STREAM: "stream:audio:global"                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND: Worker Process                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TWO PARALLEL PIPELINES                            │    │
│  │                                                                      │    │
│  │  PATH A: Batch STT (Pause-Based)     PATH B: Streaming STT (Real-Time)   │
│  │  ─────────────────────────────────   ────────────────────────────────    │
│  │                                                                      │    │
│  │  Audio → StreamManager               Audio → InterimCaptionService  │    │
│  │       → AudioChunker                      → Google Streaming STT    │    │
│  │       → Pause Detection                   → interim_transcript msgs │    │
│  │       → Accumulated Audio                 → on is_final=True:       │    │
│  │       → STT + Translate + TTS                  → StreamingTranslationProcessor
│  │       → Publish to Redis Pub/Sub              → Translate + TTS     │    │
│  │                                               → Publish to Redis    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REDIS PUB/SUB: "channel:translation:{session_id}"         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         Back to CallOrchestrator → Mobile
```

---

## Problem #1: StreamManager is NOT Thread-Safe

### Location
`backend/app/services/audio/stream_manager.py`

### Current Code (BUGGY)
```python
class StreamManager:
    def __init__(self):
        self._streams: Dict[str, StreamInfo] = {}  # ← NO LOCK!

    def create_stream(self, session_id: str, speaker_id: str) -> queue.Queue:
        key = self._get_key(session_id, speaker_id)

        if key in self._streams:  # ← Thread A reads here
            # ... check if task is dead ...
            del self._streams[key]  # ← Thread B might be reading/writing!

        audio_queue = queue.Queue()
        self._streams[key] = StreamInfo(...)  # ← Race condition!
        return audio_queue

    def has_stream(self, session_id: str, speaker_id: str) -> bool:
        key = self._get_key(session_id, speaker_id)
        if key not in self._streams:  # ← Thread A checks
            return False
        # ← Thread B might delete the key right here!
        stream_info = self._streams[key]  # ← KeyError possible!
        # ...

    def push_audio(self, session_id: str, speaker_id: str, audio_data: bytes) -> bool:
        key = self._get_key(session_id, speaker_id)
        if key not in self._streams:  # ← Check
            return False
        # ← Another thread deletes key here
        self._streams[key].audio_queue.put_nowait(audio_data)  # ← KeyError!
```

### What Happens During Speaker Switch
```
Timeline:
─────────────────────────────────────────────────────────────────────────────

T0: Speaker A (Amir) is speaking
    - StreamManager has: {"session:amir": StreamInfo(task=running)}

T1: Amir goes silent for 30+ seconds
    - Batch processing task completes (times out waiting for audio)
    - StreamManager has: {"session:amir": StreamInfo(task=DONE)}

T2: Daniel starts speaking, audio arrives at worker
    Worker Thread 1:
    - process_stream_message() for Daniel
    - Calls: stream_manager.has_stream("session", "daniel") → False
    - Calls: stream_manager.create_stream("session", "daniel")
    - StreamManager now has: {"session:amir": ..., "session:daniel": ...}

T3: Amir speaks again (unmutes), audio arrives at worker
    Worker Thread 2 (or same thread, different iteration):
    - process_stream_message() for Amir
    - Calls: stream_manager.has_stream("session", "amir")

    INSIDE has_stream():
      - key = "session:amir"
      - key in self._streams → True
      - stream_info = self._streams[key]
      - stream_info.task.done() → True (task finished at T1)
      - del self._streams[key]  ← DELETE HAPPENS HERE
      - return False

    - Calls: stream_manager.create_stream("session", "amir")
    - Creates NEW queue for Amir

T4: RACE CONDITION - Daniel's second audio chunk arrives
    Worker processes Daniel's chunk:
    - Calls: stream_manager.push_audio("session", "daniel", audio_data)

    INSIDE push_audio():
      - key = "session:daniel"
      - if key not in self._streams → False (daniel exists)
      - self._streams[key].audio_queue.put_nowait(audio_data)  ← OK

    BUT if timing is slightly different:

T4': ALTERNATIVE RACE - Dict modified during iteration
    While Thread 2 is inside create_stream() for Amir:
      - self._streams[key] = StreamInfo(...)  ← Modifying dict

    Thread 1 simultaneously in push_audio() for Daniel:
      - self._streams[key].audio_queue.put_nowait(...)  ← Dict corrupted!

    Python dicts are NOT thread-safe for concurrent modification!
    Result: RuntimeError or corrupted state
```

### The Fix
```python
import threading

class StreamManager:
    def __init__(self):
        self._streams: Dict[str, StreamInfo] = {}
        self._lock = threading.RLock()  # ← ADD REENTRANT LOCK

    def create_stream(self, session_id: str, speaker_id: str) -> queue.Queue:
        key = self._get_key(session_id, speaker_id)

        with self._lock:  # ← PROTECT ALL ACCESS
            if key in self._streams:
                existing = self._streams[key]
                if existing.task and existing.task.done():
                    del self._streams[key]
                else:
                    return self._streams[key].audio_queue

            audio_queue = queue.Queue()
            self._streams[key] = StreamInfo(
                session_id=session_id,
                speaker_id=speaker_id,
                audio_queue=audio_queue
            )
            return audio_queue

    def has_stream(self, session_id: str, speaker_id: str) -> bool:
        key = self._get_key(session_id, speaker_id)

        with self._lock:  # ← PROTECT ALL ACCESS
            if key not in self._streams:
                return False
            stream_info = self._streams[key]
            if stream_info.task and stream_info.task.done():
                del self._streams[key]
                return False
            return True

    def push_audio(self, session_id: str, speaker_id: str, audio_data: bytes) -> bool:
        key = self._get_key(session_id, speaker_id)

        with self._lock:  # ← PROTECT ALL ACCESS
            if key not in self._streams:
                return False
            try:
                self._streams[key].audio_queue.put_nowait(audio_data)
                return True
            except queue.Full:
                return False
```

---

## Problem #2: Dead Task Detection in TWO Places (My Previous Change Made This Worse)

### Location
- `backend/app/services/audio/stream_manager.py` (lines 82-86, 149-153) - I ADDED THIS
- `backend/app/services/interim_caption_service.py` (lines 117-120) - I ADDED THIS

### Current Code (CONFLICTING)

**stream_manager.py** (manages batch STT pipeline):
```python
def has_stream(self, session_id: str, speaker_id: str) -> bool:
    # ...
    if stream_info.task and stream_info.task.done():
        logger.warning(f"⚠️ Found dead stream {key} - task finished, cleaning up...")
        del self._streams[key]  # ← Cleanup #1
        return False
```

**interim_caption_service.py** (manages streaming STT pipeline):
```python
async def start_session(self, ...):
    # ...
    if existing_session.task and existing_session.task.done():
        logger.warning(f"⚠️ Found dead session for {stream_key} - task finished, restarting...")
        del self._sessions[stream_key]  # ← Cleanup #2
```

### The Conflict
```
These are TWO SEPARATE tracking systems:
- StreamManager._streams: tracks batch audio processing tasks
- InterimCaptionService._sessions: tracks streaming STT tasks

Each has its own dead task detection.
Each cleans up independently.

BUT: They share the same audio! When audio arrives:
1. Worker pushes to StreamManager for batch processing
2. Worker ALSO pushes to InterimCaptionService for streaming

If one cleans up while the other is still using the audio:
→ Confusion about stream state
→ Audio might go to wrong pipeline
→ Duplicate processing or no processing
```

### The Fix

**Option A (Recommended):** Remove dead task detection from `stream_manager.py`, keep only in `interim_caption_service.py`:

The streaming STT (InterimCaptionService) is the primary path now. When it detects a dead task and restarts, the batch path (StreamManager) should also be restarted. We should coordinate this.

**stream_manager.py** - REVERT to simpler logic:
```python
def has_stream(self, session_id: str, speaker_id: str) -> bool:
    key = self._get_key(session_id, speaker_id)
    with self._lock:
        return key in self._streams  # Simple check, no dead task detection

def create_stream(self, session_id: str, speaker_id: str) -> queue.Queue:
    key = self._get_key(session_id, speaker_id)
    with self._lock:
        if key in self._streams:
            return self._streams[key].audio_queue  # Return existing

        # Create new
        audio_queue = queue.Queue()
        self._streams[key] = StreamInfo(...)
        return audio_queue
```

**worker.py** - Add explicit cleanup when needed:
```python
async def handle_audio_stream(...):
    try:
        # ... process audio ...
    finally:
        # Always clean up when task ends
        stream_manager.remove_stream(session_id, speaker_id)
```

---

## Problem #3: StreamingTranslationProcessor Lock Scope Too Narrow

### Location
`backend/app/services/translation/streaming.py`

### Current Code (BUGGY)
```python
class StreamingTranslationProcessor:
    def __init__(self):
        self._contexts: Dict[str, StreamContext] = {}
        self._lock = asyncio.Lock()

    async def process_final_transcript(self, session_id, speaker_id, transcript, source_lang):
        stream_key = f"{session_id}:{speaker_id}"

        # Lock ONLY protects context creation
        async with self._lock:
            if stream_key not in self._contexts:
                self._contexts[stream_key] = StreamContext()
            context = self._contexts[stream_key]

        # ↓↓↓ ALL OF THIS IS OUTSIDE THE LOCK! ↓↓↓

        if context.is_duplicate(transcript):  # ← Race condition!
            return

        cached = context.recall_translation(transcript, source_lang)  # ← Race!
        if cached:
            # use cached
        else:
            translation = await self._translate(...)
            context.remember_translation(transcript, target, translation)  # ← Race!
```

### What Happens During Speaker Switch
```
Timeline with concurrent speakers:
─────────────────────────────────────────────────────────────────────────────

T0: Amir says "Hello, how are you?"
    - InterimCaptionService produces final transcript
    - Calls: streaming_processor.process_final_transcript("session", "amir", "Hello...")

    Inside process_final_transcript:
      async with self._lock:
          context_amir = self._contexts["session:amir"]  # Created

      # Outside lock:
      context_amir.is_duplicate("Hello...")  # ← Checking

T1: Daniel says "I'm fine" (WHILE Amir's is still processing)
    - Different speaker, different context key
    - Calls: streaming_processor.process_final_transcript("session", "daniel", "I'm fine")

    Inside process_final_transcript:
      async with self._lock:
          context_daniel = self._contexts["session:daniel"]  # Created

      # Outside lock:
      context_daniel.is_duplicate("I'm fine")  # ← Also checking

T2: Both translations running concurrently
    - Amir's: await self._translate("Hello...")
    - Daniel's: await self._translate("I'm fine")

    These are OK because they use different contexts.

BUT THE REAL PROBLEM IS INSIDE StreamContext:

class StreamContext:
    def __init__(self):
        self._processed_transcripts: Set[str] = set()  # ← Shared within speaker

    def is_duplicate(self, transcript: str) -> bool:
        normalized = transcript.strip().lower()
        if normalized in self._processed_transcripts:
            return True
        self._processed_transcripts.add(normalized)  # ← Not atomic!

        # THIS IS THE BUG:
        if len(self._processed_transcripts) > 50:
            self._processed_transcripts.pop()  # ← Removes RANDOM element!
        return False

If Amir speaks twice quickly:
T0: "Hello" → is_duplicate("hello") → False, add "hello" to set
T1: "How are you" → is_duplicate("how are you") → checking...
    MEANWHILE T0's code is still in is_duplicate, doing .pop()

Since there's no lock inside StreamContext, concurrent calls corrupt state.
```

### The Fix
```python
class StreamingTranslationProcessor:
    async def process_final_transcript(self, session_id, speaker_id, transcript, source_lang):
        stream_key = f"{session_id}:{speaker_id}"

        # Lock protects ENTIRE operation for this stream
        async with self._lock:
            if stream_key not in self._contexts:
                self._contexts[stream_key] = StreamContext()
            context = self._contexts[stream_key]

            # All context operations inside lock
            if context.is_duplicate(transcript):
                logger.debug(f"Skipping duplicate: {transcript[:30]}...")
                return

            cached = context.recall_translation(transcript, source_lang)
            if cached:
                translation, target_lang = cached
            else:
                translation = await self._translate(transcript, source_lang, target_lang)
                context.remember_translation(transcript, target_lang, translation)

        # Only publish (which is async-safe) outside lock
        await self._publish_translation(...)
```

**Alternative:** Add lock inside StreamContext:
```python
class StreamContext:
    def __init__(self):
        self._processed_transcripts: Set[str] = set()
        self._lock = threading.Lock()  # ← Add lock

    def is_duplicate(self, transcript: str) -> bool:
        normalized = transcript.strip().lower()
        with self._lock:  # ← Protect set operations
            if normalized in self._processed_transcripts:
                return True
            self._processed_transcripts.add(normalized)
            if len(self._processed_transcripts) > 50:
                # Remove oldest, not random
                self._processed_transcripts.pop()
            return False
```

---

## Problem #4: Deduplication Uses Random set.pop()

### Location
`backend/app/services/translation/streaming.py` (lines 77-92)

### Current Code (BUGGY)
```python
def is_duplicate(self, transcript: str) -> bool:
    normalized = transcript.strip().lower()
    if normalized in self._processed_transcripts:
        return True
    self._processed_transcripts.add(normalized)

    if len(self._processed_transcripts) > 50:
        self._processed_transcripts.pop()  # ← RANDOM ELEMENT REMOVED!
    return False
```

### The Problem
```python
# Python sets are UNORDERED. pop() removes an ARBITRARY element.

>>> s = {"hello", "world", "foo", "bar"}
>>> s.pop()
'bar'  # or could be any other element!

# So if user says:
# T0: "Hello"         → set = {"hello"}
# T1: "How are you"   → set = {"hello", "how are you"}
# T2: ... 48 more unique phrases ...
# T50: "Goodbye"      → set has 50 items
# T51: "See you"      → set has 51 items, must pop one
#                     → pop() removes... maybe "hello"? maybe "goodbye"? RANDOM!

# Later:
# T100: "Hello"       → is_duplicate("hello") →
#       If "hello" was popped: False (not a duplicate) → WRONG! User said it before!
#       If "hello" wasn't popped: True (duplicate) → Correct

# The behavior is UNPREDICTABLE!
```

### The Fix
Use timestamp-based window instead of size-based limit:
```python
from collections import OrderedDict
import time

class StreamContext:
    def __init__(self):
        # OrderedDict maintains insertion order
        self._processed_transcripts: OrderedDict[str, float] = OrderedDict()
        self._dedup_window_sec: float = 30.0  # 30 second window

    def is_duplicate(self, transcript: str) -> bool:
        normalized = transcript.strip().lower()
        now = time.time()

        # Clean old entries (older than window)
        cutoff = now - self._dedup_window_sec
        keys_to_remove = [
            key for key, timestamp in self._processed_transcripts.items()
            if timestamp < cutoff
        ]
        for key in keys_to_remove:
            del self._processed_transcripts[key]

        # Check if duplicate
        if normalized in self._processed_transcripts:
            return True

        # Add with timestamp
        self._processed_transcripts[normalized] = now
        return False
```

---

## Problem #5: InterimCaptionService Session Cleanup Race

### Location
`backend/app/services/interim_caption_service.py`

### Current Code (POTENTIAL ISSUE)
```python
async def start_session(self, session_id, speaker_id, source_lang, on_final_transcript):
    stream_key = self.get_stream_key(session_id, speaker_id)

    with self._lock:  # threading.Lock
        existing_session = self._sessions.get(stream_key)

        if existing_session and existing_session.is_active:
            if existing_session.task and existing_session.task.done():
                # Task died (e.g., STT timeout after mute)
                del self._sessions[stream_key]
            else:
                # Session alive, just update callback
                return False

        # Create new session
        session = InterimSession(...)
        self._sessions[stream_key] = session

    # OUTSIDE LOCK: Start the streaming task
    task = asyncio.create_task(self._run_streaming_session(session))
    session.task = task  # ← Race: session might be accessed before task is set!
```

### The Problem
```
T0: with self._lock:
        session = InterimSession(...)
        self._sessions[stream_key] = session
    # Lock released here

T1: Another coroutine calls push_audio()
    with self._lock:
        session = self._sessions.get(stream_key)  # Gets session from T0
        # session.task is None! (not set yet)

T2: Back to T0:
    task = asyncio.create_task(...)
    session.task = task  # Now it's set, but T1 already saw None
```

### The Fix
Set task before releasing lock, or use a "initializing" state:
```python
async def start_session(self, session_id, speaker_id, source_lang, on_final_transcript):
    stream_key = self.get_stream_key(session_id, speaker_id)

    with self._lock:
        existing_session = self._sessions.get(stream_key)

        if existing_session and existing_session.is_active:
            if existing_session.task and existing_session.task.done():
                del self._sessions[stream_key]
            else:
                return False

        session = InterimSession(
            session_id=session_id,
            speaker_id=speaker_id,
            source_lang=source_lang,
            on_final_transcript=on_final_transcript,
            is_active=True
        )
        self._sessions[stream_key] = session

        # Create task INSIDE lock (task creation is synchronous)
        task = asyncio.create_task(self._run_streaming_session(session))
        session.task = task  # ← Set before lock release

    return True
```

---

## Implementation Order

### Step 1: Revert Problematic Changes (FIRST)

Revert my dead task detection changes that created Problem #2:

**stream_manager.py:**
- Remove dead task detection from `has_stream()` (lines 147-153)
- Remove dead task detection from `create_stream()` (lines 81-86)

### Step 2: Add Thread-Safety to StreamManager

Add `threading.RLock()` and protect all methods.

### Step 3: Fix StreamingTranslationProcessor Lock Scope

Extend lock to cover entire context operation.

### Step 4: Fix Deduplication

Replace `set.pop()` with timestamp-based OrderedDict.

### Step 5: Fix InterimCaptionService Task Assignment

Move task creation inside the lock.

### Step 6: Test Each Fix

After each fix, test:
1. Amir speaks → works
2. Daniel speaks → works
3. Amir speaks again → should work now
4. Rapid alternation → should work

---

## Files to Modify

| File | Changes |
|------|---------|
| `backend/app/services/audio/stream_manager.py` | Add RLock, revert dead task detection |
| `backend/app/services/translation/streaming.py` | Fix lock scope, fix deduplication |
| `backend/app/services/interim_caption_service.py` | Move task creation inside lock |

---

## Verification Checklist

After fixes, verify:
- [ ] Single speaker works continuously
- [ ] Two speakers can alternate without issues
- [ ] Mute/unmute doesn't break transcription
- [ ] Rapid speech from both speakers works
- [ ] Long silence followed by speech works
- [ ] No duplicate transcriptions appear
- [ ] No missing transcriptions
