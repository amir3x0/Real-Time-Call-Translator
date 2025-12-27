# Contributing to Real-Time Call Translator

First off, thank you for considering contributing to Real-Time Call Translator! It's people like you that make this project such a great tool.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Project Structure](#project-structure)

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

### Our Standards

**Examples of behavior that contributes to a positive environment:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Examples of unacceptable behavior:**
- The use of sexualized language or imagery
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have:

- **Python 3.10+** installed
- **Docker & Docker Compose** set up
- **Flutter SDK 3.35+** (for mobile development)
- **Git** configured with your credentials
- A **Google Cloud account** (for testing AI features)

### Fork the Repository

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/Real-Time-Call-Translator.git
   cd Real-Time-Call-Translator
   ```

3. Add the original repository as upstream:
   ```bash
   git remote add upstream https://github.com/amir3x0/Real-Time-Call-Translator.git
   ```

4. Create a branch for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## 🤝 How Can I Contribute?

### Reporting Bugs

**Before submitting a bug report:**
- Check the existing issues to avoid duplicates
- Collect relevant information (OS, Python version, error messages, logs)

**How to submit a good bug report:**

```markdown
**Description:**
A clear and concise description of the bug.

**Steps to Reproduce:**
1. Go to '...'
2. Click on '...'
3. See error

**Expected Behavior:**
What you expected to happen.

**Actual Behavior:**
What actually happened.

**Environment:**
- OS: [e.g., Windows 11, macOS 14, Ubuntu 22.04]
- Python version: [e.g., 3.10.5]
- Docker version: [e.g., 24.0.5]
- Flutter version: [e.g., 3.35.1]

**Logs/Screenshots:**
Attach relevant logs or screenshots.
```

### Suggesting Features

**Before submitting a feature request:**
- Check if the feature already exists
- Ensure it aligns with project goals

**How to submit a feature request:**

```markdown
**Feature Description:**
A clear description of the proposed feature.

**Use Case:**
Explain the problem this feature would solve.

**Proposed Solution:**
Describe how you envision the feature working.

**Alternatives Considered:**
Other solutions you've thought about.
```

### Code Contributions

We welcome code contributions! Here are areas where you can help:

#### Backend (Python/FastAPI)
- [ ] Google Cloud API integrations
- [ ] Audio processing pipeline improvements
- [ ] Database optimization
- [ ] API endpoint enhancements
- [ ] Performance improvements
- [ ] Security hardening

#### Mobile (Flutter)
- [ ] UI/UX improvements
- [ ] Call management interface
- [ ] Voice recording features
- [ ] Real-time translation display
- [ ] Push notifications
- [ ] Offline mode

#### DevOps
- [ ] CI/CD pipeline setup
- [ ] Kubernetes deployment configs
- [ ] Monitoring and logging
- [ ] Performance benchmarking
- [ ] Security scanning

#### Documentation
- [ ] API documentation
- [ ] Code comments
- [ ] Tutorial videos
- [ ] Architecture diagrams
- [ ] Translation of docs to other languages

---

## 🛠 Development Setup

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Build Docker image:**
   ```bash
   docker build -t translator-backend .
   ```

4. **Start services:**
   ```bash
   docker-compose up -d
   ```

5. **Initialize database:**
   ```bash
   docker exec -it translator_api python scripts/create_tables.py
   ```

6. **Run tests:**
   ```bash
   docker exec -it translator_api pytest
   ```

### Mobile Setup (Flutter, updated)
1. **Navigate to mobile directory:**
    ```powershell
    cd mobile
    ```

2. **Install dependencies:**
    ```powershell
    flutter pub get
    ```

3. **Run on device or emulator:**
    ```powershell
    flutter run
    ```

4. **Recommended commands for development & testing:**
    ```powershell
    # Run static analysis
    flutter analyze

    # Run widget tests
    flutter test

    # Build APK for testing
    flutter build apk --debug
    ```

5. **Notes and best practices:**
    - Request and check microphone permissions (via `permission_handler`) before recording.
    - Use `flutter_sound` and `just_audio` for audio capture & replay. Process audio at 16kHz, mono with 200ms chunk sizes when sending over WebSocket.
    - The main API service can be found at `mobile/lib/api/api_service.dart`.
    - WebSocket adapters and message serialization live under `mobile/lib/websocket/` and are used by `call_provider`.
    - Register providers in `main.dart` using `MultiProvider` for `auth_provider`, `call_provider`, and `settings_provider`.

---

## 📝 Coding Standards

### Python Style Guide

We follow **PEP 8** with some modifications:

#### Formatting

```python
# ✅ Good
def calculate_translation_score(
    text: str,
    source_lang: str,
    target_lang: str
) -> float:
    """Calculate quality score for translation.
    
    Args:
        text: Input text to translate
        source_lang: Source language code (ISO 639-1)
        target_lang: Target language code (ISO 639-1)
    
    Returns:
        Quality score between 0.0 and 1.0
    """
    # Implementation
    pass

