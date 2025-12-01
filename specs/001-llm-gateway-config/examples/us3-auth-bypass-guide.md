# US3: Authentication Bypass Use Cases Guide

**User Story**: US3 - Multi-Provider Gateway Configuration (Priority: P3)  
**Purpose**: Understand when and how to use authentication bypass flags  
**Audience**: Platform engineers, DevOps teams

---

## Overview

When using LiteLLM as a gateway between Claude Code and cloud providers (Bedrock, Vertex AI), authentication bypass flags allow centralized credential management. This guide explains when to use these flags, how they work, and best practices.

---

## What Are Authentication Bypass Flags?

### Available Flags

| Flag                            | Purpose                                       | Value                  |
| ------------------------------- | --------------------------------------------- | ---------------------- |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | Skip Claude Code's AWS Bedrock authentication | `1`, `true`, or `True` |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH`  | Skip Claude Code's Vertex AI authentication   | `1`, `true`, or `True` |

### How They Work

**Without Bypass** (Direct Provider Access):

```
┌─────────────┐
│ Claude Code │ ← Authenticates directly to each provider
│             │ ← Manages AWS/GCP credentials
└──────┬──────┘
       │
       ├──────→ AWS Bedrock (via AWS SDK + credentials)
       └──────→ Vertex AI (via GCP SDK + credentials)
```

**With Bypass** (Gateway Pattern):

```
┌─────────────┐
│ Claude Code │ ← Skips provider-specific auth
│             │ ← Uses gateway URL + master key only
└──────┬──────┘
       │ (ANTHROPIC_BASE_URL=localhost:4000)
       │ (ANTHROPIC_API_KEY=litellm-key)
       ▼
┌──────────────┐
│   LiteLLM    │ ← Handles ALL provider authentication
│   Gateway    │ ← Manages AWS/GCP credentials centrally
└──────┬───────┘
       │
       ├──────→ AWS Bedrock (gateway authenticates)
       └──────→ Vertex AI (gateway authenticates)
```

---

## Use Case 1: Development with LiteLLM Gateway

### Scenario

- Developer running local LiteLLM proxy
- Wants to test multi-provider routing
- Has credentials for AWS/GCP configured in gateway

### Configuration

**Environment Variables**:

```bash
# LiteLLM Gateway
export LITELLM_MASTER_KEY="sk-local-dev-key"
export AWS_REGION="us-east-1"
export AWS_PROFILE="dev"
export VERTEX_PROJECT_ID="my-dev-project"
export VERTEX_LOCATION="us-central1"

# Claude Code Integration
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"

# Bypass flags
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

**LiteLLM Config** (litellm-dev.yaml):

```yaml
model_list:
  - model_name: claude-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: os.environ/AWS_REGION

  - model_name: claude-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: os.environ/VERTEX_LOCATION
```

**Benefits**:

- ✅ Single authentication point (LiteLLM)
- ✅ No need to configure AWS/GCP credentials in Claude Code
- ✅ Easy to switch between providers
- ✅ Simplified local development

**Verification**:

```bash
# Start gateway
litellm --config litellm-dev.yaml --port 4000

# Test with Claude Code
claude /status

# Run bypass test
bash tests/test-auth-bypass.sh
```

---

## Use Case 2: Enterprise Gateway Integration

### Scenario

- Company has centralized API gateway (TrueFoundry, Zuplo, custom)
- Gateway handles authentication for all downstream services
- Claude Code users should NOT manage cloud credentials

### Configuration

**Environment Variables**:

```bash
# Enterprise gateway
export ANTHROPIC_BASE_URL="https://api-gateway.company.com/claude"
export ANTHROPIC_API_KEY="company-api-token"

# Bypass ALL provider auth (gateway handles it)
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

**Gateway Configuration** (managed by platform team):

```yaml
# Gateway handles:
# - Authentication to Bedrock/Vertex AI
# - Rate limiting
# - Cost tracking
# - Compliance logging

# Claude Code users only need gateway token
```

**Benefits**:

- ✅ Centralized credential management
- ✅ Users don't need cloud accounts
- ✅ Consistent security policies
- ✅ Simplified onboarding
- ✅ Audit trail in gateway

**Architecture**:

```
[User] → [Claude Code] → [Enterprise Gateway] → [Bedrock/Vertex AI]
                          ↑
                          Handles all authentication
```

---

## Use Case 3: CI/CD Pipeline

### Scenario

- Automated tests/builds use Claude Code
- Credentials managed via secret managers
- Need consistent authentication across environments

### Configuration

**GitLab CI Example**:

```yaml
# .gitlab-ci.yml
test:
  script:
    - export ANTHROPIC_BASE_URL="http://litellm-gateway:4000"
    - export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY" # From GitLab secrets
    - export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
    - export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
    - claude analyze-code
  services:
    - name: litellm/litellm:latest
      alias: litellm-gateway
```

