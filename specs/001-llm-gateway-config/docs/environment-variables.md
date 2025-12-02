# Environment Variables Reference

**Complete reference for all environment variables used in Claude Code + LLM Gateway configuration.**

---

## Core Claude Code Variables

### ANTHROPIC_API_KEY

**Purpose**: API key for Anthropic Claude models  
**Required**: Yes (unless using gateway)  
**Format**: `sk-ant-api03-...` (starts with `sk-ant-`)  
**Example**:

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-abc123..."
```

**Gateway Mode**: Use dummy value when routing through gateway

```bash
export ANTHROPIC_API_KEY="sk-local-gateway"
```

### ANTHROPIC_BASE_URL

**Purpose**: Override default Anthropic API endpoint  
**Required**: No (defaults to `https://api.anthropic.com`)  
**Format**: Full URL including protocol  
**Example**:

```bash
# For local gateway
export ANTHROPIC_BASE_URL="http://localhost:4000"

# For enterprise gateway
export ANTHROPIC_BASE_URL="https://gateway.internal.corp:443"
```

---

## Provider-Specific Variables

### AWS Bedrock

#### AWS_ACCESS_KEY_ID

**Purpose**: AWS access key for Bedrock API  
**Required**: Yes (for Bedrock models)  
**Format**: `AKIA...` (20 characters)  
**Example**:

```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
```

#### AWS_SECRET_ACCESS_KEY

**Purpose**: AWS secret access key  
**Required**: Yes (for Bedrock)  
**Format**: 40-character string  
**Example**:

```bash
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

#### AWS_REGION

**Purpose**: AWS region for Bedrock API  
**Required**: No (defaults to `us-east-1`)  
**Format**: AWS region code  
**Example**:

```bash
export AWS_REGION="us-east-1"  # N. Virginia
export AWS_REGION="us-west-2"  # Oregon
export AWS_REGION="eu-west-1"  # Ireland
```

#### AWS_SESSION_TOKEN

**Purpose**: Temporary session token (for assumed roles)  
**Required**: No (only for temporary credentials)  
**Example**:

```bash
export AWS_SESSION_TOKEN="FwoGZXIvYXdzE..."
```

### Google Vertex AI

#### VERTEX_PROJECT_ID

**Purpose**: Google Cloud project ID for Vertex AI  
**Required**: Yes (for Vertex models)  
**Format**: Project ID string  
**Example**:

```bash
export VERTEX_PROJECT_ID="my-project-123"
```

#### VERTEX_LOCATION

**Purpose**: Google Cloud region for Vertex AI  
**Required**: No (defaults to `us-central1`)  
**Format**: Region code  
**Example**:

```bash
export VERTEX_LOCATION="us-central1"  # Iowa
export VERTEX_LOCATION="us-east4"     # N. Virginia
export VERTEX_LOCATION="europe-west1" # Belgium
```

#### GOOGLE_APPLICATION_CREDENTIALS

**Purpose**: Path to service account JSON key file  
**Required**: No (if using ADC)  
**Format**: File path  
**Example**:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

---

## Proxy Configuration

### HTTPS_PROXY / https_proxy

**Purpose**: HTTPS traffic proxy URL  
**Required**: No (only for corporate proxy)  
**Format**: `http://[user:pass@]host:port` or `socks5://host:port`  
**Note**: Uppercase takes precedence  
**Examples**:

```bash
# Simple proxy
export HTTPS_PROXY="http://proxy.corp.example.com:8080"

# With authentication
export HTTPS_PROXY="http://username:password@proxy.corp.example.com:8080"

# URL-encoded credentials (special characters)
export HTTPS_PROXY="http://user%40domain:p%40ssw0rd@proxy.corp.example.com:8080"

# SOCKS5 proxy
export HTTPS_PROXY="socks5://proxy.corp.example.com:1080"
```

### HTTP_PROXY / http_proxy

**Purpose**: HTTP traffic proxy URL  
**Required**: No  
**Format**: Same as HTTPS_PROXY  
**Example**:

```bash
export HTTP_PROXY="http://proxy.corp.example.com:8080"
```

### NO_PROXY / no_proxy

**Purpose**: Bypass proxy for specified hosts  
**Required**: No (recommended for localhost)  
**Format**: Comma-separated list of patterns  
**Examples**:

```bash
# Basic bypass
export NO_PROXY="localhost,127.0.0.1"

# With domain suffixes
export NO_PROXY="localhost,127.0.0.1,.internal,.corp,.local"

# With specific hosts
export NO_PROXY="localhost,api.internal,gateway.corp,10.0.0.5"

# IP ranges (limited support)
export NO_PROXY="localhost,192.168.0.0/16,10.0.0.0/8"
```

**Pattern Matching**:

