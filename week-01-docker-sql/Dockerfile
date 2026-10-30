# Dockerfile for Data Ingestion Pipeline
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (build-essential, libpq-dev for psycopg2 if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install python libraries
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application script
COPY pipeline.py .

# Create directory for persistent/cached data files
RUN mkdir -p /app/data

ENTRYPOINT ["python", "pipeline.py"]
