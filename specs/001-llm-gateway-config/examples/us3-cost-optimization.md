# US3: Cost Optimization Guide for Multi-Provider Scenarios

**User Story**: US3 - Multi-Provider Gateway Configuration (Priority: P3)  
**Purpose**: Strategies to minimize costs when using multiple Claude providers  
**Audience**: Platform engineers, FinOps teams, engineering managers

---

## Overview

Running Claude across multiple providers (Anthropic Direct, Bedrock, Vertex AI) offers flexibility but requires cost optimization strategies. This guide provides actionable techniques to minimize spending while maintaining performance and reliability.

---

## Provider Pricing Comparison (2024)

### Anthropic Direct

| Model             | Input (per MTok) | Output (per MTok) | Prompt Cache Write | Prompt Cache Read |
| ----------------- | ---------------- | ----------------- | ------------------ | ----------------- |
| Claude 3.5 Sonnet | $3.00            | $15.00            | $3.75              | $0.30             |
| Claude 3 Opus     | $15.00           | $75.00            | $18.75             | $1.50             |
| Claude 3 Sonnet   | $3.00            | $15.00            | $3.75              | $0.30             |
| Claude 3 Haiku    | $0.25            | $1.25             | $0.30              | $0.03             |

### AWS Bedrock

| Model             | Input (per MTok) | Output (per MTok) |
| ----------------- | ---------------- | ----------------- |
| Claude 3.5 Sonnet | $3.00            | $15.00            |
| Claude 3 Opus     | $15.00           | $75.00            |
| Claude 3 Sonnet   | $3.00            | $15.00            |
| Claude 3 Haiku    | $0.25            | $1.25             |

**Additional Costs**: None (no data transfer charges within same region)

### Google Vertex AI

| Model             | Input (per MTok) | Output (per MTok) |
| ----------------- | ---------------- | ----------------- |
| Claude 3.5 Sonnet | $3.00            | $15.00            |
| Claude 3 Opus     | $15.00           | $75.00            |
| Claude 3 Sonnet   | $3.00            | $15.00            |
| Claude 3 Haiku    | $0.25            | $1.25             |

**Additional Costs**: Vertex AI Model Garden charges (typically 10-20% markup)

**Cost Ranking** (Cheapest to Most Expensive):

1. **Anthropic Direct** (with prompt caching): Cheapest for repeated prompts
2. **AWS Bedrock**: Competitive pricing, no markup
3. **Anthropic Direct** (without caching): Base pricing
4. **Vertex AI**: 10-20% markup over base pricing

---

## Cost Optimization Strategies

### Strategy 1: Priority-Based Routing

**Concept**: Route to cheapest provider first, use expensive ones only as fallback.

**Implementation**:

```yaml
router_settings:
  routing_strategy: usage-based-routing

model_list:
  - model_name: claude-3-5-sonnet-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 10 # Highest - use first

  - model_name: claude-3-5-sonnet-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    priority: 5 # Medium - use as backup

  - model_name: claude-3-5-sonnet-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    priority: 1 # Lowest - use only when others exhausted
```

**Estimated Savings**: 10-20% by avoiding expensive provider markup

---

### Strategy 2: Prompt Caching (Anthropic Direct Only)

**Concept**: Cache repeated prompt prefixes to reduce input token costs by 90%.

**Implementation**:

```yaml
litellm_settings:
  anthropic_beta: "prompt-caching-2024-07-31"
```

**When to Use**:

- Long system prompts (>1000 tokens)
- Repeated context (documentation, code files)
- Multi-turn conversations with stable context

**Example Savings**:

```
Without caching:
  Input:  10,000 tokens × $3.00/MTok = $0.03
  Output: 1,000 tokens × $15.00/MTok = $0.015
  Total per request: $0.045

With caching (after first request):
  Cached input:  9,000 tokens × $0.30/MTok = $0.0027
  New input:     1,000 tokens × $3.00/MTok = $0.003
  Output:        1,000 tokens × $15.00/MTok = $0.015
  Total per request: $0.0207

Savings: 54% per cached request
```

**Best Practices**:

- Structure prompts with stable prefix, variable suffix
- Cache expires after 5 minutes of inactivity
- Minimum cache size: 1024 tokens

---

### Strategy 3: Model Tiering

**Concept**: Use cheaper models for simple tasks, expensive ones for complex tasks.

**Implementation**:

```yaml
model_list:
  # Tier 1: Simple tasks (90% of requests)
  - model_name: claude-3-haiku
    litellm_params:
      model: anthropic/claude-3-haiku-20240307
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 100
    priority: 10

  # Tier 2: Medium tasks (8% of requests)
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 50
    priority: 5

  # Tier 3: Complex tasks (2% of requests)
  - model_name: claude-3-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    rpm: 20
    priority: 1
```

