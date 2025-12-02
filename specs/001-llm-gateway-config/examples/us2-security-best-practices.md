# Security Best Practices for Enterprise Gateway Deployments

**Audience**: Security engineers, Platform engineers, DevOps teams  
**Purpose**: Security hardening guidance for production gateway deployments  
**Scope**: Claude Code with enterprise API gateways

---

## Security Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimum necessary permissions
3. **Secrets Management**: Never hardcode credentials
4. **Audit Everything**: Comprehensive logging for compliance
5. **Encrypt All Communications**: TLS 1.2+ mandatory
6. **Regular Rotation**: Credentials rotated every 90 days maximum

---

## 1. Credentials & Secrets Management

### ❌ NEVER Do This

```bash
# DON'T: Hardcode API keys in scripts
export ANTHROPIC_AUTH_TOKEN="zpka_live_1234567890abcdef"

# DON'T: Commit secrets to version control
echo "ANTHROPIC_AUTH_TOKEN=sk-ant-api03-xxxxx" >> .env
git add .env

# DON'T: Store secrets in plaintext config files
# config.yaml
auth_token: "zpka_live_1234567890abcdef"

# DON'T: Share secrets via email/chat
"Hey, the gateway token is zpka_live_..."
```

### ✅ DO This Instead

#### Use Secret Managers

**AWS Secrets Manager**:

```bash
# Store secret
aws secretsmanager create-secret \
  --name claude-code/gateway-token \
  --secret-string "zpka_live_xxxxx"

# Retrieve in application
TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id claude-code/gateway-token \
  --query SecretString --output text)
export ANTHROPIC_AUTH_TOKEN="$TOKEN"
```

**Google Secret Manager**:

```bash
# Store secret
echo -n "zpka_live_xxxxx" | \
  gcloud secrets create claude-code-gateway-token --data-file=-

# Retrieve
export ANTHROPIC_AUTH_TOKEN=$(gcloud secrets versions access latest \
  --secret="claude-code-gateway-token")
```

**HashiCorp Vault**:

```bash
# Store secret
vault kv put secret/claude-code gateway_token="zpka_live_xxxxx"

# Retrieve
export ANTHROPIC_AUTH_TOKEN=$(vault kv get -field=gateway_token secret/claude-code)
```

**Kubernetes Secrets**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: claude-code-gateway
type: Opaque
stringData:
  token: zpka_live_xxxxx
---
# In Pod spec
env:
  - name: ANTHROPIC_AUTH_TOKEN
    valueFrom:
      secretKeyRef:
        name: claude-code-gateway
        key: token
```

---

## 2. Authentication & Authorization

### Gateway Authentication Patterns

#### Pattern 1: API Key with Secret Manager (Recommended)

```bash
# Retrieve from secret manager
GATEWAY_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id prod/claude-gateway-token \
  --query SecretString --output text)

# Use in application
export ANTHROPIC_BASE_URL="https://gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="$GATEWAY_TOKEN"
```

**Security Benefits**:

- ✅ Secrets never in source code or environment permanently
- ✅ Centralized secret rotation
- ✅ Audit trail of secret access
- ✅ Automatic encryption at rest

#### Pattern 2: OAuth 2.0 with PKCE (Enterprise SSO)

```bash
# Use PKCE for authorization code flow
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d '=' | tr '/+' '_-')
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -binary -sha256 | base64 | tr -d '=' | tr '/+' '_-')

# Authorization URL with PKCE
AUTH_URL="https://auth.example.com/oauth/authorize?\
client_id=$CLIENT_ID&\
response_type=code&\
redirect_uri=$REDIRECT_URI&\
code_challenge=$CODE_CHALLENGE&\
code_challenge_method=S256"
```

**Security Benefits**:

- ✅ No client secret in public clients
- ✅ Protection against authorization code interception
- ✅ Short-lived access tokens (15-60 min)
- ✅ Refresh tokens for long-term access

#### Pattern 3: Mutual TLS (mTLS) (Highest Security)

```bash
# Client certificate for authentication
export ANTHROPIC_BASE_URL="https://gateway.example.com"
export SSL_CERT_FILE="/path/to/client.crt"
export SSL_KEY_FILE="/path/to/client.key"
export SSL_CAFILE="/path/to/ca.crt"
```

**Security Benefits**:

- ✅ Strong cryptographic authentication
- ✅ No bearer tokens to steal
- ✅ Protection against MITM attacks
- ✅ Certificate-based identity

**Certificate Management**:

```bash
# Generate certificate with short validity (30 days)
openssl req -new -x509 -days 30 \
  -key client.key -out client.crt \
  -subj "/CN=claude-code-client/O=YourOrg"

