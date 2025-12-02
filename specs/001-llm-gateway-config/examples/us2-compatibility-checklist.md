# Gateway Compatibility Checklist (User Story 2)

**Purpose**: Validate that an enterprise gateway meets Claude Code compatibility requirements  
**Usage**: Check each criterion before deploying gateway for production use  
**Reference**: spec.md - Gateway Compatibility Criteria (7 requirements)

---

## Quick Validation

Run automated validator first:

```bash
python scripts/validate-gateway-compatibility.py \
  --url https://your-gateway.example.com \
  --token your-api-key \
  --verbose \
  --output compatibility-report.json
```

If all automated checks pass, proceed with manual verification below.

---

## Required Criteria (ALL must pass)

### ✅ Criterion 1: Messages API Endpoint Support

**Requirement**: Gateway MUST support POST requests to `/v1/messages` endpoint

**Test**:

```bash
curl -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "test"}]
  }'
```

**Expected**: HTTP 200 (success) or 401/403 (auth error, but endpoint exists)

**Verification Checklist**:

- [ ] POST /v1/messages endpoint exists and responds
- [ ] Endpoint accepts JSON request body
- [ ] Endpoint returns JSON response (or SSE for streaming)
- [ ] Endpoint does not modify request/response structure

**Common Issues**:

- ❌ 404 Not Found → Endpoint not configured
- ❌ 405 Method Not Allowed → POST method not enabled
- ❌ Endpoint at different path (e.g., `/api/v1/messages`) → Non-standard path

**Fix**: Configure gateway routing to forward `/v1/messages` to `https://api.anthropic.com/v1/messages`

---

### ✅ Criterion 2: Required Header Forwarding

**Requirement**: Gateway MUST forward these headers without modification:

- `anthropic-version` (required)
- `anthropic-beta` (required for beta features)
- `anthropic-client-version` (recommended)
- `Content-Type` (required)
- `Accept` (required)

**Test**:

```bash
./tests/test-header-forwarding.sh \
  --url https://your-gateway.example.com \
  --token your-token
```

**Expected**: All header forwarding tests pass

**Verification Checklist**:

- [ ] `anthropic-version` header forwarded to Anthropic API
- [ ] `anthropic-beta` header forwarded (if provided by client)
- [ ] `anthropic-client-version` header forwarded (if provided)
- [ ] `Content-Type: application/json` preserved
- [ ] `Accept: application/json` or `Accept: text/event-stream` preserved
- [ ] Gateway does NOT strip unknown `anthropic-*` headers

**Common Issues**:

- ❌ 400 Bad Request with "Missing required header" → Headers not forwarded
- ❌ Gateway strips all custom headers → Overly restrictive header filtering
- ❌ Gateway adds unwanted headers that break API → Header injection issue

**Fix**: Configure gateway to forward all `anthropic-*` headers. See `templates/enterprise/header-forwarding.md`

**Gateway-Specific Configuration**:

**Kong**:

```yaml
plugins:
  - name: request-transformer
    config:
      pass:
        - anthropic-version
        - anthropic-beta
        - anthropic-client-version
```

**Nginx**:

```nginx
proxy_pass_request_headers on;
proxy_set_header anthropic-version $http_anthropic_version;
proxy_set_header anthropic-beta $http_anthropic_beta;
```

**AWS API Gateway**:

- Integration Request → HTTP Headers → Add mappings for each header

---

### ✅ Criterion 3: Request/Response Body Preservation

**Requirement**: Gateway MUST NOT modify request or response JSON bodies

**Test**:

```bash
# Send request with specific structure
curl -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 20,
    "messages": [{"role": "user", "content": "Say exactly: test123"}]
  }' | jq .
```

**Expected**: Response contains fields:

```json
{
  "id": "msg_xxxxx",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "..."}],
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 10, "output_tokens": 5}
}
```

**Verification Checklist**:

- [ ] All standard response fields present (`id`, `type`, `role`, `content`, `model`, `usage`)
- [ ] Field names NOT changed (e.g., `content` not renamed to `response`)
- [ ] Field types preserved (numbers stay numbers, not converted to strings)
- [ ] Nested objects preserved (e.g., `content` array structure intact)
- [ ] No extra wrapper objects added (e.g., `{"data": {...}}`)
- [ ] Request body passed through without modification

**Common Issues**:

- ❌ Gateway wraps response: `{"success": true, "data": {...}}` → Body modification
- ❌ Gateway renames fields for "consistency" → Breaking change
- ❌ Gateway removes fields it doesn't recognize → Data loss
- ❌ Gateway transforms response to different format → Incompatible

**Fix**: Disable all request/response transformations. Use "passthrough" or "proxy" mode.

---

### ✅ Criterion 4: Standard HTTP Status Codes

**Requirement**: Gateway MUST return correct HTTP status codes:

- `200 OK` - Successful response
- `401 Unauthorized` - Invalid/missing authentication
- `403 Forbidden` - Valid auth but insufficient permissions
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Gateway error
- `502 Bad Gateway` - Anthropic API error
- `503 Service Unavailable` - Gateway overloaded
- `504 Gateway Timeout` - Request timeout

**Test**:

```bash
# Test 401 (invalid token)
curl -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer invalid-token-12345" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'

# Expected: HTTP 401 or 403
```

**Verification Checklist**:

- [ ] Invalid token returns 401 (not 400 or 500)
- [ ] Rate limit returns 429 (not 503)
- [ ] Gateway errors return 500-504 (not 200 with error body)
- [ ] Successful requests return 200 (not 201 or 202)
- [ ] Status codes match error types (auth → 401/403, rate limit → 429)

**Common Issues**:

- ❌ All errors return 500 → Status code not differentiated
- ❌ Gateway returns 200 with `{"error": "..."}` body → Misleading success
- ❌ Gateway returns custom codes (e.g., 599) → Non-standard

**Fix**: Configure gateway to preserve upstream status codes, not override them

---

### ✅ Criterion 5: Server-Sent Events (SSE) Streaming Support

**Requirement**: Gateway MUST support streaming responses with SSE format

**Test**:

```bash
curl -N -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 50,
    "messages": [{"role": "user", "content": "Count to 5"}],
    "stream": true
  }'
```

**Expected**: Real-time streaming output:

```
event: message_start
data: {"type":"message_start","message":{...}}

event: content_block_delta
data: {"type":"content_block_delta","delta":{"text":"1"}}

event: content_block_delta
data: {"type":"content_block_delta","delta":{"text":", 2"}}
...
```

**Verification Checklist**:

- [ ] `Content-Type: text/event-stream` header in response
- [ ] Events arrive in real-time (not buffered until complete)
- [ ] SSE format preserved (`event:` and `data:` lines)
- [ ] `[DONE]` completion marker included
- [ ] Streaming works with `curl -N` (no buffering)
- [ ] Connection stays open during streaming
- [ ] Gateway does NOT buffer entire response before sending

**Common Issues**:

- ❌ Response arrives all at once after completion → Buffering enabled
- ❌ `Content-Type: application/json` instead of `text/event-stream` → Wrong type
- ❌ Connection closes immediately → Streaming not supported
- ❌ Chunks arrive but SSE format lost → Gateway modifying response

**Fix**: Disable response buffering in gateway configuration:

**Nginx**:

```nginx
proxy_buffering off;
```

**Kong**:

```yaml
plugins:
  - name: response-buffering
    config:
      enabled: false
```

**AWS API Gateway**: Not suitable for SSE streaming (30s timeout limit). Use ALB or API Gateway WebSocket API instead.

---

### ✅ Criterion 6: Bearer Token Authentication

**Requirement**: Gateway MUST accept authentication via `Authorization: Bearer <token>` header

**Test**:

```bash
# Test with valid token
curl -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-valid-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"test"}]}'

# Expected: HTTP 200 (or 403 if token lacks permissions)
```

**Verification Checklist**:

- [ ] `Authorization: Bearer <token>` header accepted
- [ ] Valid token results in successful request (200)
- [ ] Invalid token results in auth error (401)
- [ ] Expired token results in auth error (401)
- [ ] Gateway validates token before forwarding to Anthropic
- [ ] Gateway replaces client token with provider API key upstream
- [ ] Multiple concurrent requests with same token work correctly

**Common Issues**:

- ❌ Gateway requires different auth format (e.g., `X-API-Key`) → Non-standard
- ❌ Gateway doesn't validate token (security issue) → Open access
- ❌ Gateway forwards client token to Anthropic (security issue) → Token leakage
- ❌ Token validation too slow (>1s latency) → Performance issue

**Fix**: Implement Bearer token auth that validates locally and swaps with provider key

---

### ✅ Criterion 7: Minimum 60-Second Timeout

**Requirement**: Gateway MUST support requests taking up to 60 seconds minimum (recommended: 300-600s)

**Test** (manual timing):

```bash
# Send request that takes 30-60 seconds
time curl -X POST https://your-gateway.example.com/v1/messages \
  -H "Authorization: Bearer your-token" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 4000,
    "messages": [{"role": "user", "content": "Write a detailed 2000-word essay about artificial intelligence"}]
  }'
```

**Expected**: Request completes successfully (not 504 timeout)

**Verification Checklist**:

- [ ] Gateway timeout ≥ 60 seconds (check config)
- [ ] Complex requests complete without 504 errors
- [ ] Streaming requests can run for several minutes
- [ ] Gateway doesn't kill idle connections prematurely
- [ ] Separate read timeout from connect timeout

**Common Issues**:

- ❌ Gateway timeout too short (e.g., 30s) → Requests timeout
- ❌ Gateway kills idle connections → Streaming interrupted
- ❌ No separate read vs connect timeout → Slow responses fail

**Fix**: Increase gateway timeouts:

**Nginx**:

```nginx
proxy_connect_timeout 10s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
```

**Kong**:

```yaml
services:
  - connect_timeout: 10000
    write_timeout: 600000
    read_timeout: 600000
```

**AWS API Gateway**: Maximum 29 seconds (hard limit). Use ALB for longer timeouts.

---

## Summary

### Passing Criteria

Gateway is **COMPATIBLE** if ALL 7 criteria pass:

- ✅ 1. Messages API endpoint supported
- ✅ 2. Required headers forwarded
- ✅ 3. Request/response body preserved
- ✅ 4. Standard HTTP status codes returned
- ✅ 5. SSE streaming supported
- ✅ 6. Bearer token authentication works
- ✅ 7. Timeout ≥ 60 seconds configured

### Failing Criteria

Gateway is **INCOMPATIBLE** if ANY criterion fails. Fix issues before production deployment.

### Automated Validation

```bash
# Run full compatibility check
python scripts/validate-gateway-compatibility.py \
  --url https://your-gateway.example.com \
  --token your-api-key \
  --verbose \
  --output report.json

# Expected exit code: 0 (compatible)
```

---

## Additional Resources

- **Automated Validator**: `scripts/validate-gateway-compatibility.py`
- **Header Forwarding Tests**: `tests/test-header-forwarding.sh`
- **Rate Limiting Tests**: `tests/test-rate-limiting.py`
- **Auth Troubleshooting**: `scripts/debug-auth.sh`
- **Configuration Templates**: `templates/enterprise/*.yaml`
- **Integration Guide**: `examples/us2-enterprise-integration.md`
