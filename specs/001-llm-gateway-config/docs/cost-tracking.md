# Cost Tracking and Optimization

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: Platform Engineers, FinOps Teams  
**Last Updated**: 2025-12-01

---

## Overview

LLM costs can be significant. Proper cost tracking and optimization strategies can reduce spending by 40-70% while maintaining performance and quality.

**Cost Optimization Strategies**:

- 💰 **Caching**: 40-70% savings by reusing responses
- 🎯 **Smart Routing**: 20-40% savings with cost-based routing
- 📊 **Model Selection**: 30-60% savings with right-sized models
- ⏱️ **Rate Limiting**: Prevent runaway costs

---

## Cost Tracking

### Enable Cost Logging

**Configuration**:

```yaml
litellm_settings:
  # Track costs
  success_callback: ["langfuse", "prometheus"]

  # Cost database
  database_url: "postgresql://user:pass@host:5432/litellm"

  # Model costs (optional override)
model_cost_map:
  "claude-3.5-sonnet":
    input_cost_per_token: 0.000003 # $3/1M tokens
    output_cost_per_token: 0.000015 # $15/1M tokens
```

### View Cost Metrics

```bash
# Current spend rate
curl http://localhost:4000/metrics | grep litellm_cost_total

# Spend by model
curl http://localhost:4000/admin/costs?group_by=model

# Spend by user/API key
curl http://localhost:4000/admin/costs?group_by=api_key
```

**Response**:

```json
{
  "total_cost": 145.32,
  "period": "last_24h",
  "breakdown": {
    "claude-3.5-sonnet": 95.2,
    "gemini-2.0-flash": 30.15,
    "codestral": 19.97
  }
}
```

---

## Caching Strategies

### Semantic Caching

Cache similar prompts to reduce duplicate requests.

**Configuration**:

```yaml
litellm_settings:
  # Enable caching
  cache: true
  cache_type: "redis"
  cache_ttl: 3600 # 1 hour

  # Redis connection
  redis_host: "localhost"
  redis_port: 6379
  redis_password: os.environ/REDIS_PASSWORD

  # Semantic caching (similar prompts)
  enable_semantic_cache: true
  cache_similarity_threshold: 0.95 # 95% similarity
```

**Savings Example**:

```
Original costs (no cache):
- 1000 requests/day × $0.045/request = $45/day

With 60% cache hit rate:
- 400 new requests × $0.045 = $18/day
- 600 cached requests × $0 = $0
- Total: $18/day (60% savings)
```

### Prompt Caching (Anthropic)

Cache prompt prefixes to reduce input token costs.

**Configuration**:

```yaml
model_list:
  - model_name: claude-cache
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
      cache_control: true # Enable prompt caching
```

**Application Code**:

```python
import litellm

response = litellm.completion(
    model="claude-cache",
    messages=[
        {
            "role": "system",
            "content": [
                {
                    "type": "text",
                    "text": "You are a helpful coding assistant...",  # Large system prompt
                    "cache_control": {"type": "ephemeral"}  # Cache this prefix
                }
            ]
        },
        {"role": "user", "content": "Write a function..."}  # New request
    ]
)
```

**Savings**:

- Cached input tokens: 90% cheaper
- System prompt (5000 tokens) cached: $0.015 → $0.0015 (90% off)
- Per request savings: $0.0135

---

## Cost-Based Routing

### Route to Cheapest Provider

**Configuration**:

```yaml
router_settings:
  routing_strategy: "cost-based-routing"

model_list:
  # Expensive: Anthropic Direct
  - model_name: claude-any
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      input_cost_per_token: 0.000003 # $3/1M input
      output_cost_per_token: 0.000015 # $15/1M output

  # Cheaper: AWS Bedrock (bulk discount)
  - model_name: claude-any
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      input_cost_per_token: 0.0000024 # $2.40/1M input (20% off)
      output_cost_per_token: 0.000012 # $12/1M output (20% off)

  # Cheapest: Vertex AI (committed use discount)
  - model_name: claude-any
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      input_cost_per_token: 0.0000018 # $1.80/1M input (40% off)
      output_cost_per_token: 0.000009 # $9/1M output (40% off)
```

**Savings**: 20-40% by routing to cheapest available provider

---

## Model Selection Optimization

