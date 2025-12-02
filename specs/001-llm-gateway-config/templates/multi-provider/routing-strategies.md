# Provider Routing Strategies Guide

**User Story**: US3 - Multi-Provider Gateway Configuration (Priority: P3)  
**Purpose**: Explain routing strategies for distributing requests across multiple providers/models  
**Audience**: Platform engineers configuring multi-provider gateways

---

## Overview

When configuring LiteLLM with multiple providers (Anthropic, Bedrock, Vertex AI), you need a routing strategy to distribute requests efficiently. This guide explains available strategies, their trade-offs, and when to use each.

---

## Routing Strategy Options

LiteLLM supports three primary routing strategies, configured via `router_settings.routing_strategy`:

### 1. Simple Shuffle (`simple-shuffle`)

**How It Works**: Randomly distributes requests across all available models with equal probability.

**Configuration**:

```yaml
router_settings:
  routing_strategy: simple-shuffle
```

**Use Cases**:

- **Development/Testing**: Quick setup without optimization concerns
- **Equal Provider Capacity**: All providers have similar rate limits and performance
- **Load Distribution**: Spreading load evenly across providers for cost management

**Advantages**:

- ✅ Simplest configuration
- ✅ No state tracking required
- ✅ Predictable cost distribution

**Disadvantages**:

- ❌ Ignores model performance differences
- ❌ No awareness of current load or health
- ❌ May route to overloaded models

**Example**:

```yaml
model_list:
  - model_name: claude-3-5-sonnet-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 50

  - model_name: claude-3-5-sonnet-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    rpm: 40

  - model_name: claude-3-5-sonnet-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: my-project
      vertex_location: us-central1
    rpm: 30

router_settings:
  routing_strategy: simple-shuffle # Each request has ~33% chance to each provider
```

---

### 2. Least Busy (`least-busy`)

**How It Works**: Routes requests to the model with the fewest active requests at the moment.

**Configuration**:

```yaml
router_settings:
  routing_strategy: least-busy
```

**Use Cases**:

- **Production Environments**: Optimize for low latency and high throughput
- **Variable Workloads**: Requests vary in complexity and duration
- **Heterogeneous Providers**: Providers have different capacities or performance characteristics

**Advantages**:

- ✅ Minimizes queuing delays
- ✅ Adapts to real-time load
- ✅ Better utilization of faster providers

**Disadvantages**:

- ❌ Requires tracking active connections (minimal overhead)
- ❌ May favor faster models even if higher cost
- ❌ Potential "thundering herd" if all models equally busy

**Example**:

```yaml
model_list:
  - model_name: claude-3-5-haiku # Fast model, high throughput
    litellm_params:
      model: anthropic/claude-3-5-haiku-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 100

  - model_name: claude-3-opus # Slow model, high capability
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 30

router_settings:
  routing_strategy: least-busy # Routes more requests to Haiku (faster completion)
```

---

### 3. Usage-Based Routing (`usage-based-routing`)

**How It Works**: Routes based on historical usage patterns and configurable priorities.

**Configuration**:

```yaml
router_settings:
  routing_strategy: usage-based-routing
```

**Use Cases**:

- **Cost Optimization**: Route to cheaper models first, fallback to expensive ones
- **Provider Quotas**: Distribute requests to stay within quota limits
- **Tiered Performance**: Use fast models for simple tasks, powerful models for complex ones

**Advantages**:

- ✅ Optimizes for cost and quota management
- ✅ Considers model priorities (configure via `priority` field)
- ✅ Adapts to usage patterns over time

**Disadvantages**:

- ❌ More complex configuration
- ❌ Requires historical data for optimal performance
- ❌ May not adapt quickly to sudden load changes

**Example**:

```yaml
model_list:
  - model_name: claude-3-haiku
    litellm_params:
      model: anthropic/claude-3-haiku-20240307
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 100
    tpm: 3000000
    priority: 10 # Highest priority (cheapest, use first)

  - model_name: claude-3-sonnet
    litellm_params:
      model: anthropic/claude-3-sonnet-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 60
    tpm: 2000000
    priority: 5 # Medium priority (balanced cost/performance)

  - model_name: claude-3-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 30
    tpm: 1500000
    priority: 1 # Lowest priority (most expensive, use last)

router_settings:
  routing_strategy: usage-based-routing # Routes to Haiku first, Opus as last resort
```

---

## Advanced Routing Patterns

### Pattern 1: Provider Fallback (Primary + Backup)

Route to primary provider, fallback to backup on failure.