**Task Classification**:
| Task Type | Model | Cost per Request (avg) |
|-----------|-------|------------------------|
| Simple Q&A, formatting | Haiku | $0.002 |
| Code generation, analysis | Sonnet | $0.05 |
| Complex reasoning, research | Opus | $0.30 |

**Estimated Savings**: 70-80% by using appropriate model tier

**Implementation in Application**:

```python
# Python example
def get_model_for_task(task_type: str) -> str:
    if task_type in ["qa", "format", "summary"]:
        return "claude-3-haiku"
    elif task_type in ["code", "analysis", "translation"]:
        return "claude-3-5-sonnet"
    else:  # complex reasoning, multi-step tasks
        return "claude-3-opus"

response = client.chat.completions.create(
    model=get_model_for_task(user_task),
    messages=[...]
)
```

---

### Strategy 4: Rate Limit Optimization

**Concept**: Set rate limits to match actual needs, avoid over-provisioning.

**Implementation**:

```yaml
model_list:
  - model_name: claude-3-5-sonnet
    rpm: 30 # ← Set based on actual usage patterns
    tpm: 1500000
```

**How to Determine Optimal Limits**:

1. Monitor actual usage for 1 week
2. Calculate 95th percentile RPM
3. Set limit to 95th percentile + 20% buffer
4. Adjust monthly based on trends

**Example Analysis**:

```bash
# Query LiteLLM metrics
curl http://localhost:4000/metrics | grep requests_per_minute

# Sample output:
# requests_per_minute{model="claude-3-5-sonnet"} 18.5

# Optimal setting: 18.5 × 1.2 = 22.2 ≈ 25 RPM
```

**Cost Impact**: Prevents overage charges and throttling costs

---

### Strategy 5: Regional Optimization

**Concept**: Use geographically nearest provider to reduce latency and data transfer costs.

**Implementation** (Multi-Region):

```yaml
model_list:
  # US traffic
  - model_name: claude-us
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  # EU traffic
  - model_name: claude-eu
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1

  # APAC traffic
  - model_name: claude-apac
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: asia-southeast1
```

**Application-Level Routing**:

```python
def get_model_for_region(user_ip: str) -> str:
    region = geoip_lookup(user_ip)
    if region == "US":
        return "claude-us"
    elif region == "EU":
        return "claude-eu"
    else:
        return "claude-apac"
```

**Estimated Savings**: 5-10% latency reduction, no cross-region data transfer charges

---

### Strategy 6: Batch Processing

**Concept**: Aggregate multiple small requests into larger batches to reduce overhead.

**Implementation**:

```python
# Instead of 100 individual requests
for item in items:
    response = client.chat.completions.create(...)  # 100 API calls

# Batch into 10 requests of 10 items each
for batch in chunk(items, size=10):
    combined_prompt = "Process these items:\n" + "\n".join(batch)
    response = client.chat.completions.create(
        model="claude-3-5-sonnet",
        messages=[{"role": "user", "content": combined_prompt}]
    )  # 10 API calls
```

**Estimated Savings**: 40-60% reduction in request overhead

**Trade-offs**:

- ✅ Fewer API calls = lower costs
- ❌ Higher latency per batch
- ❌ All-or-nothing failure mode

---

## Cost Monitoring & Alerts

### 1. Enable LiteLLM Analytics

```yaml
litellm_settings:
  success_callback: ["langfuse"]
  database_url: os.environ/DATABASE_URL
```

**Benefits**:

- Track cost per model/provider
- Identify expensive requests
- Monitor usage trends

### 2. Set Up Provider Alerts

**AWS CloudWatch Alarm** (Bedrock):

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name bedrock-cost-alert \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100.00 \
  --comparison-operator GreaterThanThreshold
```

**GCP Budget Alert** (Vertex AI):

```bash
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Vertex AI Budget" \
  --budget-amount=1000 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90
```

### 3. Daily Cost Report Script

```bash
#!/bin/bash
# daily-cost-report.sh

echo "=== Daily Claude Cost Report ==="
echo "Date: $(date)"

# Query LiteLLM database
psql $DATABASE_URL -c "
  SELECT
    model_name,
    provider,
    COUNT(*) as requests,
    SUM(input_tokens) as input_tokens,
    SUM(output_tokens) as output_tokens,
    SUM(cost) as total_cost
  FROM request_logs
  WHERE created_at >= NOW() - INTERVAL '1 day'
  GROUP BY model_name, provider
  ORDER BY total_cost DESC;
