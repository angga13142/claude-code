# Proxy + Gateway Architecture

**Purpose**: Visual and conceptual reference for corporate proxy integration with LLM gateway.

## Architecture Overview

```
┌─────────────────┐
│   Claude Code   │  User's local machine
│   (CLI Tool)    │
└────────┬────────┘
         │ HTTPS requests
         │ (uses HTTPS_PROXY)
         ↓
┌─────────────────┐
│ Corporate Proxy │  Company firewall/gateway
│  (HTTP/HTTPS)   │  - Authentication
│                 │  - SSL inspection
└────────┬────────┘  - Traffic logging
         │
         │ Proxied HTTPS
         ↓
┌─────────────────┐
│  LiteLLM Proxy  │  Internal or local server
│   (Gateway)     │  - Model routing
│                 │  - Load balancing
└────────┬────────┘  - Caching
         │
         │ Provider API calls
         │ (via corporate proxy)
         ↓
┌─────────────────────────────────────┐
│         Provider APIs               │
│  ┌──────────┐ ┌────────┐ ┌────────┐│
│  │Anthropic │ │Bedrock │ │Vertex  ││
│  │  Claude  │ │ Claude │ │ Gemini ││
│  └──────────┘ └────────┘ └────────┘│
└─────────────────────────────────────┘
```

## Request Flow

### 1. Local Request (No Proxy)

```
Claude Code → LiteLLM Gateway (localhost:4000)
```

**Characteristics**:

- Direct connection to gateway
- No proxy involved
- Fast, low latency
- Gateway runs on same machine

**Configuration**:

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export NO_PROXY="localhost,127.0.0.1"
```

### 2. Gateway to Provider (Through Proxy)

```
LiteLLM Gateway → Corporate Proxy → Anthropic API
```

**Characteristics**:

- Gateway makes external API calls
- Corporate proxy routes traffic
- SSL inspection may occur
- Authentication required

**Configuration**:

```bash
# Gateway uses these automatically
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export SSL_CERT_FILE="/path/to/ca-bundle.crt"
```

### 3. Complete End-to-End Flow

```
Claude Code
  → localhost:4000 (no proxy)
    → LiteLLM Gateway
      → Corporate Proxy (HTTPS_PROXY)
        → api.anthropic.com
          → Claude API Response
        ← Response
      ← Proxied Response
    ← Gateway Response
  ← Final Response
```

## Deployment Patterns

### Pattern 1: Local Gateway + Proxy

```
┌──────────────────────────────────┐
│      Developer Machine           │
│                                  │
│  ┌─────────────┐                │
│  │ Claude Code │                │
│  └──────┬──────┘                │
│         │ NO_PROXY               │
│         ↓                        │
│  ┌─────────────┐                │
│  │  LiteLLM    │                │
│  │  Gateway    │                │
│  └──────┬──────┘                │
│         │ HTTPS_PROXY            │
└─────────┼──────────────────────────┘
          │
          ↓
    Corporate Proxy
```

**Use Case**: Individual developer setup  
**Pros**: Simple, full control, easy debugging  
**Cons**: Gateway per developer, resource intensive

### Pattern 2: Shared Internal Gateway + Proxy

```
┌────────────┐  ┌────────────┐  ┌────────────┐
│Developer 1 │  │Developer 2 │  │Developer 3 │
└─────┬──────┘  └─────┬──────┘  └─────┬──────┘
      │               │               │
      └───────────────┼───────────────┘
                      │
                      ↓
            ┌─────────────────┐
            │ Internal Server │
            │  LiteLLM Gateway│
            └────────┬────────┘
                     │ HTTPS_PROXY
                     ↓
              Corporate Proxy
