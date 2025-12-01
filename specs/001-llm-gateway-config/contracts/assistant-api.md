# Configuration Assistant API Contract

**Feature**: 001-llm-gateway-config  
**Version**: 1.0.0  
**Date**: 2025-12-01

---

## Overview

This contract defines the interaction interface for the LLM Gateway Configuration Assistant. Since this is an assistive system (not a REST API), the contract specifies input prompts, expected outputs, and verification procedures rather than HTTP endpoints.

---

## Assistant Interaction Contract

### 1. Gateway Setup Request

**User Intent**: "How do I set up LiteLLM with Claude Code?"

**Input Contract**:

```typescript
interface SetupRequest {
  gateway_type?: "litellm" | "truefoundry" | "zuplo" | "mintmcp" | "custom";
  environment?: "development" | "staging" | "production";
  use_case?: "personal" | "team" | "enterprise";
}
```

**Output Contract**:

```typescript
interface SetupResponse {
  quick_answer: string;  // 2-3 sentence summary
  configuration_block: {
    yaml_config: string;          // Complete litellm_config.yaml
    environment_variables: {
      name: string;
      value: string;
      description: string;
    }[];
    startup_commands: string[];   // Commands to start gateway
  };
  verification_steps: {
    step_number: number;
    command: string;
    expected_output: string;
    success_criteria: string;
  }[];
  additional_context?: {
    security_warnings: string[];
    third_party_notice?: string;
    documentation_links: string[];
  };
}
```

**Example Output**:

```json
{
  "quick_answer": "Configure LiteLLM as a local proxy, then point Claude Code to it via environment variables.",
  "configuration_block": {
    "yaml_config": "model_list:\n  - model_name: claude-sonnet-4.5\n    litellm_params:\n      model: anthropic/claude-sonnet-4.5\n      api_key: os.environ/ANTHROPIC_API_KEY\n\nlitellm_settings:\n  master_key: os.environ/LITELLM_MASTER_KEY",
    "environment_variables": [
      {
        "name": "ANTHROPIC_API_KEY",
        "value": "your-anthropic-api-key",
        "description": "Your Anthropic API key for model access"
      },
      {
        "name": "LITELLM_MASTER_KEY",
        "value": "sk-generated-key",
        "description": "Master key for authenticating to LiteLLM proxy"
      },
      {
        "name": "ANTHROPIC_BASE_URL",
        "value": "http://localhost:4000",
        "description": "Point Claude Code to LiteLLM proxy"
      },
      {
        "name": "ANTHROPIC_AUTH_TOKEN",
        "value": "$LITELLM_MASTER_KEY",
        "description": "Use LiteLLM master key for Claude Code auth"
      }
    ],
    "startup_commands": [
      "export ANTHROPIC_API_KEY=\"your-key\"",
      "export LITELLM_MASTER_KEY=\"sk-generated-key\"",
      "litellm --config litellm_config.yaml"
    ]
  },
  "verification_steps": [
    {
      "step_number": 1,
      "command": "claude /status",
      "expected_output": "Base URL: http://localhost:4000",
      "success_criteria": "Custom base URL is displayed"
    }
  ],
  "additional_context": {
    "security_warnings": [
      "Never hardcode API keys in configuration files",
      "Use environment variables or secret managers for production"
    ],
    "third_party_notice": "LiteLLM is third-party; Anthropic doesn't maintain it.",
    "documentation_links": [
      "https://docs.litellm.ai/docs/proxy/quick_start",
      "https://docs.anthropic.com/claude-code/gateways"
    ]
  }
}
```

---

### 2. Vertex AI Model Configuration Request

**User Intent**: "Add Vertex AI Model Garden models to LiteLLM"

**Input Contract**:

```typescript
interface VertexModelRequest {
  models: {
    display_name: string;         // e.g., "gemini-2.5-flash"
    model_id: string;             // e.g., "vertex_ai/gemini-2.5-flash"
    publisher?: string;           // e.g., "google", "deepseek", "meta"
  }[];
  gcp_project_id: string;
  gcp_region?: string;             // defaults to "us-central1"
  authentication_method: "gcloud" | "service_account";
  service_account_path?: string;  // required if authentication_method = "service_account"
}
```

**Output Contract**:

```typescript
interface VertexModelResponse {
  quick_answer: string;
  configuration_block: {
    yaml_snippet: string;         // Model list entries for litellm_config.yaml
    prerequisites: {
      item: string;
      status: "required" | "optional" | "recommended";
      instructions: string;
    }[];
  };
  verification_steps: {
    step_number: number;
    command: string;
    expected_output: string;
    troubleshooting?: string;
  }[];
  additional_context: {
    capabilities: {
      model_name: string;
      function_calling: boolean;
      vision: boolean;
      reasoning: boolean;
      fill_in_middle: boolean;
      max_context: number;
    }[];
    pricing_notes?: string[];
    quota_warnings?: string[];
  };
}
```

**Example Output**:

```json
{
  "quick_answer": "Add Vertex AI models to your litellm_config.yaml with vertex_ai_project and vertex_ai_location parameters.",
  "configuration_block": {
    "yaml_snippet": "model_list:\n  - model_name: gemini-2.5-flash\n    litellm_params:\n      model: vertex_ai/gemini-2.5-flash\n      vertex_ai_project: \"my-project-id\"\n      vertex_ai_location: \"us-central1\"\n      vertex_credentials: \"/path/to/service_account.json\"",
    "prerequisites": [
      {
        "item": "Google Cloud Project with Vertex AI API enabled",
        "status": "required",
        "instructions": "Visit console.cloud.google.com and enable Vertex AI API"
      },
      {
        "item": "Service account with Vertex AI User role",
        "status": "required",
        "instructions": "Create service account with roles/aiplatform.user IAM role"
      },
      {
        "item": "gcloud CLI installed and authenticated",
        "status": "recommended",
        "instructions": "Run: gcloud auth application-default login"
      }
    ]
  },
  "verification_steps": [
    {
      "step_number": 1,
      "command": "python test_vertex_models.py",
      "expected_output": "✅ SUCCESS for all models",
      "troubleshooting": "If 'Permission denied', check service account IAM roles"
    }
  ],
  "additional_context": {
    "capabilities": [
      {
        "model_name": "gemini-2.5-flash",
        "function_calling": true,
        "vision": true,
        "reasoning": false,
        "fill_in_middle": false,
        "max_context": 1048576
      }
    ],
    "pricing_notes": [
      "Gemini 2.5 Flash: ~$0.15 per 1M input tokens",
      "Enable prompt caching to reduce costs by up to 90%"
    ],
    "quota_warnings": [
      "Default quota: 10 req/min per model",
      "Request increases via GCP Console Quotas page"
    ]
  }
}
```

---

### 3. Multi-Provider Configuration Request

**User Intent**: "Configure Claude Code with multiple LLM providers through gateway"

**Input Contract**:

```typescript
interface MultiProviderRequest {
  providers: {
    name: "anthropic" | "bedrock" | "vertex_ai";
    region?: string;
    authentication_bypass?: boolean;
  }[];
  gateway_handles_auth: boolean;
}
```

**Output Contract**:

```typescript
interface MultiProviderResponse {
  quick_answer: string;
  configuration_block: {
    environment_variables: {
      name: string;
      value: string;
      description: string;
      provider: string;
    }[];
    settings_json: string;  // For .claude/settings.json
  };
  verification_steps: {
    step_number: number;
    provider: string;
    command: string;
    expected_output: string;
  }[];
  additional_context: {
    authentication_flow_diagram: string;
    provider_specific_notes: {
      provider: string;
      notes: string[];
    }[];
  };
}
```

---

### 4. Troubleshooting Request

**User Intent**: "My gateway setup isn't working, error: [ERROR_MESSAGE]"

**Input Contract**:

```typescript
interface TroubleshootRequest {
  error_message: string;
  gateway_type?: string;
  verification_results?: {
    base_url_reachable: boolean;
    auth_valid: boolean;
    model_accessible: boolean;
  };
  configuration_snippet?: string;
}
```

**Output Contract**:

```typescript
interface TroubleshootResponse {
  quick_answer: string;  // Root cause summary
  diagnostic_steps: {
    step_number: number;
    description: string;
    command: string;
    expected_output: string;
    what_it_checks: string;
  }[];
  likely_solutions: {
    solution_title: string;
    probability: "high" | "medium" | "low";
    steps: string[];
    verification_command: string;
  }[];
  related_issues: {
    issue_title: string;
    symptoms: string[];
    documentation_link: string;
  }[];
}
```

**Example Output**:

```json
{
  "quick_answer": "Model not found error indicates the model isn't deployed in your GCP region. Check Model Garden console and deploy to the correct region.",
  "diagnostic_steps": [
    {
      "step_number": 1,
      "description": "Verify Vertex AI API is enabled",
      "command": "gcloud services list --enabled --filter=\"NAME:aiplatform.googleapis.com\"",
      "expected_output": "aiplatform.googleapis.com",
      "what_it_checks": "Whether Vertex AI API is enabled in your GCP project"
    },
    {
      "step_number": 2,
      "description": "Check model availability in region",
      "command": "Check Model Garden console for model deployment status",
      "expected_output": "Model shows as 'Available' in your region",
      "what_it_checks": "Whether model is accessible in specified vertex_ai_location"
    }
  ],
  "likely_solutions": [
    {
      "solution_title": "Deploy model to your region",
      "probability": "high",
      "steps": [
        "Go to console.cloud.google.com/vertex-ai/model-garden",
        "Search for your model (e.g., gemini-2.5-flash)",
        "Click 'Deploy' and select your target region",
        "Wait for deployment to complete (5-10 minutes)"
      ],
      "verification_command": "python test_vertex_models.py"
    }
  ],
  "related_issues": [
    {
      "issue_title": "Permission denied errors",
      "symptoms": ["403 Forbidden", "Insufficient permissions"],
      "documentation_link": "https://cloud.google.com/vertex-ai/docs/general/access-control"
    }
  ]
}
```

---

## Configuration File Contracts

### LiteLLM Config YAML Schema

**File**: `litellm_config.yaml`

```yaml
model_list:  # REQUIRED
  - model_name: string  # REQUIRED - Logical name for the model
    litellm_params:  # REQUIRED
      model: string  # REQUIRED - Provider model ID (e.g., "vertex_ai/gemini-2.5-flash")
      vertex_ai_project: string  # REQUIRED for Vertex AI models
      vertex_ai_location: string  # REQUIRED for Vertex AI models
      vertex_credentials: string  # OPTIONAL - Path to service account JSON
      api_key: string  # OPTIONAL - For other providers
      rpm: integer  # OPTIONAL - Requests per minute limit
      tpm: integer  # OPTIONAL - Tokens per minute limit

router_settings:  # OPTIONAL
  routing_strategy: string  # OPTIONAL - "simple-shuffle" | "least-busy" | "usage-based-routing" | "latency-based-routing"
  num_retries: integer  # OPTIONAL - Default: 3
  timeout: integer  # OPTIONAL - Timeout in seconds, default: 30
  fallbacks: array  # OPTIONAL - Fallback model chains
  enable_pre_call_check: boolean  # OPTIONAL - Check rate limits before call
  redis_host: string  # OPTIONAL - For multi-instance deployments
  redis_password: string  # OPTIONAL
  redis_port: integer  # OPTIONAL - Default: 6379

litellm_settings:  # OPTIONAL
  drop_params: boolean  # RECOMMENDED: true - Drop unsupported parameters
  set_verbose: boolean  # OPTIONAL - Enable debug logging
  success_callback: array  # OPTIONAL - ["langfuse"], ["prometheus"], etc.
  cache: boolean  # OPTIONAL - Enable caching

general_settings:  # OPTIONAL
  master_key: string  # REQUIRED for authentication
  database_url: string  # OPTIONAL - For usage tracking
```

**Validation Rules**:

1. At least one entry in `model_list` is required
2. Each `model_name` must be unique within the file
3. For Vertex AI models, both `vertex_ai_project` and `vertex_ai_location` are mandatory
4. `routing_strategy` must be one of the enumerated values
5. `num_retries` must be between 0-10
6. Environment variable references use `os.environ/VAR_NAME` syntax

---

### Claude Code Settings JSON Schema

**File**: `~/.claude/settings.json` or `.claude/settings.json`

```json
{
  "anthropic": {
    "baseURL": "string",      // REQUIRED - Gateway URL (e.g., "http://localhost:4000")
    "authToken": "string"     // REQUIRED - Gateway authentication token
  },
  "bedrock": {
    "baseURL": "string",      // OPTIONAL - Bedrock gateway URL
    "skipAuth": "boolean"     // OPTIONAL - Skip Bedrock authentication
  },
  "vertex": {
    "baseURL": "string",      // OPTIONAL - Vertex AI gateway URL
    "skipAuth": "boolean"     // OPTIONAL - Skip Vertex authentication
  }
}
```

**Validation Rules**:

