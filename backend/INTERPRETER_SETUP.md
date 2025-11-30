# בחירת Python Interpreter - מדריך

## סקירה כללית

פרויקט זה משתמש ב-**Python 3.10** בכל הסביבות (פיתוח, Docker, CI/CD).

## איך לבחור Interpreter מתאים?

### 1. בסביבת פיתוח מקומית (Local Development)

#### Windows (PowerShell/CMD):
```powershell
# בדוק גרסת Python מותקנת
python --version
# או
python3 --version

# אם יש לך מספר גרסאות, ציין במפורש:
py -3.10 --version
```

#### Linux/Mac:
```bash
# בדוק גרסת Python
python3 --version

# אם יש לך pyenv (מומלץ):
pyenv install 3.10.13
pyenv local 3.10.13
```

#### VS Code / Cursor:
1. לחץ על `Ctrl+Shift+P` (או `Cmd+Shift+P` ב-Mac)
2. הקלד: `Python: Select Interpreter`
3. בחר Python 3.10.x מהרשימה
4. אם לא מופיע, לחץ על "Enter interpreter path" והזן:
   - Windows: `C:\Python310\python.exe` (או הנתיב שלך)
   - Linux/Mac: `/usr/bin/python3.10` (או הנתיב שלך)

### 2. ב-Docker (אוטומטי)

ה-Dockerfile מגדיר את גרסת Python:
```dockerfile
FROM python:3.10-slim
```

**אין צורך לבחור ידנית** - Docker בונה את התמונה עם Python 3.10.

### 3. ב-CI/CD (GitHub Actions)

ה-CI מוגדר אוטומטית:
```yaml
- name: Set up Python 3.10
  uses: actions/setup-python@v4
  with:
    python-version: "3.10"
```

## בדיקת תאימות

### בדיקה מקומית:
```bash
# בדוק שהגרסה נכונה
python --version  # צריך להציג: Python 3.10.x

# בדוק שהחבילות מותקנות
pip list | grep -E "fastapi|uvicorn|sqlalchemy"
```

### בדיקה ב-Docker:
```bash
# הרץ את הקונטיינר
docker-compose up -d backend

# בדוק את גרסת Python בתוך הקונטיינר
docker exec -it translator_api python3 --version

# בדוק את החבילות
docker exec -it translator_api pip list
```

## בעיות נפוצות ופתרונות

### בעיה: "Python version mismatch"
**פתרון**: ודא שגרסת Python המקומית תואמת ל-3.10:
```bash
# התקן Python 3.10 אם חסר
# Windows: הורד מ-python.org
# Linux: sudo apt install python3.10
# Mac: brew install python@3.10
```

### בעיה: "Module not found" ב-Docker
**פתרון**: בנה מחדש את התמונה:
```bash
docker-compose build --no-cache backend
docker-compose up -d backend
```

### בעיה: "pip install fails"
**פתרון**: שדרג pip תחילה:
```bash
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

## קבצי הגדרה

- **`.python-version`** - קובץ זה מגדיר את גרסת Python לפרויקט (תומך ב-pyenv)
- **`Dockerfile`** - מגדיר את גרסת Python בסביבת Docker
- **`requirements.txt`** - מגדיר את התלויות (חבילות Python)

## סיכום

✅ **Python 3.10** - גרסה אחת לכל הסביבות
✅ **Docker** - מוגדר אוטומטית ב-Dockerfile
✅ **פיתוח מקומי** - בחר Python 3.10 ב-IDE שלך
✅ **CI/CD** - מוגדר אוטומטית ב-GitHub Actions

## קישורים שימושיים

- [Python 3.10 Documentation](https://docs.python.org/3.10/)
- [Docker Python Images](https://hub.docker.com/_/python)
- [VS Code Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
