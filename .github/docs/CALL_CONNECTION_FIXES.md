# Call Connection Fixes - תיקוני תקשורת שיחה

## סקירה כללית

מסמך זה מתעד את תהליך הדיבוג והפתרון של בעיות התקשורת במערכת השיחות בזמן אמת, בפורמט STAR (Situation, Task, Action, Result).

**תאריך:** 5-6 בינואר 2026  
**Branch:** `amir-audio-connection`  
**משתתפים:** Amir Mishayev, Daniel Fraimovich

---

# 🔴 בעיה ראשית: שיחות מתנתקות אוטומטית

## Situation (מצב התחלתי)

### תיאור הבעיה
בעת ניסיון לבצע שיחה בין שני מכשירים (CPH2645 ו-SM T970), השיחה נוצרה בהצלחה אך התנתקה אוטומטית אחרי **2-3 שניות**. שני המשתתפים ראו את המסך עובר ל-"Waiting for participants..." במקום להישאר בשיחה פעילה.

### לוגים מהקליינט (Flutter)
```
I/flutter: [WebSocketService] Connected to session 54e23241-378a-4a6f-9272-9418b9f95d09
I/flutter: [AudioController] Initializing audio...
I/flutter: [AudioController] Player started in stream mode
I/flutter: [AudioController] Microphone started
I/flutter: [AudioController] Audio initialized successfully
I/flutter: [AudioController] Sent 50 chunks (2560 bytes each)
I/flutter: [AudioController] Sent 50 chunks (2560 bytes each)
I/flutter: [WebSocketService] Connection closed        ← ❌ ניתוק פתאומי!
I/flutter: [CallProvider] endCall called
```

### תסמינים
1. השיחה נוצרת בהצלחה
2. אודיו מתחיל להישלח
3. אחרי כ-8 שניות - ניתוק אוטומטי
4. שני הקליינטים מתנתקים **בו-זמנית**
5. אין שגיאה גלויה בצד הקליינט

---

## Task (המשימה)

לזהות את הסיבה לניתוק האוטומטי ולתקן אותה כך שהשיחה תישאר יציבה ותאפשר תקשורת אודיו דו-כיוונית.

---

## Action (הפעולות שננקטו)

### שלב 1: ניתוח הלוגים בצד הקליינט

**השערה ראשונה:** בעיה ב-UI שמציג "Waiting for participants"

בדקנו את `ParticipantGrid`:
```dart
// mobile/lib/widgets/call/participant_grid.dart
if (participants.isEmpty) {
  return _buildEmptyState();  // "Waiting for participants..."
}
```

**מסקנה:** רשימת ה-participants מתרוקנת - לא בעיה ב-UI עצמו.

---

### שלב 2: בדיקת מנגנון ה-Lobby Reconnect

**השערה שנייה:** ה-Lobby מתחבר מחדש ומנתק את השיחה

בדקנו את `main.dart` וגילינו:
```dart
// כשהאפליקציה חוזרת מ-background
if (callProvider.status == CallStatus.active ||
    callProvider.status == CallStatus.ringing ||
    // ❌ חסר: CallStatus.initiating
    lobbyProvider.incomingCall != null) {
  return;
}
lobbyProvider.connect(token);  // מנתק את חיבור השיחה!
```

**תיקון חלקי:**
```dart
if (callProvider.status == CallStatus.active ||
    callProvider.status == CallStatus.ringing ||
    callProvider.status == CallStatus.initiating ||  // ✅ נוסף
    lobbyProvider.incomingCall != null) {
  return;
}
```

**תוצאה:** לא פתר את הבעיה העיקרית - השיחה עדיין מתנתקת.

---

### שלב 3: בדיקת לוגים בצד השרת

**פקודה שהרצנו:**
```bash
docker logs translator_api --tail 100 2>&1 | Select-String -Pattern "Error|WebSocket|audio|bytes"
```

