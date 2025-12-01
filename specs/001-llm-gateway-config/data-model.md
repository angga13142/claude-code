# Data Model: LLM Gateway Configuration Assistant

**Feature**: 001-llm-gateway-config  
**Date**: 2025-12-01  
**Status**: Draft

---

## Overview

This document defines the logical data entities for the LLM Gateway Configuration Assistant. Since this is primarily a configuration guidance system (not a data-storage application), entities represent conceptual configuration objects rather than database tables.

---

## Core Entities

### 1. Gateway Configuration

Represents the complete setup for connecting Claude Code to an LLM gateway.

**Attributes:**

- **gateway_url** (string, required): Base URL of the LLM gateway (e.g., "http://localhost:4000")
- **authentication_token** (string, required): API key or auth token for gateway access
- **gateway_type** (enum, required): Type of gateway solution
  - Values: `litellm`, `truefoundry`, `zuplo`, `mintmcp`, `custom`
- **deployment_pattern** (enum, required): Architecture approach
  - Values: `direct`, `proxy`, `gateway`, `proxy_gateway`
- **configuration_level** (enum, required): Scope of configuration
  - Values: `user`, `project`, `environment`
- **created_at** (timestamp): When configuration was created
- **last_verified_at** (timestamp): Last successful verification via `/status`

**Relationships:**

- Has many: Model Deployments
- Has one: Authentication Method
- May have many: Provider Configurations

**Validation Rules:**

- `gateway_url` must be valid HTTP/HTTPS URL
- `authentication_token` must not be empty if gateway requires auth
- `gateway_type = litellm` requires at least one Model Deployment

---

### 2. Model Deployment

Represents a specific model configuration within a gateway.

**Attributes:**

- **model_name** (string, required): Logical name exposed by gateway (e.g., "gemini-2.5-flash")
- **provider_model_id** (string, required): Full provider-specific identifier
  - Format: `vertex_ai/<publisher>/<model-id>` or `vertex_ai/<model-id>`
  - Examples:
    - `vertex_ai/gemini-2.5-flash`
    - `vertex_ai/deepseek-ai/deepseek-r1-0528-maas`
- **publisher** (string, required): Model publisher
  - Values: `google`, `deepseek`, `meta`, `mistral`, `qwen`, `openai`, `custom`
- **vertex_project_id** (string, required for Vertex AI): GCP project ID
- **vertex_location** (string, required for Vertex AI): GCP region
  - Examples: `us-central1`, `us-east1`, `europe-west1`
- **rate_limits** (object): Throttling configuration
  - **rpm** (integer): Requests per minute limit
  - **tpm** (integer): Tokens per minute limit
- **capabilities** (object): Model-specific features
  - **supports_function_calling** (boolean)
  - **supports_vision** (boolean)
  - **supports_reasoning** (boolean)
  - **supports_fim** (boolean): Fill-in-middle for code completion
  - **max_context_tokens** (integer)
  - **max_output_tokens** (integer)
- **priority** (integer, 1-10): Load balancing weight (higher = preferred)
- **enabled** (boolean, default: true): Whether deployment is active

**Relationships:**

- Belongs to: Gateway Configuration
- May have one: Fallback Model Deployment (for failover)

**Validation Rules:**

- `model_name` must be unique within a Gateway Configuration
- `vertex_location` must be a valid GCP region where model is available
- `rpm` and `tpm` must be positive integers if specified
- `priority` must be between 1-10

---

### 3. Provider Configuration

Represents provider-specific settings (Bedrock, Vertex AI, etc.).

**Attributes:**

- **provider_name** (enum, required): Cloud provider
  - Values: `anthropic`, `bedrock`, `vertex_ai`
- **base_url** (string): Custom provider endpoint URL
  - For Vertex AI: Optional if using default endpoints
  - For Bedrock: `ANTHROPIC_BEDROCK_BASE_URL` value
- **authentication_bypass** (boolean, default: false): Skip provider auth when using gateway
  - Corresponds to: `CLAUDE_CODE_SKIP_BEDROCK_AUTH`, `CLAUDE_CODE_SKIP_VERTEX_AUTH`
- **region** (string): Provider-specific region
  - Bedrock: AWS region (e.g., `us-west-2`)
  - Vertex AI: GCP location (e.g., `us-central1`)
- **credentials_path** (string): Path to service account JSON (Vertex AI) or AWS credentials

**Relationships:**

- Belongs to: Gateway Configuration
- May support multiple: Model Deployments

**Validation Rules:**

- `authentication_bypass = true` requires gateway to handle authentication
- `credentials_path` must point to readable file if specified
- `region` must be valid for the specified provider

---

### 4. Authentication Method

Represents how the gateway authenticates requests.

**Attributes:**

- **auth_type** (enum, required): Authentication mechanism
  - Values: `bearer_token`, `api_key`, `service_account`, `gcloud_auth`, `none`
