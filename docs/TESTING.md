# Testing Guide

## Overview

This document describes the testing strategy, how to run tests, and coverage focus areas for the Real-Time Call Translator project.

---

## Backend Testing

### Test Structure

```
backend/tests/
├── conftest.py              # Pytest fixtures
├── helpers.py               # Test utilities
├── test_auth_api.py         # Authentication endpoint tests
├── test_calls_api.py        # Call management tests
├── test_contacts_api.py     # Contact API tests
├── test_user_model.py       # User model tests
├── test_voice_service.py    # Voice upload tests
├── test_rtc_service.py      # RTC service tests
├── test_streaming.py        # Streaming translation tests
├── test_real_translation.py # GCP integration tests
├── live_transcription.py    # Live transcription testing
├── record_audio.py          # Audio recording utility
├── verify_e2e.py            # End-to-end verification
└── verify_translation_flow.py  # Translation flow verification
```

### Running Tests

```bash
cd backend

# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_auth_api.py

# Run specific test function
pytest tests/test_auth_api.py::test_register_user

# Run with verbose output
pytest -v

# Run only marked tests
pytest -m "not slow"
```

### Test Configuration (`pytest.ini`)

```ini
[pytest]
asyncio_mode = auto
testpaths = tests
python_files = test_*.py
python_functions = test_*
addopts = -v --tb=short
filterwarnings =
    ignore::DeprecationWarning
```

### Fixtures (`conftest.py`)

```python
@pytest.fixture
async def db_session():
    """Provides test database session"""

@pytest.fixture
async def test_user(db_session):
    """Creates a test user"""

@pytest.fixture
async def auth_headers(test_user):
    """Provides authenticated request headers"""

@pytest.fixture
async def test_call(db_session, test_user):
    """Creates a test call"""
```

### Test Categories

#### Unit Tests
- Model validation
- Service functions (isolated)
- Utility functions
- Data transformations

#### Integration Tests
- API endpoint behavior
- Database operations
- Redis interactions
- WebSocket connections

#### End-to-End Tests
- Full call flow
- Translation pipeline
- Audio processing

---

## Mobile Testing

### Test Structure

```
mobile/test/
├── test_helpers.dart        # Test utilities
├── providers/
│   └── auth_provider_test.dart
├── screens/
│   ├── login_screen_test.dart
│   └── home_screen_test.dart
└── widgets/
    └── custom_button_test.dart
```

### Running Tests

```bash
cd mobile

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/providers/auth_provider_test.dart

# Run with verbose output
flutter test --reporter expanded
```

### Widget Testing

```dart
testWidgets('CustomButton displays text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CustomButton(
        text: 'Click Me',
        onPressed: () {},
      ),
    ),
  );

  expect(find.text('Click Me'), findsOneWidget);
});
```

### Provider Testing

```dart
test('AuthProvider login updates state', () async {
  final provider = AuthProvider();

  await provider.login('0501234567', 'password');

  expect(provider.isAuthenticated, isTrue);
  expect(provider.userId, isNotNull);
});
```

---

## Test Data & Fixtures

### Backend Test Users

```python
TEST_USER = {
    "phone": "0501234567",
    "full_name": "Test User",
    "password": "testpass",
    "primary_language": "en"
}

TEST_USER_2 = {
    "phone": "0509876543",
    "full_name": "Test User 2",
    "password": "testpass",
    "primary_language": "he"
}
```

### Test Audio Files

Located in `backend/data/`:
- `test_audio.wav` - Sample audio for STT testing

### Mock Data

For mobile development without backend:
- Previously in `mobile/lib/data/mock/` (now removed)
- Use real backend for testing

---

## Coverage Focus Areas

### Critical Paths (High Priority)

| Area | Coverage Target | Rationale |
|------|-----------------|-----------|
| Authentication | 90%+ | Security critical |
| Call Lifecycle | 85%+ | Core functionality |
| WebSocket Messages | 80%+ | Real-time reliability |
| Translation Pipeline | 75%+ | User experience |

### Medium Priority

| Area | Coverage Target |
|------|-----------------|
| Contact Management | 70%+ |
| Voice Upload | 70%+ |
| Error Handling | 65%+ |

### Lower Priority

| Area | Coverage Target |
|------|-----------------|
| Settings/Config | 50%+ |
| Utility Functions | 50%+ |

---

## Integration Testing

