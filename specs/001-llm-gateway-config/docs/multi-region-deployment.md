# Multi-Region Deployment

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: Platform Engineers, DevOps, Architects  
**Last Updated**: 2025-12-01

---

## Overview

Multi-region deployment distributes LLM infrastructure across geographic locations to improve latency, comply with data residency requirements, and provide disaster recovery capabilities.

**Benefits**:

- 🌍 **Low Latency**: Route users to nearest region
- 🛡️ **High Availability**: Survive regional outages
- 📍 **Data Residency**: Comply with GDPR, data sovereignty laws
- 📈 **Scalability**: Distribute load globally

---

## Architecture Patterns

### Pattern 1: Active-Passive (Disaster Recovery)

Primary region handles all traffic, secondary regions on standby.

**Architecture**:

```
[Users] → [Primary: US-West-2]
            ↓ (on failure)
          [Secondary: US-East-1]
            ↓ (on failure)
          [Tertiary: EU-West-1]
```

**Configuration**:

```yaml
model_list:
  # Primary: US West
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2
    priority: 1 # Highest priority

  # Secondary: US East (failover)
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    priority: 2

  # Tertiary: EU West (disaster recovery)
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1
    priority: 3

router_settings:
  routing_strategy: "priority-routing" # Use priority field
  num_retries: 2
  allowed_fails: 5 # Switch to secondary after 5 failures
  cooldown_time: 300 # 5 minutes before retrying primary
```

**Use Case**: Cost-sensitive deployments, simple disaster recovery

**RTO/RPO**:

- Recovery Time Objective: < 5 minutes
- Recovery Point Objective: 0 (no data loss, stateless)

---

### Pattern 2: Active-Active (Global Load Balancing)

All regions handle traffic simultaneously, routed by latency or user location.

**Architecture**:

```
[US Users] → [US-West-2]
[EU Users] → [EU-West-1]
[APAC Users] → [AP-Southeast-1]
```

**Configuration**:

```yaml
model_list:
  # North America
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2
      metadata:
        region: "us-west"
        latency_target: 50 # ms

  # Europe
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1
      metadata:
        region: "eu-west"
        latency_target: 50

  # Asia-Pacific
  - model_name: claude-global
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: ap-southeast-1
      metadata:
        region: "ap-southeast"
        latency_target: 50

router_settings:
  routing_strategy: "latency-based-routing" # Route to fastest
  num_retries: 2
  health_check_interval: 30
```

**Use Case**: Global applications, latency-sensitive workloads

**Benefits**:

- 50-200ms latency reduction per user
- Even load distribution
- No single point of failure

---

### Pattern 3: Data Residency Compliance

Route based on user location to comply with data laws.

**Architecture**:

```
[EU Users] → [EU-West-1 ONLY]  # GDPR requirement
[US Users] → [US-West-2 or US-East-1]
[APAC Users] → [AP-Southeast-1 or AP-Northeast-1]
```

**Configuration**:

```yaml
# Separate gateways per region with strict routing

# EU Gateway (eu-gateway.company.com)
model_list:
  - model_name: claude-eu
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: company-eu-project
      vertex_location: europe-west1  # EU only

router_settings:
  allowed_regions: ["europe-west1", "europe-west3"]  # Enforce EU

# US Gateway (us-gateway.company.com)
model_list:
  - model_name: claude-us
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2

# Application routes by user location
```

**Compliance Requirements**:

- ✅ GDPR (EU): Data stays in EU
- ✅ CCPA (California): Honored via US regions
- ✅ Data Sovereignty: Region-specific deployments

---

## Deployment Models

### Model 1: Single Gateway, Multi-Region Backends

One LiteLLM gateway routes to multiple regional providers.

**Setup**:

```bash
# Single gateway deployment
litellm --config litellm-multi-region.yaml --port 4000
```

**Configuration** (`litellm-multi-region.yaml`):

```yaml
model_list:
  - model_name: claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2
  - model_name: claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: eu-west-1
  - model_name: claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: ap-southeast-1

router_settings:
  routing_strategy: "latency-based-routing"
```

**Pros**:

- ✅ Simple deployment
- ✅ Centralized monitoring
- ✅ Easy configuration updates

**Cons**:

- ❌ Gateway is single point of failure
- ❌ May not meet data residency requirements

---

### Model 2: Regional Gateways with Global Load Balancer

LiteLLM gateway deployed in each region, global load balancer routes users.

**Setup**:

```bash
# Deploy in each region
# US-West-2
litellm --config litellm-us-west.yaml --port 4000

# EU-West-1
litellm --config litellm-eu-west.yaml --port 4000

# AP-Southeast-1
litellm --config litellm-ap-southeast.yaml --port 4000
```

**Global Load Balancer** (AWS Route 53, Cloudflare, etc.):

```
gateway.company.com:
  - us-west-gateway.company.com (34.x.x.x) [US users]
  - eu-west-gateway.company.com (18.x.x.x) [EU users]
  - ap-southeast-gateway.company.com (13.x.x.x) [APAC users]
```

**Regional Config Example** (`litellm-us-west.yaml`):

```yaml
model_list:
  # Primary: Local region
  - model_name: claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2

  # Fallback: Nearby region
  - model_name: claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

router_settings:
  routing_strategy: "priority-routing"
  num_retries: 2
```

