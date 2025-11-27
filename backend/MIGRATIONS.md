# Running Alembic Migrations

This repository contains Alembic migrations under `backend/alembic`.

To apply migrations locally (inside the backend folder / container):

1. Make sure Alembic is installed in your Python environment or container:

```bash
pip install -r backend/requirements.txt
```

2. Run Alembic upgrade:

```bash
# From project root
alembic -c backend/alembic.ini upgrade head
```

Notes:
- The `alembic.ini` file uses settings derived from the `app.config.settings` when running inside the project.
- When running inside a Docker container, ensure the container uses the latest code (rebuild if necessary) or copy the updated migration files to the container.