1. `anthropic.baseURL` must be a valid HTTP/HTTPS URL
2. `anthropic.authToken` must not be empty if gateway requires authentication
3. `*.baseURL` must include protocol (http:// or https://)
4. `*.skipAuth` only valid when using gateway that handles provider authentication

---

## Environment Variables Contract

### Required Variables

| Variable Name | Type | Required | Description | Example Value |
|--------------|------|----------|-------------|---------------|
| `ANTHROPIC_BASE_URL` | URL | Yes* | Gateway endpoint | `http://localhost:4000` |
| `ANTHROPIC_AUTH_TOKEN` | String | Yes* | Gateway auth token | `sk-litellm-master-key` |
| `GCP_PROJECT_ID` | String | Yes** | Google Cloud project ID | `my-project-123` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path | No | Service account JSON path | `/path/to/sa.json` |
| `LITELLM_MASTER_KEY` | String | Yes*** | LiteLLM proxy master key | `sk-random-generated-key` |

\* Required when using gateway  
\*\* Required for Vertex AI models  
\*\*\* Required when running LiteLLM proxy with authentication

### Optional Variables

| Variable Name | Type | Description | Example Value |
|--------------|------|-------------|---------------|
| `ANTHROPIC_BEDROCK_BASE_URL` | URL | Bedrock gateway endpoint | `https://bedrock-gateway.com` |
| `ANTHROPIC_VERTEX_BASE_URL` | URL | Vertex AI gateway endpoint | `https://vertex-gateway.com` |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | Boolean | Skip Bedrock auth when using gateway | `1` or `true` |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH` | Boolean | Skip Vertex auth when using gateway | `1` or `true` |
| `ANTHROPIC_LOG` | String | Enable debug logging | `debug` |
| `LITELLM_LOG` | String | LiteLLM logging level | `DEBUG` |
| `HTTPS_PROXY` | URL | Corporate proxy URL | `http://proxy.corp.com:8080` |
| `REDIS_HOST` | String | Redis host for shared state | `localhost` |
| `REDIS_PASSWORD` | String | Redis authentication | `redis-password` |
| `REDIS_PORT` | Integer | Redis port | `6379` |

---

## Verification Procedure Contract

### Status Check Procedure

**Command**: `claude /status`

**Expected Output Fields**:

```typescript
interface StatusOutput {
  base_url: {
    value: string;
    status: "✓" | "✗";
    note?: string;
  };
  auth_token: {
    present: boolean;
    masked_value: string;  // e.g., "sk-****"
    status: "✓" | "✗";
  };
  configuration_source: "user" | "project" | "environment";
  models_available?: string[];  // If gateway exposes /models endpoint
}
```

**Success Criteria**:

- Both `base_url.status` and `auth_token.status` show "✓"
- `base_url.value` matches expected gateway URL
- `auth_token.present` is `true`

---

### End-to-End Test Procedure

**Command**: `curl http://localhost:4000/chat/completions -H "Authorization: Bearer $TOKEN" -d '{"model": "gemini-2.5-flash", "messages": [{"role": "user", "content": "Hello"}]}'`

**Expected Response**:

```typescript
interface CompletionResponse {
  id: string;
  object: "chat.completion";
  created: number;  // Unix timestamp
  model: string;
  choices: {
    index: number;
    message: {
      role: "assistant";
      content: string;
    };
    finish_reason: "stop" | "length" | "content_filter";
  }[];
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}
```

**Success Criteria**:

- HTTP status code is 200
- Response contains `choices` array with at least one entry
- `choices[0].message.content` is non-empty
- `usage.total_tokens` > 0

---

## Error Response Contract

### Standard Error Format

```typescript
interface ErrorResponse {
  error: {
    type: string;  // "authentication_error" | "model_not_found" | "rate_limit_exceeded" | "server_error"
    code: string;  // e.g., "model_not_found"
    message: string;  // Human-readable error description
    param?: string;  // Parameter that caused the error (if applicable)
    troubleshooting_steps?: string[];  // Suggested resolution steps
    documentation_link?: string;  // Link to relevant docs
  };
  timestamp: string;  // ISO 8601 format
  request_id?: string;  // For support/debugging
}
```

**Example Error Responses**:

```json
{
  "error": {
    "type": "model_not_found",
    "code": "model_unavailable",
    "message": "Model 'vertex_ai/gemini-2.5-flash' not found in region 'us-central1'",
    "param": "model",
    "troubleshooting_steps": [
      "Verify model is deployed in Model Garden",
      "Check vertex_ai_location matches deployment region",
      "Ensure Vertex AI API is enabled"
    ],
    "documentation_link": "https://cloud.google.com/vertex-ai/docs/model-garden"
  },
  "timestamp": "2025-12-01T10:30:00Z",
  "request_id": "req_abc123"
}
```

---

## Contract Version History

- **v1.0.0** (2025-12-01): Initial contract definition
  - Assistant interaction patterns
  - Configuration file schemas
  - Verification procedures
  - Error formats

---

**Contract Status**: ✅ Complete  
**Next**: Create quickstart.md with step-by-step implementation guide
