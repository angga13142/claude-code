# Verification Checklist - US1 (Basic LiteLLM Gateway Setup)

**User Story**: US1 - Basic LiteLLM Gateway Setup  
**Purpose**: Step-by-step verification checklist to ensure correct setup  
**Estimated Time**: 5 minutes

---

## How to Use This Checklist

Work through each section sequentially. Each item should be checked off (✓) before proceeding to the next.

**Status Key**:

- ☐ Not checked
- ✓ Verified working
- ✗ Failed (see troubleshooting guide)

---

## 1. Prerequisites

### System Requirements

- [ ] Python 3.9+ installed

  ```bash
  python3 --version  # Should show 3.9.0 or higher
  ```

- [ ] pip/pip3 available

  ```bash
  pip3 --version
  ```

- [ ] Claude Code installed

  ```bash
  claude --version
  ```

- [ ] curl available (for testing)

  ```bash
  curl --version
  ```

**If any fail**: See [Installation Issues](./us1-troubleshooting.md#installation-issues)

---

## 2. Python Dependencies

### Required Packages

- [ ] LiteLLM installed

  ```bash
  python3 -c "import litellm; print(f'✓ LiteLLM {litellm.__version__}')"
  ```

- [ ] Google Cloud AI Platform SDK installed

  ```bash
  python3 -c "import google.cloud.aiplatform; print('✓ GCP SDK installed')"
  ```

- [ ] PyYAML installed

  ```bash
  python3 -c "import yaml; print('✓ PyYAML installed')"
  ```

- [ ] litellm command available

  ```bash
  litellm --version  # Or: python3 -m litellm --version
  ```

**If any fail**: Run `pip3 install litellm google-cloud-aiplatform pyyaml`

---

## 3. Google Cloud Setup

### GCP Project

- [ ] GCP project exists and is accessible

  ```bash
  gcloud config get-value project  # Should output your project ID
  ```

- [ ] Billing is enabled

  ```bash
  gcloud beta billing projects describe $(gcloud config get-value project)
  ```

- [ ] Vertex AI API is enabled

  ```bash
  gcloud services list --enabled | grep aiplatform.googleapis.com
  ```

**If any fail**: See [gcloud Auth Guide](./us1-gcloud-auth.md)

### Authentication

Choose ONE method and verify:

#### Option A: gcloud Auth

- [ ] gcloud CLI installed

  ```bash
  gcloud --version
  ```

- [ ] Application Default Credentials configured

  ```bash
  gcloud auth application-default print-access-token | head -c 20
  ```

- [ ] Default project set

  ```bash
  gcloud config list
  ```

#### Option B: Service Account

- [ ] Service account key file exists

  ```bash
  ls -lh $GOOGLE_APPLICATION_CREDENTIALS
  ```

- [ ] Key file has secure permissions (600)

  ```bash
  stat -c "%a" $GOOGLE_APPLICATION_CREDENTIALS  # Should show 600
  ```

- [ ] Key file is valid JSON

  ```bash
  cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email
  ```

- [ ] Service account has Vertex AI User role

  ```bash
  SA_EMAIL=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq -r .client_email)
  gcloud projects get-iam-policy $(gcloud config get-value project) \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL" | grep aiplatform.user
  ```

**If any fail**: See [Authentication Issues](./us1-troubleshooting.md#authentication-issues)

---

## 4. LiteLLM Configuration

### Configuration File

- [ ] Configuration file exists

  ```bash
  ls -lh ~/litellm-config.yaml
  ```

- [ ] No placeholder "YOUR_PROJECT_ID" remains

  ```bash
  ! grep -q "YOUR_PROJECT_ID" ~/litellm-config.yaml && echo "✓ No placeholders" || echo "✗ Placeholders found"
  ```

- [ ] Configuration is valid YAML

  ```bash
  python3 -c "import yaml; yaml.safe_load(open('$HOME/litellm-config.yaml'))" && echo "✓ Valid YAML"
  ```

- [ ] Configuration passes validation

  ```bash
  cd specs/001-llm-gateway-config
  python3 scripts/validate-config.py ~/litellm-config.yaml
  ```

- [ ] All 8 models are configured

  ```bash
  grep "model_name:" ~/litellm-config.yaml | wc -l  # Should show 8
  ```

**If any fail**: See [Configuration Issues](./us1-troubleshooting.md#configuration-issues)

---

## 5. Environment Variables

### Required Variables

- [ ] LITELLM_MASTER_KEY is set

  ```bash
  [ -n "$LITELLM_MASTER_KEY" ] && echo "✓ Set: ${LITELLM_MASTER_KEY:0:8}..." || echo "✗ Not set"
  ```

- [ ] ANTHROPIC_BASE_URL is set to gateway

  ```bash
  [ "$ANTHROPIC_BASE_URL" = "http://localhost:4000" ] && echo "✓ Correct" || echo "✗ Wrong: $ANTHROPIC_BASE_URL"
  ```

- [ ] ANTHROPIC_AUTH_TOKEN matches LITELLM_MASTER_KEY

  ```bash
  [ "$ANTHROPIC_AUTH_TOKEN" = "$LITELLM_MASTER_KEY" ] && echo "✓ Tokens match" || echo "✗ Tokens don't match"
  ```

### Optional Variables (for service account)

- [ ] GOOGLE_APPLICATION_CREDENTIALS is set (if using service account)

  ```bash
  [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && echo "✓ Set" || echo "Using gcloud auth"
  ```

**If any fail**: See [Environment Variables Setup](./us1-env-vars-setup.md)

---

## 6. LiteLLM Gateway

### Gateway Process

- [ ] LiteLLM is running

  ```bash
  ps aux | grep -v grep | grep litellm
  ```

- [ ] Port 4000 is listening

  ```bash
  lsof -i :4000 || netstat -an | grep :4000
  ```

**If any fail**: Start gateway with `./scripts/start-litellm-proxy.sh`

### Gateway Health

- [ ] Health endpoint responds

  ```bash
  curl -s http://localhost:4000/health | jq .
  ```

- [ ] Gateway reports "healthy" status

  ```bash
  curl -s http://localhost:4000/health | jq -r '.status' | grep -q "healthy" && echo "✓ Healthy"
  ```

- [ ] Models endpoint is accessible

  ```bash
  curl -s http://localhost:4000/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq '.data | length'
  ```

- [ ] All 8 models are listed

  ```bash
  MODEL_COUNT=$(curl -s http://localhost:4000/models -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq '.data | length')
  [ "$MODEL_COUNT" = "8" ] && echo "✓ All 8 models" || echo "✗ Only $MODEL_COUNT models"
  ```

**If any fail**: See [Gateway Startup Issues](./us1-troubleshooting.md#gateway-startup-issues)

---

## 7. Model Testing

### Individual Model Tests

Test at least 2 models (one fast, one large):

- [ ] Gemini 2.5 Flash responds

  ```bash
  curl -s http://localhost:4000/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -d '{"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}' \
    | jq -r '.choices[0].message.content'
  ```

- [ ] Llama3 405B responds

  ```bash
  curl -s http://localhost:4000/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -d '{"model":"llama3-405b","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}' \
    | jq -r '.choices[0].message.content'
  ```

### Automated Test Suite

- [ ] All models test passes

  ```bash
  cd specs/001-llm-gateway-config
  python3 tests/test-all-models.py
  # Should show: "✓ All models working correctly!"
  ```

- [ ] No model errors reported

  ```bash
  python3 tests/test-all-models.py | grep -q "Errors: 0"
  ```

**If any fail**: See [Model Access Issues](./us1-troubleshooting.md#model-access-issues)

---

## 8. Claude Code Integration

### Configuration Check

- [ ] Claude Code sees gateway URL

  ```bash
  cd specs/001-llm-gateway-config
  ./scripts/check-status.sh | grep "ANTHROPIC_BASE_URL is set"
  ```

- [ ] Claude Code authentication configured

  ```bash
  ./scripts/check-status.sh | grep "ANTHROPIC_AUTH_TOKEN is set"
  ```

- [ ] Gateway is reachable from Claude Code's perspective

  ```bash
  ./scripts/check-status.sh | grep "Gateway is reachable"
  ```

### End-to-End Test

- [ ] Claude Code can execute commands

  ```bash
  claude "Say hello in one word"
  # Should respond through gateway
  ```

- [ ] Claude Code status shows gateway URL

  ```bash
  claude /status
  # Should show: Base URL: http://localhost:4000
  ```

**If any fail**: See [Claude Code Integration Issues](./us1-troubleshooting.md#claude-code-integration-issues)

---

## 9. Usage Logging

### Logging Verification

- [ ] Usage logging is functional

  ```bash
  cd specs/001-llm-gateway-config
  ./tests/verify-usage-logging.sh
  ```

- [ ] Test request was logged

  ```bash
  curl -s http://localhost:4000/spend/logs \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq 'length'
  # Should show > 0
  ```

**Note**: Database logging is optional for basic setup. In-memory logging is sufficient.

---

## 10. Performance Verification

### Latency Check

- [ ] Fast model responds quickly (<1 second)

  ```bash
  time curl -s http://localhost:4000/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -d '{"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Hi"}],"max_tokens":5}' \
    > /dev/null
  # Should complete in < 1 second
  ```

- [ ] No timeout errors

  ```bash
  python3 tests/test-all-models.py --json | jq -r '.results[] | select(.status=="error") | .error' | grep -v timeout
  ```

**If slow**: See [Performance Issues](./us1-troubleshooting.md#performance-issues)

---

## Summary Check

Run automated verification:

```bash
cd specs/001-llm-gateway-config

# Run all checks
echo "=== Prerequisites ==="
./scripts/check-prerequisites.sh

echo ""
echo "=== Configuration Status ==="
./scripts/check-status.sh

echo ""
echo "=== Gateway Health ==="
./scripts/health-check.sh

echo ""
echo "=== Model Testing ==="
python3 tests/test-all-models.py
```

**Expected**: All checks should pass with ✓ symbols.

---

## Completion Criteria

To consider US1 setup complete, ALL of the following must be true:

- ✓ All prerequisite checks pass
- ✓ LiteLLM gateway is running and healthy
- ✓ At least 6 out of 8 models respond successfully
- ✓ Claude Code is configured and routing through gateway
- ✓ End-to-end test passes

**If all criteria met**: ✅ **Setup Complete!** You can now use Claude Code with 8 Vertex AI models.

---

## Next Steps

Once verified:

1. **Save your configuration**:

   ```bash
   # Backup working config
   cp ~/litellm-config.yaml ~/litellm-config-working.yaml
   
   # Save environment variables
   cat > ~/.litellm.env << EOF
   export LITELLM_MASTER_KEY="$LITELLM_MASTER_KEY"
   export ANTHROPIC_BASE_URL="http://localhost:4000"
   export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
   EOF
   ```

2. **Automate startup** (optional):

   ```bash
   # Add to ~/.bashrc
   echo "source ~/.litellm.env" >> ~/.bashrc
   
   # Create systemd service (Linux) or launchd (macOS) for auto-start
   ```

3. **Explore advanced features**:
   - Enable database logging for persistence
   - Configure fallback routes
   - Set up rate limiting per model
   - Add more providers (Anthropic, Bedrock)

---

## Troubleshooting

If any checks fail, refer to:

- [Troubleshooting Guide](./us1-troubleshooting.md) - Detailed solutions
- [Environment Variables Setup](./us1-env-vars-setup.md) - Configuration help
- [gcloud Auth Guide](./us1-gcloud-auth.md) - Authentication help
- [Quickstart Guide](./us1-quickstart-basic.md) - Setup walkthrough

---

## Related Documentation

- [Quickstart Guide](./us1-quickstart-basic.md)
- [Troubleshooting Guide](./us1-troubleshooting.md)
- [Environment Variables Reference](../templates/env-vars-reference.md)
- [Deployment Patterns](../templates/deployment-patterns.md)
