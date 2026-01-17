# Real-Time Call Translator - Documentation

## Overview

**Real-Time Call Translator** is a mobile application that enables seamless voice conversations between speakers of different languages. The system performs real-time speech recognition, translation, and text-to-speech synthesis to deliver dubbed audio to each participant in their preferred language.

### Key Features

- **Real-time Translation**: Sub-2-second latency from speech to translated audio
- **Multi-party Calls**: Support for 2-4 participants with different languages
- **Live Captions**: Real-time interim captions showing speech as it's being spoken
- **Voice Cloning** (Future): Personalized voice synthesis using speaker's voice samples
- **Cross-platform**: Flutter mobile app for iOS and Android

### Supported Languages

| Code | Language | Locale |
|------|----------|--------|
| `he` | Hebrew | he-IL |
| `en` | English | en-US |
| `ru` | Russian | ru-RU |

### Target Users

- Multilingual families and friends
- International business communications
- Travelers and tourists
- Healthcare providers with multilingual patients
- Customer support across language barriers

### Non-Goals (Current Scope)

- Video calling (audio only)
- More than 4 participants per call
- Languages beyond Hebrew, English, Russian
- Offline translation (requires internet)
- End-to-end encryption (capstone project scope)

---

## Documentation Index

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | System architecture, components, data flow |
| [SETUP.md](./SETUP.md) | Installation, configuration, deployment |
| [API.md](./API.md) | REST API endpoints and WebSocket protocol |
| [MOBILE.md](./MOBILE.md) | Flutter app architecture and components |
| [TESTING.md](./TESTING.md) | Test strategy, running tests, coverage |
| [CHANGELOG.md](./CHANGELOG.md) | Version history and upgrade notes |

---

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Google Cloud Platform account with Speech, Translate, and TTS APIs enabled
- Flutter SDK 3.35+ (for mobile development)

### Backend Setup

```bash
cd backend

# Copy environment template
cp .env.example .env

# Add your GCP credentials
# Place google-credentials.json in backend/app/config/

# Start services
docker-compose up -d

# Verify
curl http://localhost:8000/health
```

### Mobile Setup

```bash
cd mobile

# Install dependencies
flutter pub get

# Configure server IP in app settings or:
# Edit lib/config/app_config.dart

# Run on device/emulator
flutter run
```

---

## Technology Stack

### Backend
- **Framework**: FastAPI (Python 3.11)
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Speech Services**: Google Cloud Speech-to-Text, Translate, Text-to-Speech
- **Real-time**: WebSocket (native FastAPI)

### Mobile
- **Framework**: Flutter 3.35 (Dart)
- **State Management**: Provider
- **Audio**: record, flutter_sound, just_audio
- **Networking**: http, web_socket_channel

### Infrastructure
- **Containerization**: Docker, Docker Compose
- **CI/CD**: GitHub Actions

---

## Project Structure

```
Real-Time-Call-Translator/
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── api/            # REST endpoints
│   │   ├── config/         # Settings, constants
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   └── services/       # Business logic
│   │       ├── audio/      # Audio processing
│   │       ├── translation/# Translation pipeline
│   │       ├── core/       # Shared utilities
│   │       ├── call/       # Call management
│   │       ├── session/    # WebSocket sessions
│   │       └── connection/ # Connection management
│   ├── scripts/            # Utility scripts
│   ├── tests/              # Backend tests
│   └── docker-compose.yml
├── mobile/                  # Flutter app
│   └── lib/
│       ├── config/         # App configuration
│       ├── core/           # Navigation, routing
│       ├── data/           # API services
│       ├── models/         # Data models
│       ├── providers/      # State management
│       ├── screens/        # UI screens
│       ├── services/       # Business services
│       ├── utils/          # Utilities
│       └── widgets/        # Reusable widgets
├── docs/                    # Documentation
└── scripts/                 # Project-level scripts
```

---

## Contributing

See [.github/docs/CONTRIBUTING.md](../.github/docs/CONTRIBUTING.md) for contribution guidelines.

## License

This project is developed as a capstone project. See [LICENSE](../LICENSE) for details.
