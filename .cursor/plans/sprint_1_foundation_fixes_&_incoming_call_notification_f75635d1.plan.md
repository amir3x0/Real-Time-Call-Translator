---
name: "Sprint 1: Foundation Fixes & Incoming Call Notification"
overview: תיקון שגיאת 500 ב-backend ומימוש incoming call notification (backend + Flutter) כדי לאפשר שיחה בין שני מכשירים פיזיים.
todos: []
---

# Sprint 1: Foundation Fixes & Incoming Call Notification

## מטרת הספרינט

לאפשר למשתמש A להתקשר למשתמש B, כאשר B מקבל התראה על שיחה נכנסת ויכול לקבל או לדחות.

## Day 1: Fix Backend 500 Error

### בעיה נוכחית

בקובץ `backend/app/services/call_service.py` בשורה 298, הקוד קורא ל-`participant.set_voice_clone_quality(user.voice_quality_score)` אבל:

1. המתודה `set_voice_clone_quality` לא קיימת ב-`CallParticipant` model
2. `user.voice_quality_score` יכול להיות `None`

### תיקונים נדרשים

#### 1. הוספת Methods ל-CallParticipant Model

**קובץ:** `backend/app/models/call_participant.py`

להוסיף שני methods:

```python
def determine_dubbing_required(self, call_language: str) -> None:
    """Set dubbing_required based on language match."""
    self.dubbing_required = (self.participant_language != call_language)

def set_voice_clone_quality(self, voice_quality_score: Optional[int]) -> None:
    """Set voice_clone_quality based on score."""
    if voice_quality_score is None:
        self.voice_clone_quality = 'fallback'
        self.use_voice_clone = False
    elif voice_quality_score > 80:
        self.voice_clone_quality = 'excellent'
        self.use_voice_clone = True
    elif voice_quality_score > 60:
        self.voice_clone_quality = 'good'
        self.use_voice_clone = True
    elif voice_quality_score > 40:
        self.voice_clone_quality = 'fair'
        self.use_voice_clone = True
    else:
        self.voice_clone_quality = 'fallback'
        self.use_voice_clone = False
```

#### 2. תיקון call_service.py

**קובץ:** `backend/app/services/call_service.py`

השורה 298 כבר קוראת נכון, אבל צריך לוודא שה-methods קיימים. אם יש שגיאה, להוסיף try/catch:

```python
# Around line 294-298
try:
    participant.determine_dubbing_required(call.call_language)
    participant.set_voice_clone_quality(user.voice_quality_score)
except AttributeError as e:
    logger.error(f"Error setting participant properties: {e}")
    # Set defaults
    participant.dubbing_required = (participant.participant_language != call.call_language)
    participant.voice_clone_quality = 'fallback'
    participant.use_voice_clone = False
```

#### 3. בדיקות

- לבדוק `/api/calls/start` עם משתמש ללא `voice_quality_score`
- לבדוק שהשיחה נוצרת בהצלחה
- לבדוק ש-participants נוצרים עם ערכים נכונים

---

## Day 2: Incoming Call Backend

### מטרה

להוסיף מנגנון backend לניהול שיחות נכנסות.

### 1. עדכון Call Model Status

**קובץ:** `backend/app/models/call.py`

לוודא שה-`status` field תומך בערכים: `'initiating'`, `'ringing'`, `'ongoing'`, `'ended'`, `'missed'`, `'rejected'`

### 2. יצירת Endpoint ל-Pending Calls

**קובץ:** `backend/app/api/calls.py`

להוסיף endpoint חדש:

```python
@router.get("/calls/pending", response_model=List[CallDetailResponse])
async def get_pending_calls(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get all pending incoming calls for current user.
    Returns calls where:
    - status is 'ringing' or 'initiating'
    - user is a participant but not the caller
    - call was created in last 30 seconds
    """
```

### 3. עדכון Call Service

**קובץ:** `backend/app/services/call_service.py`