- `localhost` - Exact match
- `.internal` - Domain suffix (matches `*.internal`)
- `10.0.0.5` - Specific IP
- `10.0.0.0/16` - IP range (CIDR notation, not all tools support)

### ALL_PROXY / all_proxy

**Purpose**: Fallback proxy for all protocols  
**Required**: No  
**Format**: Same as HTTPS_PROXY  
**Example**:

```bash
export ALL_PROXY="http://proxy.corp.example.com:8080"
```

---

## SSL/TLS Certificate Variables

### SSL_CERT_FILE

**Purpose**: Path to CA certificate bundle  
**Required**: No (only if custom CA needed)  
**Format**: File path  
**Example**:

```bash
export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
```

### REQUESTS_CA_BUNDLE

**Purpose**: CA bundle for Python requests library  
**Required**: No (Python-specific)  
**Format**: File path  
**Example**:

```bash
export REQUESTS_CA_BUNDLE="/path/to/corporate-ca-bundle.crt"
```

### CURL_CA_BUNDLE

**Purpose**: CA bundle for curl/libcurl  
**Required**: No (curl-specific)  
**Format**: File path  
**Example**:

```bash
export CURL_CA_BUNDLE="/path/to/corporate-ca-bundle.crt"
```

### NODE_EXTRA_CA_CERTS

**Purpose**: Additional CA certificates for Node.js  
**Required**: No (Node.js-specific)  
**Format**: File path  
**Example**:

```bash
export NODE_EXTRA_CA_CERTS="/path/to/corporate-ca-bundle.crt"
```

---

## Authentication Bypass Variables

### CLAUDE_CODE_SKIP_BEDROCK_AUTH

**Purpose**: Skip Bedrock authentication (use gateway auth)  
**Required**: No  
**Format**: Boolean string  
**Example**:

```bash
export CLAUDE_CODE_SKIP_BEDROCK_AUTH="true"
```

### CLAUDE_CODE_SKIP_VERTEX_AUTH

**Purpose**: Skip Vertex AI authentication (use gateway auth)  
**Required**: No  
**Format**: Boolean string  
**Example**:

```bash
export CLAUDE_CODE_SKIP_VERTEX_AUTH="true"
```

### BEDROCK_BASE_URL

**Purpose**: Override Bedrock API endpoint  
**Required**: No  
**Format**: Full URL  
**Example**:

```bash
export BEDROCK_BASE_URL="http://localhost:4000"
```

### VERTEX_BASE_URL

**Purpose**: Override Vertex AI endpoint  
**Required**: No  
**Format**: Full URL  
**Example**:

```bash
export VERTEX_BASE_URL="http://localhost:4000"
```

---

## Cache Configuration

### REDIS_HOST

**Purpose**: Redis server hostname for caching  
**Required**: No (only if using Redis cache)  
**Format**: Hostname or IP  
**Example**:

```bash
export REDIS_HOST="localhost"
export REDIS_HOST="redis.internal.corp"
```

### REDIS_PORT

**Purpose**: Redis server port  
**Required**: No (defaults to 6379)  
**Format**: Port number  
**Example**:

```bash
export REDIS_PORT="6379"
```

### REDIS_PASSWORD

**Purpose**: Redis authentication password  
**Required**: No (only if Redis requires auth)  
**Format**: String  
**Example**:

```bash
export REDIS_PASSWORD="your-redis-password"
```

---

## LiteLLM-Specific Variables

### LITELLM_LOG

**Purpose**: Enable LiteLLM debug logging  
**Required**: No  
**Format**: Log level (DEBUG, INFO, WARNING, ERROR)  
**Example**:

```bash
export LITELLM_LOG=DEBUG
```

### LITELLM_MODE

**Purpose**: LiteLLM operation mode  
**Required**: No  
**Format**: Mode string  
**Example**:

```bash
export LITELLM_MODE="PRODUCTION"
```

---

## Configuration by Scenario

### Scenario 1: Direct Provider (No Gateway, No Proxy)

```bash
# Only provider credentials needed
export ANTHROPIC_API_KEY="sk-ant-api03-..."
```

### Scenario 2: Local Gateway (No Proxy)

```bash
# Claude Code
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"

# Gateway needs real credentials
export ANTHROPIC_API_KEY="sk-ant-api03-..."  # Real key for gateway
export VERTEX_PROJECT_ID="my-project"
export VERTEX_LOCATION="us-central1"

# AWS (if using Bedrock)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

### Scenario 3: Corporate Proxy (No Gateway)

```bash
# Proxy configuration
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export HTTP_PROXY="http://proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"

# Provider credentials
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# CA certificate (if proxy uses custom CA)
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
```

### Scenario 4: Proxy + Gateway (Most Common Enterprise)

```bash
# Claude Code → Gateway (bypass proxy for localhost)
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"
export NO_PROXY="localhost,127.0.0.1"

