# US3: Provider-Specific Environment Variables Reference

**User Story**: US3 - Multi-Provider Gateway Configuration (Priority: P3)  
**Purpose**: Complete reference for environment variables across all providers  
**Audience**: Platform engineers, DevOps teams

---

## Overview

This document provides a complete reference for environment variables required to configure multi-provider LiteLLM gateways with Claude Code.

---

## Variable Categories

### 1. LiteLLM Gateway Variables

**Scope**: Gateway operation and authentication

| Variable             | Required    | Description                                 | Example                          |
| -------------------- | ----------- | ------------------------------------------- | -------------------------------- |
| `LITELLM_MASTER_KEY` | ✅ Yes      | Master key for LiteLLM proxy authentication | `sk-1234abcd...`                 |
| `REDIS_HOST`         | ❌ Optional | Redis host for caching (multi-instance)     | `localhost`                      |
| `REDIS_PORT`         | ❌ Optional | Redis port                                  | `6379`                           |
| `REDIS_PASSWORD`     | ❌ Optional | Redis password                              | `password123`                    |
| `DATABASE_URL`       | ❌ Optional | PostgreSQL connection for logging/analytics | `postgresql://user:pass@host/db` |

---

### 2. Anthropic Direct Variables

**Scope**: Direct Anthropic API access

| Variable             | Required    | Description                                  | Example                     |
| -------------------- | ----------- | -------------------------------------------- | --------------------------- |
| `ANTHROPIC_API_KEY`  | ✅ Yes      | API key from Anthropic Console               | `sk-ant-api03-...`          |
| `ANTHROPIC_BASE_URL` | ❌ Optional | Custom base URL (default: api.anthropic.com) | `https://api.anthropic.com` |
| `ANTHROPIC_LOG`      | ❌ Optional | Enable debug logging (`debug`, `info`)       | `debug`                     |

**How to Obtain**:

1. Visit https://console.anthropic.com/settings/keys
2. Click "Create Key"
3. Copy key (starts with `sk-ant-`)

**Rate Limits** (as of 2024):

- **Free Tier**: 5 RPM
- **Build Tier** ($5+ monthly): 50 RPM (Sonnet), 20 RPM (Opus)
- **Scale Tier** ($1000+ monthly): Custom limits

---

### 3. AWS Bedrock Variables

**Scope**: AWS Bedrock access for Claude models

| Variable                     | Required      | Description                             | Example                                   |
| ---------------------------- | ------------- | --------------------------------------- | ----------------------------------------- |
| `AWS_REGION`                 | ✅ Yes        | AWS region where Bedrock is enabled     | `us-east-1`                               |
| `AWS_ACCESS_KEY_ID`          | ❌ Optional\* | AWS access key ID                       | `AKIA...`                                 |
| `AWS_SECRET_ACCESS_KEY`      | ❌ Optional\* | AWS secret access key                   | `wJalrXUtnFEMI...`                        |
| `AWS_SESSION_TOKEN`          | ❌ Optional   | Session token for temporary credentials | `IQoJb3JpZ2lu...`                         |
| `AWS_PROFILE`                | ❌ Optional   | AWS CLI profile name                    | `bedrock`                                 |
| `ANTHROPIC_BEDROCK_BASE_URL` | ❌ Optional   | Custom Bedrock endpoint                 | `https://bedrock.us-east-1.amazonaws.com` |

\*Optional if using IAM role (EC2/ECS/Lambda) or AWS CLI profile

**Authentication Methods**:

1. **IAM Role** (Recommended for AWS resources): No env vars needed
2. **Access Keys**: Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
3. **CLI Profile**: Set `AWS_PROFILE` after running `aws configure`

**Required IAM Permissions**:

```json
{
  "Effect": "Allow",
  "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
  "Resource": "arn:aws:bedrock:*:*:inference-profile/anthropic.claude-*"
}
```

**Supported Regions**:

- `us-east-1` (US East, N. Virginia) ← Most models available
- `us-west-2` (US West, Oregon)
- `eu-west-1` (Europe, Ireland)
- `ap-northeast-1` (Asia Pacific, Tokyo)
- `ap-southeast-1` (Asia Pacific, Singapore)

---

### 4. Google Vertex AI Variables

**Scope**: Vertex AI access for Claude and Model Garden models

