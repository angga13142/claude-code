# Load Balancing Strategies

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: Platform Engineers, DevOps Teams  
**Last Updated**: 2025-12-01

---

## Overview

Load balancing distributes requests across multiple model endpoints to improve performance, reliability, and cost-efficiency. LiteLLM provides several load balancing strategies that can be configured through the gateway.

**Benefits**:

- 🚀 **Performance**: Reduce latency by distributing load
- 💪 **Reliability**: Automatic failover when endpoints are unavailable
- 💰 **Cost Optimization**: Route to cheaper providers when available
- 📊 **Resource Utilization**: Balance load across infrastructure

---

## Load Balancing Strategies

### 1. Round Robin (Default)

Distributes requests evenly across all available endpoints in rotation.

**Use Case**: Equal performance across all endpoints, predictable distribution

**Configuration**:

```yaml
router_settings:
  routing_strategy: "simple-shuffle" # Round-robin
  num_retries: 3
```

**Behavior**:

- Request 1 → Endpoint A
- Request 2 → Endpoint B
- Request 3 → Endpoint C
- Request 4 → Endpoint A (cycle continues)

**Pros**:

- ✅ Simple and predictable
- ✅ Even distribution
- ✅ No configuration needed

**Cons**:

- ❌ Doesn't consider endpoint performance
- ❌ Doesn't optimize for cost

---

### 2. Latency-Based Routing

Routes requests to the endpoint with the lowest response time.

**Use Case**: Optimize for speed, reduce user-facing latency

**Configuration**:

```yaml
router_settings:
  routing_strategy: "latency-based-routing"
  num_retries: 3
  window_size: 100 # Sample size for latency calculation
```

**Example Setup**:

```yaml
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-3.5-sonnet # Same name, different provider
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  - model_name: claude-3.5-sonnet # Same name, different region
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1

router_settings:
  routing_strategy: "latency-based-routing"
```

**Behavior**:

- LiteLLM tracks P50/P99 latency for each endpoint
- Routes new requests to fastest endpoint
- Adapts to changing network conditions

**Pros**:

- ✅ Optimizes for user experience
- ✅ Automatically adapts to performance changes
- ✅ Reduces tail latency

**Cons**:

- ❌ May not optimize for cost
- ❌ Requires warm-up period

---

### 3. Cost-Based Routing

Routes requests to the cheapest available endpoint.

**Use Case**: Optimize for cost savings, batch processing

**Configuration**:

```yaml
router_settings:
  routing_strategy: "cost-based-routing"
  num_retries: 3

model_list:
  - model_name: gpt-4
    litellm_params:
      model: gpt-4-turbo
      api_key: os.environ/OPENAI_API_KEY
      rpm: 100 # Rate limit
      input_cost_per_token: 0.00001 # $0.01 per 1K tokens
      output_cost_per_token: 0.00003 # $0.03 per 1K tokens

  - model_name: gpt-4 # Same name, cheaper provider
    litellm_params:
      model: azure/gpt-4-turbo
      api_key: os.environ/AZURE_API_KEY
      input_cost_per_token: 0.000008 # $0.008 per 1K tokens (20% cheaper)
      output_cost_per_token: 0.000024
```

**Behavior**:

- Routes to lowest cost endpoint first
- Falls back to higher cost if rate limited
- Tracks cumulative cost savings

**Pros**:

- ✅ Maximizes cost savings
- ✅ Clear cost control
- ✅ Transparent pricing

**Cons**:

- ❌ May sacrifice latency
- ❌ Requires accurate cost data

---

### 4. Usage-Based Routing

Routes based on remaining quota/rate limits for each endpoint.

**Use Case**: Avoid rate limit errors, maximize throughput

**Configuration**:

```yaml
router_settings:
  routing_strategy: "usage-based-routing"
  num_retries: 3
  allowed_fails: 3 # Fails before marking endpoint as down

model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
      rpm: 1000 # Requests per minute limit
      tpm: 100000 # Tokens per minute limit

  - model_name: claude-3.5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      rpm: 5000 # Higher limit on Bedrock
      tpm: 500000
```

**Behavior**:

- Tracks usage against limits
- Routes to endpoint with most available quota
- Automatically fails over when limits reached