- **token_source** (enum): Where auth credentials come from
  - Values: `environment_variable`, `file`, `secret_manager`, `hardcoded`
- **environment_variable_name** (string): Env var containing token (if applicable)
  - Default: `ANTHROPIC_AUTH_TOKEN`
- **secret_manager_path** (string): Path in secret manager (if applicable)
- **rotation_policy** (object): Credential rotation settings
  - **enabled** (boolean)
  - **interval_days** (integer): How often to rotate (e.g., 90 days)

**Relationships:**

- Belongs to: Gateway Configuration

**Validation Rules:**

- `token_source = environment_variable` requires `environment_variable_name`
- `token_source = secret_manager` requires `secret_manager_path`
- `rotation_policy.interval_days` should not exceed 365 for security

---

### 5. Routing Strategy

Represents load balancing and fallback configuration.

**Attributes:**

- **strategy_type** (enum, required): Routing algorithm
  - Values: `simple_shuffle`, `least_busy`, `usage_based`, `latency_based`
- **fallback_chain** (array of strings): Ordered list of model names to try
  - Example: `["gemini-2.5-pro", "gemini-2.5-flash"]`
- **retry_policy** (object): How to handle failures
  - **max_retries** (integer, default: 3)
  - **timeout_seconds** (integer, default: 30)
  - **retry_on_errors** (array of strings): Which error types to retry
    - Values: `timeout`, `rate_limit`, `server_error`, `auth_error`
- **health_check_enabled** (boolean, default: true): Enable endpoint health monitoring
- **cooldown_period_seconds** (integer, default: 60): Time to wait before retrying failed endpoint

**Relationships:**

- Belongs to: Gateway Configuration
- References many: Model Deployments (via fallback chain)

**Validation Rules:**