### Right-Size Your Models

Use cheaper models when quality difference is minimal.

**Model Tiers**:

| Model             | Input Cost | Output Cost | Use Case                       |
| ----------------- | ---------- | ----------- | ------------------------------ |
| Gemini 2.0 Flash  | $0.075/1M  | $0.30/1M    | Simple Q&A, classification     |
| Claude 3.5 Haiku  | $0.80/1M   | $4.00/1M    | Chat, summaries, short content |
| Claude 3.5 Sonnet | $3.00/1M   | $15.00/1M   | Complex reasoning, coding      |
| Claude 3 Opus     | $15.00/1M  | $75.00/1M   | Highest quality, research      |

**Configuration**:

```yaml
# Simple tasks → Gemini Flash
model_list:
  - model_name: simple-tasks
    litellm_params:
      model: vertex_ai/gemini-2.0-flash-exp
      max_tokens: 500 # Limit output

  # Complex tasks → Claude Sonnet
  - model_name: complex-tasks
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      max_tokens: 4000
```

**Savings Example**:

- 70% of requests are simple (classification, extraction)
- Switch from Sonnet ($3/$15) to Flash ($0.075/$0.30)
- Savings: 97.5% on simple tasks

---

## Rate Limiting & Budgets

### Per-User Budgets

Prevent runaway costs from individual users.

**Configuration**:

```yaml
litellm_settings:
  # Enable budget tracking
  database_url: "postgresql://..."

  # Per-API key budgets
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
# Create API keys with budgets
```

**Create Budget-Limited Key**:

```bash
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "user_id": "user_123",
    "max_budget": 100.00,
    "budget_duration": "monthly"
  }'
```

**Behavior**:

- Tracks spend per API key
- Rejects requests when budget exceeded
- Resets monthly/daily

### Global Rate Limiting

Limit total requests to control costs.

**Configuration**:

```yaml
router_settings:
  rpm: 1000 # Max 1000 requests per minute
  tpm: 100000 # Max 100K tokens per minute

# Per-model limits
model_list:
  - model_name: expensive-model
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      rpm: 100 # Only 100 RPM for expensive model
      max_budget_per_hour: 50.00 # Max $50/hour
```

---

## Cost Monitoring

### Real-Time Cost Dashboard

**Grafana Queries**:

**Spend Rate ($/hour)**:

```promql
rate(litellm_cost_total[1h]) * 3600
```

**Spend by Model**:

```promql
sum by (model) (litellm_cost_total)
```

**Top Spenders (by API key)**:

```promql
topk(10, sum by (api_key_id) (litellm_cost_total))
```

**Cache Savings**:

```promql
# Savings from cache hits
(litellm_cache_hits_total / (litellm_cache_hits_total + litellm_cache_misses_total)) * litellm_cost_total
```

### Cost Alerts

**Daily Budget Alert**:

```yaml
- alert: DailyBudgetExceeded
  expr: sum(increase(litellm_cost_total[24h])) > 100 # $100/day limit
  labels:
    severity: critical
  annotations:
    summary: "Daily budget exceeded: ${{ $value }}"
```

**Unusual Spending Pattern**:

```yaml
- alert: UnusualSpendingSpike
  expr: rate(litellm_cost_total[1h]) > avg_over_time(rate(litellm_cost_total[1h])[7d:1h]) * 2 # 2x average
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "Spending spike detected"
```

---

## Optimization Strategies

### Strategy 1: Aggressive Caching

**Before**:

- Cache TTL: 1 hour
- Cache hit rate: 40%
- Daily cost: $45

**After**:

```yaml
litellm_settings:
  cache_ttl: 86400 # 24 hours
  enable_semantic_cache: true
  cache_similarity_threshold: 0.90 # More aggressive matching
```

**Result**:

- Cache hit rate: 65%
- Daily cost: $18 (60% savings)

---

### Strategy 2: Tiered Model Routing

Route by complexity automatically.

**Configuration**:

```python
# Application-level routing
def get_model_for_task(prompt: str, task_type: str) -> str:
    """Select cheapest appropriate model."""

    # Simple classification/extraction
    if task_type == "classification" or len(prompt) < 200:
        return "gemini-2.0-flash"  # $0.075/$0.30 per 1M

    # Code generation
    elif "code" in task_type.lower():
        return "codestral"  # $1/$3 per 1M

    # Complex reasoning
    elif task_type == "reasoning":
        return "claude-3.5-sonnet"  # $3/$15 per 1M

    # Default
    else:
        return "claude-3.5-haiku"  # $0.80/$4 per 1M
```

**Savings**: 30-50% by right-sizing models

---

### Strategy 3: Output Length Limits

Prevent excessive output costs.

**Configuration**:

```yaml
model_list:
  - model_name: claude-limited
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      max_tokens: 1000 # Limit output to 1K tokens

  # For summaries only
  - model_name: claude-summary
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      max_tokens: 200 # Very short summaries
```

**Savings**: Output tokens are 5x more expensive than input

---

### Strategy 4: Batch Processing

Process multiple requests together.

**Configuration**:

```yaml
# Use batch API when available
model_list:
  - model_name: claude-batch
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      use_batch_api: true # 50% cheaper
      batch_window: 300 # Wait up to 5 minutes to batch
```

**Savings**: 50% with batch API (when latency acceptable)

---

## Cost Reporting

### Daily Cost Report

**Script** (`scripts/daily-cost-report.sh`):

```bash
#!/bin/bash
# Generate daily cost report

echo "=== Daily LLM Cost Report ==="
echo "Date: $(date)"
echo ""

# Total spend
total=$(curl -s http://localhost:4000/admin/costs?period=24h | jq '.total_cost')
echo "Total: \$$total"

# By model
echo ""
echo "By Model:"
curl -s http://localhost:4000/admin/costs?period=24h | jq -r '.breakdown | to_entries[] | "\(.key): $\(.value)"'

# Top users
echo ""
echo "Top 10 Users:"
curl -s http://localhost:4000/admin/costs?period=24h&group_by=user_id | jq -r '.breakdown | to_entries | sort_by(.value) | reverse | .[0:10][] | "\(.key): $\(.value)"'
```

### Monthly Cost Analysis

**SQL Query** (if using database):

```sql
SELECT
  DATE_TRUNC('day', created_at) as date,
  model,
  COUNT(*) as requests,
  SUM(input_tokens) as input_tokens,
  SUM(output_tokens) as output_tokens,
  SUM(cost) as total_cost,
  AVG(cost) as avg_cost_per_request
FROM requests
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY date, model
ORDER BY date DESC, total_cost DESC;
```

---

## Best Practices

1. **Enable caching first**: Easiest 40-70% savings
2. **Set budgets**: Prevent surprises
3. **Monitor daily**: Review dashboard every morning
4. **Right-size models**: Don't use Opus for classification
5. **Limit output**: Set reasonable max_tokens
6. **Use batch when possible**: 50% cheaper
7. **Track by user**: Identify high-cost users
8. **Review monthly**: Optimize based on usage patterns

---

## Cost Optimization Checklist

- [ ] Enable Redis caching (60% savings potential)
- [ ] Enable Anthropic prompt caching (90% on cached prompts)
- [ ] Set up cost-based routing (20-40% savings)
- [ ] Right-size models (30-60% savings)
- [ ] Set output token limits (prevent runaway costs)
- [ ] Enable per-user budgets (cost control)
- [ ] Set up cost alerts (proactive monitoring)
- [ ] Review top spenders weekly (identify optimization opportunities)
- [ ] Use batch API where latency allows (50% savings)
- [ ] Monitor cache hit rate (target >60%)

---

## ROI Calculator

**Scenario**: 1M requests/month

**Without Optimization**:

- Model: Claude 3.5 Sonnet
- Avg input: 1000 tokens × $3/1M = $3
- Avg output: 500 tokens × $15/1M = $7.50
- Cost per request: $10.50
- **Monthly cost: $10,500**

**With Optimization**:

- Cache hit rate: 60% → 400K new requests
- Cost-based routing: 20% savings → $8.40/request
- Right-sized models (30% simple tasks): → $6.50/request (weighted avg)
- **Monthly cost: $2,600** (75% savings)

**Annual Savings**: $94,800

---

## Related Documentation

- [Observability and Monitoring](observability.md)
- [Load Balancing Strategies](load-balancing.md)
- [Configuration Reference](configuration-reference.md)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