"
```

---

## Cost Optimization Checklist

### Initial Setup

- [ ] Choose cheapest primary provider (Anthropic Direct with caching)
- [ ] Configure priority-based routing (usage-based-routing)
- [ ] Set up model tiering (Haiku/Sonnet/Opus)
- [ ] Enable prompt caching for Anthropic Direct
- [ ] Configure regional routing if serving global traffic

### Ongoing Optimization

- [ ] Review cost reports weekly
- [ ] Adjust rate limits based on actual usage
- [ ] Identify and optimize high-cost requests
- [ ] Test batch processing for bulk operations
- [ ] Monitor cache hit rates (target >80% for cached prompts)

### Monitoring

- [ ] Set up billing alerts (50% and 90% thresholds)
- [ ] Track cost per user/team/project
- [ ] Monitor provider-specific spending
- [ ] Analyze cost trends (daily/weekly/monthly)

---

## Cost Estimation Examples

### Example 1: Development Team (5 engineers)

**Usage Pattern**:

- 500 requests/day
- Average: 5,000 input tokens, 1,000 output tokens per request
- Mix: 80% Sonnet, 20% Opus

**Without Optimization**:

```
Sonnet: 400 req × (5k × $3/MTok + 1k × $15/MTok) = $12.00/day
Opus:   100 req × (5k × $15/MTok + 1k × $75/MTok) = $15.00/day
Total: $27.00/day × 20 workdays = $540/month
```

**With Optimization** (tiering + caching):

```
Haiku:  300 req × (5k × $0.25/MTok + 1k × $1.25/MTok) = $0.75/day
Sonnet: 150 req × (1k × $3/MTok + 1k × $15/MTok) = $2.70/day  # 4k cached
Opus:   50 req × (5k × $15/MTok + 1k × $75/MTok) = $7.50/day
Total: $10.95/day × 20 workdays = $219/month

Savings: $321/month (59%)
```

---

### Example 2: Production API (10,000 req/day)

**Usage Pattern**:

- High volume, simple tasks
- Average: 2,000 input tokens, 500 output tokens per request
- 100% Haiku eligible

**Without Optimization** (using Sonnet):

```
10,000 req × (2k × $3/MTok + 0.5k × $15/MTok) = $135/day
Total: $135/day × 30 days = $4,050/month
```

**With Optimization** (Haiku):

```
10,000 req × (2k × $0.25/MTok + 0.5k × $1.25/MTok) = $11.25/day
Total: $11.25/day × 30 days = $337.50/month

Savings: $3,712.50/month (92%)
```

---

## Advanced Cost Techniques

### 1. Smart Caching Layer

**Concept**: Cache identical requests at application layer (before hitting LLM).

```python
import hashlib
import redis

redis_client = redis.Redis(host='localhost', port=6379)

def get_cached_response(prompt: str, ttl: int = 3600):
    cache_key = f"claude:{hashlib.sha256(prompt.encode()).hexdigest()}"
    cached = redis_client.get(cache_key)

    if cached:
        return json.loads(cached)  # Cache hit - $0 cost

    response = client.chat.completions.create(...)  # Cache miss - API cost
    redis_client.setex(cache_key, ttl, json.dumps(response))
    return response
```

**Estimated Savings**: 30-50% for applications with repeated queries

---

### 2. Quota Management

**Concept**: Enforce per-user/team quotas to prevent runaway costs.

```yaml
general_settings:
  database_url: os.environ/DATABASE_URL
# Configure user quotas (requires LiteLLM database)
```

**Application-Level**:

```python
def check_quota(user_id: str, cost: float) -> bool:
    monthly_usage = get_user_monthly_cost(user_id)
    user_quota = get_user_quota(user_id)  # e.g., $100/month

    if monthly_usage + cost > user_quota:
        raise QuotaExceededError(f"Monthly quota of ${user_quota} exceeded")
    return True
```

---

## Next Steps

- **Setup**: Follow [examples/us3-multi-provider-setup.md](./us3-multi-provider-setup.md)
- **Provider Selection**: See [examples/us3-provider-selection.md](./us3-provider-selection.md)
- **Monitoring**: Configure Langfuse or similar analytics platform
- **Optimization**: Implement 2-3 strategies from this guide, measure impact

---

## Additional Resources

- [Anthropic Pricing](https://www.anthropic.com/pricing)
- [AWS Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing)
- [LiteLLM Cost Tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)
- [Prompt Caching Guide](https://docs.anthropic.com/claude/docs/prompt-caching)
