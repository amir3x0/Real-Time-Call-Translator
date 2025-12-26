$env:PYTHONPATH = '.'; $env:REDIS_HOST = '127.0.0.1'; $env:REDIS_PASSWORD = 'NONE'; .\venv\Scripts\uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
