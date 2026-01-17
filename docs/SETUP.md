# Setup & Operations Guide

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Docker | 20.10+ | Container runtime |
| Docker Compose | 2.0+ | Multi-container orchestration |
| Python | 3.11+ | Backend development |
| Flutter | 3.35+ | Mobile development |
| Git | 2.30+ | Version control |

### Required Accounts

- **Google Cloud Platform**: Speech-to-Text, Translate, Text-to-Speech APIs
- **Android Studio** or **Xcode**: Mobile development and emulators

---

## Backend Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/Real-Time-Call-Translator.git
cd Real-Time-Call-Translator/backend
```

### 2. Environment Configuration

```bash
# Copy template
cp .env.example .env

# Edit .env with your settings
```

#### Environment Variables

```bash
# Database
DB_USER=translator_admin
DB_PASSWORD=your_secure_password
DB_NAME=call_translator
DB_HOST=postgres          # Use 'localhost' for local dev without Docker
DB_PORT=5432

# Redis
REDIS_HOST=redis          # Use 'localhost' for local dev without Docker
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=/app/app/config/google-credentials.json
GOOGLE_PROJECT_ID=your-gcp-project-id

# API Server
API_HOST=0.0.0.0
API_PORT=8000
API_PUBLIC_HOST=192.168.1.100  # Your machine's IP for mobile access
DEBUG=true

# JWT
JWT_SECRET_KEY=your-super-secret-key-change-in-production
JWT_ALGORITHM=HS256
JWT_EXP_DAYS=7

# CORS (comma-separated origins)
BACKEND_CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

### 3. Google Cloud Setup

1. Create a GCP project at [console.cloud.google.com](https://console.cloud.google.com)

2. Enable required APIs:
   - Cloud Speech-to-Text API
   - Cloud Translation API
   - Cloud Text-to-Speech API

3. Create a service account:
   ```
   IAM & Admin → Service Accounts → Create Service Account
   ```

4. Grant roles:
   - Cloud Speech Client
   - Cloud Translation API User
   - Cloud Text-to-Speech Client

5. Create and download JSON key:
   ```
   Service Account → Keys → Add Key → Create new key → JSON
   ```

6. Place the credentials file:
   ```bash
   mv ~/Downloads/your-project-*.json backend/app/config/google-credentials.json
   ```

### 4. Start Services with Docker

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

**Services Started:**
| Service | Port | Purpose |
|---------|------|---------|
| postgres | 5433 | Database |
| redis | 6379 | Cache/Queue |
| backend | 8000 | API Server |
| worker | - | Audio Processing |
| adminer | 8080 | Database Admin UI |

### 5. Initialize Database

```bash
# Run migrations (first time)
docker-compose exec backend alembic upgrade head

# Or create tables directly
docker-compose exec backend python -m scripts.create_tables
```

### 6. Verify Installation

```bash
# Health check
curl http://localhost:8000/health

# Expected response:
# {"status": "healthy"}
```

---

## Local Development (Without Docker)

### 1. Python Environment

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt
```

### 2. Start PostgreSQL & Redis

```bash
# Using Docker for services only
docker run -d --name postgres \
  -e POSTGRES_USER=translator_admin \
  -e POSTGRES_PASSWORD=TranslatorPass2024 \
  -e POSTGRES_DB=call_translator \
  -p 5433:5432 \
  postgres:15-alpine

docker run -d --name redis \
  -p 6379:6379 \
  redis:7-alpine
```

### 3. Update Environment

```bash
# .env for local development
DB_HOST=localhost
DB_PORT=5433
REDIS_HOST=localhost
GOOGLE_APPLICATION_CREDENTIALS=./app/config/google-credentials.json
```

### 4. Run Backend

```bash
# Terminal 1: API Server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2: Audio Worker
python -m scripts.worker
```

---

## Mobile Setup

### 1. Install Flutter

Follow [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

```bash
# Verify installation
flutter doctor
```

### 2. Configure Server IP

Edit `mobile/lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String defaultServerIp = '192.168.1.100'; // Your backend IP
  static const int defaultServerPort = 8000;
}
```

Or configure via Settings screen in the app.

### 3. Install Dependencies

```bash
cd mobile
flutter pub get
```

### 4. Run on Device/Emulator

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run on all connected devices
flutter run -d all
```

### 5. Build Release APK

```bash
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Database Operations

### Migrations

```bash
# Create new migration
cd backend
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback one version
alembic downgrade -1

