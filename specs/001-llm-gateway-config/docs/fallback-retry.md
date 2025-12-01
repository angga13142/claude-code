# Fallback and Retry Policies

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: Platform Engineers, SREs  
**Last Updated**: 2025-12-01

---

## Overview

Fallback and retry policies ensure reliable LLM applications by automatically handling failures, timeouts, and provider outages. LiteLLM provides built-in retry mechanisms and fallback strategies to maintain high availability.

**Benefits**:

- 🛡️ **Reliability**: Automatic recovery from transient failures
- ⚡ **Availability**: 99.9%+ uptime with proper fallback configuration
- 🔄 **Resilience**: Graceful degradation during provider outages
- 🎯 **User Experience**: Reduced error rates

---

## Retry Policies

### Basic Retry Configuration

```yaml
litellm_settings:
  num_retries: 3 # Retry up to 3 times
  request_timeout: 600 # Timeout after 10 minutes
  retry_after: 10 # Wait 10 seconds between retries
```

**Behavior**:

- Retries on network errors, timeouts, 5xx errors
- Exponential backoff between retries
- Maximum 3 retry attempts

---

### Retry Strategies

#### 1. Exponential Backoff (Default)

Increases wait time exponentially between retries.

**Configuration**:

```yaml
litellm_settings:
  num_retries: 5
  retry_policy: "exponential_backoff"
  initial_delay: 1 # Start with 1 second
  max_delay: 60 # Cap at 60 seconds
```

**Behavior**:

- Attempt 1: Immediate
- Attempt 2: Wait 1s
- Attempt 3: Wait 2s
- Attempt 4: Wait 4s
- Attempt 5: Wait 8s

**Use Case**: Network congestion, temporary API issues

---

#### 2. Fixed Delay

Waits a fixed amount of time between retries.

**Configuration**:

```yaml
litellm_settings:
  num_retries: 3
  retry_policy: "fixed_delay"
  retry_after: 5 # Wait 5 seconds every time
```

**Behavior**:

- Attempt 1: Immediate
- Attempt 2: Wait 5s
- Attempt 3: Wait 5s

**Use Case**: Predictable retry timing, testing

---

#### 3. Jittered Backoff

Adds randomness to prevent thundering herd problem.

**Configuration**:

```yaml
litellm_settings:
  num_retries: 5
  retry_policy: "exponential_backoff_jitter"
  initial_delay: 1
  max_delay: 60
  jitter: 0.3 # ±30% randomness
```

**Behavior**:

- Attempt 2: Wait 0.7-1.3s (1s ± 30%)
- Attempt 3: Wait 1.4-2.6s (2s ± 30%)
- Attempt 4: Wait 2.8-5.2s (4s ± 30%)

**Use Case**: High-traffic scenarios, multiple clients

---

### Retry on Specific Errors

Configure which errors trigger retries:

```yaml
litellm_settings:
  num_retries: 3
  retry_on_status_codes: [429, 500, 502, 503, 504] # Rate limit + server errors
  retry_on_timeout: true
  retry_on_network_error: true
```

**Default Retryable Errors**:

- `429`: Rate limit exceeded
- `500`: Internal server error
- `502`: Bad gateway
- `503`: Service unavailable
- `504`: Gateway timeout
- Network errors (connection refused, DNS failures)
- Timeouts

**Non-Retryable Errors** (fail immediately):

- `400`: Bad request (invalid input)
- `401`: Unauthorized (bad API key)
- `403`: Forbidden (insufficient permissions)
- `404`: Not found (invalid endpoint)

---

## Fallback Strategies

### Model Fallback

Automatically switch to backup models when primary fails.

**Configuration**:

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: gpt-4-turbo
      api_key: os.environ/OPENAI_API_KEY

  # Fallback 1: Same provider, older model
  - model_name: gpt-4-fallback
    litellm_params:
      model: gpt-4
      api_key: os.environ/OPENAI_API_KEY

  # Fallback 2: Different provider
  - model_name: gpt-4-fallback-2
    litellm_params:
      model: azure/gpt-4
      api_key: os.environ/AZURE_API_KEY

router_settings:
  enable_fallback: true
  fallback_models: ["gpt-4-fallback", "gpt-4-fallback-2"]
  num_retries: 2 # Try each fallback twice
