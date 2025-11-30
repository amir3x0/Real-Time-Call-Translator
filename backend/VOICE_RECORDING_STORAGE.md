# שמירת קבצי הקלטה - מדריך

## סקירה כללית

המערכת שומרת קבצי הקלטה (voice recordings) לשתי מטרות:
1. **אימון מודל קול** - דגימות קול לאימון Chatterbox
2. **היסטוריית הקלטות** - שמירת הקלטות למשתמש

## מבנה התיקיות

### ב-Docker (Production)
```
/app/data/
├── voice_samples/    # קבצי הקלטה גולמיים
├── models/          # מודלים מאומנים
└── uploads/         # קבצים נוספים (אם נדרש)
```

### בפיתוח מקומי
```
backend/
├── data/
│   ├── voice_samples/    # קבצי הקלטה
│   ├── models/           # מודלים
│   └── uploads/         # קבצים נוספים
└── app/
```

## איך נשמרים הקבצים?

### 1. העלאת הקלטה (Upload)

כאשר משתמש מעלה הקלטה דרך ה-API:

**Endpoint:** `POST /api/voice/upload`

**תהליך:**
1. הקובץ מתקבל כ-`UploadFile` ב-FastAPI
2. נוצר שם קובץ ייחודי: `{user_id}_{uuid}.{extension}`
3. הקובץ נשמר ב-`/app/data/voice_samples/`
4. נוצר רשומה ב-DB בטבלה `voice_recordings` עם:
   - `file_path` - הנתיב המלא לקובץ
   - `user_id` - מזהה המשתמש
   - `language` - שפת ההקלטה
   - `text_content` - הטקסט שנקרא
   - `file_size_bytes` - גודל הקובץ
   - `audio_format` - פורמט (wav, mp3, ogg)

**קוד רלוונטי:**
```python
# backend/app/api/voice.py
VOICE_UPLOAD_DIR = settings.VOICE_SAMPLES_DIR  # /app/data/voice_samples

# שמירת הקובץ
file_path = os.path.join(VOICE_UPLOAD_DIR, unique_filename)
with open(file_path, 'wb') as f:
    f.write(contents)
```

### 2. עיבוד הקלטה (Processing)

לאחר השמירה, ההקלטה מתווספת לתור עיבוד:

1. **הערכת איכות** - נבדקת איכות האודיו
2. **סימון כמעובד** - `is_processed = True`
3. **ציון איכות** - `quality_score` (1-100)

**קוד רלוונטי:**
```python
# backend/app/services/voice_training_service.py
await voice_training_service.queue_recording_for_processing(recording.id)
```

### 3. שימוש לאימון

כאשר יש לפחות 2 הקלטות מעובדות עם ציון איכות >= 40:
- ההקלטות מסומנות כ-`used_for_training = True`
- מודל הקול מאומן באמצעות Chatterbox
- המודל נשמר ב-`/app/data/models/`

## הגדרות נתיבים

הנתיבים מוגדרים ב-`settings.py`:

```python
# backend/app/config/settings.py
DATA_DIR: str = "/app/data"
VOICE_SAMPLES_DIR: str = "/app/data/voice_samples"
UPLOADS_DIR: str = "/app/data/uploads"
MODELS_DIR: str = "/app/data/models"
```

ניתן לשנות דרך משתני סביבה:
```bash
export VOICE_SAMPLES_DIR=/custom/path/to/voice_samples
```

## מבנה הטבלה voice_recordings

```sql
CREATE TABLE voice_recordings (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    language VARCHAR(10) NOT NULL,        -- he, en, ru
    text_content TEXT NOT NULL,
    file_path VARCHAR(500) NOT NULL,      -- הנתיב המלא לקובץ
    file_size_bytes INTEGER,
    audio_format VARCHAR(10),             -- wav, mp3, ogg
    quality_score INTEGER,                 -- 1-100
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP,
    used_for_training BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL
);
```

## דוגמאות שימוש

### העלאת הקלטה (Python)
```python
import requests

files = {'file': open('recording.wav', 'rb')}
data = {
    'language': 'he',
    'text_content': 'שלום, זה מבחן הקלטה'
}

response = requests.post(
    'http://localhost:8000/api/voice/upload',
    files=files,
    data=data,
    headers={'Authorization': 'Bearer YOUR_TOKEN'}
)
```

### רשימת הקלטות
```python
response = requests.get(
    'http://localhost:8000/api/voice/recordings',
    headers={'Authorization': 'Bearer YOUR_TOKEN'}
)
recordings = response.json()['recordings']
```

### מחיקת הקלטה
```python
requests.delete(
    f'http://localhost:8000/api/voice/recordings/{recording_id}',
    headers={'Authorization': 'Bearer YOUR_TOKEN'}
)
```

## ניהול קבצים

### בדיקת קבצים ב-Docker
```bash
# כניסה לקונטיינר
docker exec -it translator_api bash

# רשימת קבצים
ls -lh /app/data/voice_samples/

# בדיקת גודל
du -sh /app/data/voice_samples/
```

### ניקוי קבצים ישנים
הקבצים נשמרים עד שמחוקים ידנית או דרך ה-API.
למחיקה אוטומטית, ניתן להוסיף background task.

## בעיות נפוצות

### בעיה: "Failed to save file"
**פתרון:**
1. ודא שהתיקייה קיימת: `mkdir -p /app/data/voice_samples`
2. בדוק הרשאות כתיבה
3. בדוק מקום פנוי בדיסק

### בעיה: קבצים לא נשמרים ב-Docker
**פתרון:**
1. ודא שה-volume ממופה: `./data:/app/data` ב-docker-compose.yml
2. בדוק שהתיקייה `backend/data/voice_samples` קיימת
3. בנה מחדש: `docker-compose build --no-cache backend`

### בעיה: נתיב לא נכון
**פתרון:**
- ודא ש-`VOICE_SAMPLES_DIR` ב-settings.py מצביע על `/app/data/voice_samples`
- בדוק שהנתיב תואם ל-Dockerfile ו-docker-compose.yml

## סיכום

✅ **נתיב שמירה:** `/app/data/voice_samples/`  
✅ **פורמטים נתמכים:** wav, mp3, ogg  
✅ **מבנה שם:** `{user_id}_{uuid}.{extension}`  
✅ **מינימום לאימון:** 2 הקלטות מעובדות עם ציון >= 40  
✅ **Volume mapping:** `./data:/app/data` ב-Docker

## קישורים

- [API Documentation - Voice Endpoints](backend/app/api/voice.py)
- [Voice Recording Model](backend/app/models/voice_recording.py)
- [Voice Training Service](backend/app/services/voice_training_service.py)