# ❌ Bad
def calc(t,s,tg):
    pass
```

#### Type Hints

Always use type hints:

```python
# ✅ Good
from typing import List, Optional

async def get_user_languages(user_id: str) -> List[str]:
    pass

def get_voice_sample(user_id: str) -> Optional[bytes]:
    pass

# ❌ Bad
async def get_user_languages(user_id):
    pass
```

#### Docstrings

Use Google-style docstrings:

```python
def translate_text(text: str, target_language: str) -> str:
    """Translate text to target language using Google Translate.
    
    This function handles translation with caching and error handling.
    It automatically detects the source language if not specified.
    
    Args:
        text: The text to translate
        target_language: Target language code (e.g., 'he', 'en', 'ru')
    
    Returns:
        Translated text string
    
    Raises:
        TranslationError: If translation fails
        InvalidLanguageError: If target language is not supported
    
    Example:
        >>> translate_text("Hello world", "he")
        'שלום עולם'
    """
    pass
```

#### Import Organization

```python
# Standard library imports
import asyncio
import logging
from datetime import datetime
from typing import List, Optional

# Third-party imports
from fastapi import FastAPI, HTTPException
from sqlalchemy import Column, String
import redis

# Local imports
from app.config.settings import settings
from app.models.user import User
from app.services.translation import TranslationService
```

#### Async/Await

Always use async/await for I/O operations:

```python
# ✅ Good
async def process_audio_chunk(session_id: str, audio_data: bytes):
    redis_client = await get_redis()
    await redis_client.xadd(f"stream:audio:{session_id}", {"data": audio_data})

# ❌ Bad
def process_audio_chunk(session_id, audio_data):
    redis_client = get_redis()  # Blocking call
    redis_client.xadd(...)
```

### Dart/Flutter Style Guide

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

```dart
// ✅ Good
class CallService {
  Future<void> initiateCall({
    required String sessionId,
    required String targetLanguage,
  }) async {
    // Implementation
  }
}

// ❌ Bad
class callservice {
  void InitiateCall(sessionId, targetLanguage) {
    // Implementation
  }
}
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Python Variables | `snake_case` | `user_id`, `translation_result` |
| Python Functions | `snake_case` | `get_user()`, `translate_text()` |
| Python Classes | `PascalCase` | `User`, `TranslationService` |
| Python Constants | `UPPER_SNAKE_CASE` | `MAX_RETRIES`, `DEFAULT_LANGUAGE` |
| Dart Variables | `camelCase` | `userId`, `targetLanguage` |
| Dart Classes | `PascalCase` | `CallScreen`, `VoiceService` |
| Dart Constants | `lowerCamelCase` | `defaultTimeout` |

---

## 🧪 Testing Guidelines

### Backend Testing

#### Unit Tests

```python
# tests/test_translation_service.py
import pytest
from app.services.translation import TranslationService

@pytest.mark.asyncio
async def test_translate_text():
    """Test basic translation functionality."""
    service = TranslationService()
    result = await service.translate("Hello", target_lang="he")
    assert result == "שלום"

@pytest.mark.asyncio
async def test_translate_with_invalid_language():
    """Test translation with invalid language code."""
    service = TranslationService()
    with pytest.raises(InvalidLanguageError):
        await service.translate("Hello", target_lang="invalid")
```

#### Integration Tests

```python
# tests/test_api_integration.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_health_endpoint(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

@pytest.mark.asyncio
async def test_upload_audio_chunk(client):
    """Test audio chunk upload."""
    files = {"file": ("audio.wav", b"fake audio data", "audio/wav")}
    response = client.post("/api/sessions/test123/chunk", files=files)
    assert response.status_code == 200
```

#### Running Tests

```bash
# Run all tests
docker exec -it translator_api pytest

# Run specific test file
docker exec -it translator_api pytest tests/test_translation_service.py

# Run with coverage
docker exec -it translator_api pytest --cov=app tests/

# Run with verbose output
docker exec -it translator_api pytest -v
```

