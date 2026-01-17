# API Documentation

## Base URL

```
http://<server-ip>:8000
```

## Authentication

All authenticated endpoints require a JWT Bearer token in the Authorization header:

```
Authorization: Bearer <token>
```

Tokens are obtained via `/auth/login` or `/auth/register` and expire after 7 days.

---

## Authentication API

### Register User

```http
POST /auth/register
Content-Type: application/json
```

**Request Body:**
```json
{
  "phone": "0501234567",
  "full_name": "John Doe",
  "password": "securepass",
  "primary_language": "en"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| phone | string | Yes | Phone number (6-20 chars) |
| full_name | string | Yes | Display name (1-255 chars) |
| password | string | Yes | Password (min 4 chars) |
| primary_language | string | No | Language code: "he", "en", "ru" (default: "he") |

**Response (201):**
```json
{
  "user_id": "uuid-string",
  "token": "jwt-token-string",
  "message": "User registered successfully"
}
```

**Errors:**
- `409`: Phone already registered

---

### Login

```http
POST /auth/login
Content-Type: application/json
```

**Request Body:**
```json
{
  "phone": "0501234567",
  "password": "securepass"
}
```

**Response (200):**
```json
{
  "user_id": "uuid-string",
  "token": "jwt-token-string",
  "full_name": "John Doe",
  "primary_language": "en"
}
```

**Errors:**
- `401`: Invalid credentials

---

### Get Current User

```http
GET /auth/me
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "id": "uuid-string",
  "phone": "0501234567",
  "full_name": "John Doe",
  "primary_language": "en",
  "is_online": true,
  "has_voice_sample": false,
  "voice_model_trained": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

### Update Profile

```http
PATCH /auth/profile
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "full_name": "John Smith",
  "primary_language": "he"
}
```

Both fields are optional. Only provided fields are updated.

**Response (200):** Updated user object (same as GET /auth/me)

---

### Logout

```http
POST /auth/logout
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Logged out successfully"
}
```

---

## Contacts API

### Search Users

```http
GET /contacts/search?q=<query>
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| q | string | Yes | Search query (name or phone) |

**Response (200):**
```json
{
  "users": [
    {
      "id": "uuid-string",
      "full_name": "Jane Doe",
      "phone": "0509876543",
      "primary_language": "he",
      "is_online": true
    }
  ]
}
```

---

### Get All Contacts

```http
GET /contacts
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "contacts": [
    {
      "id": "contact-uuid",
      "user_id": "owner-uuid",
      "contact_user_id": "contact-uuid",
      "contact_name": "Custom Nickname",
      "full_name": "Jane Doe",
      "phone": "0509876543",
      "primary_language": "he",
      "is_online": true,
      "is_favorite": false,
      "is_blocked": false,
      "added_at": "2024-01-10T15:00:00Z"
    }
  ],
  "pending_incoming": [
    {
      "contact_id": "request-uuid",
      "requester": { /* user object */ },
      "added_at": "2024-01-14T12:00:00Z"
    }
  ],
  "pending_outgoing": [ /* contact objects with status=pending */ ]
}
```

---

### Add Contact (Send Friend Request)

```http
POST /contacts/add
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "contact_user_id": "target-user-uuid",
  "contact_name": "Optional Nickname"
}
```

**Response (201):**
```json
{
  "contact_id": "uuid-string",
  "message": "Friend request sent"
}
```

**Errors:**
- `400`: Cannot add yourself
- `404`: User not found
- `409`: Contact already exists or request pending

---

### Accept Friend Request

```http
POST /contacts/{request_id}/accept
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Friend request accepted"
}
```

---

### Reject Friend Request

```http
POST /contacts/{request_id}/reject
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Friend request rejected"
}
```

---

### Delete Contact (Unfriend)

```http
DELETE /contacts/{contact_id}
Authorization: Bearer <token>
```

**Response (204):** No content

---

### Toggle Favorite

```http
PATCH /contacts/{contact_id}/favorite
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "is_favorite": true
}
```

---

### Toggle Block

```http
PATCH /contacts/{contact_id}/block
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "is_blocked": true
}
```

---

## Calls API

### Start Call

```http
POST /calls/start
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "participant_user_ids": ["user-uuid-1", "user-uuid-2"],
  "skip_contact_validation": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| participant_user_ids | array | Yes | 1-3 user IDs to call (max 4 total including caller) |
