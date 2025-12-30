"""
Connection Management Module

Re-exports ConnectionManager and CallConnection for backwards compatibility.
"""
from .models import CallConnection
from .manager import ConnectionManager

# Singleton instance
connection_manager = ConnectionManager()

__all__ = [
    "CallConnection",
    "ConnectionManager",
    "connection_manager",
]
