# US3 Quickstart: Multi-Provider Gateway Setup

**Time Required**: 20-30 minutes  
**Difficulty**: Advanced  
**Target Audience**: Platform engineers configuring enterprise gateways with multiple cloud providers

---

## Overview

This guide walks you through setting up a LiteLLM gateway that routes Claude requests across multiple providers: Anthropic Direct, AWS Bedrock, and Google Vertex AI.

**What you'll achieve**:

- ✅ Multi-provider LiteLLM gateway with automatic fallback
- ✅ Provider-specific authentication configured
- ✅ Authentication bypass flags for Claude Code integration
- ✅ Cost-optimized routing across providers
- ✅ High availability through provider diversity

---

## Prerequisites

Before starting, ensure you have:

### Software

- [ ] **Python 3.9+** installed (`python3 --version`)
- [ ] **LiteLLM** installed (`pip install litellm`)
- [ ] **Claude Code** installed (`claude --version`)

### Cloud Provider Access

- [ ] **Anthropic Direct**: API key from https://console.anthropic.com/settings/keys
- [ ] **AWS Bedrock**: AWS account with Bedrock access enabled
- [ ] **Google Vertex AI**: GCP project with Vertex AI API enabled

### Authentication Tools

- [ ] **AWS CLI** installed and configured (`aws --version`, `aws sts get-caller-identity`)
- [ ] **gcloud CLI** installed and configured (`gcloud --version`, `gcloud auth list`)

**Run automated check**:

```bash
cd specs/001-llm-gateway-config
python scripts/validate-provider-env-vars.py templates/multi-provider/multi-provider-config.yaml
```

---

## Architecture Overview

```
┌─────────────────┐
│   Claude Code   │
│                 │
│ ANTHROPIC_BASE_URL=localhost:4000
│ SKIP_*_AUTH=1   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  LiteLLM Proxy  │  ← Routes based on strategy
│  (Port 4000)    │  ← Handles auth for all providers
│                 │  ← Provides fallback/retry logic
└───┬─────┬───┬───┘
    │     │   │
    ▼     ▼   ▼
┌───────┐┌───────┐┌────────┐
│Anthrop││Bedrock││Vertex  │
│  ic   ││       ││  AI    │
│Direct ││  AWS  ││  GCP   │
└───────┘└───────┘└────────┘
```

**Key Benefits**:

- **High Availability**: If one provider fails, traffic automatically routes to others
- **Cost Optimization**: Route to cheapest provider first, expensive ones as fallback
- **Compliance**: Use specific providers for different compliance requirements
- **Performance**: Route to geographically nearest provider

---

## Step 1: Configure Anthropic Direct (5 minutes)

### 1.1 Get API Key

1. Visit https://console.anthropic.com/settings/keys
2. Click "Create Key"
3. Copy the key (starts with `sk-ant-`)

### 1.2 Set Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_API_KEY="sk-ant-api-key-here"

# Reload shell
source ~/.bashrc  # or source ~/.zshrc
```

### 1.3 Verify Authentication

```bash
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Hi"}]
  }'
```

**Expected**: JSON response with Claude's reply

---

## Step 2: Configure AWS Bedrock (10 minutes)

### 2.1 Enable Bedrock Access

1. Log into AWS Console
2. Navigate to AWS Bedrock service
3. Go to "Model access"
4. Request access to Anthropic Claude models
5. Wait for approval (usually instant for Claude 3 models)

### 2.2 Configure AWS Credentials

**Option A: IAM Role (Recommended for EC2/ECS)**

```bash
# No explicit credentials needed - use instance/task IAM role
export AWS_REGION="us-east-1"
```

**Option B: Access Keys**

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

**Option C: AWS CLI Profile**

```bash
# Configure profile
aws configure --profile bedrock

# Use profile
export AWS_PROFILE="bedrock"
export AWS_REGION="us-east-1"
```

### 2.3 Verify IAM Permissions

```bash
# Test Bedrock access
aws bedrock-runtime invoke-model \
  --region us-east-1 \
  --model-id anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --body '{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Hi"}]
  }' \
  output.json

cat output.json
```

**Expected**: JSON response in `output.json`

### 2.4 Required IAM Policy

Ensure your IAM user/role has this policy attached:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": ["arn:aws:bedrock:*:*:inference-profile/anthropic.claude-*"]
    }
  ]
}
```

---

## Step 3: Configure Google Vertex AI (10 minutes)

### 3.1 Enable Vertex AI API

```bash
# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable APIs
gcloud services enable aiplatform.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3.2 Authenticate

**Option A: gcloud Auth (Development)**

```bash
gcloud auth application-default login
```

**Option B: Service Account (Production)**

```bash
# Create service account
gcloud iam service-accounts create litellm-gateway \
  --description="LiteLLM Gateway Service Account" \
  --display-name="LiteLLM Gateway"

# Grant Vertex AI permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:litellm-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Create and download key
gcloud iam service-accounts keys create ~/litellm-sa-key.json \
  --iam-account=litellm-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/litellm-sa-key.json"
