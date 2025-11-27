#!/bin/sh
# Run alembic upgrade head using the backend alembic.ini
alembic -c backend/alembic.ini upgrade head
