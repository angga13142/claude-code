# Environment Variables Setup Guide - User Story 1

**User Story**: Basic LiteLLM Gateway Setup  
**Target**: Developers configuring local LiteLLM proxy with Vertex AI models  
**Estimated Time**: 5 minutes

---

## Overview

This guide shows you how to set up the environment variables needed for User Story 1 (Basic LiteLLM Gateway Setup with 8 Vertex AI models).

---

## Required Environment Variables

### 1. LiteLLM Master Key

**Purpose**: Authentication token for the LiteLLM proxy

```bash
export LITELLM_MASTER_KEY="sk-1234567890abcdef"
```

**Recommendations**:
- Use a strong, random string (at least 20 characters)
- Start with `sk-` prefix for clarity
- Store in `.env` file (gitignored) for persistence

**Generate a secure key**:
```bash
# Option 1: Using openssl
export LITELLM_MASTER_KEY="sk-$(openssl rand -hex 16)"

# Option 2: Using Python
export LITELLM_MASTER_KEY="sk-$(python3 -c 'import secrets; print(secrets.token_hex(16))')"

# Option 3: Manual
export LITELLM_MASTER_KEY="sk-your-secure-key-here"
```

### 2. Claude Code Gateway Configuration

**Purpose**: Point Claude Code to your local LiteLLM gateway

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-1234567890abcdef"  # Same as LITELLM_MASTER_KEY
```

**Important**: `ANTHROPIC_AUTH_TOKEN` must match `LITELLM_MASTER_KEY` for authentication to work.

### 3. Google Cloud Authentication

**Choose ONE method:**

#### Option A: gcloud Auth (Recommended for Development)

```bash
# Authenticate with your Google account
gcloud auth application-default login

# Set your default project
gcloud config set project YOUR_PROJECT_ID
```

**Pros**: 
- No credential files to manage
- Automatic token refresh
- Easy to set up

**Cons**:
- Requires gcloud CLI installed
- Per-user setup

#### Option B: Service Account (Recommended for Production)

```bash
# Set path to service account JSON key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# Ensure file has restrictive permissions
chmod 600 "$GOOGLE_APPLICATION_CREDENTIALS"
```

**Pros**:
- Portable across environments
- Works in CI/CD
- Fine-grained IAM control

**Cons**:
- Requires secure secret management

---

## Optional Environment Variables

### Debugging

Enable debug logging for troubleshooting:

```bash
# Claude Code debug logging
export ANTHROPIC_LOG=debug

# LiteLLM debug logging
export LITELLM_LOG=DEBUG
```

### Logging Configuration

For production environments with request logging:

```bash
# PostgreSQL database for request logs
export DATABASE_URL="postgresql://user:password@localhost:5432/litellm"
```

---

## Complete Setup Scripts

### Development Setup (gcloud auth)

Create a file named `.env` in your project root:

```bash
# .env - Development configuration

# LiteLLM Configuration
export LITELLM_MASTER_KEY="sk-dev-1234567890abcdef"

# Claude Code Configuration
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-dev-1234567890abcdef"

# Google Cloud Project
# Note: Use gcloud auth application-default login for credentials
# gcloud config set project YOUR_PROJECT_ID
```

**Load environment variables**:
```bash
source .env
```

### Production Setup (service account)

Create a file named `.env.production`:

```bash
# .env.production - Production configuration

# LiteLLM Configuration
export LITELLM_MASTER_KEY="sk-prod-SECURE-KEY-FROM-VAULT"

# Claude Code Configuration
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-prod-SECURE-KEY-FROM-VAULT"

# Google Cloud Authentication
export GOOGLE_APPLICATION_CREDENTIALS="/opt/secrets/litellm-sa-key.json"

# Optional: Enable request logging
export DATABASE_URL="postgresql://litellm:password@postgres:5432/litellm_prod"
```

**Security Note**: Never commit `.env.production` to version control!

---

## Verification

### Check Environment Variables

```bash
# Check if variables are set
echo "LiteLLM Master Key: ${LITELLM_MASTER_KEY:0:8}..."
echo "Base URL: $ANTHROPIC_BASE_URL"
echo "Auth Token: ${ANTHROPIC_AUTH_TOKEN:0:8}..."

