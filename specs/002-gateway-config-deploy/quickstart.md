# Quick Start: Deploy LLM Gateway Configuration

**Feature**: 002-gateway-config-deploy  
**Time**: 5-10 minutes  
**Audience**: Users who completed 001-llm-gateway-config or want to use the gateway configuration

---

## Prerequisites

✅ **Required**:
- Linux, macOS, or WSL2
- Bash 4.0+ (`bash --version`)
- Python 3.7+ (`python3 --version`)
- Write access to `~/.claude` directory

✅ **Optional**:
- GCP credentials (for Vertex AI models)
- Enterprise gateway URL and token (for enterprise preset)
- Corporate proxy details (for proxy preset)

---

## Quick Deploy (2 minutes)

### Step 1: Navigate to Repository

```bash
cd ~/claude-code  # Or your repository location
```

### Step 2: Run Deployment

```bash
# Basic deployment with all 8 Vertex AI models
bash scripts/deploy-gateway-config.sh --preset basic
```

**Output**:
```
🚀 Deploying LLM Gateway Configuration
  Preset: basic
  Models: 8 Vertex AI models
  Target: /home/user/.claude/gateway

✓ Pre-flight checks passed
✓ Created backup: gateway-backup-20251202-143022.tar.gz
⏳ Copying files... (80+ files, 2.5 MB)
✓ Files deployed successfully
✓ Generated .env file
✓ Generated start-gateway.sh script
✓ Post-deployment validation passed

✅ Deployment completed in 7 seconds
```

### Step 3: Configure Environment

Edit `~/.claude/gateway/.env`:

```bash
vi ~/.claude/gateway/.env
```

Update these values:
```bash
# Required: LiteLLM master key (generate a secure key)
LITELLM_MASTER_KEY="sk-$(openssl rand -hex 32)"

# Required: Google Cloud authentication
GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account.json"
# OR use gcloud auth:
# gcloud auth application-default login

# Optional: Vertex AI settings
VERTEX_AI_PROJECT="your-gcp-project-id"
VERTEX_AI_LOCATION="us-central1"
```

### Step 4: Start Gateway

```bash
bash ~/.claude/gateway/start-gateway.sh
```

**Expected Output**:
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     LiteLLM Proxy running on http://0.0.0.0:4000
```

### Step 5: Test Connection

```bash
# Configure Claude Code to use gateway
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"

# Test
claude "What is 2+2?"
```

✅ **Success!** If you get a response, your gateway is working.

---

## Preset Options

### Basic (Default)

**Use Case**: Development, testing, learning

```bash
bash scripts/deploy-gateway-config.sh --preset basic
```

**Includes**:
- All 8 Vertex AI models
- Local LiteLLM proxy
- Complete documentation
- All test scripts

**Models**: gemini-2.5-flash, gemini-2.5-pro, deepseek-r1, llama3-405b, codestral, qwen3-coder-480b, qwen3-235b, gpt-oss-20b

---

### Enterprise

**Use Case**: Connect to existing enterprise gateway (TrueFoundry, Zuplo, custom)

```bash
bash scripts/deploy-gateway-config.sh --preset enterprise \
  --gateway-url https://gateway.company.com \
  --auth-token sk-your-token-here
```

**Includes**:
- Enterprise gateway configuration
- Authentication setup
- Security best practices
- Compliance guides

**Note**: No local LiteLLM needed - connects to your gateway

---

### Multi-Provider

**Use Case**: Route to multiple providers (Anthropic, Bedrock, Vertex AI)

```bash
bash scripts/deploy-gateway-config.sh --preset multi-provider
```

**Includes**:
- Multi-provider routing configuration
- Provider-specific settings
- Cost optimization guides
- Fallback strategies

**Requires**: API keys for multiple providers

---

### Proxy

**Use Case**: Corporate networks with HTTP/HTTPS proxy

```bash
bash scripts/deploy-gateway-config.sh --preset proxy \
  --proxy https://proxy.company.com:8080 \
  --proxy-auth username:password
```

**Includes**:
- Proxy configuration
- Firewall considerations
- Connectivity troubleshooting
- Certificate handling

---

## Custom Model Selection

Deploy only specific models:

```bash
# Deploy only Gemini models
bash scripts/deploy-gateway-config.sh --preset basic \
  --models gemini-2.5-flash,gemini-2.5-pro

# Deploy reasoning and code models
bash scripts/deploy-gateway-config.sh --preset basic \
  --models deepseek-r1,codestral,qwen3-coder-480b