### GCP Integration Tests

These tests require valid GCP credentials:

```bash
# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json

# Run GCP tests
pytest tests/test_real_translation.py -v
```

### WebSocket Testing

```python
async def test_websocket_connection():
    async with websockets.connect(ws_url) as ws:
        # Send ping
        await ws.send(json.dumps({"type": "ping"}))

        # Expect pong
        response = await ws.recv()
        data = json.loads(response)
        assert data["type"] == "pong"
```

### Audio Processing Tests

```python
async def test_audio_transcription():
    # Read test audio
    with open("data/test_audio.wav", "rb") as f:
        audio_data = f.read()

    # Send to pipeline
    result = pipeline.transcribe(audio_data, "en-US")

    assert result is not None
    assert len(result) > 0
```

---

## End-to-End Testing

### Manual E2E Test Checklist

#### Authentication Flow
- [ ] Register new user
- [ ] Login with credentials
- [ ] View profile
- [ ] Update profile
- [ ] Logout

#### Contact Flow
- [ ] Search for user
- [ ] Send friend request
- [ ] Accept friend request (other user)
- [ ] View contacts list
- [ ] Delete contact

#### Call Flow
- [ ] Start call with contact
- [ ] Receive incoming call notification
- [ ] Accept incoming call
- [ ] Verify audio bidirectional
- [ ] See transcriptions
- [ ] See translations
- [ ] Toggle mute
- [ ] Toggle speaker
- [ ] End call
- [ ] View call history

#### Voice Training
- [ ] Record voice sample
- [ ] Upload voice sample
- [ ] View recordings
- [ ] Train voice model

### Automated E2E Scripts

```bash
# Run verification script
cd backend
python tests/verify_e2e.py
```

---

## Performance Testing

### Latency Benchmarks

```python
import time

async def benchmark_translation():
    start = time.time()

    # Simulate audio chunk
    audio = generate_test_audio(100)  # 100ms

    # Process
    transcript = await transcribe(audio)
    translation = await translate(transcript)
    audio_out = await synthesize(translation)

    elapsed = time.time() - start
    print(f"End-to-end: {elapsed*1000:.0f}ms")

    assert elapsed < 2.0  # Target: <2s
```

### Load Testing

```bash
# Using locust (install: pip install locust)
locust -f tests/load_test.py --host http://localhost:8000
```

---

## Continuous Integration

### GitHub Actions (Backend)

`.github/workflows/backend-ci.yml`:

```yaml
name: Backend CI
on:
  push:
    paths: ['backend/**']
  pull_request:
    paths: ['backend/**']

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
      redis:
        image: redis:7

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt

      - name: Run tests
        run: |
          cd backend
          pytest --cov=app --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

### GitHub Actions (Mobile)

`.github/workflows/mobile-ci.yml`:

```yaml
name: Mobile CI
on:
  push:
    paths: ['mobile/**']
  pull_request:
    paths: ['mobile/**']

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'

      - name: Install dependencies
        run: |
          cd mobile
          flutter pub get

      - name: Analyze
        run: |
          cd mobile
          flutter analyze

      - name: Test
        run: |
          cd mobile
          flutter test
```

---

## Debugging Tests

### Backend Debugging

```python
# Add debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

# Use pytest with stdout
pytest -s tests/test_file.py

# Drop into debugger on failure
pytest --pdb tests/test_file.py
```

### Mobile Debugging

```dart
// Print debug info
debugPrint('Value: $value');

// Use assert for development checks
assert(value != null, 'Value should not be null');
```

---

## Test Environment Setup

### Local Testing

```bash
# Backend
cd backend
docker-compose up -d postgres redis  # Start dependencies
pytest                                # Run tests

# Mobile
cd mobile
flutter test
```

### CI/CD Testing

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests targeting those branches
- Changes to respective directories (`backend/**` or `mobile/**`)

---

## Writing New Tests

### Backend Test Template

```python
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_feature_name():
    """Test description."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # Arrange
        data = {"key": "value"}

        # Act
        response = await client.post("/endpoint", json=data)

        # Assert
        assert response.status_code == 200
        assert response.json()["expected_key"] == "expected_value"
```

### Mobile Test Template

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureName', () {
    test('should do something', () {
      // Arrange
      final input = 'test';

      // Act
      final result = processInput(input);

      // Assert
      expect(result, equals('expected'));
    });
  });
}
```
