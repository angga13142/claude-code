# US1 Quickstart: Basic LiteLLM Gateway Setup

**Time Required**: 10-15 minutes  
**Difficulty**: Intermediate  
**Target Audience**: Developers with YAML, CLI, and cloud basics

---

## Overview

This guide walks you through setting up a local LiteLLM proxy with 8 Vertex AI models and configuring Claude Code to use it.

**What you'll achieve**:

- ✅ LiteLLM proxy running with 8 Vertex AI models
- ✅ Claude Code routing requests through the gateway
- ✅ Usage tracking and cost monitoring
- ✅ End-to-end verification

---

## Prerequisites

Before starting, ensure you have:

- [ ] **Python 3.9+** installed (`python3 --version`)
- [ ] **pip** package manager (`pip3 --version`)
- [ ] **Claude Code** installed (`claude --version`)
- [ ] **Google Cloud Project** with billing enabled
- [ ] **Vertex AI API** enabled in your GCP project
- [ ] **10-15 minutes** of focused time

**Run automated check**:

```bash
cd specs/001-llm-gateway-config
./scripts/check-prerequisites.sh
```

---

## Step 1: Install Dependencies (2 minutes)

```bash
# Install LiteLLM and Google Cloud SDK
pip install litellm google-cloud-aiplatform pyyaml

# Verify installation
litellm --version
python3 -c "import google.cloud.aiplatform; print('✓ GCP SDK installed')"
```

**Troubleshooting**:

- If `pip` not found: Use `pip3` instead
- If permission denied: Add `--user` flag: `pip install --user litellm`

---

## Step 2: Authenticate with Google Cloud (3 minutes)

**Choose ONE option:**

### Option A: gcloud Auth (Recommended for Development)

```bash
# Authenticate with your Google account
gcloud auth application-default login

# Set your default project
gcloud config set project YOUR_PROJECT_ID

# Verify authentication
gcloud auth application-default print-access-token | head -c 20
```

### Option B: Service Account (Recommended for Production)

```bash
# Download service account key from GCP Console
# Save as: ~/litellm-sa-key.json

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/litellm-sa-key.json

# Secure the file
chmod 600 ~/litellm-sa-key.json

# Verify
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email
```

---

## Step 3: Configure LiteLLM (3 minutes)

### Copy and customize configuration

```bash
# Navigate to the templates directory
cd specs/001-llm-gateway-config/templates

# Copy the complete configuration
cp litellm-complete.yaml ~/litellm-config.yaml

# Edit with your project ID
nano ~/litellm-config.yaml
# OR
vi ~/litellm-config.yaml
# OR
code ~/litellm-config.yaml
```

### Replace placeholders

Find and replace `YOUR_PROJECT_ID` with your actual GCP project ID:

```yaml
# Before:
vertex_project: YOUR_PROJECT_ID

# After (example):
vertex_project: my-gcp-project-123
```

**Quick replace** (Linux/Mac):

```bash
sed -i 's/YOUR_PROJECT_ID/my-gcp-project-123/g' ~/litellm-config.yaml
```

**Validate configuration**:

```bash
cd specs/001-llm-gateway-config
python3 scripts/validate-config.py ~/litellm-config.yaml
```

---

## Step 4: Set Environment Variables (2 minutes)

### Generate and set master key

```bash
# Generate a secure master key
export LITELLM_MASTER_KEY="sk-$(openssl rand -hex 16)"

# Display it (save this somewhere secure!)
echo "Your master key: $LITELLM_MASTER_KEY"
```

**IMPORTANT**: Save this key! You'll need it to configure Claude Code.

### Configure Claude Code

```bash
# Point Claude Code to local gateway
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
```

### Make environment variables persistent

**Option 1: .env file (recommended)**

```bash
# Create .env file
cat > ~/.litellm.env << EOF
export LITELLM_MASTER_KEY="$LITELLM_MASTER_KEY"
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
EOF

# Load it
source ~/.litellm.env

# Add to shell profile for automatic loading
echo "source ~/.litellm.env" >> ~/.bashrc  # or ~/.zshrc
```

**Option 2: Add to shell profile directly**

```bash
echo "export LITELLM_MASTER_KEY=\"$LITELLM_MASTER_KEY\"" >> ~/.bashrc
echo "export ANTHROPIC_BASE_URL=\"http://localhost:4000\"" >> ~/.bashrc
echo "export ANTHROPIC_AUTH_TOKEN=\"$LITELLM_MASTER_KEY\"" >> ~/.bashrc
source ~/.bashrc
```

---

## Step 5: Start LiteLLM Gateway (1 minute)

### Start the gateway

```bash
cd specs/001-llm-gateway-config

# Start with validation
./scripts/start-litellm-proxy.sh ~/litellm-config.yaml 4000
```

**Expected output**:

```
========================================
LiteLLM Proxy Startup
========================================

✓ Configuration file: /home/user/litellm-config.yaml
✓ Port: 4000
✓ LITELLM_MASTER_KEY is set
✓ Using gcloud application-default credentials
✓ Configuration is valid

Starting LiteLLM proxy...

INFO:     Started server process
INFO:     Uvicorn running on http://0.0.0.0:4000
```

