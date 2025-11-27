import sys
import pytest
from pathlib import Path

# Add project root (2 levels up from tests/) to sys.path so tests can import 'app'
root = Path(__file__).resolve().parents[1]
if str(root) not in sys.path:
    sys.path.insert(0, str(root))


# Optionally set PYTHONPATH for runtime
import os
os.environ.setdefault('PYTHONPATH', str(root))

# Make sure tests don't depend on the system 'bcrypt' native extension.
# Override the global pwd_context used by the auth service to use a pure-python
# algorithm that doesn't require compiled C extensions. This keeps tests fast and
# avoids build/compat issues with the bcrypt wheel in CI/dev containers.
try:
    from passlib.context import CryptContext
    import app.services.auth_service as auth_service

    # Use pbkdf2_sha256 for tests to avoid bcrypt runtime issues (72 byte limit / C ext)
    auth_service.pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
except Exception:
    # If passlib isn't available in the minimal test environment, tests that rely on
    # password hashing may fail early; fail fast is OK for CI to report missing deps.
    pass


from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
import asyncio
from app.models.database import Base as DBBase
import app.models.database as database_module


# Replace the app's database engine at import-time so that module-level imports
# created by `from app.main import app` will receive the in-memory engine.
test_engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False, future=True)
test_async_session = sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)

# Create the tables immediately so that any import code that expects tables exists
async def _init_test_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(DBBase.metadata.create_all)

asyncio.run(_init_test_db())

# Bind into the app's database module
database_module.engine = test_engine
database_module.AsyncSessionLocal = test_async_session

@pytest.fixture
async def async_db():
    """Override the app's database engine to use an in-memory SQLite engine for tests.
    This avoids connecting to the dev Postgres instance and makes tests deterministic
    and faster.
    """
    async_session = test_async_session
    # Reset DB before each test to ensure isolation
    async with test_engine.begin() as conn:
        await conn.run_sync(DBBase.metadata.drop_all)
        await conn.run_sync(DBBase.metadata.create_all)
    # Provide a dependency override for FastAPI to use the test session
    async def _get_test_db():
        async with async_session() as session:
            yield session

    from app.main import app as _app
    _app.dependency_overrides[database_module.get_db] = _get_test_db
    yield
    _app.dependency_overrides.clear()
