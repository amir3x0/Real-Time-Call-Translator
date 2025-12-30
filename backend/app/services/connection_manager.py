"""
WebSocket Connection Manager

DEPRECATED: This file is kept for backwards compatibility.
Import from app.services.connection instead.

Example:
    from app.services.connection import connection_manager, ConnectionManager
"""
from app.services.connection import (
    CallConnection,
    ConnectionManager,
    connection_manager,
)

__all__ = [
    "CallConnection",
    "ConnectionManager",
    "connection_manager",
]