```

**Behavior**:

1. Try `gpt-4-turbo` (primary)
2. If fails, try `gpt-4` (fallback 1)
3. If fails, try `azure/gpt-4` (fallback 2)
4. If all fail, return error

---

### Provider Fallback

Switch providers while maintaining model quality.

**Configuration**:

```yaml
model_list:
  # Primary: Anthropic Direct
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  # Fallback 1: AWS Bedrock
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  # Fallback 2: Google Vertex AI
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1

router_settings:
  routing_strategy: "simple-shuffle" # Try each in order
  num_retries: 1 # One retry per provider
  allowed_fails: 3 # Skip provider after 3 consecutive fails
```

**Behavior**:

- Routes to healthy provider automatically
- Tracks provider health
- Temporarily skips failing providers

---

### Regional Fallback

Fallback across geographic regions.

**Configuration**:

```yaml
model_list:
  # Primary: US West
  - model_name: claude-regional
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2

  # Fallback 1: US East
  - model_name: claude-regional
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  # Fallback 2: EU West
  - model_name: claude-regional
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1

  # Fallback 3: AP Southeast
  - model_name: claude-regional
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: ap-southeast-1

router_settings:
  routing_strategy: "latency-based-routing" # Route to fastest region
  num_retries: 2
  allowed_fails: 3
```

**Use Case**: Regional outages, data residency requirements

---

## Advanced Patterns

### Circuit Breaker with Fallback

Combine circuit breaker and fallback for robust error handling.

**Configuration**:

```yaml
router_settings:
  # Circuit breaker
  enable_circuit_breaker: true
  failure_threshold: 10 # Open circuit after 10 failures
  success_threshold: 3 # Close circuit after 3 successes
  timeout: 120 # Seconds before attempting reset

  # Fallback
  enable_fallback: true
  fallback_models: ["claude-fallback-1", "claude-fallback-2"]

  # Retry
  num_retries: 3
  retry_policy: "exponential_backoff_jitter"
```

**Behavior**:

1. Try primary model
2. If circuit is open, skip to fallback immediately
3. If circuit is closed, try with retries
4. On repeated failures, open circuit and use fallback
5. Periodically test if primary recovered

---

### Timeout-Based Fallback

Fallback to faster models on timeout.

**Configuration**:

```yaml
model_list:
  # Primary: High-quality, slow
  - model_name: claude-quality
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      request_timeout: 120 # 2 minute timeout

  # Fallback: Lower quality, fast
  - model_name: claude-quality-fallback
    litellm_params:
      model: anthropic/claude-3.5-haiku-20241022
      request_timeout: 30 # 30 second timeout

router_settings:
  enable_fallback: true
  fallback_on_timeout: true
  fallback_models: ["claude-quality-fallback"]
```

**Use Case**: Time-sensitive applications, interactive chat

---

### Content-Based Fallback

Fallback based on content type or length.

**Configuration** (Application-level):

```python
import litellm

def get_model_for_content(prompt: str) -> str:
    """Select model based on content characteristics."""
    prompt_length = len(prompt)

    if prompt_length > 50000:  # Long context
        return "claude-3.5-sonnet"  # 200K context
    elif "code" in prompt.lower():  # Code generation
        return "codestral"  # Optimized for code
    else:
        return "gemini-flash"  # Fast, cheap for general use

# Use in application
response = litellm.completion(
    model=get_model_for_content(user_prompt),
    messages=[{"role": "user", "content": user_prompt}],
    fallback_models=["gpt-4-turbo", "claude-3.5-sonnet"]  # Generic fallbacks
)
```

---

## Monitoring and Alerting

### Track Retry Rates

```yaml
litellm_settings:
  success_callback: ["langfuse", "prometheus"]
  failure_callback: ["langfuse", "prometheus"]
  retry_callback: ["langfuse"] # Track retry events
```

**Prometheus Metrics**:

```promql
# Retry rate
rate(litellm_retries_total[5m])

# Success rate after retries
litellm_requests_success_total / litellm_requests_total

