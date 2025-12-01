# Credential Rotation Procedures

**Feature**: 001-llm-gateway-config  
**Category**: Advanced Features  
**Audience**: Security Teams, DevOps, Platform Engineers  
**Last Updated**: 2025-12-01

---

## Overview

Regular credential rotation is critical for security. This guide provides procedures for rotating API keys, service account credentials, and gateway authentication tokens without service interruption.

**Rotation Frequency**:

- 🔄 **API Keys**: Every 90 days (minimum)
- 🔄 **Service Accounts**: Every 180 days
- 🔄 **TLS Certificates**: Before expiration (typically 90 days)
- 🔄 **Database Passwords**: Every 180 days

---

## API Key Rotation

### Anthropic API Keys

**Zero-Downtime Rotation Process**:

#### Step 1: Generate New Key

```bash
# Log in to Anthropic Console
# Navigate to API Keys → Generate New Key
# Copy new key: sk-ant-...new
```

#### Step 2: Update Configuration (Dual Key)

```yaml
# Option A: Environment variables (supports multiple)
# Export both keys temporarily
export ANTHROPIC_API_KEY="sk-ant-...old"
export ANTHROPIC_API_KEY_NEW="sk-ant-...new"

# Option B: Config file
model_list:
  # Old key (primary)
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: sk-ant-...old

  # New key (fallback during rotation)
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: sk-ant-...new
```

#### Step 3: Verify New Key

```bash
# Test new key
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: sk-ant-...new" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3.5-sonnet-20241022",
    "messages": [{"role": "user", "content": "test"}],
    "max_tokens": 10
  }'

# Expected: 200 OK response
```

#### Step 4: Switch Primary to New Key

```yaml
# Update config to use new key as primary
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: sk-ant-...new # New key now primary
```

```bash
# Reload configuration
kill -HUP $(cat ~/.litellm/litellm.pid)
# Or restart gateway
systemctl reload litellm
```

#### Step 5: Monitor for Errors

```bash
# Watch logs for auth errors
tail -f ~/.litellm/logs/litellm.log | grep -i "unauthorized\|401\|invalid"

# Check metrics
curl http://localhost:4000/metrics | grep litellm_auth_failures_total
```

#### Step 6: Remove Old Key (After 24h)

```yaml
# Remove old key from config
model_list:
  - model_name: claude-3.5-sonnet
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: sk-ant-...new # Only new key
```

```bash
# Revoke old key in Anthropic Console
# API Keys → sk-ant-...old → Revoke
```

---

### AWS Credentials (Bedrock)

**Rotation Using AWS Secrets Manager**:

#### Step 1: Generate New Access Key

```bash
# AWS Console or CLI
aws iam create-access-key --user-name litellm-service-user

# Output:
# AccessKeyId: AKIA...new
# SecretAccessKey: wJalr...new
```

#### Step 2: Store in Secrets Manager

```bash
# Create new secret version
aws secretsmanager put-secret-value \
  --secret-id litellm/aws-credentials \
  --secret-string '{
    "access_key": "AKIA...new",
    "secret_key": "wJalr...new"
  }'
```

#### Step 3: Update LiteLLM Configuration

```yaml
model_list:
  - model_name: claude-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID # Will be updated
      aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY
      aws_region_name: us-west-2
```

```bash
# Retrieve from Secrets Manager and export
eval $(aws secretsmanager get-secret-value \
  --secret-id litellm/aws-credentials \
  --query 'SecretString' \
  --output text | jq -r 'to_entries[] | "export \(.key | ascii_upcase)=\(.value)"')

# Restart gateway to pick up new env vars
systemctl restart litellm
```

#### Step 4: Verify New Credentials

```bash
# Test Bedrock access
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --region us-west-2 \
  --body '{"messages":[{"role":"user","content":"test"}],"max_tokens":10}' \
  output.json

# Check gateway can use new creds
curl -X POST http://localhost:4000/v1/chat/completions \
  -d '{"model": "claude-bedrock", "messages": [{"role": "user", "content": "test"}]}'
```

#### Step 5: Delete Old Access Key

