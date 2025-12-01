# Docker Compose Setup for LiteLLM Gateway

This directory contains Docker Compose configuration for running LiteLLM gateway locally with optional Redis caching and UI dashboard.

## Quick Start

1. **Copy environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Prepare configuration**:
   ```bash
   # Copy your LiteLLM configuration
   mkdir -p config
   cp ../../templates/litellm-complete.yaml config/litellm.yaml
   # Edit config/litellm.yaml with your GCP project ID
   ```

3. **Start services**:
   ```bash
   docker-compose up -d
   ```

4. **Verify gateway is running**:
   ```bash
   curl http://localhost:4000/health
   ```

5. **Access UI dashboard** (optional):
   ```bash
   docker-compose --profile ui up -d
   # Open http://localhost:4001 in your browser
   ```

## Services

### LiteLLM Gateway (`litellm-gateway`)
- **Port**: `4000`
- **Health Check**: `http://localhost:4000/health`
- **Configuration**: Mounted from `./config/litellm.yaml`
- **Logs**: Available in `./logs/` directory

### Redis Cache (`redis`)
- **Port**: `6379`
- **Purpose**: Caching for improved performance and cost savings
- **Data Persistence**: Stored in Docker volume `redis-data`

### LiteLLM UI (`litellm-ui`) - Optional
- **Port**: `4001`
- **Purpose**: Web dashboard for monitoring and usage analytics
- **Start**: Use `--profile ui` flag: `docker-compose --profile ui up`

## Configuration

### Environment Variables

Edit `.env` file with your settings:

```bash
# Required
LITELLM_MASTER_KEY=sk-your-master-key-here

# Google Cloud (choose one)
# Option 1: Service account file
GOOGLE_APPLICATION_CREDENTIALS=/app/gcp-key.json

# Option 2: Application-default credentials
# Mount ~/.config/gcloud to container
```

### Google Cloud Authentication

**Option 1: Service Account File** (Recommended for Docker)
1. Create a service account in GCP Console
2. Download the JSON key file
3. Place it in the `docker/` directory
4. Mount it in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./gcp-key.json:/app/gcp-key.json:ro
   ```

**Option 2: Application Default Credentials** (For local development)
1. Run `gcloud auth application-default login`
2. Mount the credentials directory:
   ```yaml
   volumes:
     - ~/.config/gcloud:/root/.config/gcloud:ro
   ```

### Configuration File

Place your `litellm.yaml` configuration in `config/litellm.yaml`. The file is mounted as read-only to the container.

## Usage

### Start Services
```bash
docker-compose up -d
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f litellm-gateway
```

### Stop Services
```bash
docker-compose down
```

### Stop and Remove Volumes
```bash
docker-compose down -v
```

### Restart Service
```bash
docker-compose restart litellm-gateway
```

### Access Container Shell
```bash
docker-compose exec litellm-gateway /bin/bash
```

## Building Custom Image

If you want to build a custom Docker image:

```bash
# Build image
docker build -t litellm-gateway:latest .

# Run container
docker run -d \
  -p 4000:4000 \
  -v $(pwd)/config/litellm.yaml:/app/config.yaml:ro \
  -e LITELLM_MASTER_KEY=sk-local-gateway \
  litellm-gateway:latest
```

## Integration with Claude Code

After starting the gateway, configure Claude Code:

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-local-gateway"  # Use LITELLM_MASTER_KEY value
```

Then test:
```bash
claude "Hello, world!"
```

## Troubleshooting

### Gateway Not Starting

1. **Check logs**:
   ```bash
   docker-compose logs litellm-gateway
   ```

2. **Verify configuration**:
   ```bash
   docker-compose exec litellm-gateway python3 -c "import yaml; yaml.safe_load(open('/app/config.yaml'))"
   ```

3. **Check port availability**:
   ```bash
   lsof -i :4000
   ```

### Authentication Errors

1. **Verify GCP credentials**:
   ```bash
   docker-compose exec litellm-gateway gcloud auth list
   ```

2. **Check service account permissions**:
   - Ensure the service account has `Vertex AI User` role
   - Verify the project ID matches in `litellm.yaml`

### Redis Connection Issues

1. **Check Redis is running**:
   ```bash
   docker-compose ps redis
   ```

2. **Test Redis connection**:
   ```bash
   docker-compose exec redis redis-cli ping
   ```

## Production Considerations

For production deployments:

1. **Use secrets management**:
   - Store `LITELLM_MASTER_KEY` in Docker secrets or environment variable management
   - Never commit credentials to version control

2. **Enable HTTPS**:
   - Use a reverse proxy (nginx, traefik) with SSL certificates
   - Configure TLS termination

3. **Resource limits**:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 4G
   ```

4. **Monitoring**:
   - Set up health check monitoring
   - Configure log aggregation
   - Enable Prometheus metrics (if available)

5. **Backup**:
   - Regularly backup Redis data volume
   - Version control configuration files

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Gateway Configuration Guide](../../README.md)

