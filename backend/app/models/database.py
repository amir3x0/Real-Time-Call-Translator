"""Database configuration and session management.

This module provides:
- Async SQLAlchemy engine configuration with connection pooling
- Session factory for database operations
- FastAPI dependency for request-scoped sessions
- Database initialization and reset utilities
"""

import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config.settings import settings
from app.config.constants import DB_POOL_SIZE, DB_POOL_MAX_OVERFLOW

logger = logging.getLogger(__name__)

# Build async database URL with asyncpg driver
DATABASE_URL = (
    f"postgresql+asyncpg://{settings.DB_USER}:{settings.DB_PASSWORD}"
    f"@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
)

# Create async engine
engine = create_async_engine(
    DATABASE_URL,
    echo=settings.DEBUG,
    future=True,
    pool_pre_ping=True,
    pool_size=DB_POOL_SIZE,
    max_overflow=DB_POOL_MAX_OVERFLOW
)

# Create async session factory
AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Base class for models
Base = declarative_base()


# Dependency for FastAPI
async def get_db():
    """Database dependency for FastAPI endpoints"""
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """Initialize database by creating all tables.

    Creates tables defined in SQLAlchemy models if they don't exist.
    Safe to call multiple times (idempotent operation).
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables initialized successfully")


async def reset_db():
    """Drop all database tables.

    WARNING: This permanently deletes all data. Use only in development
    or when intentionally resetting the database schema.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    logger.warning("Database tables dropped - all data removed")