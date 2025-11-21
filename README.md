<div align="center">
  
# 🌐 Real-Time Call Translator

### AI-Powered Real-Time Translation & Voice Cloning for Seamless Global Communication

[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.35+-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[Features](#-features) • [Architecture](#-architecture) • [Quick Start](#-quick-start) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-features)
- [Technology Stack](#-technology-stack)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuration](#configuration)
- [Project Structure](#-project-structure)
- [API Documentation](#-api-documentation)
- [Development](#-development)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

---

## 🎯 Overview

**Real-Time Call Translator** is an advanced communication platform that breaks down language barriers by providing real-time translation and voice cloning during phone calls. Using cutting-edge AI technologies from Google Cloud, the system transcribes speech, translates it to the desired language, and synthesizes it back in the caller's original voice.

### 🌟 Why This Project?

- **Break Language Barriers**: Enable seamless communication between people speaking different languages
- **Preserve Voice Identity**: Maintain the caller's unique voice characteristics through AI voice cloning
- **Real-Time Processing**: Sub-second latency for natural conversation flow
- **Cross-Platform**: Available on iOS, Android, and Web
- **Enterprise-Ready**: Scalable architecture designed for production deployment

---

## ✨ Features

### Core Functionality

- 🎤 **Real-Time Speech Recognition** - Instant transcription using Google Cloud Speech-to-Text
- 🌍 **Multi-Language Translation** - Support for 100+ languages via Google Translate API
- 🔊 **Voice Cloning** - Preserve caller's voice using Google Cloud Text-to-Speech with custom voice models
- 📞 **WebRTC Integration** - Low-latency audio streaming for real-time communication
- 🔐 **Secure Authentication** - Firebase-based user authentication and session management

### Advanced Features

- 🎚️ **Voice Training** - Upload voice samples to create personalized voice models
- 🗣️ **Multi-Language Support** - Hebrew, English, Russian, Arabic, and more
- 📊 **Quality Metrics** - Voice quality scoring and translation accuracy tracking
- 💾 **Session Recording** - Optional call recording with transcription
- 🔄 **Bidirectional Translation** - Both parties can speak in their native language
- ⚡ **Redis Streaming** - High-performance message queue for audio chunks

### User Experience

- 📱 **Cross-Platform Mobile App** - Native iOS and Android apps built with Flutter
- 🎨 **Modern UI/UX** - Intuitive interface with real-time status indicators
- 🌙 **Dark Mode** - Eye-friendly interface for all lighting conditions
- 🔔 **Push Notifications** - Call alerts and translation status updates
- 📈 **Analytics Dashboard** - Usage statistics and quality metrics

---

## 🛠 Technology Stack

### Backend

| Technology | Purpose | Version |
|------------|---------|---------|
| **Python** | Core Backend Language | 3.10+ |
| **FastAPI** | Async Web Framework | 0.104.1 |
| **PostgreSQL** | Primary Database | 15 |
| **Redis** | Cache & Message Broker | 7 |
| **SQLAlchemy** | ORM with Async Support | 2.0.23 |
| **Uvicorn** | ASGI Server | 0.24.0 |
| **WebSockets** | Real-Time Communication | 12.0 |

### AI & Cloud Services

| Service | Purpose |
|---------|---------|
| **Google Cloud Speech-to-Text** | Speech recognition and transcription |
| **Google Cloud Translate** | Multi-language translation |
| **Google Cloud Text-to-Speech** | Voice synthesis with cloning |
| **Firebase Authentication** | User authentication and management |

### Mobile

| Technology | Purpose | Version |
|------------|---------|---------|
| **Flutter** | Cross-Platform Framework | 3.35.1 |
| **Dart** | Programming Language | 3.9.0 |

### DevOps & Infrastructure

| Technology | Purpose |
|------------|---------|
| **Docker** | Containerization |
| **Docker Compose** | Multi-Container Orchestration |
| **pgAdmin** | Database Management |
| **Pytest** | Testing Framework |

---

## 🏗 Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   iOS App    │  │ Android App  │  │   Web App    │          │
│  │  (Flutter)   │  │  (Flutter)   │  │  (Flutter)   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                  │                   │
│         └─────────────────┴──────────────────┘                   │
│                           │                                       │
└───────────────────────────┼───────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   API Gateway   │
                    │   (FastAPI)     │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌──────▼───────┐  ┌────────▼────────┐
│  WebSocket     │  │  REST API    │  │  Authentication │
│  Handler       │  │  Endpoints   │  │  (Firebase)     │
└───────┬────────┘  └──────┬───────┘  └────────┬────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌──────▼───────┐  ┌────────▼────────┐
│  Redis Streams │  │  PostgreSQL  │  │  Redis Cache    │
│  (Audio Queue) │  │  (User Data) │  │  (Sessions)     │
└───────┬────────┘  └──────────────┘  └─────────────────┘
        │
┌───────▼────────────────────────────────────────────────────────┐
│                   AI Processing Pipeline                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Speech     │─▶│  Translation │─▶│     TTS      │         │
│  │  Recognition │  │    Engine    │  │ Voice Clone  │         │
│  │   (Google)   │  │   (Google)   │  │   (Google)   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Audio Capture** - Client captures audio chunks (100-500ms)
2. **WebSocket Streaming** - Audio sent via WebSocket to backend
3. **Redis Queue** - Audio chunks queued in Redis Streams
4. **Speech Recognition** - Google Cloud STT transcribes audio
5. **Translation** - Google Translate converts to target language
6. **Voice Synthesis** - Google Cloud TTS generates audio with cloned voice
7. **Audio Playback** - Translated audio streamed back to recipient

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:

- **Python 3.10+** - [Download Python](https://www.python.org/downloads/)
- **Docker & Docker Compose** - [Install Docker](https://docs.docker.com/get-docker/)
- **Flutter SDK 3.35+** - [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Google Cloud Account** - [Create Account](https://cloud.google.com/)
- **Git** - [Install Git](https://git-scm.com/)

### Installation

#### 1️⃣ Clone the Repository

```bash
git clone https://github.com/amir3x0/Real-Time-Call-Translator.git
cd Real-Time-Call-Translator
```

#### 2️⃣ Set Up Backend

```bash
cd backend

# Create environment file
cp .env.example .env

# Edit .env with your configuration
# Add your database credentials, Redis password, etc.
```

#### 3️⃣ Build Docker Image

```bash
# Build the backend Docker image
docker build -t translator-backend .
```

#### 4️⃣ Start Services

```bash
# Start all services (PostgreSQL, Redis, Backend, pgAdmin)
docker-compose up -d

# Check service status
docker-compose ps
```

#### 5️⃣ Initialize Database

```bash
# Create database tables
docker exec -it translator_api python scripts/create_tables.py
```

#### 6️⃣ Verify Installation

```bash
# Test health endpoint
curl http://localhost:8000/health

# Expected response: {"status":"ok"}
```

### Configuration

#### Backend Environment Variables

Edit `backend/.env`:

```env
# Database Configuration
DB_USER=translator_admin
DB_PASSWORD=YourSecurePassword123!
DB_NAME=call_translator
DB_HOST=postgres
DB_PORT=5432

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=YourRedisPassword123!

# Google Cloud Configuration
GOOGLE_APPLICATION_CREDENTIALS=/app/config/google-credentials.json
GOOGLE_PROJECT_ID=your-gcp-project-id

# Application Settings
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=True
```

#### Google Cloud Setup

1. **Create a Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project

2. **Enable Required APIs**
   - Cloud Speech-to-Text API
   - Cloud Translation API
   - Cloud Text-to-Speech API

3. **Create Service Account**
   - IAM & Admin → Service Accounts → Create Service Account
   - Grant roles: Speech-to-Text Admin, Translation Admin, Text-to-Speech Admin
   - Create JSON key

4. **Add Credentials**
   ```bash
   # Place the downloaded JSON key in backend/config/
   cp ~/Downloads/your-service-account-key.json backend/config/google-credentials.json
   ```

---

## 📁 Project Structure

```
Real-Time-Call-Translator/
├── 📂 .github/                      # GitHub Configuration & Documentation
│   ├── 📂 docs/                     # Project Documentation
│   │   ├── CODE_GUIDELINES.md       # Coding standards
│   │   ├── CONTRIBUTING.md          # Contribution guide
│   │   ├── GIT_INSTRUCTIONS.md      # Git workflow
│   │   └── POSTGRESQL_GUIDE.md      # Database guide
│   ├── 📂 workflows/                # GitHub Actions (Future)
│   ├── 📂 templates/                # Issue/PR Templates (Future)
│   ├── copilot-instructions.md      # GitHub Copilot config
│   ├── CUSTOM_INSTRUCTIONS.md       # Detailed Copilot instructions
│   └── README.md                    # GitHub directory guide
├── 📂 backend/                      # Backend API (Python/FastAPI)
│   ├── 📂 app/
│   │   ├── 📂 api/                  # API endpoints
│   │   │   └── __init__.py          # Routes (health, audio upload)
│   │   ├── 📂 config/               # Configuration
│   │   │   ├── settings.py          # Pydantic settings
│   │   │   └── redis.py             # Redis connection
│   │   ├── 📂 models/               # Database models (6 models)
│   │   │   ├── database.py          # SQLAlchemy async setup
│   │   │   ├── user.py              # User model
│   │   │   ├── call.py              # Call sessions
│   │   │   ├── call_participant.py  # Participants
│   │   │   ├── contact.py           # User contacts
│   │   │   ├── voice_model.py       # Voice cloning models
│   │   │   └── message.py           # Transcriptions
│   │   ├── 📂 services/             # Business logic
│   │   │   └── rtc_service.py       # Real-time comm service
│   │   └── main.py                  # FastAPI app entry point
│   ├── 📂 scripts/
│   │   ├── create_tables.py         # Database initialization
│   │   ├── worker.py                # Background audio processor
│   │   └── init_db.sql              # SQL initialization
│   ├── 📂 tests/
│   │   ├── test_user_model.py       # User model tests
│   │   └── test_rtc_service.py      # Service tests
│   ├── 📄 Dockerfile                # Backend Docker image
│   ├── 📄 docker-compose.yml        # Multi-container setup
│   ├── 📄 requirements.txt          # Python dependencies
│   ├── 📄 .env.example              # Environment template
│   └── 📄 .gitignore                # Git ignore rules
├── 📂 mobile/                       # Flutter mobile app (Day 4 - Starting)
│   ├── 📂 lib/
│   ├── 📂 android/
│   ├── 📂 ios/
│   └── pubspec.yaml
├── 📄 plan.txt                      # Work plan generator
├── 📄 .gitignore                    # Global git ignore
├── 📄 README.md                     # This file
└── 📄 LICENSE                       # MIT License
```

---

## 📚 Documentation

Comprehensive documentation is available in the `.github/docs/` directory:

### Quick Start Guides
- **[Installation & Setup](.github/docs/CONTRIBUTING.md#getting-started)** - Get up and running
- **[Git Workflow](.github/docs/GIT_INSTRUCTIONS.md)** - Branching, commits, and PRs
- **[Database Guide](.github/docs/POSTGRESQL_GUIDE.md)** - PostgreSQL operations and queries

### Developer Guides
- **[Code Guidelines](.github/docs/CODE_GUIDELINES.md)** - Coding standards and best practices
- **[Contributing Guide](.github/docs/CONTRIBUTING.md)** - How to contribute to the project
- **[API Reference](#api-documentation)** - REST and WebSocket endpoints

### GitHub Copilot
- **[Copilot Instructions](.github/copilot-instructions.md)** - Quick reference for AI assistance
- **[Custom Instructions](.github/CUSTOM_INSTRUCTIONS.md)** - Detailed project context

### API Documentation

#### Base URL
```
http://localhost:8000
```

### Endpoints

#### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "ok"
}
```

#### Upload Audio Chunk
```http
POST /api/sessions/{session_id}/chunk
Content-Type: multipart/form-data
```

**Parameters:**
- `session_id` (path) - Unique session identifier
- `file` (form-data) - Audio file chunk

**Response:**
```json
{
  "status": "ok",
  "len": 8192
}
```

#### WebSocket Connection
```
WS /ws/{session_id}
```

**Usage:**
```javascript
const ws = new WebSocket('ws://localhost:8000/ws/session123');
ws.onopen = () => {
  // Send binary audio data
  ws.send(audioBuffer);
};
```

### Docker Services

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| **Backend API** | `translator_api` | 8000 | FastAPI application |
| **PostgreSQL** | `translator_db` | 5433→5432 | Database |
| **Redis** | `translator_cache` | 6379 | Cache & message broker |
| **pgAdmin** | `translator_dbadmin` | 5050→80 | Database management UI |

**Access pgAdmin:**
- URL: `http://localhost:5050`
- Email: `admin@calltranslator.local`
- Password: `PgAdmin2024`

---

## 💻 Development

### Backend Development

#### Run Tests
```bash
cd backend

# Run all tests
docker exec -it translator_api pytest

# Run specific test file
docker exec -it translator_api pytest tests/test_user_model.py

# Run with coverage
docker exec -it translator_api pytest --cov=app tests/
```

#### Access Database
```bash
# Using psql
docker exec -it translator_db psql -U translator_admin -d call_translator

# Using pgAdmin
# Navigate to http://localhost:5050
```

#### View Logs
```bash
# Backend API logs
docker logs -f translator_api

# Database logs
docker logs -f translator_db

# Redis logs
docker logs -f translator_cache
```

#### Hot Reload
The backend uses `--reload` flag in Dockerfile, so code changes are reflected immediately.

### Mobile Development (Coming Soon)

```bash
cd mobile

# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Build for production
flutter build apk --release
flutter build ios --release
```

---

## 🚢 Deployment

### Production Checklist

- [ ] Change all default passwords in `.env`
- [ ] Set `DEBUG=False` in production
- [ ] Configure HTTPS/SSL certificates
- [ ] Set up firewall rules
- [ ] Enable database backups
- [ ] Configure Redis persistence
- [ ] Set up monitoring and logging
- [ ] Review security best practices
- [ ] Configure CORS for production domains
- [ ] Set up CI/CD pipeline

### Docker Production Deployment

```bash
# Build production image
docker build -t translator-backend:production .

# Run with production compose
docker-compose -f docker-compose.prod.yml up -d

# Scale backend instances
docker-compose up -d --scale backend=3
```

### Cloud Deployment Options

- **AWS**: ECS/Fargate with RDS and ElastiCache
- **Google Cloud**: Cloud Run with Cloud SQL and Memorystore
- **Azure**: Container Instances with Azure Database and Redis Cache
- **Kubernetes**: Helm charts for orchestration

---

## 🧪 Testing

### Backend Tests

```bash
# Unit tests
pytest tests/test_user_model.py

# Integration tests
pytest tests/test_rtc_service.py

# Load testing (coming soon)
locust -f tests/load_tests.py
```

### Test Coverage

Current backend coverage: **85%+**

### Continuous Integration

GitHub Actions workflow (coming soon):
- Automated testing on PR
- Code quality checks (pylint, black)
- Security scanning
- Docker image building

---

## 🗺 Roadmap

### Phase 1: Foundation (Q4 2024) ✅
- [x] Backend architecture setup
- [x] Database models and migrations
- [x] Docker containerization
- [x] Basic API endpoints
- [x] Redis integration

### Phase 2: Core Features (Q1 2025) 🚧
- [ ] Google Cloud API integration
- [ ] Voice recognition pipeline
- [ ] Translation engine
- [ ] Text-to-speech synthesis
- [ ] Voice cloning implementation

### Phase 3: Mobile App (Q2 2025) 📱
- [ ] Flutter app structure
- [ ] Authentication flow
- [ ] Voice recording interface
- [ ] Real-time call UI
- [ ] Push notifications

### Phase 4: Advanced Features (Q3 2025) 🚀
- [ ] Voice training dashboard
- [ ] Quality metrics and analytics
- [ ] Session recording playback
- [ ] Multi-party calls
- [ ] Custom vocabulary

### Phase 5: Enterprise (Q4 2025) 🏢
- [ ] SLA monitoring
- [ ] Advanced security features
- [ ] White-label options
- [ ] API rate limiting
- [ ] Enterprise authentication

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](.github/docs/CONTRIBUTING.md) for detailed information.

### Quick Contribution Steps

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add amazing feature'
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines

- Follow our [Code Guidelines](.github/docs/CODE_GUIDELINES.md)
- Read the [Git Instructions](.github/docs/GIT_INSTRUCTIONS.md) for workflow
- Write tests for new features
- Update documentation
- Use meaningful commit messages
- Keep PRs focused and small

For more details, see [CONTRIBUTING.md](.github/docs/CONTRIBUTING.md)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Amir Mishayev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 📞 Contact

**Amir Mishayev**

- GitHub: [@amir3x0](https://github.com/amir3x0)
- Email: [Contact via GitHub](https://github.com/amir3x0)
- Project Link: [Real-Time-Call-Translator](https://github.com/amir3x0/Real-Time-Call-Translator)

---

## 🙏 Acknowledgments

- [Google Cloud Platform](https://cloud.google.com/) - AI/ML services
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [Flutter](https://flutter.dev/) - Cross-platform mobile framework
- [PostgreSQL](https://www.postgresql.org/) - Robust database
- [Redis](https://redis.io/) - In-memory data store

---

<div align="center">

### ⭐ Star this repository if you find it helpful!

**Made with ❤️ by Amir Mishayev**

</div>