| skip_contact_validation | boolean | No | Skip friend check (default: false) |

**Response (200):**
```json
{
  "call_id": "call-uuid",
  "session_id": "session-uuid",
  "call_language": "he",
  "websocket_url": "ws://192.168.1.100:8000/ws/session-uuid",
  "participants": [
    {
      "id": "participant-uuid",
      "user_id": "user-uuid",
      "full_name": "John Doe",
      "phone": "0501234567",
      "primary_language": "en",
      "target_language": "en",
      "speaking_language": "he",
      "dubbing_required": true,
      "use_voice_clone": true,
      "voice_clone_quality": "good"
    }
  ]
}
```

**Errors:**
- `400`: Invalid participant count (must be 2-4 total)
- `403`: Not authorized (not in contacts)
- `404`: User not found or offline
- `409`: Already in an active call

---

### End Call

```http
POST /calls/end
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "call_id": "call-uuid"
}
```

**Response (200):**
```json
{
  "call_id": "call-uuid",
  "status": "ended",
  "duration_seconds": 125,
  "message": "Call ended successfully"
}
```

---

### Accept Incoming Call

```http
POST /calls/{call_id}/accept
Authorization: Bearer <token>
```

**Response (200):** Full call detail object (same as GET /calls/{call_id})

---

### Reject Incoming Call

```http
POST /calls/{call_id}/reject
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "status": "rejected",
  "call_id": "call-uuid",
  "message": "Call rejected successfully"
}
```

---

### Leave Call

```http
POST /calls/{call_id}/leave
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Left call successfully",
  "call_ended": false,
  "call_id": "call-uuid"
}
```

If fewer than 2 participants remain, `call_ended` will be `true`.

---

### Get Call Details

```http
GET /calls/{call_id}
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "call_id": "call-uuid",
  "session_id": "session-uuid",
  "call_language": "he",
  "status": "ongoing",
  "is_active": true,
  "started_at": "2024-01-15T10:30:00Z",
  "ended_at": null,
  "duration_seconds": 0,
  "participants": [ /* participant objects */ ]
}
```

---

### Get Call History

```http
GET /calls/history?limit=20
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| limit | integer | 20 | Max results (1-20) |

**Response (200):**
```json
{
  "calls": [
    {
      "call_id": "call-uuid",
      "session_id": "session-uuid",
      "initiated_at": "2024-01-15T10:30:00Z",
      "ended_at": "2024-01-15T10:35:00Z",
      "duration_seconds": 300,
      "language": "he",
      "status": "ended",
      "participant_count": 2
    }
  ]
}
```

---

### Toggle Mute

```http
POST /calls/{call_id}/mute?muted=true
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Mute toggled",
  "is_muted": true
}
```

---

### Debug: Reset Call State

```http
POST /calls/debug/reset_state
Authorization: Bearer <token>
```

Force leaves all active calls for current user. Useful for recovering from stuck states.

**Response (200):**
```json
{
  "message": "Reset successful. Left 1 calls.",
  "calls_left": ["call-uuid"]
}
```

---

## Voice API

### Upload Voice Sample

```http
POST /voice/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Form Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| file | file | Yes | Audio file (wav, mp3, ogg) |
| language | string | Yes | Recording language: "he", "en", "ru" |
| text_content | string | Yes | Text that was read |

