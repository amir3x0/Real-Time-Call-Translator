@echo off
cd /d "%~dp0"
set PYTHONPATH=.
set REDIS_HOST=127.0.0.1
set REDIS_PASSWORD=NONE
.\venv\Scripts\python scripts\worker.py
pause