```

**Available Models**:
- `gemini-2.5-flash` - Google Gemini 2.5 Flash (fastest)
- `gemini-2.5-pro` - Google Gemini 2.5 Pro (most capable)
- `deepseek-r1` - DeepSeek R1 (reasoning)
- `llama3-405b` - Meta Llama 3 405B
- `codestral` - Mistral Codestral (code specialized)
- `qwen3-coder-480b` - Qwen 3 Coder 480B
- `qwen3-235b` - Qwen 3 235B
- `gpt-oss-20b` - OpenAI GPT-OSS 20B

---

## Verification Steps

### 1. Check Deployed Files

```bash
ls -la ~/.claude/gateway/
```

**Expected**:
```
drwx------  config/
drwxr-xr-x  templates/
drwxr-xr-x  scripts/
drwxr-xr-x  docs/
drwxr-xr-x  examples/
drwx------  backups/
-rw-------  .env
-rwxr-xr-x  start-gateway.sh
-rw-r--r--  deployment.log
```

### 2. Validate Configuration

```bash
python3 ~/.claude/gateway/scripts/validate-config.py \
  ~/.claude/gateway/config/litellm.yaml
```

**Expected Output**:
```
✓ YAML syntax valid
✓ All required fields present
✓ Model configurations valid
✓ No duplicate model names
Configuration validated successfully
```

### 3. Test Gateway Health

```bash
# Start gateway (if not already running)
bash ~/.claude/gateway/start-gateway.sh &

# Wait for startup (5 seconds)
sleep 5

# Check health
bash ~/.claude/gateway/scripts/health-check.sh http://localhost:4000
```

**Expected Output**:
```
✓ Gateway endpoint reachable
✓ Health check passed
✓ Models endpoint accessible
✓ 8 models available
Gateway is healthy
```

### 4. Test Model Access

```bash
# Configure Claude Code
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$(grep LITELLM_MASTER_KEY ~/.claude/gateway/.env | cut -d= -f2)"

# Test with simple query
claude "What is 2+2?"

# Test with specific model
claude --model gemini-2.5-flash "Explain quantum computing in one sentence"
```

---

## Common Operations

### Update Deployment

Add more models:
```bash
bash scripts/deploy-gateway-config.sh update \
  --add-models llama3-405b,codestral
```

Update gateway URL:
```bash
bash scripts/deploy-gateway-config.sh update \
  --gateway-url https://new-gateway.company.com
```

### View Backups

```bash
bash scripts/deploy-gateway-config.sh list-backups
```

**Output**:
```
📦 Available backups in ~/.claude/gateway/backups/

  1. gateway-backup-20251202-143022.tar.gz (2.3 MB) - 2 hours ago
  2. gateway-backup-20251202-105045.tar.gz (2.1 MB) - 5 hours ago
  3. gateway-backup-20251201-162030.tar.gz (2.0 MB) - 1 day ago

Total: 3 backups (6.4 MB)
```

### Rollback to Previous

```bash
# Rollback to latest backup
bash scripts/deploy-gateway-config.sh rollback latest

# Rollback to specific backup
bash scripts/deploy-gateway-config.sh rollback gateway-backup-20251201-162030.tar.gz
```

### Preview Changes (Dry Run)

```bash
bash scripts/deploy-gateway-config.sh --preset basic \
  --models gemini-2.5-flash \
  --dry-run
```

---

## Troubleshooting

### Issue: Permission Denied

**Error**:
```
❌ Error: Permission denied
   Cannot write to /home/user/.claude directory
```

**Solution**:
```bash
# Create directory with correct permissions
mkdir -p ~/.claude
chmod 700 ~/.claude
```

---

### Issue: LiteLLM Already Running

**Warning**:
```
⚠️  LiteLLM process detected (PID: 12345)
    Continue anyway? [y/N]:
```

**Solution**:
```bash
# Stop existing process
kill 12345
# OR
pkill -f litellm

# Then retry deployment
```

---

### Issue: Invalid YAML Configuration

**Error**:
```
❌ Error: Validation failed
   YAML syntax error in config/litellm.yaml
```

**Solution**:
```bash
# Rollback to last working configuration
bash scripts/deploy-gateway-config.sh rollback latest

# Re-run deployment
bash scripts/deploy-gateway-config.sh --preset basic
```

---

### Issue: Models Not Available

**Error**:
```
❌ Error: Invalid model 'invalid-model'
   Must be one of: gemini-2.5-flash, ...