# Check Google Cloud credentials
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "Using service account: $GOOGLE_APPLICATION_CREDENTIALS"
    ls -lh "$GOOGLE_APPLICATION_CREDENTIALS"
else
    echo "Using gcloud auth"
    gcloud auth application-default print-access-token | head -c 20
    echo "..."
fi
```

### Run Automated Check

Use the provided script to verify all prerequisites:

```bash
cd specs/001-llm-gateway-config
source ../../.env  # Load environment variables first
./scripts/check-status.sh
```

**Expected output** (when everything is configured correctly):

```text
==========================================
Claude Code Gateway Configuration Check
==========================================

Check 1: Claude Code Installation
----------------------------------
✓ Claude Code is installed (version: 2.0.55 (Claude Code))

Check 2: Environment Variables
-------------------------------
✓ ANTHROPIC_BASE_URL is set
  Value: http://localhost:4000
✓ URL format is valid

✓ ANTHROPIC_AUTH_TOKEN is set
  Value: sk-0****ab91 (masked)
✓ Token length appears valid (35 characters)

Check 3: Provider Auth Bypass Flags
------------------------------------
ℹ CLAUDE_CODE_SKIP_BEDROCK_AUTH not set (default behavior)
ℹ CLAUDE_CODE_SKIP_VERTEX_AUTH not set (default behavior)

Check 4: Proxy Configuration
----------------------------
ℹ HTTPS_PROXY not set (direct connection)

Check 5: Google Cloud Credentials
----------------------------------
✓ Using gcloud application-default credentials

Check 6: Gateway Connectivity
-----------------------------
✓ Gateway is reachable at http://localhost:4000

==========================================
Summary & Next Steps
==========================================

✓ Configuration looks complete!

Your setup:
  Gateway: http://localhost:4000
  Authentication: ✓ Configured

Next steps:
  1. Test health: ./health-check.sh
  2. Test completion: claude "Hello, world!"
  3. Check logs: claude /status (within Claude Code)
```

**Note**: If gateway is not running, Check 6 will show:

```text
✗ Cannot reach gateway at http://localhost:4000
  Check if gateway is running: ./health-check.sh
```

This is normal if you haven't started the gateway yet. Start it with:
```bash
litellm --config templates/litellm-complete.yaml --port 4000
```

---

## Platform-Specific Instructions

### macOS/Linux

**Temporary (current session only)**:
```bash
export LITELLM_MASTER_KEY="sk-1234567890abcdef"
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-1234567890abcdef"
```

**Permanent (add to shell profile)**:
```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export LITELLM_MASTER_KEY="sk-1234567890abcdef"' >> ~/.bashrc
echo 'export ANTHROPIC_BASE_URL="http://localhost:4000"' >> ~/.bashrc
echo 'export ANTHROPIC_AUTH_TOKEN="sk-1234567890abcdef"' >> ~/.bashrc

# Reload shell
source ~/.bashrc
```

### Windows (PowerShell)

**Temporary (current session only)**:
```powershell
$env:LITELLM_MASTER_KEY="sk-1234567890abcdef"
$env:ANTHROPIC_BASE_URL="http://localhost:4000"
$env:ANTHROPIC_AUTH_TOKEN="sk-1234567890abcdef"
```

**Permanent (user-level)**:
```powershell
[System.Environment]::SetEnvironmentVariable('LITELLM_MASTER_KEY', 'sk-1234567890abcdef', 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'http://localhost:4000', 'User')
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', 'sk-1234567890abcdef', 'User')
```

### Windows (Command Prompt)

**Temporary (current session only)**:
```cmd
set LITELLM_MASTER_KEY=sk-1234567890abcdef
set ANTHROPIC_BASE_URL=http://localhost:4000
set ANTHROPIC_AUTH_TOKEN=sk-1234567890abcdef
```

**Permanent (system-level)**:
```cmd
setx LITELLM_MASTER_KEY "sk-1234567890abcdef"
setx ANTHROPIC_BASE_URL "http://localhost:4000"
setx ANTHROPIC_AUTH_TOKEN "sk-1234567890abcdef"
```

---

## Docker/Container Environments

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  litellm:
    image: ghcr.io/berriai/litellm:latest
    environment:
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
      - GOOGLE_APPLICATION_CREDENTIALS=/secrets/sa-key.json
    volumes:
      - ./litellm-complete.yaml:/app/config.yaml
      - ./service-account-key.json:/secrets/sa-key.json:ro
    ports:
      - "4000:4000"
    command: --config /app/config.yaml --port 4000
```