# Store private key in HSM (production)
# Use cert-manager for automatic renewal (Kubernetes)
```

---

## 3. Network Security

### TLS/SSL Configuration

**Minimum Requirements**:

- ✅ TLS 1.2 or higher (TLS 1.3 recommended)
- ✅ Strong cipher suites only
- ✅ Certificate validation enabled
- ✅ No self-signed certificates in production

**Nginx Configuration**:

```nginx
server {
    listen 443 ssl http2;
    
    # TLS configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    
    # HSTS (force HTTPS for 1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Certificate pinning (optional)
    add_header Public-Key-Pins 'pin-sha256="<primary>"; pin-sha256="<backup>"; max-age=5184000';
}
```

### IP Allowlisting (Optional but Recommended)

**Gateway Configuration**:

```yaml
# TrueFoundry
security:
  ip_allowlist:
    - 203.0.113.0/24  # Corporate office
    - 198.51.100.0/24 # VPN range

# Kong
plugins:
  - name: ip-restriction
    config:
      allow:
        - 203.0.113.0/24
        - 198.51.100.0/24
```

**Benefits**:

- ✅ Prevents unauthorized access even with stolen tokens
- ✅ Defense against token exfiltration
- ✅ Compliance with network segmentation policies

### Private Network Deployment

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐
│ Claude Code │────────▶│ VPN/Bastion  │────────▶│   Gateway    │
│  (Laptop)   │         │    (Public)  │         │  (Private)   │
└─────────────┘         └──────────────┘         └──────────────┘
                                                          │
                                                          ▼
                                                  ┌──────────────┐
                                                  │ Anthropic API│
                                                  │   (Public)   │
                                                  └──────────────┘
```

**Benefits**:

- ✅ Gateway not exposed to public internet
- ✅ Access only through VPN or bastion
- ✅ Additional layer of authentication

---

## 4. Audit Logging & Monitoring

### What to Log

**Required Logs**:

```json
{
  "timestamp": "2025-12-01T10:30:00Z",
  "request_id": "req_12345",
  "client_ip": "203.0.113.42",
  "user_id": "user@example.com",
  "auth_method": "bearer_token",
  "gateway_endpoint": "/v1/messages",
  "upstream_endpoint": "https://api.anthropic.com/v1/messages",
  "http_method": "POST",
  "status_code": 200,
  "response_time_ms": 1234,
  "tokens_used": 150,
  "model": "claude-3-5-sonnet-20241022",
  "rate_limited": false
}
```

**DO NOT Log**:

- ❌ Full Authorization header (redact token)
- ❌ API keys in request/response
- ❌ PII/PHI in prompts (if applicable)
- ❌ Full request/response bodies (only metadata)

**Redaction Example**:

```json
{
  "authorization": "Bearer zpka_****ef",  // ✅ Redacted
  "full_token": "zpka_live_1234567890abcdef"  // ❌ NEVER log
}
```

### Alerting Rules

**Critical Alerts** (PagerDuty/Slack):

- 🚨 Authentication failures > 10/min from same IP
- 🚨 Gateway error rate > 5%
- 🚨 Latency P99 > 10 seconds
- 🚨 Rate limit exhaustion (> 90% of quota)
- 🚨 Invalid token usage spike

**Warning Alerts** (Email):

- ⚠️ Token approaching expiration (< 7 days)
- ⚠️ Unusual traffic patterns
- ⚠️ New client IP addresses
- ⚠️ Cost spike (> 150% of baseline)

**Prometheus Example**:

```yaml
groups:
  - name: gateway_alerts
    rules:
      - alert: HighAuthFailureRate
        expr: rate(gateway_auth_failures_total[5m]) > 10
        annotations:
          summary: "High authentication failure rate detected"
      
      - alert: HighErrorRate
        expr: rate(gateway_errors_total[5m]) / rate(gateway_requests_total[5m]) > 0.05
        annotations:
          summary: "Gateway error rate above 5%"
```

---

## 5. Token & Credential Rotation

### Rotation Schedule

| Credential Type | Rotation Frequency | Method |
|-----------------|-------------------|---------|
| API Keys | 90 days (max) | Manual or automated |
| OAuth Tokens | 15-60 min (auto) | Refresh token flow |
| Service Account Keys | 90 days (max) | GCP key rotation |
| Client Certificates | 30-90 days | Cert-manager automation |

### Automated Rotation (AWS Lambda Example)

```python
import boto3
import requests
from datetime import datetime, timedelta

def rotate_gateway_token(event, context):
    """Rotate gateway API key every 90 days"""
    
    # 1. Generate new token from gateway
    response = requests.post(
        "https://gateway.example.com/api/keys",
        json={"name": f"claude-code-{datetime.now().isoformat()}"},
        headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}
    )
    new_token = response.json()["key"]
    
    # 2. Update secret in AWS Secrets Manager
    secrets = boto3.client('secretsmanager')
    secrets.update_secret(
        SecretId='claude-code/gateway-token',
        SecretString=new_token
    )
    
    # 3. Schedule old token revocation (24h grace period)
    lambda_client = boto3.client('lambda')
    lambda_client.invoke(
        FunctionName='revoke-old-token',
        InvocationType='Event',
        Payload=json.dumps({
            'token': OLD_TOKEN,
            'revoke_at': (datetime.now() + timedelta(hours=24)).isoformat()
        })
    )
    
    return {"statusCode": 200, "message": "Token rotated successfully"}
```

