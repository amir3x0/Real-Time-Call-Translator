$env:PYTHONPATH = '.'; $env:REDIS_HOST = '127.0.0.1'; $env:REDIS_PASSWORD = ''; $env:DB_HOST = '127.0.0.1'; $env:DB_PORT = '5433'; .\venv\Scripts\python scripts\worker.py