# View migration history
alembic history
```

### Database Access

**Via Adminer (Web UI):**
- URL: http://localhost:8080
- System: PostgreSQL
- Server: postgres
- Username: translator_admin
- Password: TranslatorPass2024
- Database: call_translator

**Via psql:**
```bash
docker-compose exec postgres psql -U translator_admin -d call_translator
```

### Common Queries

```sql
-- Active calls
SELECT * FROM calls WHERE is_active = true;

-- Online users
SELECT id, full_name, phone FROM users WHERE is_online = true;

-- Call participants
SELECT cp.*, u.full_name
FROM call_participants cp
JOIN users u ON cp.user_id = u.id
WHERE cp.call_id = 'your-call-id';
```

---

## Redis Operations

### Connect to Redis CLI

```bash
docker-compose exec redis redis-cli
```

### Common Commands

```bash
# List all keys
KEYS *

# View stream info
XINFO STREAM audio:stream:session_id

# Clear all data
FLUSHALL

# Monitor real-time commands
MONITOR
```

### Clear Test Data

```bash
cd backend
python -m scripts.clear_redis
```

---

## Build Scripts

### Backend

| Script | Purpose |
|--------|---------|
| `run_server.ps1` | Start FastAPI server (Windows) |
| `run_server.bat` | Start FastAPI server (Windows CMD) |
| `run_worker.ps1` | Start audio worker (Windows) |
| `scripts/create_tables.py` | Initialize database tables |
| `scripts/clear_redis.py` | Clear Redis cache |
| `scripts/test_redis.py` | Test Redis connection |

### Mobile

| Script | Purpose |
|--------|---------|
| `flutter run` | Run in debug mode |
| `flutter build apk` | Build Android APK |
| `flutter build ios` | Build iOS app |
| `flutter test` | Run tests |
| `flutter analyze` | Lint code |

---

## Deployment

### Production Checklist

1. **Security**
   - [ ] Change default passwords in `.env`
   - [ ] Generate strong JWT_SECRET_KEY
   - [ ] Enable HTTPS/TLS
   - [ ] Configure proper CORS origins
   - [ ] Secure GCP credentials

2. **Database**
   - [ ] Use managed PostgreSQL (Cloud SQL, RDS, etc.)
   - [ ] Configure connection pooling
   - [ ] Set up backups

3. **Redis**
   - [ ] Use managed Redis (Cloud Memorystore, ElastiCache)
   - [ ] Configure persistence if needed

4. **Scaling**
   - [ ] Run multiple API server instances behind load balancer
   - [ ] Scale audio workers based on call volume
   - [ ] Monitor GCP API quotas

5. **Monitoring**
   - [ ] Set up logging aggregation
   - [ ] Configure health check endpoints
   - [ ] Add metrics/alerting

### Docker Production Build

```bash
# Build production image
docker build -t translator-backend:prod -f Dockerfile .

# Run with production settings
docker run -d \
  --name translator-api \
  -p 8000:8000 \
  -e DEBUG=false \
  -e JWT_SECRET_KEY=production-secret \
  -v /path/to/credentials:/app/app/config/google-credentials.json \
  translator-backend:prod
```

---

## Troubleshooting

### Backend Issues

**Database connection failed:**
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Check logs
docker-compose logs postgres

# Verify connection string in .env
```

**GCP API errors:**
```bash
# Verify credentials file exists
ls -la backend/app/config/google-credentials.json

# Test GCP connection
python -c "from google.cloud import speech; print(speech.SpeechClient())"
```

**WebSocket not connecting:**
```bash
# Check CORS settings
# Verify API_PUBLIC_HOST is set correctly
# Check firewall allows port 8000
```

### Mobile Issues

**Can't connect to backend:**
1. Verify backend IP in app settings
2. Ensure phone and server on same network
3. Check firewall allows connections
4. Try: `ping <backend-ip>` from device

**Audio not working:**
1. Check microphone permissions granted
2. Verify audio settings in app
3. Check device audio output (speaker vs earpiece)

**Build errors:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Common Solutions

```bash
# Reset everything
docker-compose down -v
docker-compose up -d --build

# Clear mobile build cache
cd mobile
flutter clean
flutter pub cache repair

# Reset database
docker-compose exec backend python -c "
from app.models.database import engine, Base
import asyncio
asyncio.run(Base.metadata.drop_all(engine))
asyncio.run(Base.metadata.create_all(engine))
"
```
