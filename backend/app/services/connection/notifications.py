"""
Connection Notifications

Functions for sending real-time notifications to connected users:
- User status changes
- Contact requests
- Incoming calls
"""
from datetime import datetime
from typing import Dict, List, Any, TYPE_CHECKING
import logging

if TYPE_CHECKING:
    from .models import CallConnection

logger = logging.getLogger(__name__)


async def broadcast_user_status(
    sessions: Dict[str, Dict[str, "CallConnection"]],
    user_id: str,
    is_online: bool,
    contact_user_ids: List[str]
) -> int:
    """
    Broadcast user status change to all their contacts.
    
    Args:
        sessions: Active sessions dictionary
        user_id: ID of the user whose status changed
        is_online: New online status
        contact_user_ids: List of contact user IDs to notify
        
    Returns:
        Number of contacts notified
    """
    if not contact_user_ids:
        return 0
    
    notification = {
        "type": "user_status_changed",
        "user_id": user_id,
        "is_online": is_online,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    notified_count = 0
    # Find all connections for contact users
    for contact_user_id in contact_user_ids:
        for session_id, connections in sessions.items():
            for conn in connections.values():
                if conn.user_id == contact_user_id:
                    try:
                        await conn.send_json(notification)
                        notified_count += 1
                        logger.debug(f"Notified user {contact_user_id} about {user_id} status: {is_online}")
                    except Exception as e:
                        logger.error(f"Error notifying user {contact_user_id}: {e}")
    
    return notified_count


async def notify_contact_request(
    sessions: Dict[str, Dict[str, "CallConnection"]],
    user_sessions: Dict[str, str],
    target_user_id: str,
    requester_id: str,
    requester_name: str,
    request_id: str
) -> bool:
    """
    Notify a user of a new contact request.
    
    Args:
        sessions: Active sessions dictionary
        user_sessions: User to session mapping
        target_user_id: ID of user to notify
        requester_id: ID of requester
        requester_name: Name of requester
        request_id: ID of the request
        
    Returns:
        True if notification sent
    """
    notification = {
        "type": "contact_request",
        "request_id": request_id,
        "requester_id": requester_id,
        "requester_name": requester_name,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    session_id = user_sessions.get(target_user_id)
    if not session_id:
        return False
    
    conn = sessions.get(session_id, {}).get(target_user_id)
    if not conn:
        return False
    
    return await conn.send_json(notification)


async def notify_incoming_call(
    sessions: Dict[str, Dict[str, "CallConnection"]],
    user_id: str,
    call_id: str,
    caller_id: str,
    caller_name: str,
    caller_language: str
) -> bool:
    """
    Send incoming call notification to user via WebSocket if connected.
    
    Args:
        sessions: Active sessions dictionary
        user_id: ID of the user to notify
        call_id: ID of the incoming call
        caller_id: ID of the caller
        caller_name: Name of the caller
        caller_language: Language of the call
        
    Returns:
        True if notification was sent
    """
    sent_any = False
    for session_id, connections in sessions.items():
        for conn in connections.values():
            if conn.user_id == user_id:
                notification = {
                    "type": "incoming_call",
                    "call_id": call_id,
                    "caller_id": caller_id,
                    "caller_name": caller_name,
                    "call_language": caller_language,
                    "timestamp": datetime.utcnow().isoformat()
                }
                try:
                    await conn.send_json(notification)
                    logger.info(f"Sent incoming call notification to user {user_id} in session {session_id}")
                    sent_any = True
                except Exception as e:
                    logger.error(f"Error sending incoming call notification: {e}")
    
    if not sent_any:
        logger.debug(f"User {user_id} not connected, cannot send incoming call notification")
    
    return sent_any
