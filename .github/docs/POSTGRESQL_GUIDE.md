# PostgreSQL Database Guide - Real-Time Call Translator

## 📋 Table of Contents
1. [Database Overview](#database-overview)
2. [Accessing the Database](#accessing-the-database)
3. [Using pgAdmin (GUI)](#using-pgadmin-gui)
4. [Using psql (Command Line)](#using-psql-command-line)
5. [Common SQL Queries](#common-sql-queries)
6. [Database Schema](#database-schema)
7. [Python Integration](#python-integration)
8. [Backup & Restore](#backup--restore)
9. [Troubleshooting](#troubleshooting)

---

## 🗄️ Database Overview

### Database Configuration

| Parameter | Value |
|-----------|-------|
| **Database Name** | `call_translator` |
| **Database User** | `translator_admin` |
| **Database Password** | `TranslatorPass2024` |
| **Database Host** | `postgres` (inside Docker) / `localhost` (outside Docker) |
| **Database Port (Internal)** | `5432` |
| **Database Port (External)** | `5433` |
| **PostgreSQL Version** | 15 (Alpine) |

### Database Tables

The system uses 6 main tables:

1. **users** - User accounts and profiles
2. **calls** - Call sessions
3. **call_participants** - Participants in each call
4. **contacts** - User contact lists
5. **voice_models** - Voice cloning models
6. **messages** - Call transcriptions and translations

---

## 🔌 Accessing the Database

### Prerequisites

Make sure Docker containers are running:

```powershell
cd 'd:\studies\Final Project\Real-Time-Call-Translator\backend'
docker-compose ps
```

You should see these containers:
- ✅ `translator_db` (PostgreSQL)
- ✅ `translator_cache` (Redis)
- ✅ `translator_api` (Backend)
- ✅ `translator_dbadmin` (pgAdmin)

If not running:
```powershell
docker-compose up -d
```

---

## 🖥️ Using pgAdmin (GUI)

### Step 1: Access pgAdmin

Open your browser and navigate to:
```
http://localhost:5050
```

### Step 2: Login

```
Email: admin@translator.com
Password: PgAdmin2024
```

### Step 3: Add Server Connection

1. Click **"Add New Server"** or right-click **Servers → Register → Server**

2. **General Tab:**
   - Name: `Translator DB`
   - Server Group: (leave default)
   - Comments: `Real-Time Call Translator Database`

3. **Connection Tab:**
   - Host name/address: `postgres`
   - Port: `5432`
   - Maintenance database: `call_translator`
   - Username: `translator_admin`
   - Password: `TranslatorPass2024`
   - ✅ Save password

4. **SSL Tab:**
   - SSL mode: `Prefer`

5. Click **Save**

### Step 4: Navigate Database

Once connected, expand the tree:
```
Servers
  └── Translator DB
      └── Databases
          └── call_translator
              └── Schemas
                  └── public
                      └── Tables
                          ├── users
                          ├── calls
                          ├── call_participants
                          ├── contacts
                          ├── voice_models
                          └── messages
```

### Common pgAdmin Operations

#### View Table Data
1. Right-click on table (e.g., `users`)
2. Select **View/Edit Data → All Rows**
3. Data appears in grid view

#### View Table Structure
1. Click on table name
2. View tabs:
   - **Columns** - Field definitions
   - **Constraints** - Primary keys, foreign keys, unique constraints
   - **Indexes** - Database indexes
   - **Triggers** - If any

#### Run SQL Queries
1. Right-click on `call_translator` database
2. Select **Query Tool**
3. Write SQL and click ▶ Execute

Example:
```sql
SELECT phone, full_name, primary_language 
FROM users 
WHERE is_active = true;
```

#### Export Data
1. Right-click on table
2. **Import/Export**
3. Choose format (CSV, JSON, etc.)

---

## 💻 Using psql (Command Line)

### Quick Commands Reference

#### Connect to Database
```powershell
docker exec -it translator_db psql -U translator_admin -d call_translator
```

#### List All Tables
```powershell
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\dt"
```

#### Describe Table Structure
```powershell
# Users table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d users"

# Calls table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d calls"

# Call participants table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d call_participants"

# Contacts table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d contacts"

# Voice models table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d voice_models"

# Messages table
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d messages"
```

#### Detailed Table Information
```powershell
# Include size and description
docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d+ users"
```

#### Run Single Query
```powershell
docker exec -it translator_db psql -U translator_admin -d call_translator -c "SELECT COUNT(*) FROM users;"
```

### Interactive psql Session

Enter interactive mode:
```powershell
docker exec -it translator_db psql -U translator_admin -d call_translator
```

Once inside psql:

#### Meta-Commands (start with backslash)
```sql
\?                          -- Help on meta-commands
\h                          -- Help on SQL commands
\l                          -- List all databases
\dt                         -- List tables
\dt+                        -- List tables with size
\d table_name               -- Describe table
\d+ table_name              -- Describe table with details
\df                         -- List functions
\dv                         -- List views
\du                         -- List users/roles
\dn                         -- List schemas
\x                          -- Toggle expanded display
\timing                     -- Toggle query timing
\q                          -- Quit
```

#### SQL Commands
```sql
-- Select all users
SELECT * FROM users;

-- Count records
SELECT COUNT(*) FROM users;

-- Specific columns
SELECT phone, full_name FROM users WHERE is_active = true;

-- Join example
SELECT 
    u.name,
    c.session_id,
    c.status
FROM users u
JOIN call_participants cp ON u.id = cp.user_id
JOIN calls c ON cp.call_id = c.id;
```

---

## 📊 Common SQL Queries

### Users Table

#### Get All Active Users
```sql
SELECT id, phone, full_name, primary_language, created_at 
FROM users 
WHERE is_active = true 
ORDER BY created_at DESC;
```

#### Count Users by Language
```sql
SELECT 
    primary_language,
    COUNT(*) as user_count
FROM users
GROUP BY primary_language
ORDER BY user_count DESC;
```

#### Find Users with Voice Samples
```sql
SELECT phone, full_name, voice_quality_score
FROM users
WHERE has_voice_sample = true
ORDER BY voice_quality_score DESC;
```

### Calls Table

#### Get Active Calls
```sql
SELECT 
    session_id,
    status,
    current_participants,
    max_participants,
    created_at
FROM calls
WHERE status = 'ACTIVE'
ORDER BY created_at DESC;
```

#### Get Call History for User
```sql
SELECT 
    c.session_id,
    c.status,
    c.started_at,
    c.ended_at,
    c.duration_seconds
FROM calls c
JOIN call_participants cp ON c.id = cp.call_id
WHERE cp.user_id = 'USER_ID_HERE'
ORDER BY c.created_at DESC;
```

#### Calculate Average Call Duration
```sql
SELECT 
    AVG(duration_seconds) as avg_duration_sec,
    AVG(duration_seconds) / 60 as avg_duration_min
FROM calls
WHERE duration_seconds IS NOT NULL;
```

### Call Participants Table

#### Get Participants in a Call
```sql
SELECT 
    u.full_name,
    u.phone,
    cp.target_language,
    cp.speaking_language,
    cp.is_muted,
    cp.joined_at
FROM call_participants cp
JOIN users u ON cp.user_id = u.id
WHERE cp.call_id = 'CALL_ID_HERE'
ORDER BY cp.joined_at;
```

#### Find Users Using Voice Cloning
```sql
SELECT 
    u.full_name,
    u.phone,
    COUNT(*) as times_used_cloning
FROM call_participants cp
JOIN users u ON cp.user_id = u.id
WHERE cp.use_voice_cloning = true
GROUP BY u.id, u.full_name, u.phone
ORDER BY times_used_cloning DESC;
```

### Messages Table

#### Get Recent Translations
```sql
SELECT 
    original_text,
    original_language,
    translated_text,
    target_language,
    translation_confidence,
    timestamp
FROM messages
WHERE translated_text IS NOT NULL
ORDER BY timestamp DESC
LIMIT 10;
```

#### Count Messages per Call
```sql
SELECT 
    c.session_id,
    COUNT(m.id) as message_count
FROM calls c
LEFT JOIN messages m ON c.id = m.call_id
GROUP BY c.id, c.session_id
ORDER BY message_count DESC;
```

#### Find Low Confidence Translations
```sql
SELECT 
    original_text,
    translated_text,
    translation_confidence,
    timestamp
FROM messages
WHERE translation_confidence < 70
ORDER BY timestamp DESC;
```

### Contacts Table

#### Get User's Contacts
```sql
SELECT 
    u.full_name as contact_name,
    u.phone as contact_phone,
    c.nickname,
    c.is_favorite,
    c.total_calls,
    c.last_call_at
FROM contacts c
JOIN users u ON c.contact_user_id = u.id
WHERE c.user_id = 'USER_ID_HERE'
  AND c.is_blocked = false
ORDER BY c.is_favorite DESC, c.last_call_at DESC;
```

#### Find Most Popular Contacts
```sql
SELECT 
    u.full_name,
    u.phone,
    COUNT(c.id) as times_added
FROM users u
JOIN contacts c ON u.id = c.contact_user_id
GROUP BY u.id, u.full_name, u.phone
ORDER BY times_added DESC
LIMIT 10;
```

### Voice Models Table

#### Get Trained Voice Models
```sql
SELECT 
    u.phone,
    u.full_name,
    vm.sample_language,
    vm.quality_score,
    vm.similarity_score,
    vm.times_used,
    vm.trained_at
FROM voice_models vm
JOIN users u ON vm.user_id = u.id
WHERE vm.is_trained = true
ORDER BY vm.quality_score DESC;
```

#### Training Status Overview
```sql
SELECT 
    training_status,
    COUNT(*) as model_count
FROM voice_models
GROUP BY training_status
ORDER BY model_count DESC;
```

### Complex Queries

#### Full Call Details with Participants
```sql
SELECT 
    c.session_id,
    c.status,
    c.started_at,
    c.duration_seconds,
    u.full_name as participant_name,
    cp.target_language,
    cp.speaking_language,
    cp.is_muted
FROM calls c
JOIN call_participants cp ON c.id = cp.call_id
JOIN users u ON cp.user_id = u.id
WHERE c.session_id = 'SESSION_ID_HERE'
ORDER BY cp.joined_at;
```

#### User Activity Summary
```sql
SELECT 
    u.phone,
    u.full_name,
    COUNT(DISTINCT cp.call_id) as total_calls,
    COUNT(DISTINCT c2.contact_user_id) as total_contacts,
    u.has_voice_sample,
    u.created_at
FROM users u
LEFT JOIN call_participants cp ON u.id = cp.user_id
LEFT JOIN contacts c2 ON u.id = c2.user_id
GROUP BY u.id, u.phone, u.full_name, u.has_voice_sample, u.created_at
ORDER BY total_calls DESC;
```

---

## 📐 Database Schema

### Users Table
```sql
CREATE TABLE users (
    id VARCHAR PRIMARY KEY,                    -- UUID
    phone VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255),
    firebase_uid VARCHAR(255) UNIQUE,
    primary_language VARCHAR(10) DEFAULT 'he', -- he, en, ru
    supported_languages JSON DEFAULT '["he"]',
    has_voice_sample BOOLEAN DEFAULT FALSE,
    voice_sample_path VARCHAR(500),
    voice_model_trained BOOLEAN DEFAULT FALSE,
    voice_quality_score INTEGER,               -- 0-100
    is_active BOOLEAN DEFAULT TRUE,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP,
    avatar_url VARCHAR(500),
    bio VARCHAR(500),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP
);
```

### Calls Table
```sql
CREATE TABLE calls (
    id VARCHAR PRIMARY KEY,                    -- UUID
    session_id VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR NOT NULL,                   -- ENUM: PENDING, ACTIVE, ENDED, CANCELLED
    max_participants INTEGER DEFAULT 4,
    current_participants INTEGER DEFAULT 0,
    created_by VARCHAR NOT NULL,               -- User ID
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP
);
```

### Call Participants Table
```sql
CREATE TABLE call_participants (
    id VARCHAR PRIMARY KEY,                    -- UUID
    call_id VARCHAR NOT NULL,                  -- FK to calls
    user_id VARCHAR NOT NULL,                  -- FK to users
    target_language VARCHAR(10) NOT NULL,      -- Language to hear
    speaking_language VARCHAR(10) NOT NULL,    -- Language to speak
    is_muted BOOLEAN DEFAULT FALSE,
    is_speaker_on BOOLEAN DEFAULT TRUE,
    use_voice_cloning BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP NOT NULL,
    left_at TIMESTAMP,
    duration_seconds INTEGER,
    is_connected BOOLEAN DEFAULT TRUE,
    connection_quality VARCHAR(20),            -- excellent, good, fair, poor
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP,
    FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Contacts Table
```sql
CREATE TABLE contacts (
    id VARCHAR PRIMARY KEY,                    -- UUID
    user_id VARCHAR NOT NULL,                  -- FK to users
    contact_user_id VARCHAR NOT NULL,          -- FK to users
    nickname VARCHAR(255),
    is_favorite BOOLEAN DEFAULT FALSE,
    is_blocked BOOLEAN DEFAULT FALSE,
    total_calls VARCHAR DEFAULT '0',
    last_call_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP,
    UNIQUE (user_id, contact_user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (contact_user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Voice Models Table
```sql
CREATE TABLE voice_models (
    id VARCHAR PRIMARY KEY,                    -- UUID
    user_id VARCHAR NOT NULL,                  -- FK to users
    sample_file_path VARCHAR(500) NOT NULL,
    sample_duration_seconds INTEGER,
    sample_language VARCHAR(10) NOT NULL,      -- he, en, ru
    model_file_path VARCHAR(500),
    is_trained BOOLEAN DEFAULT FALSE,
    training_status VARCHAR(50) DEFAULT 'pending', -- pending, training, completed, failed
    quality_score INTEGER,                     -- 0-100
    similarity_score INTEGER,                  -- 0-100
    characteristics TEXT,                      -- JSON string
    times_used INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP,
    trained_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Messages Table
```sql
CREATE TABLE messages (
    id VARCHAR PRIMARY KEY,                    -- UUID
    call_id VARCHAR NOT NULL,                  -- FK to calls
    sender_id VARCHAR,                         -- FK to users
    original_text TEXT NOT NULL,
    original_language VARCHAR(10) NOT NULL,
    translated_text TEXT,
    target_language VARCHAR(10),
    audio_file_path VARCHAR(500),
    audio_duration_ms INTEGER,
    timestamp TIMESTAMP NOT NULL,
    translation_confidence INTEGER,            -- 0-100
    was_voice_cloned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE SET NULL
);
```

### Indexes
```sql
-- Users
CREATE UNIQUE INDEX ix_users_phone ON users(phone);
CREATE UNIQUE INDEX ix_users_firebase_uid ON users(firebase_uid);

-- Calls
CREATE UNIQUE INDEX ix_calls_session_id ON calls(session_id);

-- Call Participants
CREATE INDEX ix_call_participants_call_id ON call_participants(call_id);
CREATE INDEX ix_call_participants_user_id ON call_participants(user_id);

-- Contacts
CREATE INDEX ix_contacts_user_id ON contacts(user_id);
CREATE INDEX ix_contacts_contact_user_id ON contacts(contact_user_id);

-- Voice Models
CREATE INDEX ix_voice_models_user_id ON voice_models(user_id);

-- Messages
CREATE INDEX ix_messages_call_id ON messages(call_id);
CREATE INDEX ix_messages_sender_id ON messages(sender_id);
CREATE INDEX ix_messages_timestamp ON messages(timestamp);
```

---

## 🐍 Python Integration

### Using Models in Python

```python
import asyncio
from sqlalchemy import select
from app.models import get_db, User, Call, CallParticipant

async def example_queries():
    async with get_db() as db:
        # Get all active users
        result = await db.execute(
            select(User).where(User.is_active == True)
        )
        users = result.scalars().all()
        
        # Create new user
        new_user = User(
            email="test@example.com",
            name="Test User",
            primary_language="he"
        )
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        # Get user with relationships
        result = await db.execute(
            select(User)
            .join(CallParticipant)
            .where(User.phone == "052-111-2222")
        )
        user = result.scalar_one_or_none()
        
        return users, new_user, user

# Run
asyncio.run(example_queries())
```

### Create Database Inspection Script

Create `backend/scripts/inspect_db.py`:

```python
import asyncio
from sqlalchemy import select, func, inspect
from app.models import (
    get_db, User, Call, CallParticipant, 
    Contact, VoiceModel, Message
)

async def inspect_database():
    """Comprehensive database inspection."""
    async with get_db() as db:
        print("=" * 60)
        print("DATABASE INSPECTION")
        print("=" * 60)
        
        # Count records in each table
        tables = [
            ("Users", User),
            ("Calls", Call),
            ("Call Participants", CallParticipant),
            ("Contacts", Contact),
            ("Voice Models", VoiceModel),
            ("Messages", Message)
        ]
        
        print("\nRECORD COUNTS:")
        print("-" * 60)
        for name, model in tables:
            result = await db.execute(select(func.count()).select_from(model))
            count = result.scalar()
            print(f"{name:20} {count:>10} records")
        
        # Show table structure
        inspector = inspect(db.bind)
        print("\nTABLE STRUCTURES:")
        print("-" * 60)
        for table_name in inspector.get_table_names():
            print(f"\n{table_name.upper()}:")
            columns = inspector.get_columns(table_name)
            for col in columns:
                print(f"  - {col['name']:30} {col['type']}")
        
        # Show indexes
        print("\nINDEXES:")
        print("-" * 60)
        for table_name in inspector.get_table_names():
            indexes = inspector.get_indexes(table_name)
            if indexes:
                print(f"\n{table_name}:")
                for idx in indexes:
                    print(f"  - {idx['name']}")
        
        print("\n" + "=" * 60)

if __name__ == "__main__":
    asyncio.run(inspect_database())
```

Run:
```powershell
docker exec -it translator_api sh -c "export PYTHONPATH=/app && python scripts/inspect_db.py"
```

---

## 💾 Backup & Restore

### Create Backup

#### Full Database Backup
```powershell
docker exec -t translator_db pg_dump -U translator_admin call_translator > backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').sql
```

#### Backup Specific Tables
```powershell
docker exec -t translator_db pg_dump -U translator_admin -t users -t calls call_translator > backup_users_calls.sql
```

#### Compressed Backup
```powershell
docker exec -t translator_db pg_dump -U translator_admin call_translator | gzip > backup.sql.gz
```

### Restore from Backup

#### Restore Full Database
```powershell
cat backup.sql | docker exec -i translator_db psql -U translator_admin -d call_translator
```

#### Restore from Compressed
```powershell
gunzip -c backup.sql.gz | docker exec -i translator_db psql -U translator_admin -d call_translator
```

### Automated Backup Script

Create `backend/scripts/backup_db.ps1`:

```powershell
# Backup script for PostgreSQL
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "d:\backups\call_translator"
$backupFile = "$backupDir\backup_$timestamp.sql"

# Create backup directory if not exists
New-Item -ItemType Directory -Force -Path $backupDir

# Create backup
docker exec -t translator_db pg_dump -U translator_admin call_translator > $backupFile

# Compress
Compress-Archive -Path $backupFile -DestinationPath "$backupFile.zip"
Remove-Item $backupFile

Write-Host "✅ Backup created: $backupFile.zip"

# Keep only last 7 backups
Get-ChildItem $backupDir -Filter "*.zip" | 
    Sort-Object CreationTime -Descending | 
    Select-Object -Skip 7 | 
    Remove-Item

Write-Host "✅ Old backups cleaned"
```

---

## 🔧 Troubleshooting

### Problem: Cannot Connect to Database

**Check if container is running:**
```powershell
docker ps | Select-String translator_db
```

**Check logs:**
```powershell
docker logs translator_db
```

**Restart database:**
```powershell
docker-compose restart postgres
```

### Problem: Permission Denied

**Solution:** Make sure you're using the correct credentials:
- Username: `translator_admin`
- Password: `TranslatorPass2024`
- Database: `call_translator`

### Problem: Table Does Not Exist

**Recreate tables:**
```powershell
docker exec -it translator_api sh -c "export PYTHONPATH=/app && python scripts/create_tables.py"
```

### Problem: Port Already in Use

**Check what's using port 5433:**
```powershell
netstat -ano | Select-String ":5433"
```

**Change port in docker-compose.yml:**
```yaml
ports:
  - "5434:5432"  # Change external port
```

### Problem: pgAdmin Not Accessible

**Check if container is running:**
```powershell
docker ps | Select-String translator_dbadmin
```

**Check logs:**
```powershell
docker logs translator_dbadmin
```

**Restart pgAdmin:**
```powershell
docker-compose restart pgadmin
```

### Problem: Data Inconsistency

**Reset database (⚠️ DANGER - Deletes all data):**
```powershell
docker exec -it translator_db psql -U translator_admin -d call_translator -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker exec -it translator_api sh -c "export PYTHONPATH=/app && python scripts/create_tables.py"
```

---

## 📚 Additional Resources

### PostgreSQL Documentation
- Official Docs: https://www.postgresql.org/docs/15/
- SQL Tutorial: https://www.postgresqltutorial.com/

### pgAdmin Documentation
- Official Docs: https://www.pgadmin.org/docs/

### SQLAlchemy Documentation
- Official Docs: https://docs.sqlalchemy.org/

### Useful Commands Cheat Sheet

```powershell
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker logs -f translator_db
docker logs -f translator_api

# Enter database
docker exec -it translator_db psql -U translator_admin -d call_translator

# Run script
docker exec -it translator_api sh -c "export PYTHONPATH=/app && python scripts/your_script.py"

# Backup
docker exec -t translator_db pg_dump -U translator_admin call_translator > backup.sql

# Restore
cat backup.sql | docker exec -i translator_db psql -U translator_admin -d call_translator
```

---

## 🎯 Quick Reference Card

| Task | Command |
|------|---------|
| **Access pgAdmin** | `http://localhost:5050` |
| **List tables** | `docker exec -it translator_db psql -U translator_admin -d call_translator -c "\dt"` |
| **Describe table** | `docker exec -it translator_db psql -U translator_admin -d call_translator -c "\d users"` |
| **Interactive psql** | `docker exec -it translator_db psql -U translator_admin -d call_translator` |
| **Count users** | `docker exec -it translator_db psql -U translator_admin -d call_translator -c "SELECT COUNT(*) FROM users;"` |
| **Create tables** | `docker exec -it translator_api sh -c "export PYTHONPATH=/app && python scripts/create_tables.py"` |
| **Backup database** | `docker exec -t translator_db pg_dump -U translator_admin call_translator > backup.sql` |

---

**Need Help?** Check the [troubleshooting section](#troubleshooting) or create an issue on GitHub.

**Last Updated:** November 21, 2025