```

**Use Case**: Team/department shared gateway  
**Pros**: Centralized, efficient, easier management  
**Cons**: Network dependency, single point of failure

### Pattern 3: DMZ Gateway + Dual Proxy

```
Internal Network          DMZ               External
┌─────────────┐    ┌────────────┐    ┌──────────┐
│Claude Code  │ →  │  Internal  │ →  │ External │
│             │    │   Proxy    │    │  Proxy   │
└─────────────┘    └─────┬──────┘    └────┬─────┘
                         ↓                 ↓
                   ┌────────────┐    ┌──────────┐
                   │  LiteLLM   │ →  │Provider  │
                   │  Gateway   │    │   APIs   │
                   └────────────┘    └──────────┘
```

**Use Case**: High-security enterprise environment  
**Pros**: Maximum security, compliance-ready  
**Cons**: Complex setup, higher latency

### Pattern 4: Proxy-Only (No Gateway)

```
┌─────────────┐
│ Claude Code │
└──────┬──────┘
       │ HTTPS_PROXY
       ↓
┌──────────────┐
│ Corporate    │
│ Proxy        │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│ Anthropic API│
│ (Direct)     │
└──────────────┘
```

**Use Case**: Simple proxy-only scenario  
**Pros**: Minimal setup, no gateway maintenance  
**Cons**: No caching, load balancing, or model routing

## Network Configuration

### Firewall Rules

**Outbound Rules** (from LiteLLM Gateway):

| Destination              | Port | Protocol | Purpose              |
| ------------------------ | ---- | -------- | -------------------- |
| api.anthropic.com        | 443  | HTTPS    | Anthropic Claude API |
| bedrock.\*.amazonaws.com | 443  | HTTPS    | AWS Bedrock API      |
| \*.googleapis.com        | 443  | HTTPS    | Google Vertex AI     |
| Corporate Proxy          | 8080 | HTTP     | Proxy connection     |

**Inbound Rules** (to LiteLLM Gateway):

| Source           | Port | Protocol | Purpose           |
| ---------------- | ---- | -------- | ----------------- |
| Internal network | 4000 | HTTP     | Gateway API       |
| localhost        | 4000 | HTTP     | Local connections |

### DNS Configuration

```bash
# Internal DNS entries (optional)
gateway.internal.corp    → 10.0.1.100  # Internal gateway
proxy.internal.corp      → 10.0.0.50   # Corporate proxy

# External DNS (must resolve)
api.anthropic.com        → 2600:1901:0:f34f::  # Anthropic
bedrock.us-east-1.amazonaws.com  # AWS
aiplatform.googleapis.com        # Google
```

### Port Assignments

| Service          | Port | Notes                 |
| ---------------- | ---- | --------------------- |
| LiteLLM Gateway  | 4000 | Default, configurable |
| Corporate Proxy  | 8080 | Common, may vary      |
| HTTPS (external) | 443  | Provider APIs         |
| Redis (cache)    | 6379 | Optional caching      |

## Security Layers

### Layer 1: Claude Code → Gateway

**Security**:

- Local connection (no proxy)
- Optional API key validation
- Rate limiting (if configured)

**Configuration**:

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"  # Dummy
```

### Layer 2: Gateway → Corporate Proxy

**Security**:

- Proxy authentication (Basic/NTLM/Kerberos)
- SSL inspection (MITM)
- Traffic logging
- Content filtering

**Configuration**:

```bash
export HTTPS_PROXY="http://user:pass@proxy.corp.example.com:8080"
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
```

### Layer 3: Corporate Proxy → Provider APIs

**Security**:

- TLS 1.2+ encryption
- Certificate validation
- API key authentication
- Rate limiting (provider-side)

**Configuration**:

```yaml
# In litellm-proxy.yaml
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      api_key: os.environ/ANTHROPIC_API_KEY # Real key
```

## Traffic Patterns

### Normal Request

```
Time (ms)  | Component         | Action
-----------|-------------------|---------------------------
0          | Claude Code       | User types command
10         | Claude Code       | HTTP request to gateway
12         | LiteLLM Gateway   | Receives request
15         | LiteLLM Gateway   | Routes to provider
20         | Corporate Proxy   | Authenticates gateway
25         | Corporate Proxy   | Forwards to provider
300        | Provider API      | Processes request
600        | Provider API      | Streams response
610        | Corporate Proxy   | Forwards response
615        | LiteLLM Gateway   | Processes response
620        | Claude Code       | Receives response
```