```

**Solution**:
```bash
# List available models
bash scripts/deploy-gateway-config.sh --help | grep "Available models"

# Use correct model name
bash scripts/deploy-gateway-config.sh --preset basic \
  --models gemini-2.5-flash,gemini-2.5-pro
```

---

### Issue: Gateway Not Responding

**Problem**: Gateway health check fails

**Solution**:
```bash
# Check if gateway is running
ps aux | grep litellm

# Check gateway logs
tail -f ~/litellm.log

# Restart gateway
pkill -f litellm
bash ~/.claude/gateway/start-gateway.sh

# Verify health
bash ~/.claude/gateway/scripts/health-check.sh http://localhost:4000
```

---

## Next Steps

### 1. Explore Documentation

```bash
# Browse deployed documentation
ls ~/.claude/gateway/docs/

# Read configuration reference
cat ~/.claude/gateway/docs/configuration-reference.md

# Read troubleshooting guide
cat ~/.claude/gateway/docs/troubleshooting-guide.md
```

### 2. Try Different Models

```bash
# Test each model
for model in gemini-2.5-flash gemini-2.5-pro deepseek-r1; do
  echo "Testing $model..."
  claude --model $model "Say hello"
done
```

### 3. Monitor Usage

```bash
# View gateway logs
tail -f ~/litellm.log

# Check deployment history
cat ~/.claude/gateway/deployment.log

# Run usage verification
bash ~/.claude/gateway/tests/verify-usage-logging.sh
```

### 4. Customize Configuration

```bash
# Edit active configuration
vi ~/.claude/gateway/config/litellm.yaml

# Validate changes
python3 ~/.claude/gateway/scripts/validate-config.py \
  ~/.claude/gateway/config/litellm.yaml

# Restart gateway to apply
pkill -f litellm && bash ~/.claude/gateway/start-gateway.sh
```

---

## Additional Resources

### Documentation

- **Configuration Reference**: `~/.claude/gateway/docs/configuration-reference.md`
- **Troubleshooting Guide**: `~/.claude/gateway/docs/troubleshooting-guide.md`
- **Security Best Practices**: `~/.claude/gateway/docs/security-best-practices.md`
- **FAQ**: `~/.claude/gateway/docs/faq.md`

### Examples

- **US1 Quick Start**: `~/.claude/gateway/examples/us1-quickstart-basic.md`
- **US2 Enterprise**: `~/.claude/gateway/examples/us2-enterprise-integration.md`
- **US3 Multi-Provider**: `~/.claude/gateway/examples/us3-multi-provider-setup.md`
- **US4 Proxy Setup**: `~/.claude/gateway/examples/us4-corporate-proxy-setup.md`

### Scripts

- **Validate All**: `bash ~/.claude/gateway/scripts/validate-all.sh`
- **Health Check**: `bash ~/.claude/gateway/scripts/health-check.sh <URL>`
- **Check Prerequisites**: `bash ~/.claude/gateway/scripts/check-prerequisites.sh`

---

## Support

### Check Logs

```bash
# Deployment log
cat ~/.claude/gateway/deployment.log

# Gateway runtime logs
tail -f ~/litellm.log

# System logs
journalctl -u litellm  # If running as systemd service
```

### Run Diagnostics

```bash
# Complete validation suite
bash ~/.claude/gateway/scripts/validate-all.sh

# Test all models
python3 ~/.claude/gateway/tests/test-all-models.py
```

### Get Help

```bash
# Show command help
bash scripts/deploy-gateway-config.sh --help

# Check version
bash scripts/deploy-gateway-config.sh --version
```

---

## Clean Up

### Remove Deployment

```bash
# Backup before removal
cp ~/.claude/gateway/.env ~/gateway-env-backup

# Remove deployment
rm -rf ~/.claude/gateway/

# Keep backups (optional)
mkdir -p ~/gateway-backups
mv ~/.claude/gateway/backups/* ~/gateway-backups/
```

### Stop Gateway

```bash
# Find process
ps aux | grep litellm

# Stop gracefully
pkill -SIGTERM -f litellm

# Force stop if needed
pkill -SIGKILL -f litellm
```

---

**Deployment Complete!** 🎉

You now have a fully configured LLM gateway ready to use with Claude Code. Explore the documentation in `~/.claude/gateway/docs/` for advanced configuration options.
