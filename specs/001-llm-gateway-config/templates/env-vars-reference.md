# Environment Variables Reference

**Feature**: LLM Gateway Configuration Assistant  
**Purpose**: Complete reference for environment variables used in Claude Code gateway configuration

---

## Required Environment Variables

### Gateway Configuration

#### `ANTHROPIC_BASE_URL`
- **Description**: Base URL of the LLM gateway/proxy
- **Required**: Yes (for gateway configurations)
- **Format**: HTTP/HTTPS URL
- **Examples**:
  - Local LiteLLM: `http://localhost:4000`
  - Enterprise gateway: `https://llm-gateway.company.com`
  - TrueFoundry: `https://your-instance.truefoundry.com`
- **Default**: `https://api.anthropic.com` (if not set)

#### `ANTHROPIC_AUTH_TOKEN`
- **Description**: Authentication token for the gateway
- **Required**: Yes
- **Format**: String token
- **Examples**:
  - LiteLLM master key: `sk-litellm-master-key-1234`
  - Enterprise token: `bearer-token-xyz`
- **Security**: ⚠️ Never commit this to version control
- **Storage**: Use secret manager or `.env` file (gitignored)

#### `LITELLM_MASTER_KEY`
- **Description**: Master key for LiteLLM proxy authentication
- **Required**: Yes (for LiteLLM proxy)
- **Format**: String (recommend `sk-` prefix)
- **Example**: `sk-1234567890abcdef`
- **Usage**: Referenced in `litellm_config.yaml` as `os.environ/LITELLM_MASTER_KEY`

---

## Optional Environment Variables

### Provider-Specific Base URLs

#### `ANTHROPIC_BEDROCK_BASE_URL`
- **Description**: Custom base URL for Bedrock provider
- **Required**: No (only for Bedrock routing)
- **Format**: HTTPS URL
- **Example**: `https://bedrock-runtime.us-west-2.amazonaws.com`
- **Use Case**: Multi-provider gateways with Bedrock support

#### `ANTHROPIC_VERTEX_BASE_URL`
- **Description**: Custom base URL for Vertex AI provider
- **Required**: No (only for direct Vertex AI routing)
- **Format**: HTTPS URL
- **Example**: `https://us-central1-aiplatform.googleapis.com`
- **Use Case**: Direct Vertex AI integration without gateway

### Authentication Bypass Flags

#### `CLAUDE_CODE_SKIP_BEDROCK_AUTH`
- **Description**: Skip Bedrock-specific authentication when using gateway
- **Required**: No
- **Format**: Boolean (`1`, `true`, `yes`)
- **Example**: `export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1`
- **Use Case**: Gateway handles Bedrock auth, Claude Code should not authenticate directly
- **Security**: Only use when gateway is trusted and handles authentication

#### `CLAUDE_CODE_SKIP_VERTEX_AUTH`
- **Description**: Skip Vertex AI authentication when using gateway
- **Required**: No
- **Format**: Boolean (`1`, `true`, `yes`)
- **Example**: `export CLAUDE_CODE_SKIP_VERTEX_AUTH=true`
- **Use Case**: Gateway handles Vertex AI auth (service account or gcloud)
- **Security**: Only use when gateway is trusted

### Google Cloud Authentication

#### `GOOGLE_APPLICATION_CREDENTIALS`
- **Description**: Path to Google Cloud service account JSON key
- **Required**: No (alternative to gcloud auth)
- **Format**: File path
- **Example**: `/path/to/service-account-key.json`
- **Use Case**: Production deployments, CI/CD pipelines
- **Security**: ⚠️ Protect this file with 600 permissions

### Proxy Configuration

#### `HTTPS_PROXY`
- **Description**: Corporate HTTPS proxy for outbound requests
- **Required**: No (only in corporate environments)
- **Format**: HTTP/HTTPS URL with optional auth
- **Examples**:
  - Without auth: `http://proxy.company.com:8080`
  - With auth: `http://user:pass@proxy.company.com:8080`
- **Use Case**: Enterprise networks requiring proxy for internet access

#### `HTTP_PROXY`
- **Description**: Corporate HTTP proxy for outbound requests
- **Required**: No
- **Format**: Same as `HTTPS_PROXY`
- **Note**: Less common since most API calls use HTTPS

#### `NO_PROXY`
- **Description**: Comma-separated list of domains to bypass proxy
- **Required**: No
- **Format**: Comma-separated domains
- **Example**: `localhost,127.0.0.1,.company.com`
- **Use Case**: Local services that should not go through proxy

### Debugging and Logging

#### `ANTHROPIC_LOG`
- **Description**: Enable debug logging for Claude Code
- **Required**: No (only for troubleshooting)
- **Format**: Log level string
- **Values**: `debug`, `info`, `warn`, `error`
- **Example**: `export ANTHROPIC_LOG=debug`
- **Use Case**: Troubleshooting gateway connectivity issues

