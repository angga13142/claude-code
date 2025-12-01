# Enterprise Gateway Integration Guide (User Story 2)

**Audience**: Enterprise architects, Platform engineers, DevOps teams  
**Time to Complete**: 45-60 minutes  
**Prerequisites**: Enterprise gateway deployed (TrueFoundry, Zuplo, Kong, etc.)

---

## Overview

This guide walks through integrating Claude Code with enterprise API gateways. Enterprise gateways provide centralized authentication, rate limiting, compliance enforcement, and observability for API traffic.

**Benefits**:
- ✅ Centralized authentication and authorization
- ✅ Rate limiting and quota management per team/user
- ✅ Audit logging for compliance (SOC2, HIPAA, GDPR)
- ✅ Cost tracking and chargebacks
- ✅ Traffic monitoring and analytics

---

## Quick Start (5 minutes)

### Step 1: Get Gateway Details

From your gateway administrator, obtain:
```
Gateway URL: https://your-gateway.example.com
API Key: your-gateway-api-key-xxxxx
```

### Step 2: Configure Claude Code

```bash
export ANTHROPIC_BASE_URL="https://your-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key-xxxxx"
```

### Step 3: Verify Connection

```bash
claude /status
```

Expected output:
```
Claude Code Status
==================
Base URL: https://your-gateway.example.com (custom)
Authentication: Configured
```

### Step 4: Test Request

```bash
claude "Hello world"
```

If successful, you're done! Continue to full setup for production configuration.

---

## Full Setup Guide

### Phase 1: Gateway Selection (15 minutes)

#### Option A: TrueFoundry LLM Gateway

**When to use**: Need managed infrastructure with built-in observability

**Setup**:
1. Deploy TrueFoundry in your Kubernetes cluster
2. Configure Anthropic provider:
   ```yaml
   # truefoundry-config.yaml
   providers:
     - name: anthropic
       type: anthropic
       api_key: ${ANTHROPIC_API_KEY}
       models:
         - claude-3-5-sonnet-20241022
         - claude-3-5-haiku-20241022
   ```
3. Apply configuration:
   ```bash
   truefoundry apply -f truefoundry-config.yaml
   ```
4. Get gateway URL from TrueFoundry console

**Template**: See `templates/enterprise/truefoundry-config.yaml`

#### Option B: Zuplo API Gateway

**When to use**: Need edge gateway with developer portal

**Setup**:
1. Create Zuplo project at https://portal.zuplo.com
2. Configure route in `routes.oas.json`:
   ```json
   {
     "paths": {
       "/v1/messages": {
         "post": {
           "x-zuplo-route": {
             "handler": {
               "export": "urlForwardHandler",
               "options": {
                 "baseUrl": "https://api.anthropic.com"
               }
             },
             "policies": {
               "inbound": ["api-key-inbound", "rate-limit-inbound"]
             }
           }
         }
       }
     }
   }
   ```
3. Deploy to production
4. Generate API key in Zuplo Portal

**Template**: See `templates/enterprise/zuplo-config.yaml`

#### Option C: Custom Enterprise Gateway

**When to use**: Already have Kong, Apigee, AWS API Gateway, etc.

**Setup**:
1. Configure upstream to Anthropic API: `https://api.anthropic.com`
2. Configure authentication plugin
3. Add header forwarding rules (critical - see Phase 2)
4. Configure rate limiting
5. Deploy configuration

**Template**: See `templates/enterprise/custom-gateway-config.yaml`

---

### Phase 2: Header Forwarding Configuration (10 minutes)

**⚠️ CRITICAL**: Gateways MUST forward these headers:

| Header | Required | Purpose |
|--------|----------|---------|
| `anthropic-version` | Yes | API version (e.g., `2023-06-01`) |
| `anthropic-beta` | For beta features | Enable beta features |
| `anthropic-client-version` | Recommended | Client identification |
| `Authorization` | Yes | Authentication (replaced by gateway) |
| `Content-Type` | Yes | Request format (`application/json`) |
| `Accept` | Yes | Response format (json or SSE) |

#### Configuration Examples

**Kong Gateway**:
```yaml
plugins:
  - name: request-transformer
    config:
      add:
        headers:
          - anthropic-version:2023-06-01
          - Authorization:Bearer ${ANTHROPIC_API_KEY}
      pass:
        - anthropic-beta
        - anthropic-client-version
```

**Nginx**:
```nginx
location /v1/messages {
    proxy_pass_request_headers on;
    proxy_set_header anthropic-version $http_anthropic_version;
    proxy_set_header anthropic-beta $http_anthropic_beta;
    proxy_set_header Authorization "Bearer ${ANTHROPIC_API_KEY}";
}
```

**AWS API Gateway**:
- Integration Request → HTTP Headers
- Add mapping: `anthropic-version` → `'2023-06-01'`
- Add mapping: `anthropic-beta` → `method.request.header.anthropic-beta`

**Full Guide**: See `templates/enterprise/header-forwarding.md`

#### Verification

```bash
# Test header forwarding
./tests/test-header-forwarding.sh \
  --url https://your-gateway.example.com \
  --token your-api-key
```

Expected:
```
✓ PASS - anthropic-version header forwarded correctly
✓ PASS - anthropic-beta header forwarded correctly
✓ PASS - Content-Type header preserved correctly
```

---

### Phase 3: Authentication Setup (10 minutes)

#### Option 1: API Key (Simple)

```bash
# Get API key from gateway admin
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key"

# Test authentication
claude "test"
```

#### Option 2: OAuth 2.0 (Enterprise SSO)

