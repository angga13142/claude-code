# Quickstart Guide: LLM Gateway Configuration Assistant

**Feature**: 001-llm-gateway-config  
**Target Audience**: Developers configuring Claude Code with LiteLLM gateway  
**Estimated Time**: 10-15 minutes  
**Date**: 2025-12-01

---

## 🎯 What You'll Build

By the end of this guide, you'll have:
- ✅ LiteLLM proxy running locally with 8 Vertex AI Model Garden models
- ✅ Claude Code configured to route requests through the gateway
- ✅ Verification that everything works end-to-end

---

## 📋 Prerequisites

Before starting, ensure you have:

- [ ] **Python 3.9+** installed (`python --version`)
- [ ] **Google Cloud Project** with billing enabled
- [ ] **Vertex AI API** enabled (visit [console.cloud.google.com](https://console.cloud.google.com))
- [ ] **gcloud CLI** installed and authenticated
- [ ] **Claude Code** installed (`claude --version`)
- [ ] **10 minutes** of focused time

**GCP Information Needed:**
- Project ID: `_________________`
- Preferred Region: `_________________` (e.g., us-central1)

---

## 🚀 Step 1: Install LiteLLM

```bash
# Install LiteLLM and dependencies
pip install litellm google-cloud-aiplatform

# Verify installation
litellm --version
# Expected output: litellm, version 1.x.x
```

**Troubleshooting:**
- If `pip` not found: Install Python from python.org
- If permission denied: Use `pip install --user litellm`

---

## 🔐 Step 2: Authenticate with Google Cloud

Choose ONE authentication method:

### Option A: gcloud Auth (Recommended for Development)

```bash
# Authenticate with your Google account
gcloud auth application-default login

# Set your default project
gcloud config set project YOUR_PROJECT_ID

# Verify authentication
gcloud auth application-default print-access-token
# Should output a long token string
```

### Option B: Service Account (Recommended for Production)

```bash
# Create service account
gcloud iam service-accounts create litellm-sa \
  --display-name="LiteLLM Service Account"

# Grant Vertex AI User role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:litellm-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Create and download key
gcloud iam service-accounts keys create ~/litellm-sa-key.json \
  --iam-account=litellm-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/litellm-sa-key.json
```

---

## 📝 Step 3: Create LiteLLM Configuration

Create a file named `litellm_config.yaml`:

```yaml
# litellm_config.yaml - Complete configuration for 8 Vertex AI models

model_list:
  # ===== GOOGLE GEMINI MODELS =====
  - model_name: gemini-2.5-flash
    litellm_params:
      model: vertex_ai/gemini-2.5-flash
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-central1"      # ← CHANGE IF NEEDED
    tpm: 1000000  # 1M tokens per minute
    rpm: 10000    # 10K requests per minute

  - model_name: gemini-2.5-pro
    litellm_params:
      model: vertex_ai/gemini-2.5-pro
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-central1"
    tpm: 500000
    rpm: 5000

  # ===== DEEPSEEK REASONING MODEL =====
  - model_name: deepseek-r1
    litellm_params:
      model: vertex_ai/deepseek-ai/deepseek-r1-0528-maas
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-central1"
    tpm: 100000
    rpm: 1000

  # ===== META LLAMA MODEL =====
  - model_name: llama3-405b
    litellm_params:
      model: vertex_ai/meta/llama3-405b-instruct-maas
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-east1"         # Some models prefer different regions
    tpm: 200000
    rpm: 2000

  # ===== MISTRAL CODESTRAL =====
  - model_name: codestral
    litellm_params:
      model: vertex_ai/codestral@latest
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-central1"
    tpm: 300000
    rpm: 3000

  # ===== QWEN CODING MODELS =====
  - model_name: qwen3-coder-480b
    litellm_params:
      model: vertex_ai/qwen/qwen3-coder-480b-a35b-instruct-maas
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-east1"
    tpm: 150000
    rpm: 1500

  - model_name: qwen3-235b
    litellm_params:
      model: vertex_ai/qwen/qwen3-235b-a22b-instruct-2507-maas
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-west1"
    tpm: 200000
    rpm: 2000

  # ===== GPT-OSS MODEL =====
  - model_name: gpt-oss-20b
    litellm_params:
      model: vertex_ai/openai/gpt-oss-20b-maas
      vertex_ai_project: "YOUR_PROJECT_ID"  # ← REPLACE THIS
      vertex_ai_location: "us-central1"
    tpm: 250000
    rpm: 2500

# Router Settings - Handles load balancing and retries
router_settings:
  routing_strategy: "simple-shuffle"  # Weighted random selection
  num_retries: 3                       # Retry failed requests 3 times
  timeout: 30                          # 30 second timeout
  fallbacks:
    - {"gemini-2.5-pro": ["gemini-2.5-flash"]}  # Fallback to Flash if Pro fails
  enable_pre_call_check: true          # Check rate limits before making requests

# Global Settings
litellm_settings:
  drop_params: true   # Drop unsupported parameters gracefully
  set_verbose: false  # Set to true for debugging

# Authentication (generate a secure key)
general_settings:
  master_key: "sk-1234567890abcdef"  # ← REPLACE with secure random key
```

**Action Items:**
1. Replace ALL instances of `YOUR_PROJECT_ID` with your GCP project ID
2. Verify regions match where you want to deploy models
3. Generate a secure master key: `openssl rand -hex 16` and replace in `master_key`

**Save this file** as `litellm_config.yaml` in your working directory.

---

## ▶️ Step 4: Start LiteLLM Proxy

```bash
# Start the proxy server
litellm --config litellm_config.yaml --port 4000

# Expected output:
# INFO: LiteLLM: Proxy initialized
# INFO: Uvicorn running on http://0.0.0.0:4000
# INFO: Loaded 8 models from config
```

**Keep this terminal open!** The proxy runs in the foreground.

**Troubleshooting:**
- **Port already in use**: Change `--port 4000` to `--port 4001`
- **Config file not found**: Use full path `litellm --config /full/path/to/litellm_config.yaml`
- **Authentication errors**: Verify gcloud auth or service account key is valid

---

## 🔧 Step 5: Configure Claude Code

Open a **NEW terminal** (keep LiteLLM running) and set environment variables:

```bash
# Point Claude Code to LiteLLM proxy
export ANTHROPIC_BASE_URL="http://localhost:4000"

# Use LiteLLM master key for authentication
export ANTHROPIC_AUTH_TOKEN="sk-1234567890abcdef"  # ← Use your master_key from config

# Verify configuration is loaded
claude /status
```

**Expected Output:**
```
Claude Code Status:
├─ Base URL: http://localhost:4000 ✓
├─ Auth Token: sk-**** (masked) ✓
└─ Configuration Source: environment variables
```

**Troubleshooting:**
- If Base URL shows default (api.anthropic.com): Re-export ANTHROPIC_BASE_URL
- If Auth Token missing: Re-export ANTHROPIC_AUTH_TOKEN
- If variables don't persist: Add to `~/.bashrc` or `~/.zshrc`

---

## ✅ Step 6: Test End-to-End

### Test 1: Gateway Health Check

```bash
curl http://localhost:4000/health

# Expected output:
{"status": "healthy"}
```

### Test 2: Model Completion via Gateway

```bash
curl http://localhost:4000/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-1234567890abcdef" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Say hello in JSON format"}],
    "max_tokens": 50
  }'

# Expected output (formatted):
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1733000000,
  "model": "gemini-2.5-flash",
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "{\"greeting\": \"Hello!\"}"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 8,
    "total_tokens": 18
  }
}
```

### Test 3: Claude Code Command

```bash
# Run a simple Claude Code command
echo "What is 2+2?" | claude

# Should see:
# Response from gateway (via gemini-2.5-flash): "2+2 equals 4"
```

---

## 🎉 Success Criteria

You've successfully completed setup if:

- [x] LiteLLM proxy is running on port 4000
- [x] `claude /status` shows custom base URL
- [x] curl test returns valid JSON completion
- [x] Claude Code commands work normally

---

## 🔍 Verification Checklist

Run this comprehensive test script to verify all 8 models:

```python
# save as: test_all_models.py
import requests
import json

GATEWAY_URL = "http://localhost:4000"
AUTH_TOKEN = "sk-1234567890abcdef"  # Your master key

MODELS = [
    "gemini-2.5-flash",
    "gemini-2.5-pro",
    "deepseek-r1",
    "llama3-405b",
    "codestral",
    "qwen3-coder-480b",
    "qwen3-235b",
    "gpt-oss-20b",
]

def test_model(model_name):
    try:
        response = requests.post(
            f"{GATEWAY_URL}/chat/completions",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {AUTH_TOKEN}"
            },
            json={
                "model": model_name,
                "messages": [{"role": "user", "content": "Say hello"}],
                "max_tokens": 20
            },
            timeout=30
        )
        
        if response.status_code == 200:
            print(f"✅ {model_name}: SUCCESS")
            return True
        else:
            print(f"❌ {model_name}: FAILED - {response.status_code}")
            print(f"   Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ {model_name}: EXCEPTION - {str(e)}")
        return False

print("Testing all 8 Vertex AI models...\n")
results = [test_model(m) for m in MODELS]

print(f"\n{'='*50}")
print(f"RESULTS: {sum(results)}/{len(results)} models working")
print(f"{'='*50}")
```

**Run the test:**
```bash
python test_all_models.py
```

**Expected Output:**
```
Testing all 8 Vertex AI models...

✅ gemini-2.5-flash: SUCCESS
✅ gemini-2.5-pro: SUCCESS
✅ deepseek-r1: SUCCESS
✅ llama3-405b: SUCCESS
✅ codestral: SUCCESS
✅ qwen3-coder-480b: SUCCESS
✅ qwen3-235b: SUCCESS
✅ gpt-oss-20b: SUCCESS

==================================================
RESULTS: 8/8 models working
==================================================
```

---

## 🛠️ Common Issues & Solutions

### Issue 1: Model Not Found

**Error**: `Model 'vertex_ai/gemini-2.5-flash' not found`

**Solution**:
1. Verify model is deployed in Model Garden:
   ```bash
   # Open Model Garden console
   open https://console.cloud.google.com/vertex-ai/model-garden
   ```
2. Check model availability in your region
3. Deploy model to correct region if needed

### Issue 2: Permission Denied

**Error**: `403 Forbidden` or `Permission denied`

**Solution**:
1. Verify service account has correct IAM role:
   ```bash
   gcloud projects get-iam-policy YOUR_PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:litellm-sa@*"
   ```
2. Ensure `roles/aiplatform.user` is present
3. Re-authenticate if using gcloud auth:
   ```bash
   gcloud auth application-default login --force
   ```

### Issue 3: Quota Exceeded

**Error**: `429 Too Many Requests` or `Quota exceeded`

**Solution**:
1. Check current quotas:
   ```bash
   gcloud compute project-info describe --project=YOUR_PROJECT_ID | grep quota
   ```
2. Request quota increase in GCP Console → IAM & Admin → Quotas
3. Reduce `rpm` and `tpm` values in config temporarily

### Issue 4: Connection Refused

**Error**: `Connection refused` when calling http://localhost:4000

**Solution**:
1. Verify LiteLLM proxy is running:
   ```bash
   ps aux | grep litellm
   ```
2. Check if port 4000 is listening:
   ```bash
   lsof -i :4000  # macOS/Linux
   netstat -an | grep 4000  # Windows
   ```
3. Try restarting proxy:
   ```bash
   pkill -f litellm
   litellm --config litellm_config.yaml --port 4000
   ```

### Issue 5: Invalid Credentials

**Error**: `Invalid authentication credentials`

**Solution**:
1. Verify environment variable is set:
   ```bash
   echo $GOOGLE_APPLICATION_CREDENTIALS
   ```
2. Check service account key file exists and is readable:
   ```bash
   cat $GOOGLE_APPLICATION_CREDENTIALS | jq .
   ```
3. Regenerate service account key if corrupted

---

## 🔒 Security Best Practices

### For Development
- ✅ Use `gcloud auth application-default login`
- ✅ Store config files in project directory (not home)
- ✅ Add `litellm_config.yaml` to `.gitignore`
- ❌ Never commit API keys or project IDs to git

### For Production
- ✅ Use service accounts with minimal IAM roles
- ✅ Store secrets in Google Secret Manager:
  ```bash
  # Store master key in Secret Manager
  echo -n "sk-random-key" | gcloud secrets create litellm-master-key \
    --data-file=- --replication-policy="automatic"
  ```
- ✅ Rotate service account keys every 90 days
- ✅ Use separate GCP projects for dev/staging/prod
- ✅ Enable audit logging for all API calls
- ❌ Never hardcode credentials in config files

---

## 📚 Next Steps

### Explore Advanced Features

1. **Enable Prompt Caching** (Reduce costs by 90%):
   ```yaml
   litellm_settings:
     cache: true
     cache_params:
       type: "redis"
       host: "localhost"
       port: 6379
   ```

2. **Add Multi-Region Load Balancing**:
   ```yaml
   model_list:
     - model_name: gemini-2.5-pro
       litellm_params:
         model: vertex_ai/gemini-2.5-pro
         vertex_ai_location: "us-central1"
     - model_name: gemini-2.5-pro
       litellm_params:
         model: vertex_ai/gemini-2.5-pro
         vertex_ai_location: "europe-west1"
   ```

3. **Enable Usage Monitoring**:
   ```yaml
   litellm_settings:
     success_callback: ["langfuse"]
     set_verbose: true
   ```

4. **Configure Model-Specific Features**:
   - Function calling with Gemini models
   - Reasoning mode with DeepSeek R1
   - Fill-in-middle with Codestral

### Useful Resources

- **LiteLLM Documentation**: https://docs.litellm.ai
- **Vertex AI Model Garden**: https://cloud.google.com/vertex-ai/docs/model-garden
- **Claude Code Docs**: https://docs.anthropic.com/claude-code
- **GCP IAM Best Practices**: https://cloud.google.com/iam/docs/best-practices

---

## 🤝 Getting Help

If you encounter issues not covered here:

1. **Enable Debug Logging**:
   ```bash
   export LITELLM_LOG=DEBUG
   export ANTHROPIC_LOG=debug
   litellm --config litellm_config.yaml --debug
   ```

2. **Check LiteLLM GitHub Issues**: https://github.com/berriai/litellm/issues

3. **Review Vertex AI Status**: https://status.cloud.google.com

4. **Contact Support**:
   - LiteLLM: community Slack or GitHub
   - Vertex AI: GCP Support console
   - Claude Code: `/bug` command

---

## ✨ You're All Set!

You now have a fully functional LLM gateway connecting Claude Code to 8 Vertex AI Model Garden models. Experiment with different models for different tasks:

- **Quick responses**: gemini-2.5-flash
- **Complex reasoning**: gemini-2.5-pro, deepseek-r1
- **Code generation**: codestral, qwen3-coder-480b
- **Large context**: llama3-405b (128K tokens)

Happy coding! 🚀

---

**Quickstart Version**: 1.0.0  
**Last Updated**: 2025-12-01  
**Feedback**: Report issues via `/bug` command in Claude Code