**Keep this terminal open** - LiteLLM is running!

---

## Step 6: Verify Setup (3 minutes)

### Open a new terminal and run verification

```bash
cd specs/001-llm-gateway-config

# Check Claude Code configuration
./scripts/check-status.sh
```

**Expected output**:

```
✓ Claude Code is installed
✓ ANTHROPIC_BASE_URL is set
✓ ANTHROPIC_AUTH_TOKEN is set
✓ Gateway is reachable at http://localhost:4000
✓ Configuration looks complete!
```

### Check gateway health

```bash
./scripts/health-check.sh
```

**Expected output**:

```
✓ Gateway is reachable
✓ Health endpoint returned 200 OK
✓ Gateway status: healthy
✓ Found 8 configured model(s)

  Configured models:
    - gemini-2.5-flash
    - gemini-2.5-pro
    - deepseek-r1
    - llama3-405b
    - codestral
    - qwen3-coder-480b
    - qwen3-235b
    - gpt-oss-20b

✓ Gateway health check passed!
```

---

## Step 7: Test Models (2-3 minutes)

### Test individual model

```bash
# Test Gemini 2.5 Flash (fastest)
curl http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Say hello in one word"}],
    "max_tokens": 10
  }'
```

### Run automated test suite

```bash
cd specs/001-llm-gateway-config
python3 tests/test-all-models.py
```

**Expected output**:

```
======================================================================
End-to-End Model Testing
======================================================================

Gateway URL: http://localhost:4000
Testing 8 models...

[1/8] Testing gemini-2.5-flash... ✓ 450ms
[2/8] Testing gemini-2.5-pro... ✓ 620ms
[3/8] Testing deepseek-r1... ✓ 890ms
[4/8] Testing llama3-405b... ✓ 1200ms
[5/8] Testing codestral... ✓ 780ms
[6/8] Testing qwen3-coder-480b... ✓ 1100ms
[7/8] Testing qwen3-235b... ✓ 950ms
[8/8] Testing gpt-oss-20b... ✓ 650ms

======================================================================
Summary
======================================================================
Total models: 8
Successful: 8
Errors: 0

✓ All models working correctly!
```

---

## Step 8: Use with Claude Code (1 minute)

### Test with Claude Code CLI

```bash
# Simple test
claude "Hello! What model are you?"

# Check routing through gateway
claude /status
```

**Expected**: Claude Code should show it's using `http://localhost:4000` as the base URL.

### Verify usage tracking

```bash
cd specs/001-llm-gateway-config
./tests/verify-usage-logging.sh
```

---

## Success! 🎉

You now have:

- ✅ LiteLLM gateway running with 8 Vertex AI models
- ✅ Claude Code configured to use the gateway
- ✅ All models tested and working
- ✅ Usage tracking enabled

---

## Common Issues & Solutions

### Issue: "Connection refused" on http://localhost:4000

**Solution**:

```bash
# Check if LiteLLM is running
ps aux | grep litellm

# If not running, start it
cd specs/001-llm-gateway-config
./scripts/start-litellm-proxy.sh ~/litellm-config.yaml
```

### Issue: "403 Forbidden" for Vertex AI models

**Solution**:

```bash
# Re-authenticate with gcloud
gcloud auth application-default login

# Verify authentication
gcloud auth application-default print-access-token
```

### Issue: "YOUR_PROJECT_ID" not replaced

**Solution**:

```bash
# Verify your project ID
gcloud config get-value project

# Replace in config
sed -i 's/YOUR_PROJECT_ID/your-actual-project-id/g' ~/litellm-config.yaml

# Restart LiteLLM
```

### Issue: "Unauthorized" when calling gateway

**Solution**:

```bash
# Verify tokens match
echo "LiteLLM Key: ${LITELLM_MASTER_KEY:0:10}..."
echo "Claude Token: ${ANTHROPIC_AUTH_TOKEN:0:10}..."

# They should be identical - if not, fix it:
export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
```

---

## Next Steps

### Enable Request Logging (Optional)

For production use, enable database logging:

```bash
# Install PostgreSQL (if needed)
# Set up database
createdb litellm_logs

# Configure database URL
export DATABASE_URL="postgresql://user:password@localhost:5432/litellm_logs"

# Restart LiteLLM
```

### Explore Advanced Features

- **Load Balancing**: Configure fallback routes
- **Rate Limiting**: Set per-model limits
- **Cost Tracking**: Analyze usage patterns
- **Multi-Provider**: Add Anthropic, Bedrock models

See [Advanced Configuration Guide](../templates/litellm-complete.yaml) for details.

---

## Cleanup

To stop the gateway:

```bash
# In the terminal running LiteLLM, press Ctrl+C

# Or find and kill the process
lsof -ti:4000 | xargs kill
```

To remove configuration:

```bash
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset LITELLM_MASTER_KEY
```

---

## Related Documentation

- [Environment Variables Setup](./us1-env-vars-setup.md)
- [gcloud Authentication Guide](./us1-gcloud-auth.md)
- [Troubleshooting Guide](./us1-troubleshooting.md)
- [Verification Checklist](./us1-verification-checklist.md)
- [Deployment Patterns](../templates/deployment-patterns.md)