**גילוי קריטי:**
```
INFO: [WebSocket] Received 2560 bytes from user in session X
ERROR: [WebSocket] Error during session: can't subtract offset-naive and offset-aware datetimes
```

**זו הייתה ההשערה הנכונה!** 🎯

---

### שלב 4: איתור הקוד הבעייתי

בדקנו את `orchestrator.py` ומצאנו:
```python
# backend/app/services/session/orchestrator.py, lines 354-357

async def _handle_binary_message(self, audio_data: bytes) -> None:
    # ...
    if self.call_start_time:
        elapsed = datetime.now(UTC) - self.call_start_time  # ❌ BUG!
        timestamp_ms = int(elapsed.total_seconds() * 1000)
```

**הבעיה:**
- `datetime.now(UTC)` → timezone-aware (עם מידע על אזור זמן)
- `self.call_start_time` → timezone-naive (מהדאטהבייס, בלי אזור זמן)
- Python לא מאפשר חיסור בין שני הסוגים

**מה קרה:**
1. קליינט שולח chunk אודיו ראשון
2. השרת מנסה לחשב timestamp
3. Exception נזרק
4. ה-message loop קורס
5. `_handle_disconnect()` נקרא
6. WebSocket נסגר
7. שני הקליינטים מקבלים `connection closed`

---

### שלב 5: יישום התיקון

**הקוד המתוקן:**
```python
async def _handle_binary_message(self, audio_data: bytes) -> None:
    # ...
    timestamp_ms = 0
    if self.call_start_time:
        call_start = self.call_start_time
        if call_start.tzinfo is None:
            # Make naive datetime aware by assuming UTC
            from datetime import timezone
            call_start = call_start.replace(tzinfo=timezone.utc)
        elapsed = datetime.now(UTC) - call_start
        timestamp_ms = int(elapsed.total_seconds() * 1000)
```

**פקודות לפריסה:**
```bash
cd backend
docker-compose up -d --build backend
```

---

### שלב 6: בדיקות נוספות ותיקונים משלימים

#### בעיה משנית: "Already in Active Call"
כשניסינו להתקשר שוב, קיבלנו שגיאה שהמשתמש כבר בשיחה פעילה.

**סיבה:** שיחות קודמות לא נוקו כראוי מהדאטהבייס.

**פתרון - Auto-Recovery בקליינט:**
```dart
// mobile/lib/providers/call_provider.dart

Future<void> _initiateCallWithRetry(List<String> participantUserIds) async {
  try {
    await _executeCallInitiation(participantUserIds);
  } catch (e) {
    if (_isStuckInCallError(e)) {
      await _recoverFromStuckState(participantUserIds);
    } else {
      rethrow;
    }
  }
}

bool _isStuckInCallError(Object error) {
  final errorStr = error.toString().toLowerCase();
  return errorStr.contains('already in') && errorStr.contains('active call');
}

Future<void> _recoverFromStuckState(List<String> participantUserIds) async {
  debugPrint('[CallProvider] Detected stuck call state - auto-resetting...');
  await _apiService.resetCallState();
  debugPrint('[CallProvider] Reset successful, retrying call...');
  await _executeCallInitiation(participantUserIds);
}
```

**עקרון SRP:** כל פונקציה עושה דבר אחד בלבד:
| פונקציה | אחריות |
|---------|--------|
| `startCall()` | ניהול מצב UI |
| `_initiateCallWithRetry()` | לוגיקת retry |
| `_executeCallInitiation()` | קריאה ל-API |
| `_isStuckInCallError()` | זיהוי סוג שגיאה |
| `_recoverFromStuckState()` | התאוששות |

---

## Result (התוצאות)

### מדדי הצלחה
| מדד | לפני | אחרי |
|-----|------|------|
| משך שיחה | 2-3 שניות | ללא הגבלה ✅ |
| שגיאות בשרת | `can't subtract datetimes` | אין ✅ |
| אודיו נשלח | נקטע אחרי chunk אחד | רציף ✅ |
| Flutter Analyze | No issues | No issues ✅ |

