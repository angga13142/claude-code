# gcloud Authentication Setup Guide

**User Story**: US1 - Basic LiteLLM Gateway Setup  
**Purpose**: Configure Google Cloud authentication for Vertex AI access  
**Estimated Time**: 5-10 minutes

---

## Overview

This guide covers authentication setup for accessing Vertex AI models through LiteLLM. You'll learn how to use both gcloud CLI authentication (development) and service accounts (production).

---

## Prerequisites

- Google Cloud account with billing enabled
- Vertex AI API enabled in your project
- gcloud CLI installed (for Option A)

---

## Option A: gcloud Application Default Credentials (Development)

**Best for**: Local development, personal projects, quick testing

### Step 1: Install gcloud CLI

**macOS**:
```bash
# Using Homebrew
brew install google-cloud-sdk

# Verify installation
gcloud --version
```

**Linux**:
```bash
# Download and install
curl https://sdk.cloud.google.com | bash

# Restart shell
exec -l $SHELL

# Verify installation
gcloud --version
```

**Windows**:
```powershell
# Download installer from:
# https://cloud.google.com/sdk/docs/install

# After installation, verify:
gcloud --version
```

### Step 2: Initialize gcloud

```bash
# Initialize gcloud (opens browser for authentication)
gcloud init

# Follow prompts to:
# 1. Log in with your Google account
# 2. Select or create a project
# 3. Choose default region (us-central1 recommended)
```

### Step 3: Set Up Application Default Credentials

```bash
# Authenticate for application access
gcloud auth application-default login

# This opens browser and stores credentials in:
# - macOS/Linux: ~/.config/gcloud/application_default_credentials.json
# - Windows: %APPDATA%\gcloud\application_default_credentials.json
```

### Step 4: Configure Default Project

```bash
# Set your project as default
gcloud config set project YOUR_PROJECT_ID

# Verify configuration
gcloud config list

# Expected output:
# [core]
# account = your-email@gmail.com
# project = your-project-id
```

### Step 5: Verify Authentication

```bash
# Test authentication by getting an access token
gcloud auth application-default print-access-token

# Should output a long token string like:
# ya29.a0AfH6SMDY...
```

### Step 6: Enable Vertex AI API

```bash
# Enable the API (if not already enabled)
gcloud services enable aiplatform.googleapis.com

# Verify it's enabled
gcloud services list --enabled | grep aiplatform
```

### Troubleshooting gcloud Auth

**Issue**: "Could not find a valid project"
```bash
# List available projects
gcloud projects list

# Set specific project
gcloud config set project PROJECT_ID
```

**Issue**: "Application Default Credentials are not available"
```bash
# Re-run authentication
gcloud auth application-default login

# Or set explicit path
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/application_default_credentials.json
```

**Issue**: Token expired
```bash
# Revoke and re-authenticate
gcloud auth application-default revoke
gcloud auth application-default login
```

---

## Option B: Service Account (Production)

**Best for**: Production deployments, CI/CD pipelines, team environments

### Step 1: Create Service Account

```bash
# Set variables
export PROJECT_ID="your-project-id"
export SA_NAME="litellm-sa"
export SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create service account
gcloud iam service-accounts create $SA_NAME \
  --display-name="LiteLLM Service Account" \
  --description="Service account for LiteLLM Vertex AI access"

# Verify creation
gcloud iam service-accounts list | grep $SA_NAME
```

### Step 2: Grant IAM Permissions

```bash
# Grant Vertex AI User role (minimum required)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/aiplatform.user"

# Optional: Grant additional roles for monitoring/logging
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/logging.logWriter"
```

**IAM Roles Explained**:
- `roles/aiplatform.user`: **Required** - Access Vertex AI models
- `roles/logging.logWriter`: **Optional** - Write logs to Cloud Logging
- `roles/monitoring.metricWriter`: **Optional** - Write metrics to Cloud Monitoring

### Step 3: Create and Download Key

```bash
# Create key file
gcloud iam service-accounts keys create ~/litellm-sa-key.json \
  --iam-account=$SA_EMAIL

# Secure the key file
chmod 600 ~/litellm-sa-key.json

# Verify key contents
cat ~/litellm-sa-key.json | jq .client_email
# Should output: litellm-sa@your-project-id.iam.gserviceaccount.com
```

### Step 4: Set Environment Variable

**Linux/macOS**:
```bash
# Set for current session
export GOOGLE_APPLICATION_CREDENTIALS=~/litellm-sa-key.json

# Make persistent (add to ~/.bashrc or ~/.zshrc)
echo 'export GOOGLE_APPLICATION_CREDENTIALS=~/litellm-sa-key.json' >> ~/.bashrc
source ~/.bashrc
```

**Windows (PowerShell)**:
```powershell
# Set for current session
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\litellm-sa-key.json"

# Make persistent (user-level)
[System.Environment]::SetEnvironmentVariable(
  'GOOGLE_APPLICATION_CREDENTIALS',
  'C:\path\to\litellm-sa-key.json',
  'User'
)
```

