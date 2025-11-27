# 📋 COMPREHENSIVE COPILOT PROMPT: Real-Time Call Translation - Phase 1 Refactoring

## 🎯 **PROJECT CONTEXT**

You are working on a **Real-Time Multilingual Call Translation** system - a capstone project for Braude College. This system enables 2-4 participants to speak in different languages (Hebrew, English, Russian) and hear real-time translations while preserving each speaker's voice through AI voice cloning.

**Current Status:** Week 1 Day 4 Complete ✅
- Backend infrastructure (FastAPI, PostgreSQL, Redis, Docker) ✅
- Flutter mobile app with basic structure ✅
- Database models created ✅
- Providers, screens, widgets established ✅

**Your Mission:** Implement the **Phone-First UX Refactoring** based on the recent design decisions from the Gemini conversation.

---

## 🔄 **CRITICAL DESIGN CHANGES** (From Gemini Discussion)

### **Authentication Simplification**
❌ **OLD:** Email + Password + OTP verification  
✅ **NEW:** Phone + Full Name + Password (no OTP, simpler registration)

**Rationale:** This is an academic capstone project, not a production SaaS. We're removing SMS API complexity to focus on the core translation technology.

### **Language Simplification**
❌ **OLD:** Separate "I speak" and "I hear" language selection  
✅ **NEW:** Single `primary_language` per user (same for speaking and listening)

**Supported Languages:** Only 3 languages
- `he` - Hebrew (🇮🇱)
- `en` - English (🇺🇸)  
- `ru` - Russian (🇷🇺)

### **Contact Management**
❌ **OLD:** Sync with phone's contact list  
✅ **NEW:** Internal app-only contacts with DB search

**How it works:**
- Users search for other registered users by phone number or name
- Results come from the PostgreSQL `users` table
- When "Add Contact" is clicked, a record is created in the `contacts` table
- No external phone book integration

---

## 📐 **ARCHITECTURE OVERVIEW**

### **Technology Stack**

**Backend (Python):**
- FastAPI 0.104.1
- PostgreSQL 15 + SQLAlchemy 2.0 (async)
- Redis 7 (caching + message queuing)
- Google Cloud APIs (STT, Translate, TTS)
- **ResembleAI Chatterbox** (voice cloning) - https://huggingface.co/ResembleAI/chatterbox
- WebSocket (real-time audio streaming)

**Frontend (Flutter):**
- Flutter 3.35+ / Dart 3.9
- State Management: `provider` package
- Audio: `flutter_sound` + `just_audio`
- WebSocket: `web_socket_channel`
- UI: Material Design 3, Glassmorphism + Neon aesthetic

### **Current File Structure**

```
backend/
├── app/
│   ├── models/          # 6 models (User, Call, CallParticipant, Contact, VoiceModel, Message)
│   ├── api/             # REST endpoints (to be implemented)
│   ├── services/        # Business logic (translation, voice, etc.)
│   ├── config/          # Settings, Redis, database
│   └── main.py          # FastAPI entry point
├── docker-compose.yml
└── requirements.txt

mobile/
├── lib/
│   ├── config/          # app_config.dart, app_theme.dart
│   ├── models/          # User, Call, CallParticipant (matches backend)
│   ├── providers/       # auth_provider, call_provider, contacts_provider, settings_provider
│   ├── services/        # audio_service.dart
│   ├── api/             # api_service.dart (REST client)
│   ├── websocket/       # WebSocket adapters
│   ├── screens/         # login, home, call, contacts, settings
│   └── widgets/         # participant_card, voice_visualizer, custom_button, etc.
└── pubspec.yaml
```

---

## 🎯 **YOUR IMPLEMENTATION TASKS**

### **Phase 1A: Backend Refactoring (Python/FastAPI)**

#### **Task 1.1: Update User Model**
📁 **File:** `backend/app/models/user.py`

**Changes Needed:**
1. **Replace** `email` field with `phone` field:
   ```python
   phone = Column(String(20), unique=True, nullable=False, index=True)
   ```
2. **Add** `full_name` field:
   ```python
   full_name = Column(String(255), nullable=False)
   ```