**Response (200):**
```json
{
  "id": "recording-uuid",
  "user_id": "user-uuid",
  "language": "en",
  "text_content": "The quick brown fox...",
  "file_path": "/app/data/voice_samples/...",
  "quality_score": null,
  "is_processed": false,
  "used_for_training": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Errors:**
- `400`: Invalid file format or language

---

### Get Voice Recordings

```http
GET /voice/recordings
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "recordings": [ /* recording objects */ ],
  "total": 3
}
```

---

### Get Voice Status

```http
GET /voice/status
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "has_voice_sample": true,
  "voice_model_trained": false,
  "voice_quality_score": 75,
  "voice_clone_quality": "good",
  "recordings_count": 3,
  "processed_count": 2,
  "training_ready": true
}
```

---

### Train Voice Model

```http
POST /voice/train
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (optional):**
```json
{
  "recording_ids": ["rec-uuid-1", "rec-uuid-2"]
}
```

If `recording_ids` is null, uses best 2 processed samples automatically.

**Response (200):**
```json
{
  "message": "Voice model training queued",
  "status": "pending",
  "recordings_used": 2
}
```

**Errors:**
- `400`: Not enough processed samples (need 2+ with quality >= 40)

---

### Delete Recording

```http
DELETE /voice/recordings/{recording_id}
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "message": "Recording deleted"
}
```

---

## WebSocket Protocol

### Connection

```
ws://<server>:8000/ws/{session_id}?token={jwt}&call_id={call_id}
```

**Query Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| token | Yes | JWT authentication token |
| call_id | Yes | Call ID to join |

### Message Types

#### Control Messages (JSON)

**Heartbeat:**
```json
// Client → Server
{ "type": "ping" }

// Server → Client
{ "type": "pong" }
```

**Mute Control:**
```json
// Client → Server
{ "type": "mute", "muted": true }

// Server → Client (broadcast)
{ "type": "mute_status_changed", "user_id": "uuid", "is_muted": true }
```

**Leave Call:**
```json
// Client → Server
{ "type": "leave" }
```

**Participant Events:**
```json
{ "type": "participant_joined", "user_id": "uuid", "joined_at": "ISO8601" }
{ "type": "participant_left", "user_id": "uuid", "left_at": "ISO8601" }
```

**Transcription:**
```json
{
  "type": "translation",
  "speaker_id": "uuid",
  "transcript": "Original text",
  "translation": "Translated text",
  "source_lang": "he",
  "target_lang": "en",
  "timestamp_ms": 12500
}
```

**Interim Captions (Real-time):**
```json
{
  "type": "interim_transcript",
  "speaker_id": "uuid",
  "text": "Partial transcri...",
  "is_final": false,
  "language": "he"
}
```

**Call Ended:**
```json
{ "type": "call_ended", "reason": "All participants left" }
```

**Incoming Call (Lobby):**
```json
{
  "type": "incoming_call",
  "call_id": "uuid",
  "session_id": "uuid",
  "caller_id": "uuid",
  "caller_name": "John Doe",
  "caller_language": "he"
}
```

**Errors:**
```json
{ "type": "error", "error": "Error message" }
```

### Binary Messages

**Audio Data:**
- Format: Raw PCM16 bytes
- Sample rate: 16 kHz
- Channels: Mono
- Byte order: Little-endian
- Typical chunk: 3200 bytes (~100ms)

**Sending Audio:**
```javascript
// Send microphone audio
websocket.send(audioChunkBytes);  // Binary frame
```

**Receiving Audio:**
```javascript
websocket.onmessage = (event) => {
  if (event.data instanceof Blob) {
    // Binary audio from other participants
    playAudio(event.data);
  } else {
    // JSON control message
    handleMessage(JSON.parse(event.data));
  }
};
```

---

## Error Responses

All error responses follow this format:

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Common Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content (success, no body) |
| 400 | Bad Request (invalid input) |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (not allowed) |
| 404 | Not Found |
| 409 | Conflict (duplicate, already exists) |
| 500 | Internal Server Error |

---

## Rate Limits

Currently no rate limiting is implemented. For production:
- Recommend 100 requests/minute per user for REST API
- WebSocket connections limited to 1 per session

---

## Health Check

```http
GET /health
```

**Response (200):**
```json
{
  "status": "healthy"
}
```

No authentication required. Use for load balancer health checks.
