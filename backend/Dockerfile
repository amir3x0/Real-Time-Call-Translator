# backend/Dockerfile
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    make \
    libffi-dev \
    libssl-dev \
    curl \
    ffmpeg \
    libsndfile1 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
# Upgrade pip first to ensure latest package resolver
RUN pip install --upgrade pip setuptools wheel

# Install all dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create directories
RUN mkdir -p /app/data/{uploads,models,voice_samples}

# Expose port
EXPOSE 8000

# Health check (use Python stdlib to avoid external deps)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import sys,urllib.request;\
resp=urllib.request.urlopen('http://localhost:8000/health');\
sys.exit(0 if resp.getcode()==200 else 1)"

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]