3. **Remove** `email` field entirely
4. **Ensure** `primary_language` is a single field (not separate "speak" and "hear")
5. **Update** `to_dict()` method to reflect new fields

**Validation Rules:**
- Phone must be unique across all users
- Phone format: Israeli format (05X-XXX-XXXX) but accept any string for flexibility
- `primary_language` must be in `['he', 'en', 'ru']`
- `full_name` max 255 characters

---

#### **Task 1.2: Implement Auth Endpoints**
📁 **File:** `backend/app/api/auth.py` (create if doesn't exist)

**Endpoints to Create:**

1. **POST `/api/auth/register`**
   ```python
   class RegisterRequest(BaseModel):
       phone: str
       full_name: str
       password: str
       primary_language: str  # 'he', 'en', or 'ru'
   
   class RegisterResponse(BaseModel):
       user_id: str
       token: str
       message: str
   ```
   - Hash password using `bcrypt` or `passlib`
   - Validate language code
   - Check phone uniqueness
   - Create user in DB
   - Generate JWT token
   - Return user ID + token

2. **POST `/api/auth/login`**
   ```python
   class LoginRequest(BaseModel):
       phone: str
       password: str
   
   class LoginResponse(BaseModel):
       user_id: str
       token: str
       full_name: str
       primary_language: str
   ```
   - Find user by phone
   - Verify password hash
   - Generate JWT token
   - Return user data + token

3. **GET `/api/auth/me`**
   - **Headers:** `Authorization: Bearer <token>`
   - Return current user profile
   - Verify JWT token validity

**Security Requirements:**
- Use JWT with expiration (7 days recommended)
- Hash passwords before storing (use `passlib[bcrypt]`)
- Return 401 for invalid credentials
- Return 409 for duplicate phone on registration

---

#### **Task 1.3: Implement Contacts Endpoints**
📁 **File:** `backend/app/api/contacts.py` (create if doesn't exist)

**Endpoints to Create:**

1. **GET `/api/users/search?query={query}`**
   ```python
   class UserSearchResult(BaseModel):
       id: str
       full_name: str
       phone: str
       primary_language: str
   
   class UserSearchResponse(BaseModel):
       results: List[UserSearchResult]
   ```
   - Search users by `full_name` OR `phone` (case-insensitive partial match)
   - Exclude current user from results
   - Limit to 20 results
   - Return list of matching users

2. **POST `/api/contacts/add`**
   ```python
   class AddContactRequest(BaseModel):
       contact_user_id: str
   
   class AddContactResponse(BaseModel):
       contact_id: str
       message: str
   ```
   - **Headers:** `Authorization: Bearer <token>`
   - Add contact relationship to `contacts` table
   - Prevent duplicate contacts
   - Return contact ID

3. **GET `/api/contacts`**
   ```python
   class ContactResponse(BaseModel):
       id: str
       user_id: str
       full_name: str
       phone: str
       primary_language: str
       added_at: str
   
   class ContactsListResponse(BaseModel):
       contacts: List[ContactResponse]
   ```
   - **Headers:** `Authorization: Bearer <token>`
   - Return all contacts for authenticated user
   - Include user details from `users` table (join)

4. **DELETE `/api/contacts/{contact_id}`**
   - Remove contact relationship
   - Return 204 No Content on success

---

#### **Task 1.4: Implement Call Initiation Logic**
📁 **File:** `backend/app/api/calls.py` (create if doesn't exist)

**Endpoint to Create:**

**POST `/api/calls/start`**
```python
class StartCallRequest(BaseModel):
    participant_user_ids: List[str]  # 1-3 other users (total 2-4 including caller)

class StartCallResponse(BaseModel):
    session_id: str
    websocket_url: str
    participants: List[ParticipantInfo]
```

**Logic:**
1. Authenticate caller from JWT token
2. Validate that all `participant_user_ids` exist in `users` table
3. Validate maximum 4 total participants (caller + 3 others)
4. Create a new `Call` record in DB with status `'initiating'`
5. Create `CallParticipant` records for each user
6. Generate unique `session_id` (UUID)
7. Return `session_id` and WebSocket URL (`ws://server/ws/{session_id}`)

**Important:** For now, we're NOT implementing push notifications for incoming calls. Assume all participants' apps are open and polling or connected to a "lobby" WebSocket.

---

### **Phase 1B: Flutter Refactoring (Dart/Flutter)**

#### **Task 2.1: Update User Model**
📁 **File:** `mobile/lib/models/user.dart`

**Changes:**
1. Replace `email` with `phone`
2. Replace `name` with `fullName`
3. Ensure `primaryLanguage` is a single field
4. Update `fromJson` and `toJson` methods

**Example:**
```dart
class User {
  final String id;
  final String phone;
  final String fullName;
  final String primaryLanguage; // 'he', 'en', or 'ru'
  final DateTime createdAt;

  User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.primaryLanguage,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String,
      primaryLanguage: json['primary_language'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'primary_language': primaryLanguage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

---

#### **Task 2.2: Refactor Auth Screens**

##### **2.2A: Phone Login Screen**
📁 **File:** `mobile/lib/screens/auth/phone_login_screen.dart`

**UI Requirements:**
- **Background:** Dark gradient (Glassmorphism aesthetic from `app_theme.dart`)
- **Input Fields:**
  - Phone number field (with Israeli prefix hint: "05X-XXX-XXXX")
  - Password field (obscured text)
- **Button:** "Log In" (use `AnimatedButton` widget if available)
- **Link:** "Don't have an account? Register here"
- **Validation:**
  - Phone cannot be empty
  - Password cannot be empty

**Provider Integration:**
```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
await authProvider.login(phone, password);

if (authProvider.authStatus == AuthStatus.authenticated) {
  Navigator.pushReplacementNamed(context, '/home');
} else {
  // Show error message (use FlashBar or SnackBar)
}
```

---

##### **2.2B: Register Screen**
📁 **File:** `mobile/lib/screens/auth/register_screen.dart`

**UI Requirements:**
- **Input Fields:**
  1. Full Name
  2. Phone Number
  3. Password
  4. Confirm Password
- **Language Selector:** 3 large chips:
  - 🇮🇱 Hebrew
  - 🇺🇸 English
  - 🇷🇺 Russian
- **Button:** "Create Account"
- **Validation:**
  - All fields required
  - Passwords must match
  - One language must be selected

**Flow:**
1. User fills form
2. Clicks "Create Account"
3. Navigate to `VoiceCalibrationScreen` (next step)

---

##### **2.2C: Voice Calibration Screen**
📁 **File:** `mobile/lib/screens/auth/voice_calibration_screen.dart`

**Purpose:** Onboarding step to record user's voice for voice cloning.

**UI Requirements:**
- **Instruction Card:** (Glassmorphism) "We need a sample of your voice to preserve your identity during calls."
- **Reuse:** `VoiceRecorderWidget` from `mobile/lib/widgets/voice_recorder_widget.dart`
- **Reuse:** `VoiceVisualizer` from `mobile/lib/widgets/audio/voice_visualizer.dart`
- **Recording Logic:** Use `audio_service.dart` to record 10-15 seconds
- **Fun Fact:** Display a random translation fun fact while recording
- **Upload:** After recording, upload to `/api/users/{user_id}/voice-sample`
- **Animation:** Show "Voice DNA Created" success animation (Lottie or custom)
- **Button:** "Complete Setup" → Navigate to `/home`

---

#### **Task 2.3: Update AuthProvider**
📁 **File:** `mobile/lib/providers/auth_provider.dart`

**Methods to Implement/Update:**

1. **`Future<void> register({required String phone, required String fullName, required String password, required String primaryLanguage})`**
   - Call `POST /api/auth/register`
   - Store token in `shared_preferences`
   - Update `authStatus` to `AuthStatus.authenticated`
   - Store user data

2. **`Future<void> login({required String phone, required String password})`**
   - Call `POST /api/auth/login`
   - Store token
   - Update `authStatus`
   - Store user data

3. **`Future<void> logout()`**
   - Clear token from `shared_preferences`
   - Update `authStatus` to `AuthStatus.unauthenticated`

4. **`Future<void> checkAuthStatus()`**
   - On app start, check if token exists
   - If yes, call `GET /api/auth/me` to validate
   - Update `authStatus` accordingly

---

#### **Task 2.4: Implement Contacts Management**

##### **2.4A: Update ContactsProvider**
📁 **File:** `mobile/lib/providers/contacts_provider.dart`

**Methods to Add:**

1. **`Future<void> loadContacts()`**
   - Call `GET /api/contacts`
   - Store in `List<User> _contacts`
   - Notify listeners

2. **`Future<List<User>> searchUsers(String query)`**
   - Call `GET /api/users/search?query={query}`
   - Return list of search results
   - Do NOT add to `_contacts` (just return search results)

3. **`Future<void> addContact(String userId)`**
   - Call `POST /api/contacts/add` with `userId`
   - Reload contacts list
   - Show success message

4. **`Future<void> removeContact(String contactId)`**
   - Call `DELETE /api/contacts/{contactId}`
   - Reload contacts list

5. **Selection State for Multi-Select:**
   ```dart
   Set<String> _selectedContactIds = {};
   Set<String> get selectedContactIds => _selectedContactIds;
   
   void toggleSelection(String contactId) {
     if (_selectedContactIds.contains(contactId)) {
       _selectedContactIds.remove(contactId);
     } else {
       _selectedContactIds.add(contactId);
     }
     notifyListeners();
   }
   
   void clearSelection() {
     _selectedContactIds.clear();
     notifyListeners();
   }
   ```

---

##### **2.4B: Refactor Contacts Screen**
📁 **File:** `mobile/lib/screens/contacts/contacts_screen.dart`

**Features:**

1. **Sticky Search Bar:** (SliverAppBar)
   - Search contacts by name
   - Filter local contacts list

2. **Add Contact Button (+):** (FloatingActionButton)
   - Opens `AddContactDialog`

3. **Long-Press Selection Mode:**
   - Long-press on contact card → Enter selection mode
   - Show checkboxes on all cards
   - Bottom bar shows "Call" button when 1-3 contacts selected

4. **Dynamic FAB:**
   - **0 selected:** Show "+" icon (Add Contact)
   - **1-3 selected:** Show "📞" icon (Start Group Call)

5. **Swipe-to-Delete:** (Dismissible widget)
   - Swipe left → Delete contact with undo option

---

##### **2.4C: Add Contact Dialog**
📁 **File:** `mobile/lib/widgets/add_contact_dialog.dart`

**UI:**
- Search bar
- Results list (from `ContactsProvider.searchUsers()`)
- Each result has an "Add" button
- Clicking "Add" calls `ContactsProvider.addContact(userId)`

---

#### **Task 2.5: Main Navigation Shell**

##### **2.5A: Create Main Shell**
📁 **File:** `mobile/lib/screens/home/main_shell.dart`

**Structure:** Scaffold with BottomNavigationBar

**Tabs (4):**
1. **Recents** (Icon: `Icons.history`)
   - Screen: `RecentsScreen` (list of past calls)
2. **Contacts** (Icon: `Icons.contacts`)
   - Screen: `ContactsScreen`
3. **Keypad** (Icon: `Icons.dialpad`)
   - Screen: `KeypadScreen` (numeric dialer - optional for now)
4. **Settings** (Icon: `Icons.settings`)
   - Screen: `SettingsScreen`

**Navigation Logic:**
```dart
int _currentIndex = 1; // Start on Contacts

final List<Widget> _screens = [
  const RecentsScreen(),
  const ContactsScreen(),
  const KeypadScreen(),
  const SettingsScreen(),
];

BottomNavigationBar(
  currentIndex: _currentIndex,
  onTap: (index) {
    setState(() {
      _currentIndex = index;
    });
  },
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recents'),
    BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contacts'),
    BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Keypad'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
);
```

---

##### **2.5B: Recents Screen (Placeholder)**
📁 **File:** `mobile/lib/screens/home/recents_screen.dart`

**For now:** Display a list of mock recent calls from `CallProvider`.

**Each item shows:**
- Participant names
- Call duration
- Timestamp
- Tap → View call details (future feature)

---

#### **Task 2.6: Call Initiation Flow**

##### **2.6A: Update CallProvider**
📁 **File:** `mobile/lib/providers/call_provider.dart`

**Method to Add:**

```dart
Future<void> startCall(List<String> participantUserIds) async {
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.backendUrl}/api/calls/start'),
      headers: {
        'Authorization': 'Bearer ${authToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'participant_user_ids': participantUserIds}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _sessionId = data['session_id'];
      _participants = (data['participants'] as List)
          .map((p) => CallParticipant.fromJson(p))
          .toList();
      
      // Connect to WebSocket
      await _connectToWebSocket(_sessionId);
      
      // Navigate to ActiveCallScreen
      notifyListeners();
    } else {
      throw Exception('Failed to start call');
    }
  } catch (e) {
    print('Error starting call: $e');
    rethrow;
  }
}
```

---

##### **2.6B: Call Button Action**
📁 **File:** `mobile/lib/screens/contacts/contacts_screen.dart`

**When FAB is pressed with selected contacts:**

```dart
if (contactsProv.selectedContactIds.isNotEmpty) {
  final userIds = contactsProv.selectedContactIds.toList();
  contactsProv.clearSelection();
  
  await callProv.startCall(userIds);
  
  Navigator.pushNamed(context, '/call');
}
```

---

#### **Task 2.7: Active Call Screen (Finalize V2)**
📁 **File:** `mobile/lib/screens/call/active_call_screen_v2.dart`

**Current State:** Already exists with gradient background, participant grid, controls.

**Tasks:**

1. **Dynamic Grid Layout:**
   - Use `ParticipantGrid` widget (already exists)
   - 1 remote: Full-screen avatar + small local PiP
   - 2 remote: Vertical split
   - 3-4 remote: 2x2 Grid

2. **Live Caption Bubbles:**
   - Use `LiveCaptionBubble` widget
   - Overlay on `ParticipantCard` in Stack
   - Bind to `CallProvider.captionBubbles`

3. **Add Participant Button:**
   - **Action:** Open `BottomSheet` with `ContactsScreen` in selection mode
   - User selects 1-2 more contacts
   - Call backend to add them to the call (future WebSocket message)

4. **Voice Energy Visualization:**
   - Use `VoiceVisualizer` or `WaveformPainter`
   - Show when participant is speaking (`participant.isSpeaking`)

---

### **Phase 1C: Configuration Updates**

#### **Task 3.1: Update AppConfig**
📁 **File:** `mobile/lib/config/app_config.dart`

**Update supported languages:**
```dart
class AppConfig {
  static const String backendUrl = 'http://10.0.2.2:8000'; // Android emulator
  static const String websocketUrl = 'ws://10.0.2.2:8000';
  
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'he', 'name': 'Hebrew', 'flag': '🇮🇱'},
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'ru', 'name': 'Russian', 'flag': '🇷🇺'},
  ];
  
  // Audio settings
  static const int sampleRate = 16000;
  static const int channels = 1; // Mono
  static const int chunkDurationMs = 200;
}
```

---

#### **Task 3.2: Update Settings Screen**
📁 **File:** `mobile/lib/screens/settings/settings_screen.dart`

**Simplify to:**
- **Profile Section:**
  - Display name, phone, language
  - "Edit Profile" button
- **Language Preference:**
  - Single dropdown: Hebrew / English / Russian
- **Voice Settings:**
  - "Re-record Voice Sample" button
  - Voice cloning progress indicator
- **Notifications:**
  - Toggle switches for call notifications
- **About:**
  - App version, team info

---

## 🎨 **UI/UX DESIGN GUIDELINES**

### **Theme: Glassmorphism + Neon**
📁 **Reference:** `mobile/lib/config/app_theme.dart`

**Colors:**
- **Primary:** Neon Purple (#A855F7)
- **Secondary:** Electric Blue (#3B82F6)
- **Background:** Dark gradients (#12122A, #1A1A3A, #2B2B5C)
- **Glass:** `BackdropFilter` with `blur(20)` + semi-transparent borders

**Typography:**
- Use `GoogleFonts.poppins()` or system fonts
- `titleMedium`, `bodyLarge` from `app_theme.dart`

**Widgets:**
- **GlassContainer:** Reusable container with `BackdropFilter`
- **NeonAvatar:** Avatar with glowing border when speaking
- **AnimatedButton:** Button with ripple + scale animation

---

## 📊 **CALL FLOW DIAGRAM** (Signaling Logic)

```
┌─────────────┐                                    ┌─────────────┐
│  User A     │                                    │  User B     │
│  (Caller)   │                                    │  (Callee)   │
└──────┬──────┘                                    └──────┬──────┘
       │                                                  │
       │ 1. Select contacts in app                       │
       │    (e.g., User B, User C)                       │
       │                                                  │
       │ 2. Tap "Call" button                            │
       │                                                  │
       ▼                                                  │
