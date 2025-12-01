# Header Forwarding Configuration Guide for Enterprise Gateways

**Purpose**: Ensure enterprise gateways correctly forward required headers to Anthropic API  
**Audience**: Platform engineers, DevOps, Gateway administrators  
**Prerequisites**: Enterprise gateway deployed (Kong, Apigee, Zuplo, AWS API Gateway, etc.)

---

## Overview

Claude Code requires specific HTTP headers to communicate with the Anthropic API. When routing through an enterprise gateway, the gateway **MUST** forward these headers to the upstream Anthropic API without modification. Failure to forward headers results in `400 Bad Request` or API compatibility errors.

---

## Required Headers (MUST Forward)

### 1. `anthropic-version`

**Purpose**: Specifies the Anthropic API version to use  
**Format**: `anthropic-version: YYYY-MM-DD`  
**Example**: `anthropic-version: 2023-06-01`  
**Required**: Yes, for ALL requests  
**Default**: If not provided by client, gateway should inject `2023-06-01`

**Why Critical**:

- Anthropic API uses versioning to maintain backward compatibility
- Different versions may have different request/response schemas
- Missing this header causes `400 Bad Request: Missing required header 'anthropic-version'`

### 2. `anthropic-beta`

**Purpose**: Enables beta features like extended thinking, prompt caching, etc.  
**Format**: `anthropic-beta: feature-name-YYYY-MM-DD[,feature2-YYYY-MM-DD]`  
**Examples**:

- `anthropic-beta: messages-2025-01-01`
- `anthropic-beta: prompt-caching-2024-07-31,extended-thinking-2024-12-12`

**Required**: Yes, if using beta features  
**Default**: Can be omitted if no beta features are used

**Why Critical**:

- Beta features like extended thinking require this header
- Missing this header when using beta features causes `400 Bad Request: Beta feature not enabled`

### 3. `anthropic-client-version`

**Purpose**: Identifies the client SDK version making the request  
**Format**: `anthropic-client-version: <sdk>/<version>`  
**Example**: `anthropic-client-version: claude-code/1.0.0`  
**Required**: Optional but recommended for telemetry

**Why Useful**:

- Helps Anthropic identify client-specific issues
- Enables version-specific support and troubleshooting
- Does not affect request processing

### 4. `Authorization`

**Purpose**: Authenticates the request with Anthropic API  
**Format**: `Authorization: Bearer <api-key>`  
**Example**: `Authorization: Bearer sk-ant-api03-xxxxx`  
**Required**: Yes, for ALL requests

**Gateway Handling**:

- Client sends gateway API key: `Authorization: Bearer gateway-key`
- Gateway validates gateway key
- Gateway replaces with provider API key: `Authorization: Bearer sk-ant-api03-xxxxx`
- Gateway forwards to Anthropic API

**Why Critical**:

- Without valid provider API key, Anthropic returns `401 Unauthorized`

### 5. `Content-Type` and `Accept`

**Purpose**: Specifies request/response format  
**Format**:

- `Content-Type: application/json`
- `Accept: application/json` (non-streaming) or `Accept: text/event-stream` (streaming)

**Required**: Yes, for ALL requests

**Why Critical**:

- Anthropic API requires JSON requests
- Streaming responses use Server-Sent Events (SSE) format

---

## Optional Headers (Recommended to Forward)

### 6. `x-api-key` (Alternative Auth)

Some gateways use `x-api-key` header instead of `Authorization: Bearer`.

**Handling**:

```
Client: x-api-key: gateway-key
Gateway: Authorization: Bearer sk-ant-api03-xxxxx (to Anthropic)
```

### 7. Custom Tracking Headers

Preserve any custom headers for request tracing:

- `x-request-id`
- `x-correlation-id`
- `x-session-id`

---

## Gateway Configuration Examples

### Kong Gateway

```yaml
plugins:
  - name: request-transformer
    config:
      add:
        headers:
          - anthropic-version:2023-06-01
          - Authorization:Bearer ${ANTHROPIC_API_KEY}
      pass:
        # Preserve these headers from client
        - anthropic-beta
        - anthropic-client-version
        - Content-Type
        - Accept
```