# Gateway → Providers (via proxy)
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export HTTP_PROXY="http://proxy.corp.example.com:8080"

# Provider credentials (for gateway)
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export VERTEX_PROJECT_ID="my-project"
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."

# CA certificate (if needed)
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
```

### Scenario 5: Multi-Provider with Auth Bypass

```bash
# Claude Code points to gateway for all providers
export ANTHROPIC_BASE_URL="http://localhost:4000"
export BEDROCK_BASE_URL="http://localhost:4000"
export VERTEX_BASE_URL="http://localhost:4000"

# Skip provider-specific auth (gateway handles it)
export CLAUDE_CODE_SKIP_BEDROCK_AUTH="true"
export CLAUDE_CODE_SKIP_VERTEX_AUTH="true"

# Gateway credentials
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export VERTEX_PROJECT_ID="my-project"
```

---

## Setting Variables Permanently

### Linux/macOS (bash/zsh)

**User-specific** (`~/.bashrc` or `~/.zshrc`):

```bash
# Add to end of file
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"

# Reload
source ~/.bashrc  # or source ~/.zshrc
```

**System-wide** (`/etc/environment`):

```bash
# Requires sudo
sudo nano /etc/environment

# Add (no 'export' keyword)
ANTHROPIC_BASE_URL="http://localhost:4000"
ANTHROPIC_API_KEY="sk-local-gateway"
```

### Windows (PowerShell)

**User-specific**:

```powershell
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:4000", "User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-local-gateway", "User")
```

**System-wide** (requires admin):

```powershell
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:4000", "Machine")
```

---

## Validation Scripts

### Check All Variables

```bash
#!/bin/bash
echo "=== Environment Variables Check ==="
echo ""
echo "Claude Code:"
echo "  ANTHROPIC_BASE_URL: ${ANTHROPIC_BASE_URL:-NOT SET}"
echo "  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:0:10}... (${#ANTHROPIC_API_KEY} chars)"
echo ""
echo "Proxy:"
echo "  HTTPS_PROXY: ${HTTPS_PROXY:-NOT SET}"
echo "  NO_PROXY: ${NO_PROXY:-NOT SET}"
echo ""
echo "Providers:"
echo "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}... (${#AWS_ACCESS_KEY_ID} chars)"
echo "  VERTEX_PROJECT_ID: ${VERTEX_PROJECT_ID:-NOT SET}"
echo ""
echo "Certificates:"
echo "  SSL_CERT_FILE: ${SSL_CERT_FILE:-NOT SET}"
```

### Validate Provider Credentials

```bash
# Run validation script
python scripts/validate-provider-env-vars.py
```

---

## Troubleshooting

### Variable Not Set

```bash
# Check if variable is set
echo $ANTHROPIC_API_KEY

# List all ANTHROPIC variables
env | grep ANTHROPIC

# List all environment variables
env | sort
```

### Variable Not Taking Effect

```bash
# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc

# Check current shell
echo $SHELL

# Check variable in current shell
printenv ANTHROPIC_BASE_URL

# Start new shell
exec $SHELL
```

### Spaces in Values

```bash
# ❌ Wrong - spaces break parsing
export NO_PROXY="localhost, 127.0.0.1"

# ✅ Correct - no spaces after commas
export NO_PROXY="localhost,127.0.0.1"
```

### Special Characters in Passwords

```bash
# Password: p@ss:w/rd!
# URL-encode special characters
python3 -c "import urllib.parse; print(urllib.parse.quote('p@ss:w/rd!', safe=''))"
# Output: p%40ss%3Aw%2Frd%21

export HTTPS_PROXY="http://user:p%40ss%3Aw%2Frd%21@proxy:8080"
```

---

## Security Best Practices

1. **Never Commit to Git**:

   ```bash
   # Add to .gitignore
   .env
   .env.local
   config/*.local
   **/credentials.json
   ```

2. **Use Secrets Manager**:

   ```bash
   # AWS Secrets Manager
   export ANTHROPIC_API_KEY=$(aws secretsmanager get-secret-value --secret-id anthropic-key --query SecretString --output text)

   # 1Password CLI
   export ANTHROPIC_API_KEY=$(op read "op://Private/Anthropic API Key/credential")
   ```

3. **Restrict Permissions**:

   ```bash
   chmod 600 ~/.bashrc  # Only owner can read/write
   ```

4. **Rotate Regularly**:
   - API keys: Every 90 days
   - Proxy passwords: Per policy
   - Service account keys: Every 180 days

---

## References

- **Configuration Guide**: `docs/configuration-reference.md`
- **Proxy Setup**: `examples/us4-https-proxy-config.md`
- **Multi-Provider**: `examples/us3-provider-env-vars.md`
- **Validation Scripts**: `scripts/validate-provider-env-vars.py`

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
