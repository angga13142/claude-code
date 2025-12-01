# Configuration Reference - LLM Gateway for Claude Code

**Complete reference for all configuration options, templates, and settings.**

---

## Table of Contents

1. [LiteLLM Configuration](#litellm-configuration)
2. [Model Configuration](#model-configuration)
3. [Provider Configuration](#provider-configuration)
4. [Environment Variables](#environment-variables)
5. [Claude Code Settings](#claude-code-settings)
6. [Deployment Patterns](#deployment-patterns)
7. [Advanced Configuration](#advanced-configuration)

---

## LiteLLM Configuration

### Basic Configuration Structure

```yaml
model_list:
  - model_name: string # Display name for the model
    litellm_params:
      model: string # Provider model identifier
      api_base: string # API endpoint URL
      api_key: string # API authentication key
      timeout: integer # Request timeout in seconds

litellm_settings:
  set_verbose: boolean # Enable debug logging
  request_timeout: integer # Global request timeout
  num_retries: integer # Retry attempts on failure
  cache: boolean # Enable response caching
```

### Complete LiteLLM Settings Reference

| Setting                  | Type    | Default | Description                                 |
| ------------------------ | ------- | ------- | ------------------------------------------- |
| `set_verbose`            | boolean | false   | Enable detailed debug logging               |
| `request_timeout`        | integer | 600     | Request timeout in seconds                  |
| `num_retries`            | integer | 0       | Number of retry attempts                    |
| `retry_after`            | integer | 0       | Seconds to wait between retries             |
| `fallback_list`          | array   | []      | Fallback models if primary fails            |
| `cache`                  | boolean | false   | Enable response caching                     |
| `cache_params`           | object  | {}      | Cache configuration (type, host, port, ttl) |
| `success_callback`       | array   | []      | Success event handlers (e.g., "langfuse")   |
| `failure_callback`       | array   | []      | Failure event handlers                      |
| `drop_params`            | boolean | false   | Drop unsupported parameters                 |
| `add_function_to_prompt` | boolean | false   | Add function calling to prompt              |

### Configuration File Locations

**Templates**:

- `templates/litellm-base.yaml` - Minimal configuration
- `templates/litellm-complete.yaml` - Full 8-model setup
- `templates/enterprise/*.yaml` - Enterprise gateway configs
- `templates/multi-provider/*.yaml` - Multi-provider configs
- `templates/proxy/*.yaml` - Corporate proxy configs

**User Configuration**:

```bash
# Recommended locations
~/.claude/litellm-config.yaml          # User-specific
/etc/litellm/config.yaml               # System-wide
$PROJECT_ROOT/config/litellm.yaml      # Project-specific
```

---

## Model Configuration

### Vertex AI Models

#### Gemini Models

**Gemini 2.0 Flash** (`gemini-2.0-flash-exp`):

```yaml
- model_name: gemini-2.0-flash
  litellm_params:
    model: vertex_ai/gemini-2.0-flash-exp
    vertex_project: os.environ/VERTEX_PROJECT_ID
    vertex_location: os.environ/VERTEX_LOCATION # default: us-central1
```

**Specifications**:

- Context window: 1M tokens (input), 8K tokens (output)
- Speed: ~2000 tokens/sec
- Cost: $0.10/1M input tokens, $0.30/1M output tokens
- Best for: General purpose, fast responses

**Gemini 2.5 Pro** (`gemini-2.5-pro-exp-0114`):

```yaml
- model_name: gemini-2.5-pro
  litellm_params:
    model: vertex_ai/gemini-2.5-pro-exp-0114
    vertex_project: os.environ/VERTEX_PROJECT_ID
    vertex_location: os.environ/VERTEX_LOCATION
```

**Specifications**:

- Context window: 2M tokens
- Speed: ~500 tokens/sec
- Cost: $1.25/1M input tokens, $5.00/1M output tokens
- Best for: Complex reasoning, large context

#### Model Garden Models

**DeepSeek R1**:

```yaml
- model_name: deepseek-r1
  litellm_params:
    model: vertex_ai_model_garden/deepseek-ai/deepseek-r1
    vertex_project: os.environ/VERTEX_PROJECT_ID
    vertex_location: us-central1
```

**Llama 3.1 405B**:

```yaml
- model_name: llama3-405b
  litellm_params:
    model: vertex_ai_model_garden/meta/llama-3.1-405b-instruct-maas
    vertex_project: os.environ/VERTEX_PROJECT_ID
```

**Codestral**:

```yaml
- model_name: codestral
  litellm_params:
    model: vertex_ai_model_garden/mistralai/codestral
    vertex_project: os.environ/VERTEX_PROJECT_ID
```

**Qwen 2.5 Coder 32B**:

```yaml
- model_name: qwen-coder
  litellm_params:
    model: vertex_ai_model_garden/qwen/qwen2.5-coder-32b-instruct
    vertex_project: os.environ/VERTEX_PROJECT_ID
```

### Anthropic Models

**Claude 3.5 Sonnet**:

```yaml
- model_name: claude-3-5-sonnet-20241022
  litellm_params:
    model: anthropic/claude-3-5-sonnet-20241022
    api_base: https://api.anthropic.com/v1
    api_key: os.environ/ANTHROPIC_API_KEY
    timeout: 600
```

**Claude 3.5 Haiku**:

```yaml
- model_name: claude-3-5-haiku-20241022
  litellm_params:
    model: anthropic/claude-3-5-haiku-20241022
    api_base: https://api.anthropic.com/v1
    api_key: os.environ/ANTHROPIC_API_KEY
```

### AWS Bedrock Models

**Bedrock Claude**:

```yaml
- model_name: bedrock-claude-sonnet
  litellm_params:
    model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
    aws_region_name: os.environ/AWS_REGION
    # Uses AWS credentials from environment or ~/.aws/credentials
```

---

## Provider Configuration

### Anthropic Direct

**Required Environment Variables**:

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export ANTHROPIC_BASE_URL="http://localhost:4000"  # For gateway
```

**Configuration**:

```yaml
litellm_params:
  model: anthropic/claude-3-5-sonnet-20241022
  api_base: https://api.anthropic.com/v1
  api_key: os.environ/ANTHROPIC_API_KEY
```

**Rate Limits** (as of 2024):

- Tier 1: 50 requests/min, 40K tokens/min
- Tier 2: 1000 requests/min, 80K tokens/min
- Tier 3: 2000 requests/min, 160K tokens/min

### AWS Bedrock

**Required Environment Variables**:

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

**Configuration**:

```yaml
litellm_params:
  model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
  aws_region_name: os.environ/AWS_REGION
```

**Authentication Methods**:

1. Environment variables (above)
2. AWS credentials file (`~/.aws/credentials`)
3. IAM role (for EC2/ECS/Lambda)
4. AWS SSO

**Regions with Claude Models**:

- us-east-1 (N. Virginia)
- us-west-2 (Oregon)
- eu-west-1 (Ireland)
- ap-southeast-1 (Singapore)
- ap-northeast-1 (Tokyo)

### Google Vertex AI

**Required Environment Variables**:

```bash
export VERTEX_PROJECT_ID="your-project-id"
export VERTEX_LOCATION="us-central1"
```

**Authentication**:

```bash
# Application Default Credentials
gcloud auth application-default login

# Or service account key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

**Configuration**:

```yaml
litellm_params:
  model: vertex_ai/gemini-2.0-flash-exp
  vertex_project: os.environ/VERTEX_PROJECT_ID
  vertex_location: os.environ/VERTEX_LOCATION
```

**Available Regions**:

- us-central1 (Iowa)
- us-east4 (N. Virginia)
- europe-west1 (Belgium)
- asia-southeast1 (Singapore)

---

## Environment Variables

### Core Variables

**Claude Code**:

```bash
# Gateway endpoint
export ANTHROPIC_BASE_URL="http://localhost:4000"

# API key (dummy for gateway, real for direct)
export ANTHROPIC_API_KEY="sk-local-gateway"
```

**LiteLLM Gateway**:

```bash
# Provider API keys
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."

# Vertex AI
export VERTEX_PROJECT_ID="my-project"
export VERTEX_LOCATION="us-central1"
```

### Proxy Variables

```bash
# Corporate proxy
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export HTTP_PROXY="http://proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"

# SSL certificates
export SSL_CERT_FILE="/path/to/ca-bundle.crt"
export REQUESTS_CA_BUNDLE="/path/to/ca-bundle.crt"
export CURL_CA_BUNDLE="/path/to/ca-bundle.crt"
```

### Authentication Bypass

```bash
# Skip provider-specific authentication (use gateway auth)
export CLAUDE_CODE_SKIP_BEDROCK_AUTH="true"
export CLAUDE_CODE_SKIP_VERTEX_AUTH="true"

# Provider base URLs for gateway routing
export ANTHROPIC_BASE_URL="http://localhost:4000"
export BEDROCK_BASE_URL="http://localhost:4000"
export VERTEX_BASE_URL="http://localhost:4000"
```

### Cache Configuration

```bash
# Redis cache
export REDIS_HOST="localhost"
export REDIS_PORT="6379"
export REDIS_PASSWORD=""  # if required
```

---

## Claude Code Settings

### settings.json Schema

Location: `~/.claude/settings.json` or project `.claude/settings.json`

```json
{
  "anthropic": {
    "apiKey": "sk-local-gateway",
    "baseURL": "http://localhost:4000"
  },
  "gateway": {
    "enabled": true,
    "endpoint": "http://localhost:4000",
    "timeout": 60000,
    "retries": 3
  },
  "models": {
    "default": "claude-3-5-sonnet-20241022",
    "alternatives": ["gemini-2.0-flash", "bedrock-claude-sonnet"]
  },
  "logging": {
    "level": "info",
    "file": "~/.claude/logs/claude.log"
  }
}
```

### Configuration Priority

1. Command-line flags (highest)
2. Environment variables
3. Project `.claude/settings.json`
4. User `~/.claude/settings.json`
5. System `/etc/claude/settings.json`
6. Default values (lowest)

---

## Deployment Patterns

### Pattern 1: Direct Provider Access

```
Claude Code → Provider API (Anthropic/Bedrock/Vertex)
```

**Configuration**:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# No ANTHROPIC_BASE_URL (uses default)
```

**Use Case**: Individual developers, no gateway

### Pattern 2: Local Gateway

```
Claude Code → LiteLLM Gateway (localhost:4000) → Provider APIs
```

**Configuration**:

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"

# Start gateway
litellm --config config/litellm-complete.yaml --port 4000
```

**Use Case**: Local development, model switching, caching

### Pattern 3: Corporate Proxy

```
Claude Code → Corporate Proxy → Provider API
```

**Configuration**:

```bash
export HTTPS_PROXY="http://proxy.corp:8080"
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Use Case**: Corporate firewall, mandatory proxy

### Pattern 4: Proxy + Gateway

```
Claude Code → LiteLLM Gateway → Corporate Proxy → Provider APIs
```

**Configuration**:

```bash
# Claude Code → Gateway (no proxy)
export ANTHROPIC_BASE_URL="http://localhost:4000"
export NO_PROXY="localhost,127.0.0.1"

# Gateway → Providers (via proxy)
export HTTPS_PROXY="http://proxy.corp:8080"
```

**Use Case**: Most common enterprise setup

---

## Advanced Configuration

### Load Balancing

```yaml
model_list:
  # Round-robin between multiple instances
  - model_name: claude-sonnet-lb
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_base: https://api-1.anthropic.com/v1
      api_key: os.environ/ANTHROPIC_API_KEY_1

  - model_name: claude-sonnet-lb
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_base: https://api-2.anthropic.com/v1
      api_key: os.environ/ANTHROPIC_API_KEY_2

router_settings:
  routing_strategy: "simple-shuffle" # or "least-busy", "usage-based-routing"
```

### Fallback Configuration

```yaml
model_list:
  - model_name: claude-with-fallback
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
      fallbacks:
        [
          { "model": "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0" },
          { "model": "vertex_ai/gemini-2.0-flash-exp" },
        ]
```

### Caching Configuration

```yaml
litellm_settings:
  cache: true
  cache_params:
    type: "redis"
    host: os.environ/REDIS_HOST
    port: os.environ/REDIS_PORT
    password: os.environ/REDIS_PASSWORD
    ttl: 3600 # 1 hour
    namespace: "litellm"
```

### Rate Limiting

```yaml
litellm_settings:
  rpm: 100 # requests per minute
  tpm: 50000 # tokens per minute
  max_parallel_requests: 10
```

### Custom Headers

```yaml
model_list:
  - model_name: claude-custom-headers
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
      extra_headers:
        X-Custom-Header: "value"
        X-Request-ID: "{{request_id}}"
```

---

## Configuration Validation

### Validate Configuration File

```bash
# Using validation script
python scripts/validate-config.py config/litellm-complete.yaml

# Manual YAML validation
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

### Test Configuration

```bash
# Start gateway with validation
litellm --config config.yaml --test

# Health check
curl http://localhost:4000/health

# List models
curl http://localhost:4000/models

# Test completion
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 10
  }'
```

---

## Troubleshooting Configuration

### Common Configuration Errors

**1. Invalid YAML syntax**:

```bash
# Check syntax
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

**2. Missing environment variables**:

```bash
# Validate env vars
python scripts/validate-provider-env-vars.py
```

**3. Incorrect model identifiers**:

- Anthropic: `anthropic/model-name` (not `anthropic-model-name`)
- Bedrock: `bedrock/provider.model-id` (not `bedrock-model`)
- Vertex: `vertex_ai/model-name` or `vertex_ai_model_garden/org/model`

**4. API key format**:

- Anthropic: Must start with `sk-ant-`
- AWS: AKIA... for access key ID
- Vertex: JSON service account file or ADC

### Configuration Debug Mode

```bash
# Enable verbose logging
export LITELLM_LOG=DEBUG

# Start gateway with debug
litellm --config config.yaml --debug

# Check logs
tail -f ~/.litellm/logs/litellm.log
```

---

## References

- **Templates**: See `templates/` directory
- **Examples**: See `examples/` directory
- **Scripts**: See `scripts/` directory
- **Official Docs**: https://docs.litellm.ai/
- **Claude Code Docs**: https://github.com/anthropics/claude-code

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