להוסיף methods:

- `mark_call_ringing(call_id)` - משנה status ל-'ringing'
- `accept_call(call_id, user_id)` - משנה status ל-'ongoing' ומעדכן participant
- `reject_call(call_id, user_id)` - משנה status ל-'rejected'

### 4. WebSocket Notification

**קובץ:** `backend/app/services/connection_manager.py`

להוסיף method:

```python
async def notify_incoming_call(
    self,
    user_id: str,
    call_id: str,
    caller_name: str,
    caller_language: str
) -> bool:
    """Send incoming call notification to user via WebSocket if connected."""
```

**קובץ:** `backend/app/api/calls.py` (בתוך `start_call`)

לאחר יצירת call, לשלוח notification לכל participants שאינם caller:

```python
# After creating call and participants
for participant in participants:
    if participant.user_id != caller_id:
        # Mark call as ringing
        call.status = 'ringing'
        await db.commit()
        
        # Send WebSocket notification if user is online
        await connection_manager.notify_incoming_call(
            user_id=participant.user_id,
            call_id=call.id,
            caller_name=caller.full_name,
            caller_language=call.call_language
        )
```

### 5. Accept/Reject Endpoints

**קובץ:** `backend/app/api/calls.py`

להוסיף:

```python
@router.post("/calls/{call_id}/accept")
async def accept_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Accept an incoming call."""

@router.post("/calls/{call_id}/reject")
async def reject_call(
    call_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reject an incoming call."""
```

### 6. Timeout Logic

**קובץ:** `backend/app/services/call_service.py`

להוסיף background task (או לבדוק ב-polling):

- אם call ב-status 'ringing' יותר מ-30 שניות → משנה ל-'missed'

---

## Day 3: Incoming Call Flutter

### מטרה

להוסיף UI ופונקציונליות ב-Flutter לקבלת שיחות נכנסות.

### 1. הוספת Message Type

**קובץ:** `mobile/lib/data/websocket/websocket_service.dart`

להוסיף ל-`WSMessageType` enum:

```dart
incomingCall,
```

ולהוסיף parsing ב-`_parseMessageType`:

```dart
case 'incoming_call':
  return WSMessageType.incomingCall;
```

### 2. יצירת IncomingCallScreen

**קובץ:** `mobile/lib/screens/call/incoming_call_screen.dart` (חדש)

מסך עם:

- תמונה/avatar של הקורא
- שם הקורא
- שפת השיחה
- כפתור Accept (ירוק)
- כפתור Decline (אדום)
- Timer של 30 שניות (auto-decline)

### 3. עדכון CallProvider

**קובץ:** `mobile/lib/providers/call_provider.dart`

להוסיף:

- `CallStatus? _incomingCallStatus`
- `Call? _incomingCall`
- `Timer? _callTimeoutTimer`

להוסיף method:

```dart
void handleIncomingCall(WSMessage message) {
  final callData = message.data;
  _incomingCall = Call.fromJson(callData);
  _incomingCallStatus = CallStatus.ringing;
  _startCallTimeout();
  notifyListeners();
}

Future<void> acceptIncomingCall() async {
  if (_incomingCall == null) return;
  
  // Call API to accept
  await _apiService.acceptCall(_incomingCall!.id);
  
  // Start call normally
  await startCall([_incomingCall!.callerUserId]);
  
  _incomingCall = null;
  _incomingCallStatus = null;
  _callTimeoutTimer?.cancel();
  notifyListeners();
}

Future<void> rejectIncomingCall() async {
  if (_incomingCall == null) return;
  
  await _apiService.rejectCall(_incomingCall!.id);
  
  _incomingCall = null;
  _incomingCallStatus = null;
  _callTimeoutTimer?.cancel();
  notifyListeners();
}
```

### 4. עדכון WebSocket Message Handler

**קובץ:** `mobile/lib/providers/call_provider.dart`

ב-`_handleWebSocketMessage`, להוסיף case:

