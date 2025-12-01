# Troubleshooting Guide - US1 (Basic LiteLLM Gateway Setup)

**User Story**: US1 - Basic LiteLLM Gateway Setup  
**Purpose**: Solutions for common setup and runtime issues  
**Last Updated**: 2025-12-01

---

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Authentication Issues](#authentication-issues)
3. [Configuration Issues](#configuration-issues)
4. [Gateway Startup Issues](#gateway-startup-issues)
5. [Model Access Issues](#model-access-issues)
6. [Claude Code Integration Issues](#claude-code-integration-issues)
7. [Performance Issues](#performance-issues)
8. [Debugging Tips](#debugging-tips)

---

## Installation Issues

### Issue: "pip: command not found"

**Symptoms**:
```bash
$ pip install litellm
bash: pip: command not found
```

**Solutions**:

1. **Try pip3** (Python 3 specific):
   ```bash
   pip3 install litellm google-cloud-aiplatform
   ```

2. **Install pip**:
   ```bash
   # Ubuntu/Debian
   sudo apt install python3-pip
   
   # macOS
   brew install python3  # Includes pip
   
   # Windows
   # Download get-pip.py from https://bootstrap.pypa.io/get-pip.py
   python get-pip.py
   ```

3. **Use Python module**:
   ```bash
   python3 -m pip install litellm google-cloud-aiplatform
   ```

### Issue: "Permission denied" during pip install

**Symptoms**:
```bash
ERROR: Could not install packages due to an OSError: [Errno 13] Permission denied
```

**Solutions**:

1. **Use --user flag** (recommended):
   ```bash
   pip3 install --user litellm google-cloud-aiplatform
   ```

2. **Use virtual environment** (best practice):
   ```bash
   python3 -m venv ~/.venv/litellm
   source ~/.venv/litellm/bin/activate
   pip install litellm google-cloud-aiplatform
   ```

3. **Use sudo** (not recommended):
   ```bash
   sudo pip3 install litellm google-cloud-aiplatform
   ```

### Issue: "litellm: command not found" after installation

**Symptoms**:
```bash
$ litellm --version
bash: litellm: command not found
```

**Solutions**:

1. **Check installation location**:
   ```bash
   pip3 show litellm | grep Location
   # Output: Location: /home/user/.local/lib/python3.9/site-packages
   ```

2. **Add to PATH**:
   ```bash
   # Find where pip installs scripts
   python3 -m site --user-base
   # Example output: /home/user/.local
   
   # Add to PATH (add to ~/.bashrc for persistence)
   export PATH="$PATH:/home/user/.local/bin"
   ```

3. **Run with Python module**:
   ```bash
   python3 -m litellm --version
   ```

---

## Authentication Issues

### Issue: "Could not automatically determine credentials"

**Symptoms**:
```
google.auth.exceptions.DefaultCredentialsError: Could not automatically determine credentials
```

**Diagnosis**:
```bash
# Check if credentials are set
echo $GOOGLE_APPLICATION_CREDENTIALS
# If empty, authentication is not configured

# Check if gcloud auth is configured
gcloud auth application-default print-access-token
```

**Solutions**:

1. **Use gcloud auth**:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Use service account**:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
   ```

3. **Verify credentials file**:
   ```bash
   cat $GOOGLE_APPLICATION_CREDENTIALS | jq .
   # Should show valid JSON with client_email, project_id, etc.
   ```

### Issue: "403 Permission Denied" for Vertex AI

**Symptoms**:
```
403 Permission Denied: User does not have permission to access model
```

**Diagnosis**:
```bash
# Check which account is authenticated
gcloud auth list

# Check IAM permissions
gcloud projects get-iam-policy $(gcloud config get-value project) \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)"
```

**Solutions**:

1. **Grant Vertex AI User role**:
   ```bash
   PROJECT_ID=$(gcloud config get-value project)
   ACCOUNT=$(gcloud config get-value account)
   
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="user:$ACCOUNT" \
     --role="roles/aiplatform.user"
   ```

2. **For service accounts**:
   ```bash
   SA_EMAIL=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq -r .client_email)
   
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:$SA_EMAIL" \
     --role="roles/aiplatform.user"
   ```

3. **Verify API is enabled**:
   ```bash
   gcloud services enable aiplatform.googleapis.com
   ```

### Issue: "401 Unauthorized" when calling LiteLLM gateway

**Symptoms**:
```bash
$ curl http://localhost:4000/models
{"error": "Unauthorized"}
```

**Diagnosis**:
```bash
# Check if master key is set
echo "Master key: ${LITELLM_MASTER_KEY:0:10}..."

# Check if tokens match
[ "$ANTHROPIC_AUTH_TOKEN" = "$LITELLM_MASTER_KEY" ] && echo "Match!" || echo "Mismatch!"
```

**Solutions**:

1. **Set master key**:
   ```bash
   export LITELLM_MASTER_KEY="sk-$(openssl rand -hex 16)"
   ```

2. **Ensure tokens match**:
   ```bash
   export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
   ```

3. **Restart LiteLLM** with correct key:
   ```bash
   # Stop current instance (Ctrl+C or kill process)
   pkill -f litellm
   
   # Start with correct environment
   litellm --config ~/litellm-config.yaml --port 4000
   ```

---

## Configuration Issues

### Issue: "YOUR_PROJECT_ID" not replaced in config

**Symptoms**:
```
Error: Invalid project ID: YOUR_PROJECT_ID
```

**Diagnosis**:
```bash
# Check config file
grep "YOUR_PROJECT_ID" ~/litellm-config.yaml
# If this finds matches, placeholders weren't replaced
```

**Solutions**:

1. **Find your project ID**:
   ```bash
   gcloud config get-value project
   ```

2. **Replace in config**:
   ```bash
   # Using sed (Linux/Mac)
   sed -i 's/YOUR_PROJECT_ID/your-actual-project-id/g' ~/litellm-config.yaml
   
   # Using sed (Mac - requires empty string after -i)
   sed -i '' 's/YOUR_PROJECT_ID/your-actual-project-id/g' ~/litellm-config.yaml
   
   # Manual edit
   nano ~/litellm-config.yaml  # or vi, code, etc.
   ```

3. **Validate config**:
   ```bash
   python3 scripts/validate-config.py ~/litellm-config.yaml
   ```

### Issue: "YAML syntax error" when starting LiteLLM

**Symptoms**:
```
yaml.scanner.ScannerError: while scanning for the next token
```

**Diagnosis**:
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('~/litellm-config.yaml'))"
```

**Solutions**:

1. **Common YAML mistakes**:
   ```yaml
   # ❌ BAD: Mixed tabs and spaces
   model_list:
   	- model_name: test  # Tab character
   
   # ✅ GOOD: Consistent spacing (2 or 4 spaces)
   model_list:
     - model_name: test  # 2 spaces
   
   # ❌ BAD: Missing quotes for special characters
   master_key: sk-test:value
   
   # ✅ GOOD: Quote strings with special chars
   master_key: "sk-test:value"
   ```

2. **Use online validator**:
   - Copy config to https://www.yamllint.com/
   - Fix reported errors

3. **Use validation script**:
   ```bash
   python3 scripts/validate-config.py ~/litellm-config.yaml
   ```

---

## Gateway Startup Issues

### Issue: "Address already in use" on port 4000

**Symptoms**:
```
OSError: [Errno 48] Address already in use
```

**Diagnosis**:
```bash
# Check what's using port 4000
lsof -i :4000
# OR
netstat -an | grep 4000
```

**Solutions**:

1. **Kill existing process**:
   ```bash
   # Find process ID
   lsof -ti :4000
   
   # Kill it
   kill $(lsof -ti :4000)
   
   # Or force kill
   kill -9 $(lsof -ti :4000)
   ```

2. **Use different port**:
   ```bash
   litellm --config ~/litellm-config.yaml --port 4001
   
   # Update Claude Code
   export ANTHROPIC_BASE_URL="http://localhost:4001"
   ```

3. **Check for zombie processes**:
   ```bash
   ps aux | grep litellm
   pkill -f litellm
   ```

### Issue: Gateway starts but immediately exits

**Symptoms**:
```bash
$ litellm --config ~/litellm-config.yaml
INFO:     Started server process
[Process exits]
```

**Diagnosis**:
```bash
# Run with debug logging
export LITELLM_LOG=DEBUG
litellm --config ~/litellm-config.yaml --port 4000
```

**Common Causes & Solutions**:

1. **Missing environment variables**:
   ```bash
   # Check required vars
   echo $LITELLM_MASTER_KEY
   echo $GOOGLE_APPLICATION_CREDENTIALS  # If using service account
   ```

2. **Invalid configuration**:
   ```bash
   python3 scripts/validate-config.py ~/litellm-config.yaml
   ```

3. **Python version too old**:
   ```bash
   python3 --version  # Must be 3.9+
   ```

---

## Model Access Issues

### Issue: "Model not found" when testing

**Symptoms**:
```
{"error": "Model 'gemini-2.5-flash' not found"}
```

**Diagnosis**:
```bash
# List configured models
curl http://localhost:4000/models | jq '.data[].id'
```

**Solutions**:

1. **Check model name spelling**:
   ```bash
   # Correct model names from config
   grep "model_name:" ~/litellm-config.yaml
   ```

2. **Verify model is in config**:
   ```bash
   grep -A 5 "gemini-2.5-flash" ~/litellm-config.yaml
   ```

3. **Restart gateway** after config changes:
   ```bash
   pkill -f litellm
   litellm --config ~/litellm-config.yaml --port 4000
   ```

### Issue: "Model not available in region"

**Symptoms**:
```
404 Not Found: Model not available in us-central1
```

**Solutions**:

1. **Try different region**:
   ```yaml
   # In litellm-config.yaml
   vertex_location: us-east1  # Try different regions
   ```

2. **Check model availability**:
   ```bash
   python3 scripts/check-model-availability.py --location us-central1
   ```

3. **Verify Model Garden access**:
   - Open GCP Console
   - Navigate to Vertex AI > Model Garden
   - Check if model is available in your region

---

## Claude Code Integration Issues

### Issue: Claude Code still using Anthropic API

**Symptoms**:
```bash
$ claude /status
Base URL: https://api.anthropic.com  # Should be http://localhost:4000
```

**Diagnosis**:
```bash
# Check environment variables
echo "Base URL: $ANTHROPIC_BASE_URL"
echo "Auth Token: ${ANTHROPIC_AUTH_TOKEN:0:10}..."
```

**Solutions**:

1. **Set environment variables**:
   ```bash
   export ANTHROPIC_BASE_URL="http://localhost:4000"
   export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"
   ```

2. **Restart Claude Code**:
   ```bash
   # If running as daemon/service, restart it
   pkill claude
   claude /status
   ```

3. **Check settings file**:
   ```bash
   cat ~/.claude/settings.json
   # Should NOT have ANTHROPIC_BASE_URL set there
   # Or it should match localhost:4000
   ```

### Issue: "Connection refused" from Claude Code

**Symptoms**:
```
Error: Connection refused at http://localhost:4000
```

**Diagnosis**:
```bash
# Test gateway directly
curl http://localhost:4000/health
```

**Solutions**:

1. **Ensure gateway is running**:
   ```bash
   ps aux | grep litellm
   # If not running, start it
   litellm --config ~/litellm-config.yaml --port 4000
   ```

2. **Check URL format**:
   ```bash
   # Must use http:// (not https://)
   export ANTHROPIC_BASE_URL="http://localhost:4000"
   ```

3. **Test connectivity**:
   ```bash
   curl -v http://localhost:4000/health
   ```

---

## Performance Issues

### Issue: Slow response times (>5 seconds)

**Diagnosis**:
```bash
# Test individual model latency
time curl http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hi"}],
    "max_tokens": 10
  }'
```

**Solutions**:

1. **Check internet connection**:
   ```bash
   ping -c 3 google.com
   ```

2. **Verify GCP region** (use closer region):
   ```yaml
   vertex_location: us-central1  # Try region closest to you
   ```

3. **Reduce max_tokens** in requests:
   ```json
   {"max_tokens": 100}  # Instead of 1000+
   ```

4. **Use faster models**:
   - gemini-2.5-flash (fastest)
   - codestral (fast for code)
   - Avoid large models for simple tasks

### Issue: High memory usage

**Diagnosis**:
```bash
# Check LiteLLM memory usage
ps aux | grep litellm
```

**Solutions**:

1. **Enable request streaming**:
   ```json
   {"stream": true}
   ```

2. **Reduce concurrent requests** (add rate limiting in config):
   ```yaml
   rpm: 30  # Requests per minute
   ```

3. **Restart gateway periodically** (for long-running instances)

---

## Debugging Tips

### Enable Debug Logging

**LiteLLM debug mode**:
```bash
export LITELLM_LOG=DEBUG
litellm --config ~/litellm-config.yaml --port 4000
```

**Claude Code debug mode**:
```bash
export ANTHROPIC_LOG=debug
claude "test"
```

### View LiteLLM Logs

```bash
# Run in foreground to see logs
litellm --config ~/litellm-config.yaml --port 4000

# Or redirect to file
litellm --config ~/litellm-config.yaml --port 4000 > litellm.log 2>&1 &
tail -f litellm.log
```

### Test Gateway Manually

```bash
# Health check
curl http://localhost:4000/health | jq .

# List models
curl http://localhost:4000/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq .

# Test completion
curl http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }' | jq .
```

### Use Automated Diagnostics

```bash
cd specs/001-llm-gateway-config

# Run all checks
./scripts/check-prerequisites.sh
./scripts/check-status.sh
./scripts/health-check.sh

# Run test suite
python3 tests/test-all-models.py
```

---

## Getting Help

If none of these solutions work:

1. **Check LiteLLM documentation**: https://docs.litellm.ai/
2. **Review error logs** with DEBUG mode enabled
3. **Run diagnostic scripts** in `scripts/` directory
4. **Check GitHub issues**: https://github.com/BerriAI/litellm/issues
5. **Consult**:
   - [Verification Checklist](./us1-verification-checklist.md)
   - [Environment Variables Reference](../templates/env-vars-reference.md)
   - [gcloud Auth Guide](./us1-gcloud-auth.md)

---

## Related Documentation

- [Quickstart Guide](./us1-quickstart-basic.md)
- [Verification Checklist](./us1-verification-checklist.md)
- [Environment Variables Setup](./us1-env-vars-setup.md)
- [Deployment Patterns](../templates/deployment-patterns.md)