**GitHub Actions Example**:

```yaml
# .github/workflows/test.yml
jobs:
  test:
    steps:
      - name: Setup LiteLLM Gateway
        run: |
          litellm --config .github/litellm-ci.yaml --port 4000 &
          sleep 5

      - name: Run Claude Code Tests
        env:
          ANTHROPIC_BASE_URL: http://localhost:4000
          ANTHROPIC_API_KEY: ${{ secrets.LITELLM_MASTER_KEY }}
          CLAUDE_CODE_SKIP_BEDROCK_AUTH: 1
          CLAUDE_CODE_SKIP_VERTEX_AUTH: 1
        run: |
          claude /status
          claude run-tests
```

**Benefits**:

- ✅ Credentials managed in secret stores
- ✅ No credential files in repositories
- ✅ Consistent authentication pattern
- ✅ Easy to rotate credentials

---

## Use Case 4: Multi-Tenant SaaS

### Scenario

- SaaS platform offers Claude Code access to customers
- Platform manages all provider credentials
- Customers should NOT see/manage cloud credentials

### Configuration

**Platform Setup**:

```python
# Platform backend
def create_user_gateway_token(user_id: str) -> str:
    # Generate user-specific LiteLLM token
    return generate_token(user_id, scopes=["chat:read", "chat:write"])

def setup_user_environment(user_id: str) -> dict:
    return {
        "ANTHROPIC_BASE_URL": "https://gateway.saas.com/v1",
        "ANTHROPIC_API_KEY": create_user_gateway_token(user_id),
        "CLAUDE_CODE_SKIP_BEDROCK_AUTH": "1",
        "CLAUDE_CODE_SKIP_VERTEX_AUTH": "1"
    }
```

**User Experience**:

```bash
# User receives these values from platform
export ANTHROPIC_BASE_URL="https://gateway.saas.com/v1"
export ANTHROPIC_API_KEY="usr-token-abc123"  # User-specific token
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1

# User can immediately use Claude Code without cloud accounts
claude /status  # Works!
```

**Benefits**:

- ✅ Users never see cloud credentials
- ✅ Platform controls cost/usage per user
- ✅ Centralized billing
- ✅ Simplified user onboarding

---

## Use Case 5: Compliance-Segregated Environments

### Scenario

- Different teams use different cloud providers for compliance
- Team A: AWS Bedrock (HIPAA workloads)
- Team B: Vertex AI (standard workloads)
- Gateway routes based on team/project

### Configuration

**Team A (HIPAA)**:

```bash
export ANTHROPIC_BASE_URL="https://hipaa-gateway.company.com"
export ANTHROPIC_API_KEY="team-a-token"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1  # Not used, but set for consistency
```

**Team B (Standard)**:

```bash
export ANTHROPIC_BASE_URL="https://standard-gateway.company.com"
export ANTHROPIC_API_KEY="team-b-token"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

**Gateway Routing Logic**:

```python
# hipaa-gateway routes to Bedrock only
if user_team == "team-a":
    provider = "bedrock"
    region = "us-east-1"  # HIPAA-eligible region
    enforce_baa = True

# standard-gateway routes to Vertex AI
elif user_team == "team-b":
    provider = "vertex_ai"
    region = "us-central1"
    enforce_baa = False
```

**Benefits**:

- ✅ Compliance boundaries enforced at gateway
- ✅ Users can't accidentally use wrong provider
- ✅ Audit trail per team
- ✅ Simplified compliance certification

---

## When NOT to Use Bypass Flags

### Scenario 1: Direct Provider Access

**Don't use bypass** if Claude Code directly accesses Bedrock/Vertex AI:

```bash
# Direct Bedrock access (no gateway)
export AWS_REGION="us-east-1"
export AWS_PROFILE="bedrock"
# ❌ DON'T set CLAUDE_CODE_SKIP_BEDROCK_AUTH

claude /status  # Uses AWS credentials directly
```

**Why**: Claude Code needs its own authentication to reach the provider

---

### Scenario 2: Single Provider (Anthropic Direct)

**Don't use bypass** if only using Anthropic Direct API:

```bash
# Anthropic Direct (no gateway)
export ANTHROPIC_API_KEY="sk-ant-..."
# ❌ DON'T set bypass flags (not applicable)

claude /status  # Uses Anthropic API key directly
```

**Why**: Bypass flags only apply to Bedrock/Vertex AI

---

### Scenario 3: Testing Provider-Specific Features

**Don't use bypass** if testing Claude Code's native provider integrations:

```bash
# Testing Bedrock-specific features
export AWS_REGION="us-east-1"
# ❌ DON'T set bypass - need native integration

claude test-bedrock-integration
```

**Why**: Some features require Claude Code's native provider SDKs

---

## Security Considerations

### 1. Gateway Token Security

**Risk**: Gateway tokens have broad access (all providers)

**Mitigation**:

```bash
# Use scoped tokens where possible
export ANTHROPIC_API_KEY="token-with-limited-scope"