**Pros**:

- ✅ Prevents rate limit errors
- ✅ Maximizes throughput
- ✅ Smart quota management

**Cons**:

- ❌ Requires accurate limit configuration
- ❌ Complex to tune

---

### 5. Weighted Round Robin

Distributes requests based on configured weights.

**Use Case**: Gradual rollout, A/B testing, capacity-based routing

**Configuration**:

```yaml
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    weight: 70 # 70% of traffic

  - model_name: claude-3.5-sonnet
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    weight: 30 # 30% of traffic

router_settings:
  routing_strategy: "weighted-round-robin"
```

**Behavior**:

- Distributes traffic according to weights
- Higher weight = more requests
- Useful for gradual migration

**Use Cases**:

1. **Gradual Rollout**: Start new provider at 10%, increase to 100%
2. **A/B Testing**: Split 50/50 to compare providers
3. **Capacity-Based**: Route 80% to high-capacity, 20% to backup
4. **Cost Optimization**: 90% to cheap provider, 10% to premium

**Pros**:

- ✅ Flexible distribution control
- ✅ Safe for gradual changes
- ✅ A/B testing support

**Cons**:

- ❌ Manual weight tuning needed
- ❌ Not adaptive

---

## Advanced Configuration

### Combining Strategies

You can combine strategies for sophisticated routing:

```yaml
router_settings:
  # Primary: Cost-based routing
  routing_strategy: "cost-based-routing"

  # Fallback: Latency-based when cost is similar
  fallback_strategy: "latency-based-routing"

  # Health checks
  num_retries: 3
  allowed_fails: 5 # Mark endpoint down after 5 consecutive fails
  cooldown_time: 60 # Seconds before retrying failed endpoint

  # Rate limiting
  rpm: 1000 # Global rate limit (requests per minute)
  tpm: 100000 # Global token limit (tokens per minute)
```

### Health Checks

Configure health checks to detect and avoid unhealthy endpoints:

```yaml
router_settings:
  # Health check configuration
  health_check_interval: 30 # Seconds between checks
  health_check_timeout: 5 # Timeout for health check

  # Failure thresholds
  allowed_fails: 3 # Consecutive fails before marking down
  cooldown_time: 60 # Seconds before retry

  # Success threshold (to mark endpoint as healthy)
  success_threshold: 2 # Consecutive successes needed
```

### Circuit Breaker Pattern

Automatically stop sending requests to failing endpoints:

```yaml
router_settings:
  # Circuit breaker configuration
  enable_circuit_breaker: true
  failure_threshold: 10 # Failures before opening circuit
  success_threshold: 3 # Successes before closing circuit
  timeout: 120 # Seconds before attempting reset
```

**States**:

- **Closed**: Normal operation, requests flow through
- **Open**: Too many failures, requests bypass endpoint
- **Half-Open**: Testing if endpoint recovered

---

## Monitoring Load Balancing

### Metrics to Track

```yaml
litellm_settings:
  # Enable detailed logging
  set_verbose: true

  # Success tracking
  success_callback: ["langfuse", "prometheus"] # Track successful requests
  failure_callback: ["langfuse", "prometheus"] # Track failures

  # Store in database
  database_url: "postgresql://user:pass@host:5432/litellm"
```

**Key Metrics**:

1. **Request Distribution**: Requests per endpoint
2. **Latency**: P50/P95/P99 per endpoint
3. **Error Rate**: Failures per endpoint
4. **Cost**: Spend per endpoint
5. **Throughput**: Tokens per second

### Dashboard Example (Prometheus + Grafana)

```yaml
# prometheus.yml
scrape_configs:
  - job_name: "litellm"
    static_configs:
      - targets: ["localhost:4000"] # LiteLLM metrics endpoint
```

**Grafana Queries**:

```promql
# Request distribution
sum by (model) (litellm_requests_total)

# Average latency
avg by (model) (litellm_request_duration_seconds)

# Error rate
rate(litellm_errors_total[5m])

# Cost per hour
rate(litellm_cost_total[1h]) * 3600
```

---

## Best Practices

### 1. Start Simple

Begin with round-robin, then optimize:

```yaml
# Week 1: Round-robin (baseline)
router_settings:
  routing_strategy: "simple-shuffle"

# Week 2: Add latency optimization
router_settings:
  routing_strategy: "latency-based-routing"

# Week 3: Optimize for cost
router_settings:
  routing_strategy: "cost-based-routing"
```

### 2. Set Appropriate Limits

Configure realistic rate limits:

```yaml
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      rpm: 1000 # Start conservative
      tpm: 100000
      max_parallel_requests: 100 # Concurrent request limit
```

### 3. Monitor and Adjust

Track metrics and tune configuration:

```bash
# View request distribution
curl http://localhost:4000/metrics | grep litellm_requests_total

# Check endpoint health
curl http://localhost:4000/health/readiness
```

### 4. Test Failover

Simulate endpoint failures to verify routing:

```bash
# Stop endpoint temporarily
# Verify requests route to backup

# Check logs
tail -f ~/.litellm/logs/litellm.log | grep "routing"
```

### 5. Gradual Rollout

Use weighted routing for safe changes:

```yaml
# Week 1: 10% new provider
model_list:
  - model_name: claude
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
    weight: 90
  - model_name: claude
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
    weight: 10 # Start small

# Week 2: Increase if successful
# weight: 30

# Week 3: Full migration
# weight: 100
```

---

## Common Patterns

### Pattern 1: Multi-Region Failover

Route to closest region, failover to others:

```yaml
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2 # Primary
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1 # Backup
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1 # Backup

router_settings:
  routing_strategy: "latency-based-routing" # Routes to closest
  num_retries: 2 # Try other regions if primary fails
```

### Pattern 2: Cost-Performance Tiering

Cheap provider for batch, premium for interactive:

```yaml
# Batch processing endpoint (cost-optimized)
model_list:
  - model_name: claude-batch
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
router_settings:
  routing_strategy: "cost-based-routing"

# Interactive endpoint (latency-optimized)
model_list:
  - model_name: claude-interactive
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
router_settings:
  routing_strategy: "latency-based-routing"
```

### Pattern 3: A/B Testing

Compare providers with controlled traffic split:

```yaml
model_list:
  - model_name: claude-experiment
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      metadata:
        variant: "control"
    weight: 50

  - model_name: claude-experiment
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      metadata:
        variant: "treatment"
    weight: 50

# Track metrics by variant
litellm_settings:
  success_callback: ["langfuse"] # Track by metadata
```

---

## Troubleshooting

### Issue: Uneven Distribution

**Symptoms**: One endpoint receiving most traffic

**Solutions**:

1. Check routing strategy (simple-shuffle for even distribution)
2. Verify all endpoints are healthy
3. Check rate limits aren't being hit
4. Review weights if using weighted routing

```bash
# Check endpoint status
curl http://localhost:4000/health/readiness

# View request distribution
curl http://localhost:4000/metrics | grep litellm_requests_total
```

### Issue: High Latency

**Symptoms**: Slow responses despite load balancing

**Solutions**:

1. Switch to latency-based routing
2. Add more endpoints
3. Check endpoint health
4. Review network path

```yaml
# Optimize for latency
router_settings:
  routing_strategy: "latency-based-routing"
  window_size: 100 # Larger sample for accuracy
```

### Issue: Rate Limit Errors

**Symptoms**: 429 errors despite multiple endpoints

**Solutions**:

1. Use usage-based routing
2. Increase rpm/tpm limits
3. Add more endpoints
4. Implement request queuing

```yaml
router_settings:
  routing_strategy: "usage-based-routing"
  rpm: 1000 # Increase limit
```

---

## Related Documentation

- [Fallback and Retry Policies](fallback-retry.md) - Error handling strategies
- [Multi-Region Deployment](multi-region-deployment.md) - Geographic distribution
- [Observability and Monitoring](observability.md) - Metrics and logging
- [Cost Tracking](cost-tracking.md) - Cost optimization strategies

---

## References

- [LiteLLM Routing Documentation](https://docs.litellm.ai/docs/routing)
- [Load Balancing Algorithms](<https://en.wikipedia.org/wiki/Load_balancing_(computing)>)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