#### `LITELLM_LOG`
- **Description**: LiteLLM logging level
- **Required**: No
- **Format**: Log level string
- **Values**: `DEBUG`, `INFO`, `WARNING`, `ERROR`
- **Example**: `export LITELLM_LOG=DEBUG`
- **Use Case**: Debugging LiteLLM proxy behavior

---

## Configuration Hierarchy

Environment variables are resolved in this order:

1. **Runtime environment** (highest priority)
   ```bash
   ANTHROPIC_BASE_URL=http://localhost:4000 claude /status
   ```

2. **User-level settings** (`~/.claude/settings.json`)
   ```json
   {
     "ANTHROPIC_BASE_URL": "https://gateway.company.com"
   }
   ```

3. **Project-level settings** (`.claude/settings.json` in project root)
   ```json
   {
     "ANTHROPIC_BASE_URL": "http://localhost:4000"
   }
   ```

4. **Default values** (lowest priority)
   - `ANTHROPIC_BASE_URL`: `https://api.anthropic.com`

---

## Security Best Practices

### ✅ DO

1. **Use secret managers** for production credentials
   - AWS Secrets Manager
   - Google Secret Manager
   - HashiCorp Vault

2. **Set restrictive file permissions** on credential files
   ```bash
   chmod 600 ~/.env
   chmod 600 ~/service-account-key.json
   ```

3. **Rotate credentials regularly**
   - Service accounts: Every 90 days
   - Master keys: Every 30 days

4. **Use environment-specific credentials**
   - Different keys for dev/staging/production

### ❌ DON'T

1. **Never commit secrets to version control**
   - Add `.env` to `.gitignore`
   - Use `.env.example` with placeholder values

2. **Never hardcode credentials in YAML files**
   - Always use `os.environ/VARIABLE_NAME` syntax

3. **Don't share credentials between users**
   - Each developer gets their own service account

4. **Don't store credentials in plain text logs**
   - LiteLLM automatically masks tokens in logs

---

## Verification Commands

### Check Current Configuration
```bash
# View effective configuration (credentials masked)
claude /status

# Expected output:
# Base URL: http://localhost:4000 ✓
# Auth Token: sk-**** (masked) ✓
```

### Test Environment Variables
```bash
# Check if variable is set
echo $ANTHROPIC_BASE_URL

# Check if credential file exists
ls -la $GOOGLE_APPLICATION_CREDENTIALS

# Test gcloud authentication
gcloud auth application-default print-access-token
```

---

## Examples by Deployment Pattern

### Pattern 1: Direct Provider (No Gateway)
```bash
# No gateway-specific variables needed
# Claude Code uses default Anthropic API
```

### Pattern 2: Local LiteLLM Gateway
```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-litellm-master-key"
export LITELLM_MASTER_KEY="sk-litellm-master-key"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/litellm-sa-key.json"
```

### Pattern 3: Enterprise Gateway
```bash
export ANTHROPIC_BASE_URL="https://llm-gateway.company.com"
export ANTHROPIC_AUTH_TOKEN="<enterprise-token-from-secret-manager>"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

### Pattern 4: Corporate Proxy + Gateway
```bash
export HTTPS_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1"
export ANTHROPIC_BASE_URL="https://llm-gateway.company.com"
export ANTHROPIC_AUTH_TOKEN="<enterprise-token>"
```

---

## Troubleshooting

### Issue: "Connection refused" error
**Likely cause**: `ANTHROPIC_BASE_URL` pointing to stopped/unreachable gateway

**Solution**:
```bash
# Verify gateway is running
curl $ANTHROPIC_BASE_URL/health

# Check URL is correct
echo $ANTHROPIC_BASE_URL
```

### Issue: "Unauthorized" or "Invalid API key"
**Likely cause**: `ANTHROPIC_AUTH_TOKEN` mismatch with gateway master key

**Solution**:
```bash
# Verify tokens match
echo $ANTHROPIC_AUTH_TOKEN
echo $LITELLM_MASTER_KEY  # Should match for LiteLLM

# Check token in Claude Code
claude /status  # Shows masked token
```

### Issue: "403 Forbidden" for Vertex AI models
**Likely cause**: Missing or expired Google Cloud credentials

**Solution**:
```bash
# Re-authenticate with gcloud
gcloud auth application-default login

# Or verify service account key
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email
```

---

## Related Documentation

- [Deployment Patterns](./deployment-patterns.md)
- [Security Best Practices](../examples/us2-security-best-practices.md)
- [Troubleshooting Guide](../examples/us1-troubleshooting.md)
