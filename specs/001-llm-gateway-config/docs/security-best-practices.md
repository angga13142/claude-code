# Security Best Practices - LLM Gateway Configuration

**Consolidated security guidance for all deployment scenarios.**

---

## API Key Security

### Storage

**✅ DO**:

- Store in environment variables or secrets manager
- Use separate keys per environment (dev/staging/prod)
- Rotate keys every 90 days
- Use least-privilege keys

**❌ DON'T**:

- Commit keys to Git repositories
- Share keys via email/chat
- Hardcode in configuration files
- Use same key across environments

### Key Management

```bash
# ✅ Good: Environment variable
export ANTHROPIC_API_KEY="sk-ant-..."

# ✅ Good: Secrets manager
export ANTHROPIC_API_KEY=$(aws secretsmanager get-secret-value --secret-id anthropic-key --query SecretString --output text)

# ✅ Good: 1Password CLI
export ANTHROPIC_API_KEY=$(op read "op://Private/Anthropic/credential")

# ❌ Bad: Hardcoded
api_key: "sk-ant-api03-abc123..."  # NEVER DO THIS
```

### Key Rotation

**Process**:

1. Generate new API key from provider
2. Test new key in non-production
3. Update secrets manager/environment
4. Deploy to production
5. Monitor for errors
6. Revoke old key after 24-48 hours

**Automation**:

```bash
#!/bin/bash
# Automated key rotation script
NEW_KEY=$(generate_new_anthropic_key)
aws secretsmanager update-secret --secret-id anthropic-key --secret-string "$NEW_KEY"
# Restart services to pick up new key
systemctl restart litellm-gateway
```

---

## Network Security

### TLS/SSL Configuration

**Requirements**:

- TLS 1.2 minimum (TLS 1.3 preferred)
- Strong cipher suites only
- Valid certificates (no self-signed in production)
- Certificate pinning (optional, for high security)

**Gateway Configuration**:

```yaml
# Enable HTTPS on gateway
litellm_settings:
  ssl_cert: "/path/to/cert.pem"
  ssl_key: "/path/to/key.pem"
  ssl_ca_cert: "/path/to/ca-bundle.crt"
```

### Firewall Rules

**Outbound** (from gateway):

```bash
# Allow only necessary provider APIs
allow tcp to api.anthropic.com port 443
allow tcp to bedrock.*.amazonaws.com port 443
allow tcp to *.googleapis.com port 443
deny all  # Default deny
```

**Inbound** (to gateway):

```bash
# Restrict to internal network only
allow tcp from 10.0.0.0/8 to gateway_ip port 4000
allow tcp from 192.168.0.0/16 to gateway_ip port 4000
deny all
```

### Network Segmentation

**Zones**:

1. **User Zone** (10.0.0.0/16): Developer workstations
2. **Gateway Zone** (10.0.1.0/24): LiteLLM servers
3. **DMZ** (10.0.2.0/24): Corporate proxy
4. **External**: Provider APIs

**Access Control Lists**:

- User → Gateway: Allowed (HTTP/4000)
- Gateway → DMZ: Allowed (HTTP/8080)
- DMZ → External: Allowed (HTTPS/443)
- All other: Denied

---

## Proxy Security

### Credential Management

**Proxy Authentication**:

```bash
# ✅ Good: URL-encoded in environment
export HTTPS_PROXY="http://user:$(urlencode $PASSWORD)@proxy:8080"

# ✅ Better: Use auth proxy (cntlm)
export HTTPS_PROXY="http://localhost:3128"  # cntlm handles auth

# ❌ Bad: Plain text in scripts
HTTPS_PROXY="http://user:password123@proxy:8080"  # Visible in ps
```

### SSL Inspection

**Decision Matrix**:

| Requirement             | Enable SSL Inspection | Disable SSL Inspection |
| ----------------------- | --------------------- | ---------------------- |
| DLP required            | ✅                    | ❌                     |
| Audit logging           | ✅                    | ❌                     |
| Performance critical    | ❌                    | ✅                     |
| Low maintenance         | ❌                    | ✅                     |
| Provider ToS compliance | ❌                    | ✅                     |

