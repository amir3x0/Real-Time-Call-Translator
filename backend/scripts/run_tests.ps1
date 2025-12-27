# Run backend tests in Docker container (PowerShell)
# Usage: .\run_tests.ps1

# Ensure latest image built
Write-Host "Building Docker image (no-cache)..."
docker-compose build --no-cache backend

# Start services
Write-Host "Starting docker-compose services..."
docker-compose up -d

# Wait for Postgres and Redis to be available
Write-Host "Waiting for services to become healthy..."; Start-Sleep -Seconds 5

# Run tests with PYTHONPATH set to /app
Write-Host "Running pytest inside backend container..."
docker exec -it translator_api sh -c "export PYTHONPATH=/app && pytest -q"

Write-Host "Tests complete."