```bash
# After 24-48 hours of monitoring
aws iam delete-access-key \
  --user-name litellm-service-user \
  --access-key-id AKIA...old
```

---

### Google Cloud Service Account Keys (Vertex AI)

**Rotation Process**:

#### Step 1: Create New Service Account Key

```bash
# Generate new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=litellm-sa@project.iam.gserviceaccount.com
```

#### Step 2: Update Application Default Credentials

```bash
# Replace old key
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/new-key.json"

# Or update in config
model_list:
  - model_name: claude-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: my-project
      vertex_location: us-central1
      vertex_credentials: /path/to/new-key.json  # New key path
```

#### Step 3: Restart Gateway

```bash
systemctl restart litellm
```

#### Step 4: Verify Access

```bash
# Test Vertex AI access
gcloud ai models list --project=my-project --location=us-central1

# Test via gateway
curl -X POST http://localhost:4000/v1/chat/completions \
  -d '{"model": "claude-vertex", "messages": [{"role": "user", "content": "test"}]}'
```

#### Step 5: Delete Old Key

```bash
# List keys
gcloud iam service-accounts keys list \
  --iam-account=litellm-sa@project.iam.gserviceaccount.com

# Delete old key (after verification)
gcloud iam service-accounts keys delete OLD_KEY_ID \
  --iam-account=litellm-sa@project.iam.gserviceaccount.com
```

---

## Gateway Authentication Token Rotation

### LiteLLM Master Key Rotation

**Process**:

#### Step 1: Generate New Master Key

```bash
# Generate cryptographically random key
NEW_MASTER_KEY=$(openssl rand -hex 32)
echo "New master key: $NEW_MASTER_KEY"
```

#### Step 2: Update Configuration

```yaml
general_settings:
  master_key: $NEW_MASTER_KEY # New key

  # Optional: Support both keys during transition
  master_keys:
    - $NEW_MASTER_KEY # Primary
    - $OLD_MASTER_KEY # Temporary (for existing clients)
```

#### Step 3: Rotate API Keys

```bash
# Existing API keys are bound to old master key
# Regenerate all API keys with new master key

# List existing keys
curl http://localhost:4000/key/list \
  -H "Authorization: Bearer $OLD_MASTER_KEY"

# For each key, create new one
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $NEW_MASTER_KEY" \
  -d '{
    "user_id": "user_123",
    "max_budget": 100.00
  }'

# Distribute new keys to clients
```

#### Step 4: Remove Old Master Key

```yaml
# After all clients migrated (e.g., 30 days)
general_settings:
  master_key: $NEW_MASTER_KEY # Only new key
```

---

## TLS Certificate Rotation

### Gateway TLS Certificates

**Process**:

#### Step 1: Generate New Certificate

```bash
# Option A: Let's Encrypt (automated)
certbot certonly --standalone -d gateway.company.com

# Option B: Corporate CA
openssl req -new -key gateway.key -out gateway.csr
# Submit CSR to CA, receive new certificate
```

#### Step 2: Verify Certificate

```bash
# Check certificate details
openssl x509 -in new-cert.pem -text -noout

# Verify expiration
openssl x509 -in new-cert.pem -noout -dates
```

#### Step 3: Update Configuration

```yaml
# LiteLLM SSL config
ssl:
  certificate: /etc/litellm/ssl/new-cert.pem
  private_key: /etc/litellm/ssl/gateway.key
  certificate_chain: /etc/litellm/ssl/chain.pem
```

#### Step 4: Reload Gateway

```bash
# Graceful reload (zero downtime)
systemctl reload litellm

# Or send HUP signal
kill -HUP $(cat ~/.litellm/litellm.pid)
```

#### Step 5: Verify HTTPS

```bash
# Test TLS connection
openssl s_client -connect gateway.company.com:443 -showcerts

# Check certificate served
curl -vI https://gateway.company.com/health 2>&1 | grep "subject\|issuer\|expire"
```

---

## Automated Rotation

### Using HashiCorp Vault

**Setup**:

```yaml
# Store credentials in Vault
vault kv put secret/litellm/anthropic api_key=sk-ant-...
vault kv put secret/litellm/aws access_key=AKIA... secret_key=wJalr...

# LiteLLM config references Vault
model_list:
  - model_name: claude
    litellm_params:
      model: anthropic/claude-3.5-sonnet-20241022
      api_key: vault://secret/litellm/anthropic#api_key
```

**Rotation**:

```bash
# Update Vault secret (new version created automatically)
vault kv put secret/litellm/anthropic api_key=sk-ant-...new

# LiteLLM reads new version on next request (or restart)
systemctl reload litellm
```

### Using AWS Secrets Manager Auto-Rotation

**Enable Auto-Rotation**:

```bash
aws secretsmanager rotate-secret \
  --secret-id litellm/aws-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-west-2:123456789012:function:RotateAWSCredentials \
  --rotation-rules AutomaticallyAfterDays=90
```

**Lambda Function**: Handles credential rotation automatically every 90 days.

---

## Monitoring Rotation Health

### Alerts for Expiring Credentials

**Prometheus Alert**:

```yaml
- alert: APIKeyExpiringSoon
  expr: (litellm_api_key_expiry_timestamp - time()) < 86400 * 7 # <7 days
  labels:
    severity: warning
  annotations:
    summary: "API key expiring in {{ $value | humanizeDuration }}"
```

### Certificate Expiration Monitoring

```bash
# Check certificate expiration
openssl x509 -in /etc/litellm/ssl/cert.pem -noout -checkend 604800

# Exit code 0: Valid for >7 days
# Exit code 1: Expires within 7 days
```

**Alert**:

```yaml
- alert: TLSCertificateExpiringSoon
  expr: (ssl_certificate_expiry_timestamp{job="litellm"} - time()) < 86400 * 30 # <30 days
  labels:
    severity: warning
  annotations:
    summary: "TLS certificate expires in {{ $value | humanizeDuration }}"
```

---

## Rollback Procedures

### Emergency Rollback

If new credentials cause issues:

#### Step 1: Restore Old Credentials

```yaml
# Restore previous config from backup
cp /etc/litellm/config.yaml.backup /etc/litellm/config.yaml
```

#### Step 2: Restart Gateway

```bash
systemctl restart litellm
```

#### Step 3: Verify Restoration

```bash
# Check logs
journalctl -u litellm -n 100 --no-pager

# Test requests
curl http://localhost:4000/health/readiness
```

---

## Best Practices

1. **Rotate regularly**: Set calendar reminders for 90-day rotation
2. **Automate when possible**: Use Vault or Secrets Manager
3. **Test in staging first**: Verify rotation process before production
4. **Monitor during rotation**: Watch for auth failures
5. **Keep overlap period**: Support both old and new credentials for 24-48h
6. **Document procedures**: Keep runbook updated
7. **Alert on expiration**: Set alerts for 30/7 days before expiry
8. **Audit rotation events**: Log all credential changes

---

## Rotation Checklist

- [ ] Generate new credentials
- [ ] Store securely (Vault/Secrets Manager)
- [ ] Update configuration (dual credentials if possible)
- [ ] Reload/restart gateway
- [ ] Verify new credentials work
- [ ] Monitor for errors (24-48h)
- [ ] Remove old credentials
- [ ] Revoke old credentials from provider
- [ ] Update documentation/runbook
- [ ] Schedule next rotation (calendar)

---

## Troubleshooting

### Issue: Authentication Failures After Rotation

**Symptoms**: 401 Unauthorized errors

**Solutions**:

1. Verify new credentials are valid (test with curl)
2. Check environment variables are updated
3. Ensure gateway reloaded/restarted
4. Check for typos in API keys
5. Rollback if necessary

### Issue: Mixed Old/New Credentials

**Symptoms**: Intermittent auth failures

**Solutions**:

1. Ensure all instances updated (distributed deployment)
2. Check configuration management synced
3. Verify no cached old credentials

---

## Related Documentation

- [Security Best Practices](security-best-practices.md)
- [Configuration Reference](configuration-reference.md)
- [Troubleshooting Guide](troubleshooting-guide.md)

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