**Total Latency**: ~620ms (proxy adds ~20-30ms overhead)

### Cached Request

```
Time (ms)  | Component         | Action
-----------|-------------------|---------------------------
0          | Claude Code       | User types command
10         | Claude Code       | HTTP request to gateway
12         | LiteLLM Gateway   | Receives request
14         | LiteLLM Gateway   | Cache hit!
16         | LiteLLM Gateway   | Returns cached response
18         | Claude Code       | Receives response
```

**Total Latency**: ~18ms (96% faster!)

### Failed Request (Proxy Error)

```
Time (ms)  | Component         | Action
-----------|-------------------|---------------------------
0          | Claude Code       | User types command
10         | Claude Code       | HTTP request to gateway
12         | LiteLLM Gateway   | Receives request
15         | LiteLLM Gateway   | Routes to provider
20         | Corporate Proxy   | 407 Auth Required
25         | LiteLLM Gateway   | Retry with auth
30         | Corporate Proxy   | Authenticates
35         | Corporate Proxy   | Forwards to provider
```

## Monitoring Points

### Gateway Metrics

```python
# LiteLLM automatically tracks:
- Total requests
- Requests per model
- Average latency
- Error rate
- Cache hit rate
```

### Proxy Metrics

```bash
# Corporate proxy logs typically show:
- Connection attempts
- Authentication successes/failures
- Bytes transferred
- Response codes
```

### Provider Metrics

```bash
# Provider dashboards show:
- API usage
- Token consumption
- Rate limit status
- Error rates
```

## Troubleshooting by Layer

### Issue at Layer 1 (Claude → Gateway)

**Symptoms**: "Connection refused", "Gateway not responding"

**Debug**:

```bash
# Test gateway directly
curl http://localhost:4000/health

# Check if running
ps aux | grep litellm

# Check logs
journalctl -u litellm -f
```

### Issue at Layer 2 (Gateway → Proxy)

**Symptoms**: "407 Proxy Auth Required", "SSL certificate error"

**Debug**:

```bash
# Test proxy connectivity
curl -x $HTTPS_PROXY https://httpbin.org/ip

# Check proxy auth
curl -x http://user:pass@proxy:8080 https://httpbin.org/ip

# Verify CA certificate
openssl s_client -connect api.anthropic.com:443 -proxy proxy:8080
```

### Issue at Layer 3 (Proxy → Provider)

**Symptoms**: "Timeout", "503 Service Unavailable", "API key invalid"

**Debug**:

```bash
# Test provider API directly (from gateway machine)
curl -x $HTTPS_PROXY \\
     -H "x-api-key: $ANTHROPIC_API_KEY" \\
     https://api.anthropic.com/v1/messages

# Check API key
echo $ANTHROPIC_API_KEY

# Verify provider status
curl https://status.anthropic.com
```

## Best Practices

1. **Separate Concerns**:

   - Gateway handles model routing
   - Proxy handles network routing
   - Keep configuration independent

2. **Use NO_PROXY Correctly**:

   - Bypass proxy for local gateway
   - Include internal domains
   - Test bypass patterns

3. **Monitor All Layers**:

   - Claude Code errors
   - Gateway logs
   - Proxy logs
   - Provider dashboards

4. **Implement Caching**:

   - Redis cache at gateway
   - Reduces proxy/provider load
   - Improves latency

5. **Plan for Failures**:
   - Proxy authentication expiry
   - Network outages
   - Provider rate limits

## References

- Setup Guide: `examples/us4-corporate-proxy-setup.md`
- Proxy Configuration: `examples/us4-https-proxy-config.md`
- Troubleshooting: `examples/us4-proxy-troubleshooting.md`
- Templates: `templates/proxy/proxy-gateway-config.yaml`