**Schedule with CloudWatch Events**:

```json
{
  "scheduleExpression": "rate(90 days)",
  "target": {
    "arn": "arn:aws:lambda:us-east-1:123456789012:function:rotate-gateway-token"
  }
}
```

---

## 6. Rate Limiting & Abuse Prevention

### Per-User Rate Limiting

```yaml
# TrueFoundry
rate_limits:
  - scope: user
    requests_per_minute: 100
    tokens_per_minute: 400000
    burst_allowance: 20

# Kong
plugins:
  - name: rate-limiting
    config:
      minute: 100
      policy: redis
      redis_host: redis.example.com
      identifier: consumer
```

### Anomaly Detection

**Detect suspicious patterns**:

- Sudden traffic spike (> 300% of baseline)
- Requests from new geographic regions
- Unusual request patterns (e.g., only errors)
- Token usage from multiple IPs simultaneously

**Example Rule (Prometheus)**:

```yaml
- alert: SuspiciousTrafficSpike
  expr: |
    rate(gateway_requests_total[5m]) > 
    3 * avg_over_time(gateway_requests_total[1h])
  for: 10m
  annotations:
    summary: "Traffic spike detected - possible abuse"
```

---

## 7. Incident Response

### Security Incident Playbook

#### Scenario 1: Compromised API Key

**Actions**:

1. ✅ Immediately revoke compromised token in gateway
2. ✅ Generate and deploy new token from secret manager
3. ✅ Review audit logs for unauthorized usage
4. ✅ Identify source of compromise (git history, logs, etc.)
5. ✅ Rotate all potentially exposed credentials
6. ✅ Notify security team and affected users
7. ✅ Update security policies to prevent recurrence

**Commands**:

```bash
# 1. Revoke token (gateway API)
curl -X DELETE https://gateway.example.com/api/keys/$KEY_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 2. Generate new token
NEW_TOKEN=$(curl -X POST https://gateway.example.com/api/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"name":"claude-code-emergency"}' | jq -r '.key')

# 3. Update secret manager
aws secretsmanager update-secret \
  --secret-id claude-code/gateway-token \
  --secret-string "$NEW_TOKEN"

# 4. Verify new token works
ANTHROPIC_AUTH_TOKEN="$NEW_TOKEN" claude "test"
```

#### Scenario 2: Gateway Breach

**Actions**:

1. ✅ Isolate compromised gateway (network segmentation)
2. ✅ Rotate ALL gateway tokens immediately
3. ✅ Enable additional monitoring and logging
4. ✅ Conduct forensic analysis of breach
5. ✅ Patch vulnerabilities and redeploy gateway
6. ✅ Notify customers per breach disclosure policies

---

## 8. Compliance & Regulatory Requirements

### Data Residency

**Requirement**: Ensure data stays within geographic boundaries

**Implementation**:

```yaml
# TrueFoundry - US-only deployment
deployment:
  regions:
    - us-east-1
    - us-west-2
  data_residency: US

# Gateway configuration
upstream_regions:
  - https://api.anthropic.com  # US-based API
```

### Data Retention

**Requirement**: Retain logs for audit purposes

**Implementation**:

```yaml
# Logging configuration
logging:
  retention_days: 2555  # 7 years for SOC2/HIPAA
  storage: s3
  encryption: AES-256
  immutable: true  # WORM (Write Once Read Many)
```

---

## 9. Security Checklist

### Pre-Production

- [ ] All secrets stored in secret manager (not env vars)
- [ ] TLS 1.2+ enforced on all connections
- [ ] Certificate validation enabled
- [ ] IP allowlisting configured (if applicable)
- [ ] Rate limiting enabled per user/team
- [ ] Audit logging configured and tested
- [ ] Alerting rules configured (auth failures, errors, latency)
- [ ] Token rotation schedule defined (≤ 90 days)
- [ ] Incident response playbook documented
- [ ] Security scanning passed (OWASP ZAP, etc.)

### Production

- [ ] Secrets rotated within last 90 days
- [ ] Audit logs reviewed monthly
- [ ] No security alerts in last 24 hours
- [ ] Vulnerability scans passed (no critical/high)
- [ ] Penetration testing passed (if applicable)
- [ ] Compliance certifications current (SOC2, etc.)
- [ ] Backup and disaster recovery tested
- [ ] Security training completed by all team members

---

## 10. Additional Resources

- **Secret Management**: `templates/enterprise/auth-token-setup.md`
- **Audit Logging Examples**: Gateway-specific documentation
- **Incident Response Templates**: Your organization's security policies
- **Compliance Guide**: `examples/us2-compliance-guide.md`
- **Penetration Testing Tools**: OWASP ZAP, Burp Suite
- **Threat Modeling**: STRIDE framework for gateway architecture