| Variable                         | Required      | Description                  | Example                                         |
| -------------------------------- | ------------- | ---------------------------- | ----------------------------------------------- |
| `VERTEX_PROJECT_ID`              | ✅ Yes        | GCP project ID               | `my-project-12345`                              |
| `VERTEX_LOCATION`                | ✅ Yes        | GCP region                   | `us-central1`                                   |
| `GOOGLE_APPLICATION_CREDENTIALS` | ❌ Optional\* | Path to service account JSON | `/path/to/sa-key.json`                          |
| `ANTHROPIC_VERTEX_BASE_URL`      | ❌ Optional   | Custom Vertex AI endpoint    | `https://us-central1-aiplatform.googleapis.com` |

\*Optional if using `gcloud auth application-default login`

**Authentication Methods**:

1. **gcloud CLI** (Recommended for development):

   ```bash
   gcloud auth application-default login
   ```

2. **Service Account** (Recommended for production):

   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"
   ```

3. **Workload Identity** (Recommended for GKE): No env vars needed

**Required IAM Roles**:

- `roles/aiplatform.user` (Vertex AI User)
- Or custom role with `aiplatform.endpoints.predict` permission

**Supported Regions**:

- `us-central1` (Iowa, USA) ← Most models available
- `us-east1` (South Carolina, USA)
- `europe-west1` (Belgium, Europe)
- `asia-southeast1` (Singapore, Asia)

**Claude Models on Vertex AI**:
Currently available in: `us-central1`, `europe-west1`, `asia-southeast1`

---

### 5. Claude Code Integration Variables

**Scope**: Configuring Claude Code to use LiteLLM gateway

| Variable                        | Required    | Description                                       | Example                 |
| ------------------------------- | ----------- | ------------------------------------------------- | ----------------------- |
| `ANTHROPIC_BASE_URL`            | ✅ Yes      | LiteLLM gateway URL                               | `http://localhost:4000` |
| `ANTHROPIC_API_KEY`             | ✅ Yes      | LiteLLM master key (same as `LITELLM_MASTER_KEY`) | `sk-1234abcd...`        |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | ❌ Optional | Skip Claude Code's Bedrock auth (set to `1`)      | `1`                     |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH`  | ❌ Optional | Skip Claude Code's Vertex AI auth (set to `1`)    | `1`                     |

**Why Skip Auth?**

- When using LiteLLM gateway, **the gateway handles all provider authentication**
- Claude Code normally authenticates directly to each provider
- Bypass flags tell Claude Code to skip its own auth and use the gateway's credentials
- This allows centralized credential management in the gateway

**When to Set Bypass Flags**:

- ✅ **Set to 1**: When using LiteLLM gateway routing to Bedrock/Vertex AI
- ❌ **Don't set**: When Claude Code directly accesses Bedrock/Vertex AI (no gateway)

---

## Complete Multi-Provider Configuration Example

```bash
# ~/.bashrc or ~/.zshrc

# ===== LiteLLM Gateway =====
export LITELLM_MASTER_KEY="sk-generated-random-key-here"

# ===== Anthropic Direct =====
export ANTHROPIC_API_KEY="sk-ant-api03-your-key-here"

# ===== AWS Bedrock =====
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."

# ===== Google Vertex AI =====
export VERTEX_PROJECT_ID="my-gcp-project"
export VERTEX_LOCATION="us-central1"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"

# ===== Claude Code Integration =====
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"  # Same as LITELLM_MASTER_KEY
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1

# ===== Optional: Debugging =====
export ANTHROPIC_LOG="debug"  # Enable detailed logs
```

---

## Validation Commands

### Check All Variables

```bash
# Run automated validation
python scripts/validate-provider-env-vars.py templates/multi-provider/multi-provider-config.yaml
```

### Manual Checks

```bash
# LiteLLM Gateway
echo "LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:0:10}..."

# Anthropic Direct
echo "ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:0:10}..."

# AWS Bedrock
aws sts get-caller-identity  # Verify AWS credentials
echo "AWS_REGION: $AWS_REGION"

# Google Vertex AI
gcloud auth list  # Verify GCP authentication
echo "VERTEX_PROJECT_ID: $VERTEX_PROJECT_ID"
echo "VERTEX_LOCATION: $VERTEX_LOCATION"

# Claude Code Integration
echo "ANTHROPIC_BASE_URL: $ANTHROPIC_BASE_URL"
echo "CLAUDE_CODE_SKIP_BEDROCK_AUTH: $CLAUDE_CODE_SKIP_BEDROCK_AUTH"
echo "CLAUDE_CODE_SKIP_VERTEX_AUTH: $CLAUDE_CODE_SKIP_VERTEX_AUTH"
```

---

## Environment Variable Precedence

When the same variable is defined in multiple places:

1. **Shell Environment** (highest precedence)

   ```bash
   export ANTHROPIC_API_KEY="..."
   ```

2. **.env Files** (loaded by applications)

   ```bash
   # .env
   ANTHROPIC_API_KEY=...
   ```

3. **Config Files** (lowest precedence)

   ```yaml
   # litellm-config.yaml
   model_list:
     - litellm_params:
         api_key: os.environ/ANTHROPIC_API_KEY
   ```

**Best Practice**: Define sensitive values in shell environment, reference them in config files using `os.environ/VARIABLE_NAME`

---

## Security Best Practices

### 1. Never Commit Credentials

```bash
# ❌ DON'T DO THIS
export ANTHROPIC_API_KEY="sk-ant-actual-key-here" >> script.sh

# ✅ DO THIS
export ANTHROPIC_API_KEY="sk-ant-..."  # In shell, not in files
```

### 2. Use Secret Managers in Production

**AWS Secrets Manager**:

```bash
export ANTHROPIC_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id anthropic-api-key \
  --query SecretString \
  --output text)
```

**GCP Secret Manager**:

```bash
export ANTHROPIC_API_KEY=$(gcloud secrets versions access latest \
  --secret="anthropic-api-key")
```

**HashiCorp Vault**:

```bash
export ANTHROPIC_API_KEY=$(vault kv get -field=key secret/anthropic)
```

### 3. Rotate Keys Regularly

- **Anthropic API Keys**: Rotate quarterly
- **AWS Access Keys**: Rotate monthly
- **GCP Service Accounts**: Rotate semi-annually
- **LiteLLM Master Key**: Rotate quarterly

### 4. Use Least Privilege

- Grant only required permissions (e.g., `bedrock:InvokeModel`, not `bedrock:*`)
- Use separate service accounts for dev/staging/prod
- Implement role-based access control (RBAC)

### 5. Monitor for Anomalies

- Enable CloudTrail (AWS) and Cloud Audit Logs (GCP)
- Set up billing alerts
- Monitor API usage in provider consoles
- Log authentication attempts in LiteLLM

---

## Troubleshooting

### Variable Not Found

**Symptom**: `os.environ/VAR_NAME` returns empty or error

**Solution**:

```bash
# Verify variable is set
echo $VAR_NAME

# If not set, export it
export VAR_NAME="value"

# Verify LiteLLM can read it
python3 -c "import os; print(os.getenv('VAR_NAME'))"
```

### Permission Denied Errors

**AWS Bedrock**:

```bash
# Check IAM permissions
aws bedrock list-foundation-models --region $AWS_REGION

# Verify credentials
aws sts get-caller-identity
```

**Google Vertex AI**:

```bash
# Check IAM permissions
gcloud projects get-iam-policy $VERTEX_PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:$(gcloud config get-value account)"
```

### Authentication Bypass Not Working

**Symptom**: Claude Code still trying to authenticate directly to providers

**Solution**:

```bash
# Verify bypass flags are set
echo $CLAUDE_CODE_SKIP_BEDROCK_AUTH  # Should be "1"
echo $CLAUDE_CODE_SKIP_VERTEX_AUTH   # Should be "1"

# If not set, export them
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1

# Restart Claude Code
```

---

## Environment-Specific Configurations

### Development

```bash
# Use gcloud/AWS CLI for convenience
gcloud auth application-default login
aws configure --profile dev

export VERTEX_PROJECT_ID="my-dev-project"
export AWS_PROFILE="dev"
```

### Staging

```bash
# Use service accounts with limited permissions
export GOOGLE_APPLICATION_CREDENTIALS="/keys/staging-sa.json"
export AWS_PROFILE="staging"
```

### Production

```bash
# Use secret managers and strict IAM
export ANTHROPIC_API_KEY=$(aws secretsmanager get-secret-value ...)
export GOOGLE_APPLICATION_CREDENTIALS="/keys/prod-sa.json"

# Enable audit logging
export ANTHROPIC_LOG="info"
```

---

## Additional Resources

- [examples/us3-multi-provider-setup.md](./us3-multi-provider-setup.md) - Complete setup guide
- [examples/us3-auth-bypass-guide.md](./us3-auth-bypass-guide.md) - Authentication bypass details
- [templates/multi-provider/](../templates/multi-provider/) - Configuration templates
- [scripts/validate-provider-env-vars.py](../scripts/validate-provider-env-vars.py) - Validation tool
- [Anthropic API Docs](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [AWS Bedrock Docs](https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html)
- [Vertex AI Docs](https://cloud.google.com/vertex-ai/docs/reference/rest)