```

### 3.3 Set Project Variables

```bash
export VERTEX_PROJECT_ID="your-project-id"
export VERTEX_LOCATION="us-central1"
```

### 3.4 Verify Access

```bash
# Test Vertex AI access
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
  "https://us-central1-aiplatform.googleapis.com/v1/projects/$VERTEX_PROJECT_ID/locations/us-central1/publishers/anthropic/models/claude-3-5-sonnet@20241022:predict" \
  -d '{
    "anthropic_version": "vertex-2023-10-16",
    "messages": [{"role": "user", "content": "Hi"}],
    "max_tokens": 10
  }'
```

**Expected**: JSON response with Claude's reply

---

## Step 4: Configure LiteLLM Gateway (5 minutes)

### 4.1 Copy Multi-Provider Template

```bash
cd specs/001-llm-gateway-config

# Copy template
cp templates/multi-provider/multi-provider-config.yaml my-multi-provider-config.yaml

# Edit configuration
nano my-multi-provider-config.yaml  # or vim, code, etc.
```

### 4.2 Update Configuration

Replace placeholder values:

```yaml
# In my-multi-provider-config.yaml
model_list:
  - model_name: claude-3-5-sonnet-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY # ← Already set
    priority: 10

  - model_name: claude-3-5-sonnet-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: os.environ/AWS_REGION # ← Already set
    priority: 5

  - model_name: claude-3-5-sonnet-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID # ← Set to YOUR_PROJECT_ID
      vertex_location: os.environ/VERTEX_LOCATION # ← Set to us-central1
    priority: 1

# Set master key
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY # ← Generate below
```

### 4.3 Generate Master Key

```bash
# Generate secure random key
export LITELLM_MASTER_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Persist to shell config
echo "export LITELLM_MASTER_KEY='$LITELLM_MASTER_KEY'" >> ~/.bashrc
source ~/.bashrc

# Verify
echo $LITELLM_MASTER_KEY
```

### 4.4 Start LiteLLM Proxy

```bash
litellm --config my-multi-provider-config.yaml --port 4000
```

**Expected Output**:

```
INFO:     LiteLLM Proxy: Deployed on http://0.0.0.0:4000
INFO:     Loaded 3 models
INFO:     claude-3-5-sonnet-anthropic (anthropic/claude-3-5-sonnet-20241022)
INFO:     claude-3-5-sonnet-bedrock (bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0)
INFO:     claude-3-5-sonnet-vertex (vertex_ai/claude-3-5-sonnet@20241022)
```

### 4.5 Verify Gateway Health

**In a new terminal**:

```bash
curl http://localhost:4000/health

# Expected: {"status": "healthy"}

# Check model list
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://localhost:4000/model/info | jq
```

---

## Step 5: Configure Claude Code Integration (5 minutes)

### 5.1 Set Authentication Bypass Flags

```bash
# Bypass provider-specific auth in Claude Code
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1

# Add to shell config for persistence
echo 'export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1' >> ~/.bashrc
echo 'export CLAUDE_CODE_SKIP_VERTEX_AUTH=1' >> ~/.bashrc
source ~/.bashrc
```

**Why bypass?**

- Claude Code normally authenticates directly to each provider
- With gateway, LiteLLM handles all provider authentication
- Bypass flags tell Claude Code to skip its own auth and trust the gateway

### 5.2 Configure Claude Code Environment

```bash
# Point Claude Code to LiteLLM gateway
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"

# Add to shell config
echo 'export ANTHROPIC_BASE_URL="http://localhost:4000"' >> ~/.bashrc
echo 'export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"' >> ~/.bashrc
source ~/.bashrc
```

### 5.3 Verify Environment

```bash
# Run validation script
python scripts/validate-provider-env-vars.py my-multi-provider-config.yaml
```

**Expected**:

```
✅ All required environment variables are set
✅ All providers authenticated correctly
✅ Claude Code integration configured
```

---

## Step 6: Test Multi-Provider Routing (5 minutes)

### 6.1 Test with `claude /status`

```bash
claude /status
```

**Expected**:

```
✓ Connected to Claude API
✓ Model: claude-3-5-sonnet-20241022 (via LiteLLM)
✓ Authentication: Valid
```

### 6.2 Test Provider Routing

```bash
# Test routing to each provider
python tests/test-multi-provider-routing.py \
  --config my-multi-provider-config.yaml \
  --iterations 5
```

**Expected Output**:

```
📊 Routing Analysis

  claude-3-5-sonnet-anthropic:
    Requests: 5
    Success:  5 (100%)
    Latency:  avg=0.85s

  claude-3-5-sonnet-bedrock:
    Requests: 5
    Success:  5 (100%)
    Latency:  avg=1.20s

  claude-3-5-sonnet-vertex:
    Requests: 5
    Success:  5 (100%)
    Latency:  avg=1.15s

✅ PASS: All providers routing correctly
```

### 6.3 Test Fallback Behavior

```bash
# Test that fallback activates when primary fails
python tests/test-provider-fallback.py \
  --primary claude-3-5-sonnet-anthropic \
  --fallback claude-3-5-sonnet-bedrock
