# Dockerfile for LiteLLM Gateway
# Purpose: Custom Docker image with pre-configured LiteLLM
# Usage: docker build -t litellm-gateway:latest .

FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    litellm \
    google-cloud-aiplatform \
    redis \
    pyyaml

# Copy configuration file
COPY config/litellm.yaml /app/config.yaml

# Create logs directory
RUN mkdir -p /app/logs

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Default command
CMD ["litellm", "--config", "/app/config.yaml", "--port", "4000", "--host", "0.0.0.0"]

