"""
Core Infrastructure Module

This module contains shared infrastructure components used across the application:
- MessageDeduplicator: TTL-based message deduplication
- CallRepository: Centralized database queries for calls

Usage:
    from app.services.core import message_deduplicator, call_repository
"""

from app.services.core.deduplicator import MessageDeduplicator, message_deduplicator
from app.services.core.repositories import CallRepository, call_repository

__all__ = [
    # Deduplication
    "MessageDeduplicator",
    "message_deduplicator",
    # Repositories
    "CallRepository",
    "call_repository",
]