### לוגים אחרי התיקון
```
INFO: [WebSocket] Received 2560 bytes from user_X in session Y
INFO: [WebSocket] Received 2560 bytes from user_X in session Y
INFO: [WebSocket] Received 2560 bytes from user_X in session Y
... (ממשיך ללא שגיאות)
```

### קבצים שהשתנו

#### Backend
| קובץ | שינוי |
|------|-------|
| `orchestrator.py` | תיקון timezone בחישוב timestamp |

#### Mobile (Flutter)
| קובץ | שינוי |
|------|-------|
| `call_provider.dart` | Auto-recovery + SRP refactoring |
| `main.dart` | בדיקת `initiating` status |
| `websocket_service.dart` | הוספת `translation` message type |
| `active_call_screen.dart` | שילוב TranscriptionPanel |
| `transcription_manager.dart` | **חדש** - ניהול תמלולים |
| `transcription_panel.dart` | **חדש** - UI לתמלולים |

---

# 📊 ציר זמן של הדיבוג

```
[שעה 0:00] בעיה מדווחת - שיחות מתנתקות
    │
    ▼
[שעה 0:15] השערה 1 - בעיה ב-UI
    │       → נבדק ParticipantGrid
    │       → נפסל - הבעיה בנתונים, לא בתצוגה
    ▼
[שעה 0:30] השערה 2 - Lobby Reconnect
    │       → נמצא חוסר בבדיקת `initiating`
    │       → תוקן, אבל לא פתר את הבעיה העיקרית
    ▼
[שעה 0:45] השערה 3 - בעיה בצד השרת
    │       → בדיקת לוגים של Docker
    │       → גילוי: "can't subtract offset-naive and offset-aware datetimes"
    │       → 🎯 זו הסיבה האמיתית!
    ▼
[שעה 1:00] תיקון הבעיה העיקרית
    │       → עדכון orchestrator.py
    │       → rebuild של Docker image
    ▼
[שעה 1:15] תיקון בעיות משניות
    │       → Auto-recovery לשיחות תקועות
    │       → Refactoring לפי SRP
    ▼
[שעה 1:30] הוספת תכונות
    │       → TranscriptionPanel לתצוגת תרגומים
    │       → TranscriptionManager לניהול היסטוריה
    ▼
[שעה 2:00] ✅ בדיקה מוצלחת - שיחות עובדות!
```

---

# 🎓 לקחים שנלמדו

### 1. תמיד לבדוק לוגים בשני הצדדים
הקליינט הציג `Connection closed` בלי שגיאה, אבל השרת הכיל את השגיאה האמיתית.

### 2. Timezone awareness
כשעובדים עם datetime ב-Python:
- `datetime.utcnow()` → naive (מיושן)
- `datetime.now(UTC)` → aware (מומלץ)
- תמיד לוודא התאמה בין הסוגים

### 3. עקרון SRP
פירוק פונקציות גדולות לפונקציות קטנות עם אחריות בודדת מקל על דיבוג ותחזוקה.

### 4. Auto-recovery
במקום לדרוש מהמשתמש לפתור בעיות ידנית, לבנות מנגנוני התאוששות אוטומטיים.

---

# 🔧 פקודות שימושיות לדיבוג עתידי

```bash
# לוגים של השרת עם פילטר
docker logs translator_api --tail 100 2>&1 | grep -E "Error|bytes|WebSocket"

# ניקוי שיחות תקועות
docker exec -it translator_api python scripts/cleanup_active_calls.py

# בדיקת Flutter
cd mobile && flutter analyze --no-fatal-infos

# הרצה במצב debug
cd scripts && .\run_debug_mode.ps1
```

---

**נכתב על ידי:** GitHub Copilot  
**תאריך עדכון אחרון:** 6 בינואר 2026
