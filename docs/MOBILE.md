# Mobile App Documentation

## Overview

The Real-Time Call Translator mobile app is built with Flutter, targeting both iOS and Android platforms. It uses the Provider package for state management and follows a clean architecture pattern.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         UI Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │  Auth    │ │   Home   │ │  Call    │ │ Settings │        │
│  │ Screens  │ │  Screen  │ │ Screens  │ │  Screen  │        │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘        │
│       └────────────┴────────────┴────────────┘               │
│                           │                                   │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Providers (State)                    │   │
│  │  AuthProvider │ CallProvider │ ContactsProvider │ ... │   │
│  └────────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Services (Data)                      │   │
│  │  AuthService │ CallApiService │ WebSocketService │ ... │   │
│  └────────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   External                             │   │
│  │        Backend API │ WebSocket │ Device Audio          │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
mobile/lib/
├── main.dart                 # App entry point
├── config/
│   ├── app_config.dart       # Server configuration
│   ├── app_theme.dart        # UI theme definitions
│   └── constants.dart        # App constants
├── core/
│   └── navigation/
│       └── app_routes.dart   # Route definitions
├── data/
│   ├── services/             # API clients
│   │   ├── base_api_service.dart
│   │   ├── auth_service.dart
│   │   ├── call_api_service.dart
│   │   ├── contact_service.dart
│   │   └── voice_service.dart
│   └── websocket/
│       └── websocket_service.dart
├── models/                   # Data models
│   ├── user.dart
│   ├── contact.dart
│   ├── call.dart
│   ├── participant.dart
│   ├── transcription_entry.dart
│   ├── interim_caption.dart
│   ├── live_caption.dart
│   └── voice_recording.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── call_provider.dart
│   ├── contacts_provider.dart
│   ├── lobby_provider.dart
│   ├── settings_provider.dart
│   ├── audio_controller.dart
│   ├── caption_manager.dart
│   ├── transcription_manager.dart
│   └── incoming_call_handler.dart
├── screens/                  # UI screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── register_voice_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── call/
│   │   ├── active_call_screen.dart
│   │   ├── call_confirmation_screen.dart
│   │   ├── incoming_call_screen.dart
│   │   └── select_participants_screen.dart
│   ├── contacts/
│   │   ├── contacts_screen.dart
│   │   └── add_contact_screen.dart
│   └── settings/
│       └── settings_screen.dart
├── services/                 # Business logic
│   ├── permission_service.dart
│   └── voice_recording_service.dart
├── utils/
│   ├── language_utils.dart
│   └── pcm_stream_source.dart
└── widgets/                  # Reusable components
    ├── call/
    │   ├── participant_grid.dart
    │   ├── participant_card.dart
    │   ├── interim_caption_bubble.dart
    │   ├── live_caption_bubble.dart
    │   ├── floating_subtitle.dart
    │   ├── circle_control.dart
    │   ├── network_indicator.dart
    │   └── transcription_panel.dart
    ├── audio/
    │   └── voice_visualizer.dart
    ├── shared/
    │   ├── glass_card.dart
    │   ├── animated_gradient_background.dart
    │   └── language_selector.dart
    └── common/
        ├── custom_button.dart
        └── animated_button.dart
