"""
Call Service Exceptions

Custom exceptions for call-related errors.
"""


class CallServiceError(Exception):
    """Base exception for call service errors"""
    pass


class ContactNotAuthorizedError(CallServiceError):
    """Raised when user tries to call someone not in contacts"""
    pass


class UserOfflineError(CallServiceError):
    """Raised when target user is offline"""
    pass


class AlreadyInCallError(CallServiceError):
    """Raised when user is already in an active call"""
    pass


class CallNotFoundError(CallServiceError):
    """Raised when call is not found"""
    pass


class InvalidParticipantCountError(CallServiceError):
    """Raised when participant count is invalid (must be 2-4)"""
    pass
