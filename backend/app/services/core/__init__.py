"""
Core Infrastructure Module

This module contains shared infrastructure components used across the application:
- MessageDeduplicator: TTL-based message deduplication
- CallRepository: Centralized database queries for calls

Usage:
    from app.services.core import get_message_deduplicator, get_call_repository
"""

from app.services.core.deduplicator import MessageDeduplicator, get_message_deduplicator
from app.services.core.repositories import CallRepository, get_call_repository

__all__ = [
    # Deduplication
    "MessageDeduplicator",
    "get_message_deduplicator",
    # Repositories
    "CallRepository",
    "get_call_repository",
]