```

---

## Providers (State Management)

### AuthProvider

**Purpose:** Manages user authentication lifecycle

**State:**
```dart
bool isAuthenticated
String? userId
String? token
User? user
bool isLoading
String? error
```

**Key Methods:**
```dart
Future<void> checkAuthStatus()     // Restore session from storage
Future<bool> login(phone, password)
Future<bool> register(phone, fullName, password, language)
Future<void> logout()
Future<void> updateProfile(fullName, language)
```

**Usage:**
```dart
final auth = Provider.of<AuthProvider>(context);
if (auth.isAuthenticated) {
  // Show authenticated UI
}
```

---

### CallProvider

**Purpose:** Manages active call state, WebSocket, and audio

**State:**
```dart
CallStatus status           // idle, initiating, ringing, ongoing, ended
String? activeSessionId     // Current WebSocket session
String? activeCallId
List<CallParticipant> participants
List<LiveCaption> captionBubbles
List<TranscriptionEntry> transcriptionHistory
List<InterimCaption> interimCaptions
bool isMuted
bool isSpeakerOn
AudioController? audioController
```

**Key Methods:**
```dart
Future<void> startCall(List<String> participantUserIds)
Future<void> joinCall(sessionId, participants)
Future<void> endCall()
void toggleMute()
void toggleSpeaker()
void addCaptionBubble(caption)
void updateInterimCaption(speakerId, text)
```

**Call Status Flow:**
```
idle → initiating → ringing → ongoing → ended → idle
```

---

### ContactsProvider

**Purpose:** Manages contacts list and friend requests

**State:**
```dart
List<Contact> contacts
List<FriendRequest> pendingIncoming
List<Contact> pendingOutgoing
bool isLoading
```

**Key Methods:**
```dart
Future<void> loadContacts()
Future<List<User>> searchUsers(query)
Future<void> addContact(userId, nickname)
Future<void> acceptRequest(requestId)
Future<void> rejectRequest(requestId)
Future<void> deleteContact(contactId)
Future<void> toggleFavorite(contactId)
Future<void> toggleBlock(contactId)
```

---

### LobbyProvider

**Purpose:** Manages connection to lobby WebSocket for presence and incoming calls

**State:**
```dart
bool isConnected
IncomingCallInfo? incomingCall
```

**Key Methods:**
```dart
Future<void> connectToLobby()
void disconnectFromLobby()
void handleIncomingCall(callInfo)
void clearIncomingCall()
```

---

### AudioController

**Purpose:** Handles audio input/output (microphone recording, speaker playback)

**Recording Configuration:**
```dart
const audioSampleRate = 16000;        // 16 kHz
const audioSendIntervalMs = 100;       // Send every 100ms
const audioMinChunkSize = 3200;        // ~100ms of audio
```

**Playback Configuration:**
```dart
const audioMaxBufferSize = 8;          // Jitter buffer max
const audioMinBufferSize = 1;          // Start playback threshold
const audioPlaybackTimerMs = 150;      // Playback interval
```

**Features:**
- Acoustic Echo Cancellation (AEC)
- Noise Suppression
- Automatic Gain Control (AGC)
- Jitter buffering for smooth playback

**Key Methods:**
```dart
Future<void> initialize(WebSocketService ws)
Future<void> startRecording()
Future<void> stopRecording()
void handleIncomingAudio(Uint8List audioData)
void setMuted(bool muted)
void setSpeakerOn(bool speakerOn)
void dispose()
```

---

## Services (Data Layer)

### BaseApiService

**Purpose:** HTTP client wrapper with authentication

```dart
class BaseApiService {
  final String baseUrl;

  Future<Map<String, String>> _getHeaders();  // Adds Bearer token
  Future<Response> get(String endpoint);
  Future<Response> post(String endpoint, Map<String, dynamic> body);
  Future<Response> patch(String endpoint, Map<String, dynamic> body);
  Future<Response> delete(String endpoint);
}
```

### WebSocketService

**Purpose:** Real-time communication for calls

**Connection:**
```dart
Future<void> connect(sessionId, userId, token, callId)
```

**URL Format:**
```
ws://{serverIp}:{port}/ws/{sessionId}?token={jwt}&call_id={callId}
```

**Streams:**
```dart
Stream<Map<String, dynamic>> messages   // JSON control messages
Stream<Uint8List> audioStream           // Binary audio data
```

**Methods:**
```dart
void sendAudio(Uint8List audioData)
void sendMessage(Map<String, dynamic> json)
void setMuted(bool muted)
void disconnect()
```

**Reconnection:**
- Max 3 attempts
- 2-second delay between attempts
- Exponential backoff

---

## Screen Flow

### Authentication Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│   Splash    │────►│    Login    │────►│    Register     │
│   Screen    │     │   Screen    │◄────│    Screen       │
└─────────────┘     └──────┬──────┘     └────────┬────────┘
                           │                      │
                           ▼                      ▼
                    ┌─────────────┐     ┌─────────────────┐
                    │    Home     │◄────│ Register Voice  │
                    │   Screen    │     │    (optional)   │
                    └─────────────┘     └─────────────────┘
```

### Call Flow

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│    Home     │────►│    Select       │────►│    Call     │
│   Screen    │     │  Participants   │     │ Confirmation│
└─────────────┘     └─────────────────┘     └──────┬──────┘
                                                   │
                    ┌─────────────────┐            │
                    │  Active Call    │◄───────────┘
                    │    Screen       │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │      Home       │
                    │    (call ended) │
                    └─────────────────┘
```

### Incoming Call Flow

```
                    ┌─────────────────┐
Lobby WebSocket ───►│  Incoming Call  │
 (notification)     │    Handler      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Incoming Call  │
                    │    Screen       │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                              │
              ▼                              ▼
       ┌─────────────┐              ┌─────────────┐
       │   Accept    │              │   Reject    │
       │ Active Call │              │   Return    │
       └─────────────┘              └─────────────┘