### Test Coverage Requirements

- **Minimum coverage**: 80%
- **New features**: Must include tests
- **Bug fixes**: Should include regression tests

---

## 📤 Pull Request Process

### Before Submitting

1. **Update your branch:**
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout feature/your-feature
   git rebase develop
   ```

2. **Run tests:**
   ```bash
   docker exec -it translator_api pytest
   ```

3. **Check code style:**
   ```bash
   # Install linting tools
   pip install black flake8 mypy
   
   # Format code
   black backend/app
   
   # Check linting
   flake8 backend/app
   
   # Type checking
   mypy backend/app
   ```

4. **Update documentation:**
   - Update README.md if needed
   - Add docstrings to new functions
   - Update API documentation

### PR Template

When creating a PR, use this template:

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Related Issue
Fixes #(issue number)

## Changes Made
- List of changes
- With bullet points
- For clarity

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] All tests passing locally
- [ ] Tested on real device (for mobile)

## Screenshots (if applicable)
Add screenshots here

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing unit tests pass locally
- [ ] Any dependent changes have been merged
```

### Review Process

1. **Automated checks** run on your PR (CI/CD)
2. **Code review** by maintainers
3. **Changes requested** if needed
4. **Approval** from at least one maintainer
5. **Merge** to develop branch

### After Merge

1. **Delete your feature branch:**
   ```bash
   git branch -d feature/your-feature
   git push origin --delete feature/your-feature
   ```

2. **Update your local develop:**
   ```bash
   git checkout develop
   git pull upstream develop
   ```

---

## 📂 Project Structure

Understanding the project structure:

```
Real-Time-Call-Translator/
├── backend/                      # Python/FastAPI backend
│   ├── app/
│   │   ├── api/                 # API endpoints
│   │   ├── config/              # Configuration
│   │   ├── models/              # Database models
│   │   ├── services/            # Business logic
│   │   └── main.py              # App entry point
│   ├── scripts/                 # Utility scripts
│   ├── tests/                   # Test files
│   └── docker-compose.yml       # Docker orchestration
├── mobile/                      # Flutter mobile app
│   ├── lib/
│   │   ├── screens/            # UI screens
│   │   ├── services/           # API clients
│   │   ├── models/             # Data models
│   │   └── main.dart           # App entry point
│   └── test/                   # Widget tests
├── docs/                       # Documentation
├── .gitignore                  # Git ignore rules
├── README.md                   # Project README
├── GIT_INSTRUCTIONS.md        # Git workflow guide
└── CONTRIBUTING.md            # This file
```

---

## 🎯 Development Workflow

### Feature Development

```bash
# 1. Create feature branch
git checkout -b feature/voice-quality-scoring develop

# 2. Make changes
# Edit files...

# 3. Test changes
docker exec -it translator_api pytest

# 4. Commit changes
git add .
git commit -m "feat: implement voice quality scoring algorithm"

# 5. Push to your fork
git push origin feature/voice-quality-scoring

# 6. Create Pull Request on GitHub
```

### Bug Fixes

```bash
# 1. Create bugfix branch
git checkout -b bugfix/redis-timeout develop

# 2. Fix the bug
# Edit files...

# 3. Add regression test
# Create test in tests/

# 4. Verify fix
docker exec -it translator_api pytest tests/test_redis.py

# 5. Commit
git commit -m "fix: resolve Redis connection timeout issue"

# 6. Push and create PR
git push origin bugfix/redis-timeout
```

---

## 💡 Tips for Contributors

### Communication

- **Ask questions** - No question is too simple
- **Share ideas** - Discuss features before implementing
- **Be patient** - Reviews may take a few days
- **Be respectful** - Everyone is learning

### Good Practices

- **Start small** - Begin with documentation or small bugs
- **One feature per PR** - Keep PRs focused
- **Write tests** - Tests help prevent regressions
- **Update docs** - Keep documentation in sync
- **Follow conventions** - Consistency matters

### Getting Help

- **GitHub Issues** - For bug reports and feature requests
- **Discussions** - For general questions
- **Code Comments** - For specific implementation questions

---

## 🏆 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes for significant contributions
- GitHub contributors page

Thank you for contributing to Real-Time Call Translator! 🎉

---

**Questions?** Open an issue or reach out to the maintainers.

**Ready to contribute?** Check out the [good first issue](https://github.com/amir3x0/Real-Time-Call-Translator/labels/good%20first%20issue) label!