```yaml
model_list:
  # Primary: Anthropic Direct (lowest latency)
  - model_name: claude-3-5-sonnet-primary
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 50
    priority: 10

  # Backup: Bedrock (high availability)
  - model_name: claude-3-5-sonnet-backup
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    rpm: 40
    priority: 5

router_settings:
  routing_strategy: usage-based-routing
  retry_policy:
    InternalServerErrorRetries: 2
  allowed_fails: 3
  cooldown_time: 60
```

**Behavior**: All requests go to primary. If primary fails 3 times, switches to backup for 60 seconds.

---

### Pattern 2: Multi-Region Load Balancing

Distribute load across regions for high availability.

```yaml
model_list:
  - model_name: claude-us-east-1
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    rpm: 50

  - model_name: claude-us-west-2
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2
    rpm: 50

  - model_name: claude-eu-west-1
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1
    rpm: 50

router_settings:
  routing_strategy: simple-shuffle # Equal distribution across regions
```

**Behavior**: Requests distributed equally across three regions. If one region fails, traffic automatically redistributed to healthy regions.

---

### Pattern 3: Cost-Tiered Routing

Use cheapest model first, escalate to more expensive models only when needed.

```yaml
model_list:
  # Tier 1: Cheapest (Gemini Flash)
  - model_name: gemini-flash
    litellm_params:
      model: vertex_ai/gemini-2.5-flash
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    rpm: 100
    priority: 10

  # Tier 2: Balanced (Claude Sonnet)
  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-3-sonnet-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 60
    priority: 5

  # Tier 3: Most Capable (Claude Opus)
  - model_name: claude-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 30
    priority: 1

router_settings:
  routing_strategy: usage-based-routing
```

**Behavior**: Gemini Flash handles most requests. When Flash hits rate limits, routes to Sonnet. Opus used only as last resort.

---

### Pattern 4: Capability-Based Routing

Route based on model capabilities (vision, function calling, reasoning).

```yaml
model_list:
  # Vision-capable models
  - model_name: claude-3-5-sonnet-vision
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    model_info:
      supports_vision: true
    rpm: 50

  # Reasoning models
  - model_name: deepseek-r1-reasoning
    litellm_params:
      model: vertex_ai/deepseek-ai/deepseek-r1-0528-maas
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    model_info:
      supports_reasoning: true
    rpm: 20

  # Code-specialized models
  - model_name: codestral-fim
    litellm_params:
      model: vertex_ai/codestral@latest
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    model_info:
      supports_fim: true
    rpm: 30

router_settings:
  routing_strategy: least-busy
```

**Behavior**: Application logic selects model by capability. LiteLLM routes within capability group using least-busy strategy.

**Application Code Example**:

```python
# Route image analysis to vision model
response = client.chat.completions.create(
    model="claude-3-5-sonnet-vision",
    messages=[...],
    images=[...]
)

# Route complex reasoning to DeepSeek
response = client.chat.completions.create(
    model="deepseek-r1-reasoning",
    messages=[...]
)

# Route code completion to Codestral
response = client.chat.completions.create(
    model="codestral-fim",
    messages=[...],
    suffix="...",  # FIM context
    prefix="..."
)
```

---

## Routing Decision Matrix

| Scenario                           | Recommended Strategy                  | Configuration Notes                          |
| ---------------------------------- | ------------------------------------- | -------------------------------------------- |
| Dev/Test environments              | `simple-shuffle`                      | Simplicity over optimization                 |
| Production, single provider        | `least-busy`                          | Minimize latency within provider             |
| Production, multi-provider         | `usage-based-routing`                 | Optimize for cost and quotas                 |
| High availability (multi-region)   | `simple-shuffle` or `least-busy`      | Equal distribution or dynamic load balancing |
| Cost optimization                  | `usage-based-routing` with priorities | Route to cheap models first                  |
| Quota management                   | `usage-based-routing`                 | Distribute load to avoid hitting limits      |
| Mixed workloads (simple + complex) | `least-busy`                          | Adapt to request complexity dynamically      |

---

## Configuration Best Practices

### 1. Set Appropriate Rate Limits

```yaml
model_list:
  - model_name: claude-3-5-sonnet
    rpm: 50 # Requests per minute - set below actual limit
    tpm: 2000000 # Tokens per minute - set below actual limit
```

**Tip**: Set limits to 80-90% of actual provider limits to leave buffer for bursts.

---

### 2. Configure Retry Policies

```yaml
router_settings:
  retry_policy:
    TimeoutErrorRetries: 2 # Retry on timeouts
    RateLimitErrorRetries: 3 # Retry on rate limits (with backoff)
    InternalServerErrorRetries: 2 # Retry on 5xx errors
```

**Tip**: Higher retries for rate limits (transient), lower for server errors (may indicate outage).

---

