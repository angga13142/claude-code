# Firewall and Network Security Considerations

**Purpose**: Guide for network/security teams configuring corporate firewalls for Claude Code + LLM Gateway integration.

## Overview

This document addresses firewall rules, network policies, and security controls required for corporate proxy and LLM gateway deployments.

**Target Audience**: Network engineers, security architects, IT administrators

## Network Architecture

```
Internal Network (10.0.0.0/8)      DMZ                External Internet
┌─────────────────────┐      ┌────────────┐      ┌──────────────────┐
│  Developer          │      │ Corporate  │      │ Provider APIs    │
│  Workstations       │─────→│ Proxy      │─────→│ - Anthropic      │
│  (Claude Code +     │      │ (Firewall) │      │ - AWS Bedrock    │
│   LiteLLM Gateway)  │      └────────────┘      │ - Google Vertex  │
└─────────────────────┘                          └──────────────────┘
```

## Required Outbound Rules

### Anthropic Claude API

**Destination**: api.anthropic.com  
**Protocol**: HTTPS (TCP/443)  
**Purpose**: Claude model API access  
**Frequency**: Per user request (sporadic)  
**Bandwidth**: Low (~1-10 KB per request + response)

**Firewall Rule**:

```
Source: Internal network (10.0.0.0/8)
Destination: api.anthropic.com (2600:1901:0:f34f::, 104.18.0.0/15)
Port: 443/TCP
Protocol: HTTPS
Action: ALLOW
Logging: Enabled (for audit)
```

**DNS Requirements**:

- Must resolve: api.anthropic.com
- CDN: Cloudflare (104.18.0.0/15)
- IPv6 support recommended

### AWS Bedrock API

**Destination**: bedrock._.amazonaws.com, bedrock-runtime._.amazonaws.com  
**Protocol**: HTTPS (TCP/443)  
**Purpose**: Bedrock model API access  
**Frequency**: Per user request  
**Bandwidth**: Low (~1-10 KB per request)

**Firewall Rules**:

```
# Bedrock Control Plane
Source: Internal network
Destination: bedrock.us-east-1.amazonaws.com
Port: 443/TCP
Action: ALLOW

# Bedrock Runtime (Model Inference)
Source: Internal network
Destination: bedrock-runtime.*.amazonaws.com
Port: 443/TCP
Action: ALLOW
```

**AWS IP Ranges**: Download from https://ip-ranges.amazonaws.com/ip-ranges.json  
Filter for: `"service": "AMAZON"` and `"region": "us-east-1"` (or your region)

**DNS Requirements**:

- Dynamic AWS endpoints
- Region-specific: us-east-1, us-west-2, eu-west-1, etc.

### Google Vertex AI API

**Destination**: \*.googleapis.com, aiplatform.googleapis.com  
**Protocol**: HTTPS (TCP/443)  
**Purpose**: Vertex AI model access  
**Frequency**: Per user request  
**Bandwidth**: Low-Medium (~1-50 KB per request)

**Firewall Rules**:

```
# Vertex AI Platform
Source: Internal network
Destination: aiplatform.googleapis.com
Port: 443/TCP
Action: ALLOW

# Google Cloud APIs (general)
Source: Internal network
Destination: *.googleapis.com
Port: 443/TCP
Action: ALLOW
```

**Google IP Ranges**: Available at https://www.gstatic.com/ipranges/cloud.json

### Summary Table

| Provider        | Endpoints               | Ports | Protocol | Bandwidth | Criticality |
| --------------- | ----------------------- | ----- | -------- | --------- | ----------- |
| Anthropic       | api.anthropic.com       | 443   | HTTPS    | Low       | High        |
| AWS Bedrock     | bedrock\*.amazonaws.com | 443   | HTTPS    | Low       | Medium      |
| Google Vertex   | \*.googleapis.com       | 443   | HTTPS    | Low-Med   | Medium      |
| Corporate Proxy | proxy.corp:8080         | 8080  | HTTP     | N/A       | Critical    |

## Required Inbound Rules

### LiteLLM Gateway (Internal)

