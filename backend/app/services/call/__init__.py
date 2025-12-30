"""
Call Service Module

Re-exports CallService and exceptions for backwards compatibility.
"""
from .service import CallService
from .exceptions import (
    CallServiceError,
    ContactNotAuthorizedError,
    UserOfflineError,
    AlreadyInCallError,
    CallNotFoundError,
    InvalidParticipantCountError,
)

# Singleton instance
call_service = CallService()

__all__ = [
    "CallService",
    "call_service",
    "CallServiceError",
    "ContactNotAuthorizedError",
    "UserOfflineError",
    "AlreadyInCallError",
    "CallNotFoundError",
    "InvalidParticipantCountError",
]