### Kubernetes Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: litellm-secrets
type: Opaque
stringData:
  LITELLM_MASTER_KEY: sk-prod-key-from-vault
  GOOGLE_APPLICATION_CREDENTIALS: /secrets/sa-key.json
```

---

## Security Best Practices

### ✅ DO

1. **Use `.env` files** and add them to `.gitignore`
   ```bash
   echo ".env" >> .gitignore
   echo ".env.*" >> .gitignore
   ```

2. **Rotate keys regularly**
   - Development: Every 90 days
   - Production: Every 30 days

3. **Use secret managers in production**
   - Google Secret Manager
   - AWS Secrets Manager
   - HashiCorp Vault

4. **Restrict file permissions**
   ```bash
   chmod 600 .env
   chmod 600 service-account-key.json
   ```

### ❌ DON'T

1. **Never commit secrets to git**
   ```bash
   # Check for accidental commits
   git log -p | grep -i "LITELLM_MASTER_KEY"
   ```

2. **Never hardcode secrets in YAML files**
   ```yaml
   # BAD:
   master_key: sk-1234567890abcdef
   
   # GOOD:
   master_key: os.environ/LITELLM_MASTER_KEY
   ```

3. **Never share keys between environments**
   - Dev, staging, and production must use different keys

4. **Never log secrets**
   - LiteLLM automatically masks tokens in logs

---

## Troubleshooting

### Issue: "LITELLM_MASTER_KEY not set"

**Cause**: Environment variable not exported or gateway can't read it

**Solution**:
```bash
# Verify variable is set
echo $LITELLM_MASTER_KEY

# If empty, export it
export LITELLM_MASTER_KEY="your-key-here"

# Restart LiteLLM proxy
litellm --config litellm-complete.yaml --port 4000
```

### Issue: "Unauthorized" when calling gateway

**Cause**: `ANTHROPIC_AUTH_TOKEN` doesn't match `LITELLM_MASTER_KEY`

**Solution**:
```bash
# Ensure they match
export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"

# Verify
[ "$ANTHROPIC_AUTH_TOKEN" = "$LITELLM_MASTER_KEY" ] && echo "Match!" || echo "Mismatch!"
```

### Issue: "403 Forbidden" for Vertex AI

**Cause**: Google Cloud credentials missing or invalid

**Solution**:
```bash
# Re-authenticate with gcloud
gcloud auth application-default login

# Or verify service account file
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email

# Check IAM permissions
gcloud projects get-iam-policy $(gcloud config get-value project) \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq -r .client_email)"
```

---

## Next Steps

Once environment variables are configured:

1. **Validate configuration**: `python scripts/validate-config.py templates/litellm-complete.yaml`
2. **Start gateway**: `litellm --config templates/litellm-complete.yaml --port 4000`
3. **Verify setup**: `./scripts/check-status.sh`
4. **Test completion**: `claude "Hello, world!"`

---

## Related Documentation

- [Deployment Patterns](../templates/deployment-patterns.md)
- [Environment Variables Reference](../templates/env-vars-reference.md)
- [Troubleshooting Guide](./us1-troubleshooting.md)
- [Verification Checklist](./us1-verification-checklist.md)