**If Enabled**:

1. Install corporate CA on all clients
2. Document CA installation procedure
3. Monitor certificate expiry
4. Test regularly

---

## Data Protection

### Data at Rest

**Cache Encryption**:

```yaml
# Redis with encryption
cache_params:
  type: "redis"
  host: "redis.internal"
  port: 6379
  password: os.environ/REDIS_PASSWORD
  ssl: true # Enable TLS
  ssl_ca_certs: "/path/to/ca.pem"
```

**Log Encryption**:

```bash
# Encrypt sensitive logs
log_file="/var/log/litellm/gateway.log"
encrypted_log="${log_file}.gpg"
gpg --encrypt --recipient admin@company.com "$log_file"
shred -u "$log_file"  # Securely delete original
```

### Data in Transit

**All Connections**:

- Claude Code ↔ Gateway: HTTP (local) or HTTPS (remote)
- Gateway ↔ Providers: HTTPS (TLS 1.2+)
- Gateway ↔ Redis: TLS encrypted
- Gateway ↔ Database: TLS encrypted

### PII/Sensitive Data

**Detection**:

```yaml
# DLP rules (if using SSL inspection)
dlp_rules:
  - pattern: "\b\d{3}-\d{2}-\d{4}\b"  # SSN
    action: "block"
  - pattern: "\b\d{16}\b"  # Credit card
    action: "block"
  - pattern: "sk-ant-api[0-9a-zA-Z]+"
    action: "redact"
```

**Prevention**:

```python
# Pre-flight validation (client-side)
def validate_prompt(prompt: str) -> bool:
    """Check for sensitive data before sending."""
    if re.search(r'\b\d{3}-\d{2}-\d{4}\b', prompt):  # SSN
        raise ValueError("Prompt contains SSN")
    if re.search(r'sk-ant-api\w+', prompt):  # API key
        raise ValueError("Prompt contains API key")
    return True
```

---

## Access Control

### Authentication

**Gateway Authentication** (if shared):

```yaml
# API key authentication
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY

model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      api_key: os.environ/ANTHROPIC_API_KEY
```

**Usage**:

```bash
# Clients must provide master key
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
     http://gateway:4000/v1/chat/completions
```

### Authorization

**Role-Based Access**:

```yaml
# Different keys for different teams
teams:
  - team_name: "engineering"
    team_id: "eng-team"
    models: ["claude-3-5-sonnet", "gemini-2.0-flash"]

  - team_name: "research"
    team_id: "research-team"
    models: ["claude-3-opus", "gemini-2.5-pro"]
```

### Rate Limiting

**Per-User Limits**:

```yaml
litellm_settings:
  rpm: 100 # requests per minute per user
  tpm: 50000 # tokens per minute per user
  max_parallel_requests: 10
```

---

## Logging & Monitoring

### Audit Logging

**What to Log**:

- ✅ All API requests (timestamp, user, model, tokens)
- ✅ Authentication attempts (success/failure)
- ✅ Configuration changes
- ✅ Error responses
- ❌ Full prompt/response content (privacy)
- ❌ API keys (security)

**Log Format**:

```json
{
  "timestamp": "2025-12-01T10:30:45Z",
  "event_type": "api_request",
  "user": "john.doe@company.com",
  "source_ip": "10.0.0.123",
  "model": "claude-3-5-sonnet",
  "tokens_in": 150,
  "tokens_out": 300,
  "latency_ms": 450,
  "status": 200
}
```

### Security Monitoring

**Alerts**:

```yaml
alerts:
  - name: "High request rate"
    condition: "rpm > 1000"
    action: "notify security-team@company.com"

  - name: "Authentication failures"
    condition: "auth_failures > 10 in 5min"
    action: "block IP for 1 hour"

  - name: "Suspicious patterns"
    condition: "prompt contains 'jailbreak'"
    action: "flag for review"
```

