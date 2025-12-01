# Observability and Monitoring

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: DevOps, SREs, Platform Engineers  
**Last Updated**: 2025-12-01

---

## Overview

Observability provides visibility into LLM gateway performance, costs, and errors. Proper monitoring enables proactive issue detection, cost optimization, and capacity planning.

**Observability Pillars**:

- 📊 **Metrics**: Performance, usage, costs
- 📝 **Logs**: Request details, errors
- 🔍 **Traces**: End-to-end request flow
- 🚨 **Alerts**: Proactive issue notification

---

## Metrics Collection

### Enable Prometheus Metrics

**Configuration**:

```yaml
litellm_settings:
  success_callback: ["prometheus"]
  failure_callback: ["prometheus"]

  # Metrics endpoint
  prometheus_port: 9090
```

**Available Metrics**:

```
# Request metrics
litellm_requests_total{model, status}
litellm_request_duration_seconds{model}
litellm_tokens_total{model, type}  # type: input/output

# Cost metrics
litellm_cost_total{model, provider}

# Error metrics
litellm_errors_total{model, error_type}

# Model health
litellm_model_health{model, region}

# Cache metrics
litellm_cache_hits_total
litellm_cache_misses_total
```

### Scrape Configuration

**Prometheus** (`prometheus.yml`):

```yaml
scrape_configs:
  - job_name: "litellm"
    static_configs:
      - targets: ["localhost:9090"]
    scrape_interval: 15s
```

---

## Logging

### Enable Detailed Logging

**Configuration**:

```yaml
litellm_settings:
  set_verbose: true # Detailed logs
  log_level: "INFO" # DEBUG, INFO, WARN, ERROR

  # Log to file
  log_file: "~/.litellm/logs/litellm.log"

  # Rotation
  max_log_file_size_mb: 100
  max_log_files: 10
```

### Log Levels

**DEBUG**: All requests, responses, internal decisions

```
[DEBUG] Routing request to model: claude-3.5-sonnet
[DEBUG] Provider: anthropic, Region: us-west-2
[DEBUG] Estimated cost: $0.0045
```

**INFO**: Request summary, model selection

```
[INFO] Request received: model=claude-3.5-sonnet, tokens=1500
[INFO] Routed to: anthropic/claude-3.5-sonnet-20241022
[INFO] Response time: 2.3s, cost: $0.0045
```

**WARN**: Retries, fallbacks, rate limits

```
[WARN] Rate limit hit for anthropic, retrying with exponential backoff
[WARN] Falling back to bedrock/claude-3-5-sonnet
```

**ERROR**: Failures, invalid configs

```
[ERROR] Request failed: InvalidAPIKey
[ERROR] All fallback models exhausted
```

### Structured Logging

```yaml
litellm_settings:
  json_logs: true # Enable JSON format
```

**JSON Log Format**:

```json
{
  "timestamp": "2025-12-01T10:30:00Z",
  "level": "INFO",
  "model": "claude-3.5-sonnet",
  "provider": "anthropic",
  "region": "us-west-2",
  "duration_ms": 2300,
  "input_tokens": 1000,
  "output_tokens": 500,
  "cost": 0.0045,
  "status": "success",
  "request_id": "req_abc123"
}
```

---

## Distributed Tracing

### Enable OpenTelemetry

**Configuration**:

```yaml
litellm_settings:
  success_callback: ["otel"]
  failure_callback: ["otel"]

  # OpenTelemetry endpoint
  otel_endpoint: "http://localhost:4318" # OTLP HTTP
  otel_service_name: "litellm-gateway"
```

### Trace Example

```
Span: POST /v1/chat/completions (2.5s)
  ├─ Span: Route Selection (0.1s)
  │   └─ Model: claude-3.5-sonnet selected (latency-based)
  ├─ Span: Provider Request: anthropic (2.3s)
  │   ├─ Event: Request sent (1000 input tokens)
  │   ├─ Event: Streaming started
  │   └─ Event: Response received (500 output tokens)
  └─ Span: Response Processing (0.1s)
      └─ Event: Cost calculated: $0.0045
```

### Integrate with Jaeger

```bash
# Run Jaeger
docker run -d -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest

# Access UI
open http://localhost:16686
```

---

## Application Performance Monitoring (APM)

### Langfuse Integration

Track model performance and costs.

**Configuration**:

```yaml
litellm_settings:
  success_callback: ["langfuse"]

  # Langfuse credentials
langfuse:
  public_key: os.environ/LANGFUSE_PUBLIC_KEY
  secret_key: os.environ/LANGFUSE_SECRET_KEY
  host: "https://cloud.langfuse.com" # or self-hosted
```

**Tracked Data**:

- Request/response pairs
- Token usage
- Cost per request
- Latency percentiles
- Model comparison
- User feedback integration

### Datadog Integration

**Configuration**:

```yaml
litellm_settings:
  success_callback: ["datadog"]

datadog:
  api_key: os.environ/DATADOG_API_KEY
  site: "datadoghq.com"
```

---

## Dashboards

### Grafana Dashboard

**Panels**:

1. **Request Rate**:

```promql
rate(litellm_requests_total[5m])
```

2. **Latency (P50, P95, P99)**:

```promql
histogram_quantile(0.50, sum(rate(litellm_request_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.95, sum(rate(litellm_request_duration_seconds_bucket[5m])) by (le))
histogram_quantile(0.99, sum(rate(litellm_request_duration_seconds_bucket[5m])) by (le))
```