### Step 5: Verify Service Account Authentication

```bash
# Test authentication with Python
python3 << EOF
from google.cloud import aiplatform
from google.auth import default

credentials, project = default()
print(f"✓ Authenticated as: {credentials.service_account_email}")
print(f"✓ Project: {project}")
EOF
```

### Troubleshooting Service Account

**Issue**: "Permission denied"
```bash
# Check IAM bindings
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}"

# Should show: roles/aiplatform.user

# If missing, re-grant:
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/aiplatform.user"
```

**Issue**: "Key file not found"
```bash
# Verify file exists
ls -lh $GOOGLE_APPLICATION_CREDENTIALS

# Check environment variable is set
echo $GOOGLE_APPLICATION_CREDENTIALS

# Re-export if needed
export GOOGLE_APPLICATION_CREDENTIALS=/full/path/to/key.json
```

**Issue**: "Invalid key JSON"
```bash
# Validate JSON format
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .

# If error, re-download key:
gcloud iam service-accounts keys create ~/litellm-sa-key-new.json \
  --iam-account=$SA_EMAIL
```

---

## Comparison: gcloud Auth vs Service Account

| Feature | gcloud Auth | Service Account |
|---------|-------------|-----------------|
| **Setup Time** | 5 minutes | 10 minutes |
| **Best For** | Development | Production |
| **Credential Management** | Automatic | Manual (key file) |
| **Token Refresh** | Automatic | Automatic |
| **Portability** | Per-user | Cross-environment |
| **Security** | User-level | Fine-grained IAM |
| **CI/CD Support** | ❌ No | ✅ Yes |
| **Team Sharing** | ❌ No | ✅ Yes |

**Recommendation**:
- **Development**: Use gcloud auth for simplicity
- **Production**: Use service accounts for security and portability
- **CI/CD**: Must use service accounts

---

## Security Best Practices

### ✅ DO

1. **Rotate service account keys regularly**
   ```bash
   # Create new key
   gcloud iam service-accounts keys create ~/new-key.json \
     --iam-account=$SA_EMAIL
   
   # Update GOOGLE_APPLICATION_CREDENTIALS
   export GOOGLE_APPLICATION_CREDENTIALS=~/new-key.json
   
   # Delete old key (get KEY_ID from list command)
   gcloud iam service-accounts keys list --iam-account=$SA_EMAIL
   gcloud iam service-accounts keys delete KEY_ID --iam-account=$SA_EMAIL
   ```

2. **Use least-privilege IAM roles**
   ```bash
   # Minimum required role
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:${SA_EMAIL}" \
     --role="roles/aiplatform.user"  # Not roles/owner or roles/editor
   ```

3. **Secure key files with proper permissions**
   ```bash
   chmod 600 ~/litellm-sa-key.json  # Owner read/write only
   ```

4. **Use Google Secret Manager for production**
   ```bash
   # Store key in Secret Manager
   gcloud secrets create litellm-sa-key \
     --data-file=~/litellm-sa-key.json
   
   # Grant access to specific service account
   gcloud secrets add-iam-policy-binding litellm-sa-key \
     --member="serviceAccount:${SA_EMAIL}" \
     --role="roles/secretmanager.secretAccessor"
   ```

### ❌ DON'T

1. **Never commit service account keys to git**
   ```bash
   # Add to .gitignore
   echo "*-sa-key.json" >> .gitignore
   echo "*.json" >> .gitignore  # Be careful with this
   ```

2. **Don't use overly permissive roles**
   ```bash
   # ❌ BAD: Too much access
   # roles/owner
   # roles/editor
   
   # ✅ GOOD: Specific access
   # roles/aiplatform.user
   ```

3. **Don't share service account keys**
   - Create separate service accounts per environment/team
   - Use Workload Identity for GKE/Cloud Run

4. **Don't store keys in plain text**
   - Use secret managers (Google Secret Manager, HashiCorp Vault)
   - Avoid environment variables in production (use mounted secrets)

---

## Verification

Run this comprehensive check:

```bash
cd specs/001-llm-gateway-config

# Run prerequisite checker
./scripts/check-prerequisites.sh

# Should show:
# ✓ gcloud CLI installed (or)
# ✓ Service account credentials file found
# ✓ Vertex AI API is enabled
# ✓ Project has billing enabled
```

---

## Next Steps

Once authentication is configured:

1. **Continue with quickstart**: [us1-quickstart-basic.md](./us1-quickstart-basic.md)
2. **Configure LiteLLM**: Edit `litellm-complete.yaml` with your project ID
3. **Test models**: Run `python3 tests/test-all-models.py`

---

## Related Documentation

- [Environment Variables Setup](./us1-env-vars-setup.md)
- [Troubleshooting Guide](./us1-troubleshooting.md)
- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs)
- [Vertex AI Authentication](https://cloud.google.com/vertex-ai/docs/authentication)