```bash
# Obtain OAuth token
TOKEN=$(curl -X POST https://your-org.okta.com/oauth2/v1/token \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "scope=anthropic:read anthropic:write" \
  | jq -r '.access_token')

# Configure Claude Code
export ANTHROPIC_AUTH_TOKEN="$TOKEN"
```

#### Option 3: Service Account (GCP)

```bash
# Gateway uses service account internally
# Claude Code only needs gateway token
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key"

# Gateway handles GCP authentication automatically
```

**Full Guide**: See `templates/enterprise/auth-token-setup.md`

---

### Phase 4: Rate Limiting Configuration (5 minutes)

Configure rate limits per your gateway:

**TrueFoundry**:
```yaml
rate_limits:
  - name: claude-code-team
    requests_per_minute: 100
    tokens_per_minute: 400000
```

**Zuplo**:
```json
{
  "export": "RateLimitInboundPolicy",
  "options": {
    "rateLimitBy": "consumer",
    "requestsPerMinute": 100
  }
}
```

**Kong**:
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      policy: local
```

#### Verification

```bash
# Test rate limiting
python tests/test-rate-limiting.py \
  --url https://your-gateway.example.com \
  --token your-api-key \
  --rpm 100
```

---

### Phase 5: Validation (10 minutes)

#### Run Compatibility Validator

```bash
python scripts/validate-gateway-compatibility.py \
  --url https://your-gateway.example.com \
  --token your-api-key \
  --verbose
```

Expected output:
```
✓ PASS - Endpoint Support: Gateway supports /v1/messages endpoint
✓ PASS - Header Forwarding: All required headers forwarded correctly
✓ PASS - Body Preservation: Response body structure preserved correctly
✓ PASS - Status Codes: Gateway returns standard auth error: 401
✓ PASS - SSE Streaming: Gateway supports SSE streaming (3 chunks received)
✓ PASS - Authentication: Bearer token authentication working correctly

✓ Gateway is COMPATIBLE with Claude Code
```

#### Manual Verification Checklist

- [ ] `claude /status` shows custom base URL
- [ ] `claude "test"` returns successful response
- [ ] Streaming works: `claude "Count to 10"`
- [ ] Rate limiting enforced (429 when exceeded)
- [ ] Authentication errors return 401 (test with invalid token)
- [ ] Gateway logs show requests from Claude Code
- [ ] Cost/usage tracking visible in gateway dashboard

---

## Troubleshooting

### Issue 1: Connection Refused

**Symptoms**: `Cannot connect to gateway` error

**Solutions**:
```bash
# 1. Check gateway is running
curl https://your-gateway.example.com/health

# 2. Check network connectivity
ping your-gateway.example.com

# 3. Check firewall rules
# Ensure outbound HTTPS (443) is allowed

# 4. Verify URL is correct
echo $ANTHROPIC_BASE_URL
```

### Issue 2: 401 Unauthorized

**Symptoms**: All requests fail with 401

**Solutions**:
```bash
# Run auth troubleshooting helper
./scripts/debug-auth.sh \
  --url https://your-gateway.example.com \
  --token your-api-key

# Check token expiration (if JWT)
# See debug-auth.sh output

# Regenerate token from gateway admin
```

### Issue 3: 400 Bad Request - Missing Headers

**Symptoms**: `Missing required header: anthropic-version`

**Solutions**:
```bash
# Test header forwarding
./tests/test-header-forwarding.sh \
  --url https://your-gateway.example.com \
  --token your-api-key

# Configure header forwarding in gateway
# See templates/enterprise/header-forwarding.md

# Verify with curl
curl -v -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'
```

### Issue 4: Streaming Doesn't Work

**Symptoms**: Responses not streaming, appear all at once

**Solutions**:
```bash
# Check if gateway buffers responses
# Disable buffering in gateway config

# Nginx:
proxy_buffering off;

# Kong:
plugins:
  - name: response-buffering
    config:
      enabled: false

# Test streaming with curl
curl -N -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Accept: text/event-stream" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":50,"messages":[{"role":"user","content":"Count to 5"}],"stream":true}'
```

---

## Production Considerations

### Security

- ✅ Store API keys in secret manager (not environment variables)
- ✅ Enable mTLS for gateway authentication
- ✅ Implement IP allowlisting
- ✅ Rotate API keys every 90 days
- ✅ Enable audit logging for all requests

**See**: `examples/us2-security-best-practices.md`

### Compliance

- ✅ SOC2: Enable audit logs, encryption at rest/transit
- ✅ HIPAA: BAA with gateway provider, PHI masking
- ✅ GDPR: Data residency configuration, DPA in place

**See**: `examples/us2-compliance-guide.md`

### Observability

- ✅ Configure gateway metrics export (Prometheus)
- ✅ Set up alerting for 5xx errors, rate limits
- ✅ Enable request/response logging
- ✅ Create usage dashboards per team/project

### High Availability

- ✅ Deploy gateway in multiple availability zones
- ✅ Configure health checks and automatic failover
- ✅ Set up Redis for multi-instance state sharing
- ✅ Implement circuit breakers for upstream failures

---

## Next Steps

1. **For Development**: Follow Quick Start, test with sample requests
2. **For Staging**: Configure authentication, validate compatibility
3. **For Production**: Enable security features, set up monitoring

## Additional Resources

- **Gateway Compatibility Validator**: `scripts/validate-gateway-compatibility.py`
- **Header Forwarding Guide**: `templates/enterprise/header-forwarding.md`
- **Authentication Patterns**: `templates/enterprise/auth-token-setup.md`
- **Security Best Practices**: `examples/us2-security-best-practices.md`
- **Compliance Guide**: `examples/us2-compliance-guide.md`
- **Troubleshooting Scripts**: `scripts/debug-auth.sh`