┌──────────────────────────────────────┐                 │
│  POST /api/calls/start               │                 │
│  Body: {participant_user_ids: [...]} │                 │
└──────────────┬───────────────────────┘                 │
               │                                          │
               │ 3. Server creates Call record            │
               │    with unique session_id               │
               │                                          │
               ▼                                          │
┌──────────────────────────────────────┐                 │
│  Response: {                         │                 │
│    session_id: "abc-123",            │                 │
│    websocket_url: "ws://.../abc-123" │                 │
│  }                                   │                 │
└──────────────┬───────────────────────┘                 │
               │                                          │
               │ 4. User A connects to WebSocket         │
               │    ws://server/ws/abc-123               │
               │                                          │
               ▼                                          │
       ┌───────────────┐                                 │
       │  WebSocket    │                                 │
       │  Connection   │                                 │
       │  Established  │                                 │
       └───────┬───────┘                                 │
               │                                          │
               │ 5. Server notifies User B                │
               │    (via polling or push - simplified)   │
               │                                          │
               └──────────────────────────────────────────►
                                                          │
                                     6. User B sees "Incoming Call"
                                        from User A      │
                                                          │
                                     7. User B clicks "Accept"
                                                          │
                                                          ▼
                                  ┌───────────────────────────────┐
                                  │  User B connects to WebSocket │
                                  │  ws://server/ws/abc-123       │
                                  └───────────────┬───────────────┘
                                                  │
               ┌──────────────────────────────────┘
               │
               │ 8. Both connected to same WebSocket session
               │    Server starts relaying audio chunks
               │
               ▼
       ┌───────────────────────────────────┐
       │  Full Duplex Streaming            │
       │  A → Server → B (translated)      │
       │  B → Server → A (translated)      │
       └───────────────────────────────────┘