```

---

## Models

### User
```dart
class User {
  final String id;
  final String phone;
  final String fullName;
  final String primaryLanguage;
  final bool isOnline;
  final bool hasVoiceSample;
  final bool voiceModelTrained;
  final DateTime createdAt;
}
```

### Contact
```dart
class Contact {
  final String id;
  final String userId;
  final String contactUserId;
  final String? contactName;  // Custom nickname
  final String fullName;
  final String phone;
  final String primaryLanguage;
  final bool isOnline;
  final bool isFavorite;
  final bool isBlocked;
  final String status;  // pending, accepted
  final DateTime addedAt;
}
```

### Call
```dart
class Call {
  final String id;
  final String sessionId;
  final String callLanguage;
  final CallStatus status;
  final bool isActive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final List<CallParticipant> participants;
}

enum CallStatus {
  initiating,
  idle,
  ringing,
  ongoing,
  ended,
  missed
}
```

### CallParticipant
```dart
class CallParticipant {
  final String id;
  final String oduserId;
  final String fullName;
  final String phone;
  final String primaryLanguage;
  final String targetLanguage;
  final String speakingLanguage;
  final bool dubbingRequired;
  final bool useVoiceClone;
  final String? voiceCloneQuality;
  final bool isMuted;
  final bool isConnected;
}
```

### TranscriptionEntry
```dart
class TranscriptionEntry {
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String? translatedText;
  final String sourceLanguage;
  final String? targetLanguage;
  final DateTime timestamp;
}
```

### InterimCaption
```dart
class InterimCaption {
  final String speakerId;
  final String speakerName;
  final String text;
  final String language;
  final bool isFinal;
  final DateTime timestamp;
}
```

---

## Widgets

### Call Widgets

| Widget | Purpose |
|--------|---------|
| `ParticipantGrid` | Displays participant cards in adaptive grid layout |
| `ParticipantCard` | Individual participant with avatar, name, status |
| `InterimCaptionBubble` | Real-time typing indicator with animation |
| `LiveCaptionBubble` | Final translation caption with auto-dismiss |
| `FloatingSubtitle` | Bottom-positioned subtitle display |
| `CircleControl` | Circular button (mute, speaker, end call) |
| `NetworkIndicator` | Connection quality indicator |
| `TranscriptionPanel` | Scrollable transcript history |

### Shared Widgets

| Widget | Purpose |
|--------|---------|
| `GlassCard` | Frosted glass effect container |
| `AnimatedGradientBackground` | Animated gradient backdrop |
| `LanguageSelector` | Language picker dropdown |

---

## Configuration

### App Constants (`lib/config/constants.dart`)

```dart
class AppConstants {
  // Audio - Outgoing
  static const int audioSendIntervalMs = 100;
  static const int audioMinChunkSize = 3200;
  static const int audioSampleRate = 16000;

  // Audio - Incoming
  static const int audioMaxBufferSize = 8;
  static const int audioMinBufferSize = 1;
  static const int audioPlaybackTimerMs = 150;

  // WebSocket
  static const int wsReconnectDelaySeconds = 2;
  static const int wsPingIntervalSeconds = 10;
  static const int wsHeartbeatIntervalSeconds = 30;
  static const int wsMaxReconnectAttempts = 3;

  // Call
  static const int incomingCallTimeoutSeconds = 30;

  // Captions
  static const int captionBubbleDisplayDurationSeconds = 4;
  static const int maxTranscriptionEntries = 100;
  static const int interimCaptionTimeoutMs = 3000;
}
```

### App Config (`lib/config/app_config.dart`)

```dart
class AppConfig {
  static const String defaultServerIp = '192.168.1.100';
  static const int defaultServerPort = 8000;

  static String get serverIp => _serverIp ?? defaultServerIp;
  static int get serverPort => _serverPort ?? defaultServerPort;

  static String get baseUrl => 'http://$serverIp:$serverPort';
  static String get wsUrl => 'ws://$serverIp:$serverPort';
}
```

---

## Permissions

Required permissions (Android/iOS):

| Permission | Purpose |
|------------|---------|
| Microphone | Audio recording for calls |
| Internet | API and WebSocket communication |

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice calls</string>
```

---

## Building

### Debug Build
```bash
flutter run
```

### Release Build (Android)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Release Build (iOS)
```bash
flutter build ios --release
# Then archive in Xcode
```

### Analyze Code
```bash
flutter analyze
```

### Run Tests
```bash
flutter test
```