### 3. Enable Health Checks

```yaml
router_settings:
  allowed_fails: 3 # Mark model unhealthy after 3 consecutive failures
  cooldown_time: 60 # Wait 60 seconds before retrying unhealthy model
  enable_pre_call_check: true # Check model health before routing
```

**Tip**: Prevents cascading failures by temporarily removing unhealthy models from rotation.

---

### 4. Monitor and Tune

**Key Metrics to Track**:

- **Request distribution**: Are requests evenly distributed across providers?
- **Error rates by provider**: Is one provider failing more often?
- **Latency by provider**: Which provider is fastest?
- **Cost by provider**: Are you staying within budget?

**Tools**:

- LiteLLM Admin UI: http://localhost:4000/ui (built-in)
- Langfuse integration: Detailed request tracing and analytics
- Prometheus metrics: Export metrics for Grafana dashboards

**Tuning Example**:

```bash
# Check LiteLLM metrics
curl http://localhost:4000/metrics

# Analyze request distribution
curl http://localhost:4000/model/info | jq '.data[] | {model: .model_name, requests: .num_requests}'
```

---

## Fallback Configuration Examples

### Example 1: Three-Tier Fallback

```yaml
model_list:
  - model_name: tier1-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 10

  - model_name: tier2-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    priority: 5

  - model_name: tier3-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    priority: 1

router_settings:
  routing_strategy: usage-based-routing
  allowed_fails: 2
  cooldown_time: 30
```

---

### Example 2: Cross-Provider Load Balancing

```yaml
model_list:
  - model_name: anthropic-1
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 50

  - model_name: bedrock-1
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    rpm: 40

  - model_name: vertex-1
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    rpm: 30

router_settings:
  routing_strategy: least-busy # Adapts to provider performance in real-time
```

---

## Troubleshooting Routing Issues

### Issue: All Requests Go to One Model

**Symptom**: Despite configuring multiple models, all traffic routes to a single model.

**Possible Causes**:

1. **Priority too different**: In `usage-based-routing`, high priority model receives all traffic until exhausted
2. **Rate limits not set**: Without rpm/tpm limits, LiteLLM assumes infinite capacity
3. **Health check disabled**: Unhealthy models not detected

**Solution**:

```yaml
# Set similar priorities for load distribution
model_list:
  - model_name: model-a
    priority: 5 # Not 10
  - model_name: model-b
    priority: 4 # Not 1

# Enable health checks
router_settings:
  enable_pre_call_check: true
  allowed_fails: 3
```

---

### Issue: Frequent Fallback Switches

**Symptom**: Logs show constant switching between providers.

**Possible Causes**:

1. **Cooldown time too short**: Models marked healthy too quickly
2. **allowed_fails too low**: Transient errors trigger fallback prematurely
3. **Provider instability**: Underlying provider having issues

**Solution**:

```yaml
router_settings:
  allowed_fails: 5 # Increase tolerance for transient errors
  cooldown_time: 120 # Increase cooldown period
  retry_policy:
    RateLimitErrorRetries: 5 # Retry rate limits before fallback
```

---

### Issue: High Latency Despite least-busy Strategy

**Symptom**: Average latency higher than expected.

**Possible Causes**:

1. **Slow providers in pool**: One provider significantly slower
2. **No connection pooling**: Each request creates new connection
3. **Retry overhead**: Excessive retries adding latency

**Solution**:

```yaml
# Remove slow providers or set lower priority
model_list:
  - model_name: fast-provider
    priority: 10
  - model_name: slow-provider
    priority: 1 # Use only as last resort

# Reduce retries
router_settings:
  num_retries: 2 # Default is 3
  timeout: 20 # Reduce from 30
```

---

## Next Steps

- **Setup Guide**: See [examples/us3-multi-provider-setup.md](../../examples/us3-multi-provider-setup.md) for step-by-step configuration
- **Provider Configs**: Review provider-specific templates in this directory
- **Environment Variables**: See [examples/us3-provider-env-vars.md](../../examples/us3-provider-env-vars.md) for authentication setup
- **Cost Optimization**: See [examples/us3-cost-optimization.md](../../examples/us3-cost-optimization.md) for cost-aware routing strategies
- **Testing**: Use [tests/test-multi-provider-routing.py](../../tests/test-multi-provider-routing.py) to verify routing behavior

---

## References

- [LiteLLM Router Documentation](https://docs.litellm.ai/docs/routing)
- [Load Balancing Strategies](https://docs.litellm.ai/docs/load_balancing)
- [Fallback Configuration](https://docs.litellm.ai/docs/completion/reliable_completions)
- [Retry Policies](https://docs.litellm.ai/docs/completion/retry)