# Rotate tokens regularly
# Set expiration on gateway tokens
```

---

### 2. Network Security

**Risk**: Gateway endpoint exposed without TLS

**Mitigation**:

```bash
# ✅ Always use HTTPS in production
export ANTHROPIC_BASE_URL="https://gateway.company.com"  # NOT http://

# ❌ HTTP only acceptable for localhost development
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

---

### 3. Credential Leakage

**Risk**: Bypass flags set, but gateway credentials leaked

**Mitigation**:

- Store gateway tokens in secret managers
- Never commit tokens to version control
- Monitor for unauthorized access
- Implement rate limiting at gateway

---

## Troubleshooting

### Issue: Bypass flag set, but authentication still fails

**Symptom**:

```
❌ ERROR: Authentication failed for Bedrock
```

**Diagnosis**:

```bash
# Check if flag is actually set
echo $CLAUDE_CODE_SKIP_BEDROCK_AUTH  # Should be "1"

# Check gateway is accessible
curl $ANTHROPIC_BASE_URL/health

# Check Claude Code is using gateway
claude /status  # Should show gateway URL
```

**Solution**:

```bash
# Ensure flag value is correct
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1  # Or "true" or "True"

# Restart Claude Code session
exec $SHELL  # Reload environment
```

---

### Issue: Gateway authenticates successfully, Claude Code fails

**Symptom**:

```
✓ Gateway health check passed
❌ Claude Code cannot connect
```

**Diagnosis**:

```bash
# Test gateway directly
curl -X POST $ANTHROPIC_BASE_URL/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'

# If gateway works but Claude Code doesn't, check base URL
echo $ANTHROPIC_BASE_URL  # Should match gateway
```

**Solution**:

```bash
# Verify ALL required env vars
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

---

## Best Practices

### 1. Document Gateway Configuration

````markdown
# Team Wiki: Claude Code Setup

## For Developers

1. Install Claude Code
2. Set environment variables:
   ```bash
   export ANTHROPIC_BASE_URL="https://gateway.company.com"
   export ANTHROPIC_API_KEY="<get-from-1password>"
   export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
   export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
   ```
````

3. Verify: `claude /status`

````

---

### 2. Automate Environment Setup

```bash
# setup-claude-gateway.sh
#!/bin/bash
set -euo pipefail

echo "Setting up Claude Code with company gateway..."

# Check prerequisites
if [ -z "${COMPANY_API_TOKEN:-}" ]; then
    echo "❌ COMPANY_API_TOKEN not set. Get it from: https://internal.company.com/tokens"
    exit 1
fi

# Configure environment
export ANTHROPIC_BASE_URL="https://gateway.company.com"
export ANTHROPIC_API_KEY="$COMPANY_API_TOKEN"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1

# Persist to shell config
cat >> ~/.bashrc << 'EOF'
export ANTHROPIC_BASE_URL="https://gateway.company.com"
export ANTHROPIC_API_KEY="$COMPANY_API_TOKEN"
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
EOF

echo "✅ Configuration complete!"
claude /status
````

---

### 3. Monitor Gateway Usage

```python
# Gateway monitoring
def log_request(user_id: str, provider: str, cost: float):
    metrics.increment("gateway.requests", tags={"user": user_id, "provider": provider})
    metrics.histogram("gateway.cost", cost, tags={"provider": provider})

    # Alert on anomalies
    if cost > 1.0:  # $1 per request is high
        alert("High cost request detected", user_id=user_id, cost=cost)
```

---

## Quick Reference

### Bypass Flags Summary

| Flag                              | When to Use                                | When NOT to Use                         |
| --------------------------------- | ------------------------------------------ | --------------------------------------- |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH=1` | Using LiteLLM/gateway routing to Bedrock   | Direct Bedrock access without gateway   |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH=1`  | Using LiteLLM/gateway routing to Vertex AI | Direct Vertex AI access without gateway |

### Environment Variable Checklist

For gateway-based authentication:

- [ ] `ANTHROPIC_BASE_URL` = gateway URL
- [ ] `ANTHROPIC_API_KEY` = gateway token (NOT provider API key)
- [ ] `CLAUDE_CODE_SKIP_BEDROCK_AUTH=1` (if gateway routes to Bedrock)
- [ ] `CLAUDE_CODE_SKIP_VERTEX_AUTH=1` (if gateway routes to Vertex AI)

---

## Additional Resources

- [examples/us3-multi-provider-setup.md](./us3-multi-provider-setup.md) - Complete setup guide
- [examples/us3-provider-env-vars.md](./us3-provider-env-vars.md) - All environment variables
- [tests/test-auth-bypass.sh](../tests/test-auth-bypass.sh) - Verification script
- [templates/multi-provider/](../templates/multi-provider/) - Configuration templates