**Pros**:

- ✅ No single point of failure
- ✅ Lowest latency (local routing)
- ✅ Meets data residency requirements
- ✅ Independent scaling per region

**Cons**:

- ❌ More complex deployment
- ❌ Distributed monitoring required
- ❌ Configuration drift risk

---

### Model 3: Hybrid (Regional + Centralized)

Regional gateways for latency-sensitive apps, centralized for management.

**Architecture**:

```
[Interactive Apps] → [Regional Gateways]
[Batch/Admin] → [Central Gateway]
```

**Use Case**: Mixed workload types, cost optimization

---

## Implementation Guide

### Step 1: Choose Provider Regions

**AWS Bedrock Availability**:

- US: `us-east-1`, `us-west-2`
- EU: `eu-west-1`, `eu-central-1`
- APAC: `ap-southeast-1`, `ap-northeast-1`

**Google Vertex AI Availability**:

- US: `us-central1`, `us-east4`
- EU: `europe-west1`, `europe-west4`
- APAC: `asia-southeast1`, `asia-northeast1`

**Anthropic Direct**:

- Global (routes internally)

### Step 2: Configure Multi-Region Setup

See configurations above for each pattern.

### Step 3: Set Up Health Checks

```yaml
router_settings:
  health_check_interval: 30 # Check every 30 seconds
  health_check_timeout: 5 # Timeout after 5 seconds
  allowed_fails: 3 # Mark unhealthy after 3 fails
  cooldown_time: 60 # Wait 60s before retrying
```

### Step 4: Configure DNS/Load Balancer

**Option A: AWS Route 53 (Latency-Based Routing)**:

```json
{
  "Type": "A",
  "Name": "gateway.company.com",
  "ResourceRecords": [
    { "Value": "34.x.x.x", "Region": "us-west-2" },
    { "Value": "18.x.x.x", "Region": "eu-west-1" },
    { "Value": "13.x.x.x", "Region": "ap-southeast-1" }
  ],
  "RoutingPolicy": "Latency"
}
```

**Option B: Cloudflare Load Balancer**:

```yaml
load_balancer:
  default_pools:
    - us-west-pool
    - eu-west-pool
    - ap-southeast-pool

  geo_steering:
    policy: "dynamic_latency"
```

### Step 5: Deploy and Validate

```bash
# Test from different regions
# US
curl -X POST https://gateway.company.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude", "messages": [...]}'

# Check which region handled request
curl https://gateway.company.com/health | jq '.region'
```

---

## Monitoring Multi-Region Deployments

### Key Metrics Per Region

```promql
# Request distribution by region
sum by (region) (litellm_requests_total)

# Latency by region (P95)
histogram_quantile(0.95, sum by (region, le) (litellm_request_duration_seconds_bucket))

# Error rate by region
rate(litellm_errors_total[5m]) by (region)

# Availability by region
avg_over_time(up{job="litellm"}[5m]) by (region)
```

### Alerts

```yaml
# prometheus-alerts.yml
groups:
  - name: multi-region
    rules:
      - alert: RegionDown
        expr: up{job="litellm"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "LiteLLM gateway down in {{ $labels.region }}"

      - alert: HighLatencyInRegion
        expr: histogram_quantile(0.95, litellm_request_duration_seconds_bucket) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency in {{ $labels.region }}"
```

---

## Cost Optimization

### Data Transfer Costs

**Same Region**: Free (within AWS/GCP region)  
**Cross-Region**: $0.02/GB (AWS), $0.01/GB (GCP)  
**Cross-Cloud**: $0.09/GB+

**Optimization**:

```yaml
# Keep gateway and backend in same region
# US-West-2 gateway → US-West-2 Bedrock (free)
# EU-West-1 gateway → EU-West-1 Bedrock (free)
```

### Model Pricing by Region

Some regions are cheaper:

**Example** (AWS Bedrock Claude 3.5 Sonnet):

- US East 1: $3.00 / 1M input tokens
- US West 2: $3.00 / 1M input tokens
- EU West 1: $3.30 / 1M input tokens (+10%)
- AP Southeast 1: $3.60 / 1M input tokens (+20%)

**Optimization**: Route non-latency-sensitive workloads to cheaper regions

---

## Best Practices

1. **Start with 2 regions**: Primary + failover
2. **Add regions based on user distribution**: If >20% users in region, deploy there
3. **Use regional caching**: Cache in each region to reduce cross-region calls
4. **Monitor regional costs**: Track spend per region
5. **Test failover regularly**: Simulate regional outages monthly

---

## Troubleshooting

### Issue: High Cross-Region Traffic

**Symptoms**: High data transfer costs

**Solutions**:

- Deploy gateway in same region as backend
- Use regional caching
- Review routing strategy

### Issue: Uneven Load Distribution

**Symptoms**: One region overloaded

**Solutions**:

```yaml
# Use weighted routing
model_list:
  - model_name: claude
    litellm_params:
      model: bedrock/.../us-west-2
    weight: 40 # 40% traffic
  - model_name: claude
    litellm_params:
      model: bedrock/.../eu-west-1
    weight: 60 # 60% traffic
```

---

## Related Documentation

- [Load Balancing Strategies](load-balancing.md)
- [Fallback and Retry Policies](fallback-retry.md)
- [Observability and Monitoring](observability.md)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