```dart
case WSMessageType.incomingCall:
  handleIncomingCall(message);
  break;
```

### 5. עדכון ApiService

**קובץ:** `mobile/lib/data/api/api_service.dart`

להוסיף methods:

```dart
Future<void> acceptCall(String callId) async {
  // POST /api/calls/{call_id}/accept
}

Future<void> rejectCall(String callId) async {
  // POST /api/calls/{call_id}/reject
}

Future<List<Map<String, dynamic>>> getPendingCalls() async {
  // GET /api/calls/pending
}
```

### 6. Navigation Integration

**קובץ:** `mobile/lib/main.dart` או navigation router

להוסיף route:

```dart
'/call/incoming': (context) => IncomingCallScreen(),
```

ב-`CallProvider`, כאשר יש incoming call, לנווט ל-IncomingCallScreen.

### 7. Polling Fallback (אופציונלי)

**קובץ:** `mobile/lib/services/pending_calls_service.dart` (חדש)

אם WebSocket לא מחובר, לבדוק כל 5 שניות:

```dart
Timer.periodic(Duration(seconds: 5), (_) async {
  final pending = await _apiService.getPendingCalls();
  if (pending.isNotEmpty) {
    // Show incoming call
  }
});
```

---

## Testing Checklist

### Day 1 Tests

- [ ] `/api/calls/start` עובד עם משתמש ללא voice_quality_score
- [ ] Call נוצר בהצלחה ב-DB
- [ ] Participants נוצרים עם dubbing_required נכון
- [ ] voice_clone_quality מוגדר ל-'fallback' אם score הוא None

### Day 2 Tests

- [ ] `GET /api/calls/pending` מחזיר שיחות נכנסות
- [ ] `POST /api/calls/{id}/accept` משנה status ל-'ongoing'
- [ ] `POST /api/calls/{id}/reject` משנה status ל-'rejected'
- [ ] WebSocket notification נשלח למשתמש B כאשר A מתקשר
- [ ] Timeout עובד (30 שניות → 'missed')

### Day 3 Tests

- [ ] IncomingCallScreen מופיע כאשר יש שיחה נכנסת
- [ ] Accept button מחבר לשיחה
- [ ] Decline button דוחה את השיחה
- [ ] Timer עובד (auto-decline אחרי 30 שניות)
- [ ] Navigation עובד (IncomingCallScreen → ActiveCallScreen)

---

## Success Criteria

בסוף הספרינט:

1. ✅ משתמש A יכול להתקשר למשתמש B (ללא 500 error)
2. ✅ משתמש B מקבל התראה על שיחה נכנסת
3. ✅ משתמש B יכול לקבל או לדחות את השיחה
4. ✅ אם B מקבל, השיחה מתחילה (שניהם מחוברים ל-WebSocket)
5. ✅ אם B דוחה או לא עונה (30 שניות), השיחה מסתיימת

---

## Files to Modify

### Backend

- `backend/app/models/call_participant.py` - הוספת methods
- `backend/app/services/call_service.py` - תיקון 500 error + methods חדשים
- `backend/app/api/calls.py` - endpoints חדשים
- `backend/app/services/connection_manager.py` - notification method

### Flutter

- `mobile/lib/data/websocket/websocket_service.dart` - message type חדש
- `mobile/lib/providers/call_provider.dart` - incoming call handling
- `mobile/lib/data/api/api_service.dart` - API methods חדשים
- `mobile/lib/screens/call/incoming_call_screen.dart` - מסך חדש
- `mobile/lib/core/navigation/app_routes.dart` - route חדש (אם קיים)

---

## Notes

- WebSocket notifications הם הפתרון המועדף, אבל polling יכול לשמש fallback
- Timeout של 30 שניות הוא configurable - אפשר לשנות ב-`AppConfig`
- אם משתמש לא מחובר ל-WebSocket, הוא לא יקבל notification בזמן אמת (אבל polling יעבוד)