3. **Error Rate**:

```promql
rate(litellm_errors_total[5m]) / rate(litellm_requests_total[5m])
```

4. **Cost per Hour**:

```promql
rate(litellm_cost_total[1h]) * 3600
```

5. **Token Usage**:

```promql
rate(litellm_tokens_total{type="input"}[5m])
rate(litellm_tokens_total{type="output"}[5m])
```

6. **Cache Hit Rate**:

```promql
litellm_cache_hits_total / (litellm_cache_hits_total + litellm_cache_misses_total)
```

### Import Dashboard

Download pre-built dashboard: [Grafana Dashboard JSON](https://github.com/BerriAI/litellm/blob/main/observability/grafana-dashboard.json)

---

## Alerts

### Critical Alerts

**High Error Rate**:

```yaml
- alert: HighErrorRate
  expr: rate(litellm_errors_total[5m]) / rate(litellm_requests_total[5m]) > 0.05 # >5%
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value | humanizePercentage }} for model {{ $labels.model }}"
```

**Gateway Down**:

```yaml
- alert: GatewayDown
  expr: up{job="litellm"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "LiteLLM gateway is down"
```

**High Latency**:

```yaml
- alert: HighLatency
  expr: histogram_quantile(0.95, litellm_request_duration_seconds_bucket) > 5 # >5s
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "High P95 latency: {{ $value }}s"
```

### Cost Alerts

**Daily Budget Exceeded**:

```yaml
- alert: DailyBudgetExceeded
  expr: sum(increase(litellm_cost_total[24h])) > 100 # >$100/day
  labels:
    severity: warning
  annotations:
    summary: "Daily budget exceeded: ${{ $value }}"
```

**Unexpected Cost Spike**:

```yaml
- alert: CostSpike
  expr: rate(litellm_cost_total[1h]) > 10 # >$10/hour
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "Cost spike detected: ${{ $value }}/hour"
```

### Capacity Alerts

**Rate Limit Approaching**:

```yaml
- alert: RateLimitApproaching
  expr: litellm_requests_per_minute > 900 # 90% of 1000 RPM limit
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Approaching rate limit: {{ $value }} RPM"
```

---

## Health Checks

### Endpoint Health

```bash
# Liveness probe (is process running?)
curl http://localhost:4000/health

# Readiness probe (can it serve traffic?)
curl http://localhost:4000/health/readiness

# Detailed health
curl http://localhost:4000/health/detailed
```

**Response**:

```json
{
  "status": "healthy",
  "uptime_seconds": 86400,
  "models": {
    "claude-3.5-sonnet": {
      "status": "healthy",
      "last_check": "2025-12-01T10:30:00Z",
      "latency_ms": 2300,
      "error_rate": 0.001
    }
  },
  "cache": {
    "status": "healthy",
    "hit_rate": 0.65
  }
}
```

### Kubernetes Health Checks

```yaml
# deployment.yaml
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/readiness
    port: 4000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

---

## Log Aggregation

### Elasticsearch + Kibana

**Filebeat Configuration**:

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - ~/.litellm/logs/*.log
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["localhost:9200"]
  index: "litellm-%{+yyyy.MM.dd}"
```

**Kibana Visualizations**:

1. Request volume over time
2. Error types distribution
3. Cost breakdown by model
4. Latency heatmap

### CloudWatch Logs (AWS)

```yaml
litellm_settings:
  success_callback: ["cloudwatch"]

cloudwatch:
  log_group_name: "/aws/litellm/gateway"
  log_stream_name: "requests"
  region: "us-west-2"
```

---

## Performance Profiling

### Enable Profiling

```yaml
litellm_settings:
  enable_profiling: true
  profiling_sample_rate: 0.1 # Profile 10% of requests
```

### Profile Analysis

```bash
# View slow requests
curl http://localhost:4000/admin/slow_requests?limit=10

# View most expensive requests
curl http://localhost:4000/admin/expensive_requests?limit=10
```

---

## Security Monitoring

### Track Authentication Failures

```promql
rate(litellm_auth_failures_total[5m])
```

**Alert**:

```yaml
- alert: HighAuthFailureRate
  expr: rate(litellm_auth_failures_total[5m]) > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High authentication failure rate"
```

### Monitor API Key Usage

```yaml
litellm_settings:
  track_api_key_usage: true
```

**Metrics**:

```promql
litellm_requests_total{api_key_id="key_abc"}
litellm_cost_total{api_key_id="key_abc"}
```

---

## Best Practices

1. **Start with critical metrics**: Latency, error rate, availability
2. **Set up alerts early**: Don't wait for issues
3. **Use structured logging**: JSON format for easier parsing
4. **Monitor costs**: Set budgets and alerts
5. **Regular dashboard reviews**: Weekly performance reviews
6. **Test alerting**: Simulate failures monthly

---

## Troubleshooting

### High Memory Usage

**Check**:

```bash
# Memory metrics
curl http://localhost:4000/metrics | grep process_resident_memory_bytes
```

**Solution**:

```yaml
# Reduce cache size
litellm_settings:
  cache_size_mb: 100 # Down from 500
```

### Missing Metrics

**Check**:

```yaml
# Verify callbacks enabled
litellm_settings:
  success_callback: ["prometheus"] # Must be set
```

---

## Related Documentation

- [Cost Tracking and Optimization](cost-tracking.md)
- [Load Balancing Strategies](load-balancing.md)
- [Troubleshooting Guide](troubleshooting-guide.md)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