# Fallback usage
rate(litellm_fallback_total[5m])
```

---

### Alert on High Retry Rates

```yaml
# prometheus-alerts.yml
groups:
  - name: litellm
    rules:
      - alert: HighRetryRate
        expr: rate(litellm_retries_total[5m]) > 0.1 # >10% retry rate
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High retry rate detected"
          description: "Retry rate is {{ $value | humanizePercentage }} for model {{ $labels.model }}"

      - alert: FallbackInUse
        expr: rate(litellm_fallback_total[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Fallback models in use"
          description: "Primary model failing, using fallback"
```

---

## Best Practices

### 1. Configure Appropriate Timeouts

```yaml
litellm_settings:
  request_timeout: 600 # 10 minutes for long requests

model_list:
  - model_name: claude-interactive
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      request_timeout: 30 # Override: 30s for interactive

  - model_name: claude-batch
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      request_timeout: 300 # Override: 5min for batch
```

### 2. Limit Retry Attempts

```yaml
litellm_settings:
  num_retries: 3 # Maximum 3 retries (4 total attempts)
  max_retries: 5 # Hard limit across all fallbacks
```

**Reasoning**: Prevents infinite retry loops and user frustration

### 3. Use Jittered Backoff in Production

```yaml
litellm_settings:
  retry_policy: "exponential_backoff_jitter"
  jitter: 0.3 # ±30% randomness
```

**Reasoning**: Prevents thundering herd during outages

### 4. Test Fallback Scenarios

```bash
# Simulate primary provider failure
# Stop primary endpoint or block network

# Verify fallback works
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-3.5-sonnet", "messages": [{"role": "user", "content": "test"}]}'

# Check which model was used
tail -f ~/.litellm/logs/litellm.log | grep "fallback"
```

### 5. Monitor Fallback Usage

Set up alerts for fallback activation:

```yaml
# Alert if fallback used for >1 minute
- alert: PrimaryModelDown
  expr: rate(litellm_fallback_total[1m]) > 0
  for: 1m
```

---

## Common Patterns

### Pattern 1: Same Model, Multiple Providers

High availability for critical applications.

```yaml
model_list:
  - model_name: claude-ha
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
  - model_name: claude-ha
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
  - model_name: claude-ha
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022

router_settings:
  routing_strategy: "simple-shuffle"
  num_retries: 2
  allowed_fails: 3
```

**Availability**: 99.99% (assuming 99% per provider)

### Pattern 2: Quality Degradation

Fallback to lower quality models under load.

```yaml
model_list:
  - model_name: auto-scale
    litellm_params:
      model: anthropic/claude-3-opus-20240229 # Best quality
  - model_name: auto-scale-fallback
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022 # Good quality
  - model_name: auto-scale-fallback-2
    litellm_params:
      model: anthropic/claude-3.5-haiku-20241022 # Fast, cheap
```

### Pattern 3: Regional + Provider Fallback

Maximum resilience with geographic and provider diversity.

```yaml
model_list:
  # US West - Anthropic Direct
  - model_name: claude-resilient
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022

  # US West - Bedrock
  - model_name: claude-resilient
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2

  # US East - Bedrock
  - model_name: claude-resilient
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  # EU West - Vertex AI
  - model_name: claude-resilient
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_location: europe-west1
```

---

## Troubleshooting

### Issue: Too Many Retries

**Symptoms**: Slow responses, high latency

**Solutions**:

```yaml
# Reduce retries
litellm_settings:
  num_retries: 2 # Down from 5
  max_retries: 3 # Hard limit

  # Reduce timeout
  request_timeout: 60 # Down from 600
```

### Issue: Fallback Not Triggering

**Symptoms**: Errors instead of fallback

**Solutions**:

```yaml
# Enable fallback explicitly
router_settings:
  enable_fallback: true
  fallback_models: ["model-fallback"]

# Check error types
litellm_settings:
  retry_on_status_codes: [429, 500, 502, 503, 504]
```

### Issue: Infinite Retry Loop

**Symptoms**: Requests never complete

**Solutions**:

```yaml
# Set hard limits
litellm_settings:
  num_retries: 3
  max_retries: 5 # Absolute maximum
  request_timeout: 120 # Force timeout
```

---

## Related Documentation

- [Load Balancing Strategies](load-balancing.md)
- [Multi-Region Deployment](multi-region-deployment.md)
- [Observability and Monitoring](observability.md)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