### Nginx

```nginx
location /v1/messages {
    # Forward client headers
    proxy_pass_request_headers on;
    
    # Add required headers if missing
    proxy_set_header anthropic-version $http_anthropic_version;
    proxy_set_header anthropic-beta $http_anthropic_beta;
    proxy_set_header anthropic-client-version $http_anthropic_client_version;
    
    # Replace Authorization header with provider key
    proxy_set_header Authorization "Bearer ${ANTHROPIC_API_KEY}";
    
    # Preserve content headers
    proxy_set_header Content-Type $content_type;
    proxy_set_header Accept $http_accept;
    
    # Forward to Anthropic
    proxy_pass https://api.anthropic.com;
}
```

### AWS API Gateway

**Integration Request Mapping Template**:

```velocity
## Pass through all headers except Authorization
#set($context.requestOverride.header.anthropic-version = $input.params("anthropic-version"))
#set($context.requestOverride.header.anthropic-beta = $input.params("anthropic-beta"))
#set($context.requestOverride.header.anthropic-client-version = $input.params("anthropic-client-version"))

## Replace Authorization with provider key
#set($context.requestOverride.header.Authorization = "Bearer $stageVariables.AnthropicApiKey")
```

### Azure API Management

```xml
<policies>
  <inbound>
    <base />
    
    <!-- Preserve client headers -->
    <set-header name="anthropic-version" exists-action="skip">
      <value>2023-06-01</value>
    </set-header>
    
    <!-- Forward anthropic-beta if present -->
    <set-header name="anthropic-beta" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("anthropic-beta", ""))</value>
    </set-header>
    
    <!-- Replace authorization -->
    <set-header name="Authorization" exists-action="override">
      <value>Bearer {{anthropic-api-key}}</value>
    </set-header>
    
    <set-backend-service base-url="https://api.anthropic.com" />
  </inbound>
</policies>
```

### Zuplo (TypeScript Policy)

```typescript
import { ZuploContext, ZuploRequest } from "@zuplo/runtime";

export default async function(request: ZuploRequest, context: ZuploContext) {
  // Required headers to forward
  const requiredHeaders = [
    'anthropic-version',
    'anthropic-beta',
    'anthropic-client-version',
    'Content-Type',
    'Accept'
  ];
  
  // Ensure anthropic-version is set
  if (!request.headers.has('anthropic-version')) {
    request.headers.set('anthropic-version', '2023-06-01');
  }
  
  // Replace Authorization header with provider key
  const providerKey = context.secret('ANTHROPIC_API_KEY');
  request.headers.set('Authorization', `Bearer ${providerKey}`);
  
  return request;
}
```

### Apigee (JavaScript Policy)

```javascript
// Get client headers
var anthropicVersion = context.getVariable("request.header.anthropic-version");
var anthropicBeta = context.getVariable("request.header.anthropic-beta");
var anthropicClientVersion = context.getVariable("request.header.anthropic-client-version");

// Set default anthropic-version if missing
if (!anthropicVersion) {
    context.setVariable("request.header.anthropic-version", "2023-06-01");
}

// Forward anthropic-beta if present
if (anthropicBeta) {
    context.setVariable("target.header.anthropic-beta", anthropicBeta);
}

// Forward anthropic-client-version if present
if (anthropicClientVersion) {
    context.setVariable("target.header.anthropic-client-version", anthropicClientVersion);
}

// Set provider API key
context.setVariable("target.header.Authorization", "Bearer " + context.getVariable("private.anthropic.apikey"));
```

---

## Testing Header Forwarding

### Test Script

```bash
#!/bin/bash
# Test header forwarding through gateway

GATEWAY_URL="https://your-gateway.example.com"
GATEWAY_API_KEY="your-gateway-api-key"

echo "Testing header forwarding..."

curl -v -X POST "${GATEWAY_URL}/v1/messages" \
  -H "Authorization: Bearer ${GATEWAY_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: messages-2025-01-01" \
  -H "anthropic-client-version: test/1.0.0" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 100,
    "messages": [
      {"role": "user", "content": "Say hello"}
    ]
  }'
```