**Source**: Internal developer workstations  
**Destination**: LiteLLM gateway server (e.g., 10.0.1.100)  
**Port**: 4000/TCP (default, configurable)  
**Protocol**: HTTP  
**Purpose**: Gateway API access

**Firewall Rule**:

```
Source: Internal network (10.0.0.0/8)
Destination: 10.0.1.100 (gateway server)
Port: 4000/TCP
Protocol: HTTP
Action: ALLOW
```

**Security Notes**:

- Internal only (no external access)
- Consider TLS termination at reverse proxy
- Implement rate limiting

### Redis Cache (Optional)

**Source**: LiteLLM gateway  
**Destination**: Redis server (e.g., 10.0.1.101)  
**Port**: 6379/TCP  
**Protocol**: Redis  
**Purpose**: Response caching

**Firewall Rule**:

```
Source: 10.0.1.100 (gateway)
Destination: 10.0.1.101 (redis)
Port: 6379/TCP
Action: ALLOW
```

## Corporate Proxy Configuration

### Proxy Requirements

**Proxy Type**: HTTP/HTTPS forward proxy  
**Authentication**: Basic, NTLM, or Kerberos  
**SSL Inspection**: Optional (see considerations below)  
**Ports**: 8080/TCP (HTTP), 3128/TCP (common alternative)

### Proxy Firewall Rules

```
# Inbound (from internal network)
Source: Internal network (10.0.0.0/8)
Destination: proxy.corp (10.0.0.50)
Port: 8080/TCP
Action: ALLOW

# Outbound (to internet)
Source: proxy.corp (10.0.0.50)
Destination: Any (0.0.0.0/0)
Ports: 80/TCP, 443/TCP
Action: ALLOW (with content filtering)
```

### SSL Inspection Considerations

**⚠️ Impact on API Calls**:

**Without SSL Inspection** (Recommended):

- Provider API traffic encrypted end-to-end
- No certificate manipulation required
- Faster processing (no decrypt/re-encrypt)
- Lower CPU usage on proxy
- **Recommended for AI/ML APIs**

**With SSL Inspection**:

- Proxy can inspect/log API request/response content
- Requires corporate CA certificate on all clients
- Potential API compatibility issues
- Higher latency (~20-50ms overhead)
- May violate provider ToS

**Decision Matrix**:

| Requirement                | Recommendation         |
| -------------------------- | ---------------------- |
| Compliance audit logging   | Enable SSL inspection  |
| DLP (Data Loss Prevention) | Enable SSL inspection  |
| Threat detection           | Enable SSL inspection  |
| Performance-critical       | Disable SSL inspection |
| Low admin overhead         | Disable SSL inspection |
| Provider ToS compliance    | Disable SSL inspection |

**If SSL Inspection Enabled**:

1. Install corporate CA certificate on all developer machines
2. Set `SSL_CERT_FILE` environment variable
3. Test certificate chain: `openssl s_client -connect api.anthropic.com:443`
4. Monitor for certificate expiry

## Bandwidth and Performance

### Expected Traffic Patterns

**Per-User Daily Usage**:

- Requests: 100-500 API calls
- Data sent: 50-500 KB
- Data received: 100 KB - 5 MB
- Peak concurrent requests: 1-5

**100-User Organization**:

- Total requests: 10,000-50,000/day
- Bandwidth: 5-50 MB/day sent, 10-500 MB/day received
- Peak bandwidth: ~1-10 Mbps
- Average bandwidth: <1 Mbps

**Gateway Cache Benefits**:

- Cache hit rate: 20-40%
- Bandwidth savings: 20-40% reduction
- Latency reduction: 90%+ (600ms → 50ms)

### QoS Recommendations

**Priority Level**: Medium-High (business-critical tool)

**Bandwidth Allocation**:

- Minimum: 1 Mbps per 100 users
- Recommended: 5 Mbps per 100 users
- Peak capacity: 10 Mbps per 100 users

**Latency Requirements**:

- Target: <100ms to proxy
- Acceptable: <500ms to provider
- Timeout: 30-60 seconds

## Security Controls

### Network Segmentation

**Recommended Zones**:

```
┌─────────────────────────────────────┐
│ Zone 1: User Network (10.0.0.0/16) │
│ - Developer workstations            │
│ - Claude Code clients               │
│ Security: Standard endpoint         │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│ Zone 2: Gateway (10.0.1.0/24)      │
│ - LiteLLM proxy server              │
│ - Redis cache                       │
│ Security: Hardened, restricted      │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│ Zone 3: Proxy/DMZ (10.0.2.0/24)    │
│ - Corporate proxy                   │
│ - Firewall/IDS                      │
│ Security: Maximum, inspected        │
└────────────┬────────────────────────┘
             │
             ↓
       Internet (0.0.0.0/0)
```

### Access Control Lists (ACLs)

**Zone 1 → Zone 2** (User → Gateway):

```
Source: 10.0.0.0/16 (users)
Destination: 10.0.1.100:4000 (gateway)
Protocols: HTTP
Action: ALLOW
Logging: Session start/end
```

**Zone 2 → Zone 3** (Gateway → Proxy):

```
Source: 10.0.1.100 (gateway)
Destination: 10.0.2.50:8080 (proxy)
Protocols: HTTP/HTTPS
Action: ALLOW
Logging: All connections
```

**Zone 3 → Internet** (Proxy → Providers):

```
Source: 10.0.2.50 (proxy)
Destination: Provider IPs
Protocols: HTTPS/443
Action: ALLOW (with DPI/filtering)
Logging: Full audit
```

### Intrusion Detection/Prevention (IDS/IPS)

**Monitoring Points**:

1. User → Gateway traffic (detect anomalies)
2. Gateway → Proxy traffic (validate requests)
3. Proxy → Internet traffic (threat detection)

**IDS Rules**:

```
# Alert on excessive API calls (potential abuse)
alert tcp $INTERNAL_NET any -> $GATEWAY_IP 4000 \\
  (msg:"High request rate to LLM gateway"; \\
   threshold:type both, track by_src, count 100, seconds 60;)

# Alert on failed authentication attempts
alert tcp $GATEWAY_IP any -> $PROXY_IP 8080 \\
  (msg:"Repeated 407 Proxy Auth failures"; \\
   content:"407"; threshold:type both, track by_src, count 5, seconds 60;)

# Alert on data exfiltration patterns
alert tcp $PROXY_IP any -> any 443 \\
  (msg:"Large outbound transfer"; dsize:>1000000;)
```

### Data Loss Prevention (DLP)

**Inspection Points**:

1. **At Gateway**: Inspect prompts for sensitive data
2. **At Proxy**: Inspect requests/responses (if SSL inspection enabled)
3. **At Endpoint**: Pre-flight validation (client-side)

**DLP Rules** (if SSL inspection enabled):

- Block API keys/tokens in prompts
- Detect PII (SSN, credit cards, etc.)
- Flag sensitive keywords (confidential, secret, etc.)
- Monitor for large data transfers

**Example DLP Rule**:

```
# Block Social Security Numbers in API requests
if content matches /\b\d{3}-\d{2}-\d{4}\b/:
    action: BLOCK
    log: "SSN detected in API request from {src_ip}"
    alert: security-team@company.com
```

## Compliance Requirements

### Audit Logging

**Log All**:

- User → Gateway connections (timestamp, user, source IP)
- Gateway → Proxy connections (timestamp, destination)
- Proxy → Provider API calls (timestamp, endpoint, response code)
- Authentication attempts (success/failure)
- Configuration changes

**Log Retention**: 90 days minimum (or per compliance requirements)

**Log Format** (example):

```json
{
  "timestamp": "2024-12-01T10:30:45Z",
  "event_type": "api_request",
  "user": "john.doe@company.com",
  "source_ip": "10.0.0.123",
  "gateway": "10.0.1.100:4000",
  "proxy": "10.0.2.50:8080",
  "destination": "api.anthropic.com",
  "model": "claude-3-5-sonnet",
  "status": 200,
  "latency_ms": 450,
  "bytes_sent": 1024,
  "bytes_received": 2048
}
```

### SOC 2 / ISO 27001 Requirements

**Network Controls**:

- ✅ Segmented network zones
- ✅ Least-privilege firewall rules
- ✅ Encrypted transport (TLS 1.2+)
- ✅ Audit logging enabled
- ✅ Monitoring and alerting
- ✅ Incident response procedures