- `max_retries` must be between 0-10
- `timeout_seconds` must be positive
- Models in `fallback_chain` must exist in Model Deployments
- `retry_on_errors` should not include `auth_error` (retries won't fix auth issues)

---

### 6. Verification Result

Represents the outcome of configuration verification.

**Attributes:**

- **verified_at** (timestamp, required): When verification was performed
- **verification_method** (enum, required): How it was verified
  - Values: `claude_status`, `gateway_health`, `end_to_end_test`, `manual`
- **status** (enum, required): Verification outcome
  - Values: `success`, `warning`, `failure`
- **base_url_reachable** (boolean): Whether gateway URL responds
- **auth_valid** (boolean): Whether authentication succeeds
- **model_accessible** (boolean): Whether model completion works
- **latency_ms** (integer): Response time in milliseconds
- **error_message** (string): Details if status = failure
- **warnings** (array of strings): Non-fatal issues detected

**Relationships:**

- Belongs to: Gateway Configuration

**Validation Rules:**

- `status = success` requires all boolean flags to be true
- `status = failure` requires `error_message` to be populated
- `latency_ms` should be measured for successful verifications

---

## Entity Relationships Diagram

```
Gateway Configuration (1)
  ├─ has many ──> Model Deployment (n)
  │                └─ may have one ──> Fallback Model Deployment
  ├─ has one ───> Authentication Method (1)
  ├─ may have many ──> Provider Configuration (n)
  ├─ has one ───> Routing Strategy (1)
  └─ has many ──> Verification Result (n)
```

---

## Derived Entities (Computed from configuration)

### Configuration Template

Not stored, but generated from user requirements assessment.

**Inputs:**

- Team size (1-10, 10-100, 100+)
- Security requirements (basic, enterprise, compliance)
- Multi-provider needs (yes/no)
- Cost tracking priority (low, medium, high)

**Outputs:**

- Recommended gateway type
- Suggested deployment pattern
- Configuration YAML skeleton
- Required environment variables

### Troubleshooting Diagnostic

Computed from verification results and error patterns.

**Inputs:**

- Verification Result with status = failure
- Error message text
- Gateway Configuration details

**Outputs:**

- Root cause analysis
- Suggested resolution steps
- Related documentation links
- Alternative configuration options

---

## Example Instances

### Example 1: Basic LiteLLM Local Gateway

```json
{
  "gateway_configuration": {
    "gateway_url": "http://localhost:4000",
    "authentication_token": "sk-litellm-dev-key",
    "gateway_type": "litellm",
    "deployment_pattern": "gateway",
    "configuration_level": "user"
  },
  "model_deployments": [
    {
      "model_name": "gemini-2.5-flash",
      "provider_model_id": "vertex_ai/gemini-2.5-flash",
      "publisher": "google",
      "vertex_project_id": "my-project-123",
      "vertex_location": "us-central1",
      "rate_limits": {"rpm": 1000, "tpm": 100000},
      "capabilities": {
        "supports_function_calling": true,
        "supports_vision": true,
        "max_context_tokens": 1048576,
        "max_output_tokens": 8192
      },
      "priority": 10,
      "enabled": true
    }
  ],
  "authentication_method": {
    "auth_type": "bearer_token",
    "token_source": "environment_variable",
    "environment_variable_name": "ANTHROPIC_AUTH_TOKEN"
  },
  "routing_strategy": {
    "strategy_type": "simple_shuffle",
    "fallback_chain": ["gemini-2.5-flash"],
    "retry_policy": {
      "max_retries": 3,
      "timeout_seconds": 30,
      "retry_on_errors": ["timeout", "rate_limit", "server_error"]
    }
  }
}
```

### Example 2: Enterprise Multi-Provider Setup

```json
{
  "gateway_configuration": {
    "gateway_url": "https://litellm-gateway.company.com",
    "authentication_token": "{{SECRET_MANAGER_TOKEN}}",
    "gateway_type": "litellm",
    "deployment_pattern": "proxy_gateway",
    "configuration_level": "project"
  },
  "model_deployments": [
    {
      "model_name": "gemini-2.5-pro-us",
      "provider_model_id": "vertex_ai/gemini-2.5-pro",
      "publisher": "google",
      "vertex_project_id": "prod-project-456",
      "vertex_location": "us-central1",
      "rate_limits": {"rpm": 5000, "tpm": 500000},
      "priority": 10,
      "enabled": true
    },
    {
      "model_name": "gemini-2.5-pro-eu",
      "provider_model_id": "vertex_ai/gemini-2.5-pro",
      "publisher": "google",
      "vertex_project_id": "prod-project-456",
      "vertex_location": "europe-west1",
      "rate_limits": {"rpm": 5000, "tpm": 500000},
      "priority": 8,
      "enabled": true
    },
    {
      "model_name": "deepseek-r1",
      "provider_model_id": "vertex_ai/deepseek-ai/deepseek-r1-0528-maas",
      "publisher": "deepseek",
      "vertex_project_id": "prod-project-456",
      "vertex_location": "us-central1",
      "rate_limits": {"rpm": 1000, "tpm": 100000},
      "priority": 5,
      "enabled": true
    }
  ],
  "provider_configurations": [
    {
      "provider_name": "vertex_ai",
      "authentication_bypass": true,
      "region": "us-central1",
      "credentials_path": "/etc/secrets/gcp-service-account.json"
    }
  ],
  "authentication_method": {
    "auth_type": "bearer_token",
    "token_source": "secret_manager",
    "secret_manager_path": "projects/123/secrets/litellm-token/versions/latest",
    "rotation_policy": {
      "enabled": true,
      "interval_days": 90
    }
  },
  "routing_strategy": {
    "strategy_type": "latency_based",
    "fallback_chain": [
      "gemini-2.5-pro-us",
      "gemini-2.5-pro-eu",
      "deepseek-r1"
    ],
    "retry_policy": {
      "max_retries": 5,
      "timeout_seconds": 45,
      "retry_on_errors": ["timeout", "rate_limit", "server_error"]
    },
    "health_check_enabled": true,
    "cooldown_period_seconds": 120
  }
}
```

---

## State Transitions

### Gateway Configuration States

1. **Draft** → Configuration created but not verified
2. **Verified** → Successfully tested via `/status` or end-to-end test
3. **Active** → Currently in use by Claude Code
4. **Warning** → Working but with non-fatal issues (e.g., high latency, approaching rate limits)
5. **Failed** → Verification failed, not usable
6. **Deprecated** → Old configuration, user should migrate

### Model Deployment States

1. **Enabled** → Available for routing
2. **Cooldown** → Temporarily disabled after failures, will retry after cooldown period
3. **Disabled** → Manually disabled by user
4. **Unavailable** → Provider reports model not accessible (quota, permissions, etc.)

---

## Implementation Notes

### Configuration Storage

- **User-level**: `~/.claude/settings.json` (JSON format)
- **Project-level**: `.claude/settings.json` (JSON format, can be committed to git)
- **Gateway-level**: `litellm_config.yaml` (YAML format, read by LiteLLM proxy)

### Configuration Mapping

Claude Code settings.json → LiteLLM YAML mapping:

```javascript
// Claude Code settings.json
{
  "anthropic": {
    "baseURL": "http://localhost:4000",  // → Gateway Configuration.gateway_url
    "authToken": "sk-1234"               // → Authentication Method.token
  }
}
```

```yaml
# LiteLLM config.yaml (generated from Model Deployments)
model_list:
  - model_name: gemini-2.5-flash        # ← Model Deployment.model_name
    litellm_params:
      model: vertex_ai/gemini-2.5-flash # ← Model Deployment.provider_model_id
      vertex_ai_project: my-project      # ← Model Deployment.vertex_project_id
      vertex_ai_location: us-central1    # ← Model Deployment.vertex_location
```

---

**Data Model Status**: ✅ Complete  
**Next**: Create API contracts defining configuration endpoints and verification procedures
