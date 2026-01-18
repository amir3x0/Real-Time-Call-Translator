# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- Comprehensive documentation in `docs/` folder
- Architecture documentation
- API documentation
- Setup and operations guide
- Mobile app documentation
- Testing guide

### Removed
- Redundant mock data files from mobile app
- Unused backend models (message.py, voice_model.py)
- Legacy `start_call_legacy` API endpoint
- Outdated documentation files from `.github/`
- Dead code: heartbeat_service.dart, audio_service.dart
- Dead code: call_session.dart, call_transcript.dart models

### Changed
- Reorganized backend services into modular structure:
  - `services/audio/` - Audio processing components
  - `services/translation/` - Translation pipeline
  - `services/core/` - Shared infrastructure
- Cleaned up unused routes in mobile app

---

## [0.3.0] - 2026-01-15

### Added
- **Phase 3: Multi-Party Group Calls**
  - Support for 3-4 participants per call
  - Participant grid layout (adaptive 2x2)
  - Per-participant audio routing
  - Group call WebSocket broadcasting
  - Participant join/leave notifications

- **Real-time Interim Captions**
  - WhatsApp-style typing indicator effect
  - Streaming STT partial results
  - 150ms publish interval for smooth updates
  - Speaker identification in captions

- **Active Speaker Recognition**
  - Visual indicator for current speaker
  - Audio level detection
  - Mobile UI highlighting

### Changed
- Call API supports up to 4 participants
- WebSocket protocol extended for multi-party
- Database schema: participant_count field added

---

## [0.2.0] - 2026-01-10

### Added
- **Phase 1: Latency Optimization**
  - Reduced end-to-end latency from ~3s to ~1-1.5s
  - Streaming STT for immediate transcription
  - Parallel translation + TTS processing
  - Audio chunking optimization (100ms chunks)

- **Audio Processing Improvements**
  - FFT-based speech detection
  - Pause-based audio segmentation
  - TTS caching layer
  - Jitter buffer for smooth playback

- **OOP Refactoring**
  - Extracted `SpeechDetector` class
  - Extracted `AudioChunker` class
  - Extracted `StreamManager` class
  - Extracted `MessageDeduplicator` class
  - Extracted `CallRepository` class
  - Extracted `TranslationProcessor` class

### Changed
- Audio worker refactored from 993 lines to ~400 lines
- Centralized database queries in repository pattern
- Thread pool optimization for GCP API calls

### Fixed
- Call disconnection issues on lobby reconnect
- Audio initialization race conditions
- WebSocket message parsing errors

---

## [0.1.0] - 2025-12-30

### Added
- **Initial Release**
  - User authentication (register, login, logout)
  - Contact management (add, accept, reject, delete)
  - Two-party voice calls
  - Real-time speech-to-text (Google Cloud STT)
  - Real-time translation (Google Cloud Translate)
  - Text-to-speech synthesis (Google Cloud TTS)
  - WebSocket-based audio streaming
  - PostgreSQL database with SQLAlchemy
  - Redis for caching and message queues
  - Flutter mobile app (iOS/Android)
  - Docker Compose deployment

- **Backend Services**
  - FastAPI REST API
  - WebSocket session management
  - Audio processing worker
  - GCP integration pipeline

- **Mobile Features**
  - Provider state management
  - Audio recording and playback
  - Live captions display
  - Contact list with friend requests
  - Settings screen

- **Voice Cloning Preparation**
  - Voice sample upload API
  - Voice recording storage
  - Quality scoring system
  - Training queue (Chatterbox integration pending)

---

## Upgrade Notes

### From 0.2.x to 0.3.x

1. **Database Migration**
   ```bash
   cd backend
   alembic upgrade head
   ```

2. **Mobile App Update**
   - Clear app data and reinstall for clean state
   - Or: Settings → Debug → Reset Call State

3. **Configuration**
   - No new environment variables required
   - Existing `.env` files compatible

### From 0.1.x to 0.2.x

1. **Backend Service Restructure**
   - If importing directly from `app.services.audio_worker`, update to:
     ```python
     from app.services.audio.worker import run_worker
     ```

2. **New Constants**
   - Added latency-related constants in `config/constants.py`
   - Review and adjust if customized

3. **Redis Streams**
   - Clear Redis data for clean state:
     ```bash
     docker-compose exec redis redis-cli FLUSHALL
     ```

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.3.0 | 2026-01-15 | Multi-party calls, interim captions |
| 0.2.0 | 2026-01-10 | Latency optimization, OOP refactoring |
| 0.1.0 | 2025-12-30 | Initial release |

---

## Contributing

See [CONTRIBUTING.md](../.github/docs/CONTRIBUTING.md) for how to propose changes.

## License

See [LICENSE](../LICENSE) for license information.