```

**Note:** For this phase, we're NOT implementing the "incoming call notification" system. Assume all users' apps are open. In Week 3-4, we'll add WebSocket events or polling for notifications.

---

## ✅ **IMPLEMENTATION CHECKLIST**

### **Backend Tasks**

- [ ] **1.1** Update `User` model (phone, full_name, remove email)
- [ ] **1.2** Create `backend/app/api/auth.py`:
  - [ ] `POST /api/auth/register`
  - [ ] `POST /api/auth/login`
  - [ ] `GET /api/auth/me`
- [ ] **1.3** Create `backend/app/api/contacts.py`:
  - [ ] `GET /api/users/search`
  - [ ] `POST /api/contacts/add`
  - [ ] `GET /api/contacts`
  - [ ] `DELETE /api/contacts/{contact_id}`
- [ ] **1.4** Create `backend/app/api/calls.py`:
  - [ ] `POST /api/calls/start`
- [ ] **1.5** Update database migrations (if using Alembic)
- [ ] **1.6** Test all endpoints with Postman/Thunder Client

### **Flutter Tasks**

- [ ] **2.1** Update `User` model (phone, fullName)
- [ ] **2.2** Create auth screens:
  - [ ] `phone_login_screen.dart`
  - [ ] `register_screen.dart`
  - [ ] `voice_calibration_screen.dart`
- [ ] **2.3** Update `AuthProvider` (register, login, logout)
- [ ] **2.4** Update `ContactsProvider` (loadContacts, searchUsers, addContact, selection state)
- [ ] **2.5** Refactor `contacts_screen.dart` (search, multi-select, FAB)
- [ ] **2.6** Create `add_contact_dialog.dart`
- [ ] **2.7** Create `main_shell.dart` with BottomNavigationBar
- [ ] **2.8** Create `recents_screen.dart` (placeholder)
- [ ] **2.9** Update `CallProvider.startCall()` method
- [ ] **2.10** Finalize `active_call_screen_v2.dart` (dynamic grid, captions)
- [ ] **2.11** Update `app_config.dart` (3 languages)
- [ ] **2.12** Simplify `settings_screen.dart`
- [ ] **2.13** Test registration → login → contacts → call flow

### **Documentation**

- [ ] **3.1** Update `README.md` with new auth flow
- [ ] **3.2** Update `CUSTOM_INSTRUCTIONS.md` with refactoring status
- [ ] **3.3** Create `PHASE_1_SUMMARY.md` documenting completed work

---

## 🔐 **SECURITY REMINDERS**

1. **Never commit:**
   - `.env` files
   - `google-credentials.json`
   - JWT secret keys

2. **Always validate:**
   - Phone format (basic regex)
   - Language codes against `['he', 'en', 'ru']`
   - User existence before adding contacts
   - Maximum 4 participants per call

3. **Password handling:**
   - Use `passlib[bcrypt]` for hashing
   - Never store plain-text passwords
   - Enforce minimum 6 characters

4. **JWT tokens:**
   - Use strong secret key (environment variable)
   - Set expiration (7 days recommended)
   - Validate on every protected endpoint

---

## 📚 **CODE STYLE REFERENCES**

**Python:**
- Follow `CODE_GUIDELINES.md`
- Use async/await for all I/O
- Type hints mandatory
- Docstrings for public functions
- Import order: stdlib → third-party → local

**Dart/Flutter:**
- Follow official Dart Style Guide
- Use `provider` for state management
- Keep widgets small and focused
- Use `const` constructors where possible
- File names: `snake_case.dart`
- Class names: `PascalCase`

---

## 🎯 **SUCCESS CRITERIA**

After completing this refactoring:

1. ✅ Users can register with phone + password
2. ✅ Users can log in with phone + password
3. ✅ Users can search and add contacts from DB
4. ✅ Users can select 1-3 contacts and start a call
5. ✅ Call screen displays dynamic grid (1-4 participants)
6. ✅ Backend creates Call record and returns session_id
7. ✅ All auth/contact endpoints working and tested
8. ✅ Flutter app navigates smoothly through auth → contacts → call flow
9. ✅ Code follows project guidelines
10. ✅ No hardcoded credentials or secrets

---

## 🎤 **VOICE CLONING TECHNOLOGY**

**Model:** ResembleAI Chatterbox  
**Source:** https://huggingface.co/ResembleAI/chatterbox

**Implementation Notes:**
- Voice cloning will be implemented in **Week 6** (after core translation pipeline is working)
- The `VoiceModel` table in the database is already set up to store voice model metadata
- Users record voice samples during onboarding (10-15 seconds)
- The backend will use ResembleAI Chatterbox to generate voice models
- During calls, translated text will be synthesized using the user's cloned voice
- Fallback: If voice cloning fails, use Google TTS with default voice

---

## 📞 **NEXT STEPS AFTER PHASE 1**

Once this refactoring is complete, you'll move to:

- **Week 2:** Google Cloud API integration (STT, Translate, TTS)
- **Week 3-4:** WebSocket audio streaming pipeline
- **Week 6:** Voice cloning with ResembleAI Chatterbox
- **Week 7:** End-to-end testing

---

## 🚀 **GET STARTED**

**Backend First:**
1. Start with Task 1.1 (User model update)
2. Then Task 1.2 (Auth endpoints)
3. Test with Postman before moving to Flutter

**Flutter Next:**
1. Update User model (Task 2.1)
2. Create auth screens (Task 2.2)
3. Wire up providers (Task 2.3-2.4)
4. Test complete flow

**Remember:** Commit often, test incrementally, and refer to existing code patterns in the project.

---

## 📝 **QUESTIONS & CLARIFICATIONS**

If you encounter ambiguity:
1. Check `CODE_GUIDELINES.md` for patterns
2. Look at existing models/providers for structure
3. Reference `app_theme.dart` for UI styling
4. Ask for clarification before making assumptions

---

**Good luck! This refactoring will set a solid foundation for the rest of the project. 🎉**