### Expected Response

**Success (200 OK)**:

```json
{
  "id": "msg_xxxxx",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! How can I help you today?"
    }
  ],
  "model": "claude-3-5-sonnet-20241022",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 10,
    "output_tokens": 12
  }
}
```

**Failure (400 Bad Request)** - Missing Headers:

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Missing required header: anthropic-version"
  }
}
```

---

## Verification Checklist

Use this checklist to verify header forwarding:

- [ ] Gateway forwards `anthropic-version` header to Anthropic API
- [ ] Gateway forwards `anthropic-beta` header if present
- [ ] Gateway forwards `anthropic-client-version` header if present
- [ ] Gateway sets default `anthropic-version: 2023-06-01` if client omits it
- [ ] Gateway replaces client `Authorization` with provider API key
- [ ] Gateway preserves `Content-Type: application/json`
- [ ] Gateway preserves `Accept: application/json` or `Accept: text/event-stream`
- [ ] Test request returns 200 OK (not 400 Bad Request)
- [ ] Test request with beta features works (e.g., `anthropic-beta: messages-2025-01-01`)
- [ ] Streaming requests work (`Accept: text/event-stream`)

---

## Troubleshooting

### Issue: `400 Bad Request: Missing required header 'anthropic-version'`

**Cause**: Gateway is not forwarding `anthropic-version` header  
**Solution**:

1. Verify gateway configuration forwards `anthropic-version`
2. Check gateway logs to see if header is present in upstream request
3. Add default `anthropic-version: 2023-06-01` in gateway config
4. Test with curl to isolate issue

### Issue: `400 Bad Request: Invalid beta feature`

**Cause**: Gateway is not forwarding `anthropic-beta` header  
**Solution**:

1. Verify gateway configuration forwards `anthropic-beta`
2. Check client is sending correct `anthropic-beta` value
3. Confirm Anthropic API supports the requested beta feature
4. Test without beta header to verify basic connectivity

### Issue: `401 Unauthorized`

**Cause**: Gateway is not replacing client auth with provider API key  
**Solution**:

1. Verify gateway has valid Anthropic API key configured
2. Check gateway logs for authorization header transformation
3. Confirm provider key starts with `sk-ant-api03-`
4. Test provider key directly against Anthropic API:

   ```bash
   curl -X POST https://api.anthropic.com/v1/messages \
     -H "Authorization: Bearer sk-ant-api03-xxxxx" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
   ```

### Issue: Streaming doesn't work

**Cause**: Gateway is buffering responses or not forwarding `Accept: text/event-stream`  
**Solution**:

1. Disable response buffering in gateway config
2. Verify gateway forwards `Accept: text/event-stream` header
3. Check gateway supports Server-Sent Events (SSE) passthrough
4. Test streaming with curl:

   ```bash
   curl -N -X POST "${GATEWAY_URL}/v1/messages" \
     -H "Authorization: Bearer ${GATEWAY_API_KEY}" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -H "Accept: text/event-stream" \
     -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":100,"messages":[{"role":"user","content":"Count to 5"}],"stream":true}'
   ```

---

## Security Considerations

### DO:

- ✅ Validate client authentication before forwarding to Anthropic
- ✅ Replace client `Authorization` with provider API key
- ✅ Store provider API key in secret manager (not config files)
- ✅ Log header forwarding for audit trail (redact `Authorization`)
- ✅ Rotate provider API keys every 90 days

### DON'T:

- ❌ Forward client `Authorization` directly to Anthropic (security risk)
- ❌ Log full `Authorization` header values (exposes API keys)
- ❌ Hardcode provider API key in gateway config
- ❌ Allow clients to override `Authorization` header
- ❌ Strip all headers indiscriminately

---

## Additional Resources

- **Anthropic API Reference**: https://docs.anthropic.com/api/messages
- **API Versioning Guide**: https://docs.anthropic.com/api/versioning
- **Beta Features**: https://docs.anthropic.com/api/beta-features
- **Gateway Compatibility Checklist**: `examples/us2-compatibility-checklist.md`
- **Custom Gateway Configuration**: `templates/enterprise/custom-gateway-config.yaml`