```

### 6.4 Test Authentication Bypass

```bash
# Verify bypass flags are working
bash tests/test-auth-bypass.sh
```

**Expected**:

```
✅ CLAUDE_CODE_SKIP_BEDROCK_AUTH: Set correctly
✅ CLAUDE_CODE_SKIP_VERTEX_AUTH: Set correctly
✅ API call succeeded through gateway
✅ Authentication bypass is working correctly
```

---

## Step 7: Configure Routing Strategy (Optional)

### 7.1 Cost-Optimized Routing

Edit `my-multi-provider-config.yaml`:

```yaml
router_settings:
  routing_strategy: usage-based-routing # Route to highest priority first

# Adjust priorities (higher = use first)
model_list:
  - model_name: claude-3-5-sonnet-anthropic
    priority: 10 # Cheapest - use first

  - model_name: claude-3-5-sonnet-bedrock
    priority: 5 # Medium cost - use second

  - model_name: claude-3-5-sonnet-vertex
    priority: 1 # Highest cost - use as last resort
```

### 7.2 Performance-Optimized Routing

```yaml
router_settings:
  routing_strategy: least-busy # Route to fastest available model
```

### 7.3 Load Balancing

```yaml
router_settings:
  routing_strategy: simple-shuffle # Equal distribution across providers
```

**See**: `templates/multi-provider/routing-strategies.md` for detailed strategy guide

---

## Verification Checklist

After completing all steps, verify:

- [ ] LiteLLM gateway is running on port 4000
- [ ] Gateway health check returns `{"status": "healthy"}`
- [ ] All three providers (Anthropic, Bedrock, Vertex) are configured
- [ ] `claude /status` shows connection through gateway
- [ ] Multi-provider routing test passes (all providers respond)
- [ ] Fallback test passes (requests succeed even if primary fails)
- [ ] Authentication bypass flags are set
- [ ] Environment variables are persisted in shell config

**Run complete verification**:

```bash
cd specs/001-llm-gateway-config
./scripts/validate-all.sh
```

---

## Troubleshooting

### Issue: Gateway Won't Start

**Symptom**: `litellm --config ...` fails immediately

**Causes & Solutions**:

1. **YAML syntax error**: Validate with `yamllint my-multi-provider-config.yaml`
2. **Missing env var**: Run `python scripts/validate-provider-env-vars.py my-multi-provider-config.yaml`
3. **Port in use**: Change port in config or kill process on port 4000

### Issue: Provider Authentication Fails

**Symptom**: Requests fail with 401/403 errors

**Causes & Solutions**:

1. **Anthropic**: Verify `$ANTHROPIC_API_KEY` is set and valid
2. **Bedrock**: Run `aws sts get-caller-identity` to verify AWS credentials
3. **Vertex**: Run `gcloud auth list` to verify GCP authentication

### Issue: Routing Not Working

**Symptom**: All requests go to one provider

**Solution**: Check `routing_strategy` and model `priority` values:

```yaml
router_settings:
  routing_strategy: usage-based-routing # Or least-busy or simple-shuffle

model_list:
  - model_name: model-a
    priority: 5 # Ensure priorities are set and varied
  - model_name: model-b
    priority: 5 # Same priority = equal distribution
```

### Issue: Claude Code Can't Connect

**Symptom**: `claude /status` shows "Unable to connect"

**Solution**:

1. Verify gateway is running: `curl http://localhost:4000/health`
2. Check `ANTHROPIC_BASE_URL`: `echo $ANTHROPIC_BASE_URL` (should be http://localhost:4000)
3. Check `ANTHROPIC_API_KEY`: `echo $ANTHROPIC_API_KEY` (should match `$LITELLM_MASTER_KEY`)
4. Verify bypass flags: `echo $CLAUDE_CODE_SKIP_BEDROCK_AUTH` (should be 1)

---

## Next Steps

- **Monitor Costs**: See `examples/us3-cost-optimization.md`
- **Provider Selection**: See `examples/us3-provider-selection.md` for decision framework
- **Advanced Routing**: See `templates/multi-provider/routing-strategies.md`
- **Production Deployment**: See `examples/us2-enterprise-integration.md`
- **Environment Variables**: See `examples/us3-provider-env-vars.md` for complete reference

---

## Security Best Practices

1. **Never commit credentials** to version control
2. **Use secret managers** for production (AWS Secrets Manager, GCP Secret Manager)
3. **Rotate API keys** quarterly
4. **Monitor usage** for anomalies
5. **Set billing alerts** in all cloud consoles
6. **Use least-privilege IAM** for service accounts
7. **Enable audit logging** in LiteLLM and cloud providers

---

## Additional Resources

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Anthropic API Docs](https://docs.anthropic.com/)
- [AWS Bedrock Docs](https://docs.aws.amazon.com/bedrock/)
- [Vertex AI Docs](https://cloud.google.com/vertex-ai/docs)
- [examples/us3-provider-env-vars.md](./us3-provider-env-vars.md)
- [examples/us3-cost-optimization.md](./us3-cost-optimization.md)