**Change Control**:

- Document all firewall rule changes
- Require approval for rule additions
- Review rules quarterly
- Test rule changes in non-production

### GDPR / Data Residency

**Considerations**:

- Provider API endpoints may be in different regions
- Data may transit multiple countries
- Consider EU-specific endpoints (if available)

**Mitigation**:

- Use regional provider endpoints (e.g., `bedrock.eu-west-1.amazonaws.com`)
- Implement data masking at gateway
- Review provider Data Processing Agreements (DPAs)

## Monitoring and Alerting

### Key Metrics

**Network Metrics**:

- Bandwidth utilization (Mbps)
- Connection count (active connections)
- Latency (ms)
- Packet loss (%)
- Error rate (% failed requests)

**Security Metrics**:

- Authentication failures
- Blocked requests (by firewall/DLP)
- Anomalous traffic patterns
- Certificate validation errors

### Alert Thresholds

```
# Critical Alerts
- Gateway unavailable (no response for 5 min)
- Proxy authentication failure rate >10%
- Bandwidth spike >5x baseline
- DLP policy violations

# Warning Alerts
- Latency >1000ms for 15 min
- Error rate >5% for 10 min
- Certificate expiring <30 days
- Unusual traffic patterns
```

### Monitoring Tools

**Network Monitoring**:

- Prometheus + Grafana (metrics/dashboards)
- Zabbix (infrastructure monitoring)
- Nagios/Icinga (availability checks)

**Log Analysis**:

- ELK Stack (Elasticsearch, Logstash, Kibana)
- Splunk (enterprise SIEM)
- Graylog (open-source alternative)

**Traffic Analysis**:

- Wireshark (packet capture)
- tcpdump (CLI packet capture)
- ntop (network traffic analysis)

## Disaster Recovery

### Proxy Failure Scenarios

**Scenario 1: Primary Proxy Down**

**Detection**: Health checks fail, connections timeout  
**Response**:

1. Failover to secondary proxy (if configured)
2. Alert network team
3. Update HTTPS_PROXY to backup: `export HTTPS_PROXY="http://proxy-backup.corp:8080"`

**Scenario 2: Internet Connectivity Lost**

**Detection**: All external requests fail  
**Response**:

1. Use cached responses (if enabled)
2. Notify users of degraded service
3. Investigate ISP/WAN issues

**Scenario 3: Provider API Outage**

**Detection**: 503/504 errors from provider  
**Response**:

1. Automatic fallback to alternate provider (if configured)
2. Queue requests for retry
3. Check provider status pages

### Business Continuity

**RTO (Recovery Time Objective)**: <15 minutes  
**RPO (Recovery Point Objective)**: Real-time (no data loss)

**Recovery Procedures**:

1. Maintain secondary proxy server (hot standby)
2. Document failover procedures
3. Test failover quarterly
4. Keep emergency contact list updated

## Deployment Checklist

**Network Team**:

- [ ] Firewall rules added for provider APIs
- [ ] Proxy configuration tested
- [ ] SSL inspection decision made and documented
- [ ] Monitoring dashboards created
- [ ] Alert thresholds configured
- [ ] Audit logging enabled
- [ ] DLP rules configured (if applicable)
- [ ] Network segmentation verified
- [ ] Documentation updated

**Security Team**:

- [ ] Security controls reviewed
- [ ] Risk assessment completed
- [ ] Compliance requirements verified
- [ ] Incident response plan updated
- [ ] Penetration test scheduled
- [ ] CA certificates distributed (if SSL inspection)

**Operations Team**:

- [ ] Gateway server deployed
- [ ] Backup/HA configured
- [ ] Monitoring integrated
- [ ] Runbooks created
- [ ] Support escalation defined

## References

- **Setup Guide**: `examples/us4-corporate-proxy-setup.md`
- **Troubleshooting**: `examples/us4-proxy-troubleshooting.md`
- **Architecture**: `examples/us4-proxy-gateway-architecture.md`
- **Proxy Config**: `examples/us4-https-proxy-config.md`

## Change Log

- 2025-12-01: Initial version
- Update as network requirements evolve