### Log Retention

**Requirements**:

- **Security logs**: 1 year minimum
- **Audit logs**: 90 days minimum (or per compliance)
- **Debug logs**: 7-30 days
- **Performance logs**: 30 days

**Compliance** (SOC 2, ISO 27001, GDPR):

- Encrypted storage
- Access controls
- Tamper-evident
- Regular reviews

---

## Incident Response

### API Key Compromise

**Immediate Actions** (< 15 minutes):

1. Revoke compromised key at provider
2. Generate new key
3. Update secrets manager
4. Restart services
5. Notify affected teams

**Investigation** (< 24 hours):

1. Review audit logs for unauthorized usage
2. Identify exposure vector
3. Assess data accessed
4. Document findings

**Prevention**:

1. Rotate all related keys
2. Review security practices
3. Implement additional controls
4. Train team on key management

### Data Breach

**Response Plan**:

1. **Contain**: Isolate affected systems
2. **Assess**: Determine scope and impact
3. **Notify**: Inform stakeholders per policy
4. **Remediate**: Fix vulnerability
5. **Document**: Complete incident report

### Service Outage

**Failover**:

```yaml
# Automatic failover to backup provider
model_list:
  - model_name: claude-with-fallback
    litellm_params:
      model: anthropic/claude-3-5-sonnet
      fallbacks:
        [
          { "model": "bedrock/anthropic.claude-3-5-sonnet" },
          { "model": "vertex_ai/gemini-2.0-flash" },
        ]
```

---

## Compliance

### SOC 2 Type II

**Controls**:

- ✅ Access control (authentication + authorization)
- ✅ Encryption (TLS in transit, encryption at rest)
- ✅ Audit logging (comprehensive logs)
- ✅ Change management (documented procedures)
- ✅ Monitoring (security alerts)
- ✅ Incident response (documented plan)

### GDPR

**Requirements**:

- ✅ Data minimization (log only necessary data)
- ✅ Purpose limitation (use only for intended purpose)
- ✅ Storage limitation (retention policies)
- ✅ Right to erasure (ability to delete user data)
- ✅ Data portability (export capabilities)
- ✅ Privacy by design (security built-in)

### HIPAA (Healthcare)

**Additional Requirements**:

- ✅ Business Associate Agreement (BAA) with providers
- ✅ Audit controls (comprehensive logging)
- ✅ Integrity controls (tamper-evident logs)
- ✅ Transmission security (TLS 1.2+)
- ✅ Person/entity authentication (strong auth)

---

## Security Checklist

### Initial Setup

- [ ] API keys stored in secrets manager (not environment/files)
- [ ] TLS enabled for all external connections
- [ ] Firewall rules configured (least privilege)
- [ ] Network segmentation implemented
- [ ] Audit logging enabled
- [ ] Log retention configured per policy
- [ ] Security monitoring/alerts configured
- [ ] Incident response plan documented
- [ ] Team trained on security practices

### Ongoing Operations

- [ ] API keys rotated every 90 days
- [ ] Certificates renewed before expiry
- [ ] Logs reviewed weekly
- [ ] Security alerts triaged daily
- [ ] Vulnerability scans monthly
- [ ] Penetration test annually
- [ ] Compliance audit annually
- [ ] DR/BC test quarterly

### Before Production

- [ ] Security review completed
- [ ] Penetration test passed
- [ ] Compliance requirements verified
- [ ] Runbooks documented
- [ ] Team trained
- [ ] Monitoring validated
- [ ] Backups tested
- [ ] DR plan tested

---

## References

- **Configuration**: `docs/configuration-reference.md`
- **Environment Variables**: `docs/environment-variables.md`
- **Enterprise Security**: `examples/us2-security-best-practices.md`
- **Compliance**: `examples/us2-compliance-guide.md`
- **Firewall**: `examples/us4-firewall-considerations.md`

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
