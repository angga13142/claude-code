# Corporate Proxy Authentication Methods

**Purpose**: Comprehensive guide to authentication methods for corporate HTTP/HTTPS proxies when using Claude Code with LLM gateways

**Audience**: DevOps engineers, platform engineers, developers in enterprise environments

**Context**: Corporate networks often require authenticated proxies for outbound traffic. This guide covers all authentication methods supported by Claude Code, LiteLLM, and common HTTP libraries.

---

## Quick Reference

| Method                | Security     | Ease of Use | Production Ready | Use Case                   |
| --------------------- | ------------ | ----------- | ---------------- | -------------------------- |
| Inline Credentials    | ⚠️ Low       | ✅ High     | ❌ No            | Development/testing only   |
| .netrc File           | ⚠️ Medium    | ✅ High     | ⚠️ Limited       | Single-user workstations   |
| Environment Variables | ✅ Medium    | ✅ High     | ✅ Yes           | CI/CD, containers          |
| Secret Manager        | ✅ High      | ⚠️ Medium   | ✅ Yes           | Production (recommended)   |
| Certificate-Based     | ✅ Very High | ❌ Low      | ✅ Yes           | High-security environments |

---

## Method 1: Inline Credentials in Proxy URL

### Description

Embed username and password directly in the `HTTPS_PROXY` environment variable.

### Configuration

```bash
# Format: http://username:password@proxy.company.com:port
export HTTPS_PROXY="http://jsmith:P@ssw0rd123@proxy.company.com:8080"
export HTTP_PROXY="http://jsmith:P@ssw0rd123@proxy.company.com:8080"
```

### Special Character Handling

If username or password contains special characters, URL-encode them:

```bash
# Original: user@domain.com / P@ssw0rd!
# Encoded: user%40domain.com / P%40ssw0rd%21
export HTTPS_PROXY="http://user%40domain.com:P%40ssw0rd%21@proxy.company.com:8080"
```

Common URL encodings:

- `@` → `%40`
- `:` → `%3A`
- `/` → `%2F`
- `?` → `%3F`
- `#` → `%23`
- `&` → `%26`
- `=` → `%3D`
- `+` → `%2B`
- `%` → `%25`
- Space → `%20`

### Verification

```bash
# Test proxy authentication
curl -x "$HTTPS_PROXY" https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'

# Should return 200 OK with Claude response
```

### Security Considerations

**🔴 CRITICAL RISKS**:

- Credentials visible in process list (`ps aux | grep PROXY`)
- Stored in shell history (`history | grep HTTPS_PROXY`)
- Logged by applications and monitoring tools
- Visible in error messages and stack traces

**Use Only For**:

- Local development
- Temporary testing
- Disposable credentials

**Never Use For**:

- Production environments
- Shared systems
- CI/CD pipelines
- Any credentials with significant privileges

---

## Method 2: .netrc File (Machine Authentication)

### Description

Store proxy credentials in `~/.netrc` file, which is respected by curl, wget, Python requests, and other HTTP libraries.

### Configuration

1. Create `~/.netrc` file:

```bash
cat > ~/.netrc << 'EOF'
machine proxy.company.com
login jsmith
password P@ssw0rd123
EOF
```

2. Set restrictive permissions (required):

```bash
chmod 600 ~/.netrc
```

3. Configure proxy WITHOUT credentials:

```bash
export HTTPS_PROXY="http://proxy.company.com:8080"
export HTTP_PROXY="http://proxy.company.com:8080"
```

### Multi-Proxy Configuration

If you have multiple proxies or need different credentials per domain:

```bash
cat > ~/.netrc << 'EOF'
# Production proxy
machine proxy.company.com
login jsmith-prod
password ProductionPass123

# Development proxy
machine proxy-dev.company.com
login jsmith-dev
password DevPass456

# External API proxy
machine external-proxy.company.com
login api-user
password ApiPass789
EOF
```

### Verification

```bash
# Test with curl (should use .netrc automatically)
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

### Compatibility

**Works With**:

- curl
- wget
- Python requests library
- Git (for HTTPS repositories)
- Many HTTP clients that use libcurl

**Limitations**:

- Not all HTTP libraries respect .netrc
- Java applications typically don't read .netrc
- Some Node.js libraries require explicit configuration
- LiteLLM Python SDK should respect it (uses requests/httpx)

### Security Considerations

**Pros**:

- Credentials not visible in process list
- Not stored in shell history
- Centralized credential storage

**Cons**:

- Plaintext file (anyone with file access can read)
- File permissions can be accidentally changed
- Not suitable for shared systems
- No credential rotation automation

**Best Practices**:

- Use only on single-user workstations
- Regularly verify `chmod 600 ~/.netrc` permissions
- Exclude from backups: add to `~/.gitignore` if home directory is in git
- Rotate credentials quarterly

---

## Method 3: Environment Variables from Secret Manager

### Description

Retrieve proxy credentials from secret manager (AWS Secrets Manager, Google Secret Manager, HashiCorp Vault) at runtime.

### AWS Secrets Manager

```bash
#!/bin/bash
# Retrieve proxy credentials from AWS Secrets Manager

# Install AWS CLI if needed: pip install awscli

# Retrieve secret (JSON format: {"username":"jsmith","password":"P@ssw0rd123"})
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id prod/proxy/credentials \
  --query SecretString \
  --output text)

# Parse JSON and construct proxy URL
PROXY_USERNAME=$(echo "$SECRET" | jq -r .username)
PROXY_PASSWORD=$(echo "$SECRET" | jq -r .password)

# URL-encode if needed (or use jq's @uri filter)
export HTTPS_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@proxy.company.com:8080"
export HTTP_PROXY="$HTTPS_PROXY"

# Start LiteLLM with proxy credentials
litellm --config /path/to/config.yaml
```

### Google Secret Manager

```bash
#!/bin/bash
# Retrieve proxy credentials from Google Secret Manager

# Install gcloud CLI if needed: https://cloud.google.com/sdk/docs/install

# Retrieve secret (JSON format)
SECRET=$(gcloud secrets versions access latest \
  --secret="proxy-credentials" \
  --project="my-project")

# Parse and export
PROXY_USERNAME=$(echo "$SECRET" | jq -r .username)
PROXY_PASSWORD=$(echo "$SECRET" | jq -r .password)

export HTTPS_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@proxy.company.com:8080"
export HTTP_PROXY="$HTTPS_PROXY"

# Start application
claude /status
```

### HashiCorp Vault

```bash
#!/bin/bash
# Retrieve proxy credentials from HashiCorp Vault

# Install Vault CLI: https://www.vaultproject.io/downloads

# Authenticate (use appropriate auth method)
vault login -method=token token="$VAULT_TOKEN"

# Retrieve secret
SECRET=$(vault kv get -format=json secret/proxy | jq -r .data.data)

PROXY_USERNAME=$(echo "$SECRET" | jq -r .username)
PROXY_PASSWORD=$(echo "$SECRET" | jq -r .password)

export HTTPS_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@proxy.company.com:8080"
export HTTP_PROXY="$HTTPS_PROXY"

# Start application
litellm --config /path/to/config.yaml
```

### Docker/Kubernetes Integration

**Dockerfile**:

```dockerfile
FROM python:3.11-slim

# Install dependencies
RUN pip install litellm awscli

# Copy application
COPY config.yaml /app/config.yaml
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

WORKDIR /app

# Start script retrieves secrets and launches LiteLLM
CMD ["/app/start.sh"]
```

**start.sh**:

```bash
#!/bin/bash
set -e

# Retrieve proxy credentials
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$PROXY_SECRET_ARN" \
  --query SecretString \
  --output text)

PROXY_USERNAME=$(echo "$SECRET" | jq -r .username)
PROXY_PASSWORD=$(echo "$SECRET" | jq -r .password)

export HTTPS_PROXY="http://${PROXY_USERNAME}:${PROXY_PASSWORD}@${PROXY_HOST}:${PROXY_PORT}"
export HTTP_PROXY="$HTTPS_PROXY"

# Start LiteLLM
exec litellm --config /app/config.yaml --port 4000
```

**Kubernetes Deployment**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm-proxy
spec:
  template:
    spec:
      serviceAccountName: litellm-sa # Must have IAM role for secret access
      containers:
        - name: litellm
          image: my-registry/litellm:latest
          env:
            - name: PROXY_SECRET_ARN
              value: "arn:aws:secretsmanager:us-east-1:123456789012:secret:proxy-creds"
            - name: PROXY_HOST
              value: "proxy.company.com"
            - name: PROXY_PORT
              value: "8080"
            # Provider credentials also from secrets
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: anthropic-creds
                  key: api-key
```

### Security Considerations

**Pros**:

- Credentials never stored on disk
- Automatic rotation supported
- Audit logging of access
- Fine-grained access control (IAM policies)
- Secrets encrypted at rest and in transit

**Cons**:

- Requires secret manager service and permissions
- More complex setup
- Network dependency (secret manager must be reachable)
- Cost (secret manager pricing)

**Best Practices**:

- Use separate secrets for dev/staging/prod
- Enable automatic rotation (e.g., 90-day rotation)
- Monitor secret access logs for anomalies
- Use least-privilege IAM policies
- Implement secret caching to reduce API calls
- Have fallback mechanism if secret manager is unavailable

---

## Method 4: Certificate-Based Authentication (Mutual TLS)

### Description

Use client certificates for proxy authentication instead of username/password. Highest security level.

### Configuration

1. Obtain client certificate from IT department:

   - Client certificate: `client.crt`
   - Private key: `client.key`
   - CA certificate: `ca.crt`

2. Configure proxy to use certificates:

```bash
# For curl
export HTTPS_PROXY="https://proxy.company.com:8443"  # Note HTTPS scheme
curl --proxy-cacert ca.crt \
     --proxy-cert client.crt \
     --proxy-key client.key \
     https://api.anthropic.com/v1/messages
```

3. For Python/LiteLLM (using environment variables):

```python
import os
import httpx

# Configure HTTPX (used by LiteLLM) to use client certificate
os.environ['HTTPX_VERIFY'] = '/path/to/ca.crt'
os.environ['HTTPX_CERT'] = '/path/to/client.crt'
os.environ['HTTPX_KEY'] = '/path/to/client.key'
os.environ['HTTPS_PROXY'] = 'https://proxy.company.com:8443'

# Start LiteLLM (will use above environment variables)
```

4. System-wide certificate configuration (Linux):

```bash
# Copy certificates to system location
sudo cp client.crt /etc/pki/tls/certs/
sudo cp client.key /etc/pki/tls/private/
sudo chmod 600 /etc/pki/tls/private/client.key

# Update system proxy configuration
export HTTPS_PROXY="https://proxy.company.com:8443"
export CURL_CA_BUNDLE="/etc/pki/tls/certs/ca.crt"
```

### Security Considerations

**Pros**:

- No passwords to manage or rotate
- Certificate revocation support
- Strong cryptographic authentication
- Audit trail (certificate serial number in logs)
- Supports hardware security modules (HSMs)

**Cons**:

- Complex setup and certificate management
- Requires PKI infrastructure
- Certificate expiration monitoring needed
- Private key must be protected (same as passwords)

**Best Practices**:

- Store private keys with 600 permissions (readable only by owner)
- Use hardware security modules (HSMs) for key storage in production
- Monitor certificate expiration (alert 30 days before)
- Implement automatic certificate renewal
- Use separate certificates for different environments
- Never commit certificates/keys to version control
- Rotate certificates annually or per policy

---

## Method 5: NTLM/Kerberos Authentication (Windows)

### Description

Windows-native authentication protocols for corporate proxies in Active Directory environments.

### NTLM Configuration

```bash
# Install cntlm (NTLM proxy authenticator)
# macOS: brew install cntlm
# Ubuntu: sudo apt-get install cntlm

# Configure cntlm
cat > ~/.cntlm.conf << EOF
Username    jsmith
Domain      COMPANY
Password    P@ssw0rd123
Proxy       proxy.company.com:8080
Listen      3128
EOF

# Secure configuration file
chmod 600 ~/.cntlm.conf

# Start cntlm proxy (runs on localhost:3128)
cntlm -c ~/.cntlm.conf

# Configure applications to use local cntlm proxy
export HTTPS_PROXY="http://localhost:3128"
export HTTP_PROXY="http://localhost:3128"

# Test
curl https://api.anthropic.com
```

### Kerberos Configuration

```bash
# Install krb5 tools
# Ubuntu: sudo apt-get install krb5-user
# macOS: kinit (built-in)

# Obtain Kerberos ticket
kinit jsmith@COMPANY.COM

# Verify ticket
klist

# Configure proxy (some proxies support SPNEGO/Negotiate)
export HTTPS_PROXY="http://proxy.company.com:8080"

# Proxy should accept Kerberos authentication automatically
curl https://api.anthropic.com
```

### Security Considerations

**Pros**:

- Integrates with Windows Active Directory
- Single Sign-On (SSO) support
- Password never sent over network
- Automatic ticket renewal

**Cons**:

- Windows-specific (limited cross-platform support)
- Requires Active Directory infrastructure
- cntlm stores password in config file (plaintext)
- Kerberos tickets expire (need renewal)

**Best Practices**:

- Use Kerberos over NTLM when possible (more secure)
- Secure cntlm configuration file (chmod 600)
- Monitor Kerberos ticket expiration
- Use keytabs for automated systems (no password needed)
- Implement ticket auto-renewal in long-running services

---

## Troubleshooting

### Issue: 407 Proxy Authentication Required

**Symptoms**:

```
HTTP/1.1 407 Proxy Authentication Required
Proxy-Authenticate: Basic realm="Corporate Proxy"
```

**Solutions**:

1. Verify username/password are correct
2. Check for special characters needing URL encoding
3. Confirm .netrc file has correct permissions (600)
4. Test with curl explicitly: `curl -v -x $HTTPS_PROXY https://google.com`
5. Check proxy logs for authentication failures

### Issue: Authentication works with curl but not Claude Code

**Cause**: Different HTTP libraries may handle proxy auth differently

**Solutions**:

1. Verify HTTPS_PROXY is exported in shell where Claude Code runs:

   ```bash
   echo $HTTPS_PROXY  # Should show proxy URL with credentials
   ```

2. Test Python requests library (used by LiteLLM):

   ```python
   import os
   import requests

   os.environ['HTTPS_PROXY'] = 'http://user:pass@proxy:8080'
   response = requests.get('https://api.anthropic.com/v1/messages',
                          headers={'x-api-key': os.environ['ANTHROPIC_API_KEY']})
   print(response.status_code)  # Should be 200 or 401 (not 407)
   ```

3. Enable debug logging:
   ```bash
   export ANTHROPIC_LOG=debug
   export LITELLM_LOG=DEBUG
   claude /status
   ```

### Issue: Credentials with special characters fail

**Cause**: Unescaped special characters in proxy URL

**Solution**: URL-encode special characters

```bash
# Python helper
python3 << EOF
from urllib.parse import quote
username = "user@domain.com"
password = "P@ssw0rd!"
print(f"http://{quote(username)}:{quote(password)}@proxy:8080")
EOF
```

### Issue: .netrc not working

**Causes**:

1. File permissions too open (must be 600)
2. HTTP library doesn't support .netrc
3. Proxy hostname doesn't match machine name in .netrc

**Solutions**:

```bash
# Fix permissions
chmod 600 ~/.netrc

# Verify format (must be exact)
cat ~/.netrc
# Should show:
# machine proxy.company.com
# login username
# password pass

# Test with curl (should work)
curl -v --netrc https://api.anthropic.com
```

---

## Comparison Matrix

| Feature          | Inline    | .netrc     | Secret Manager | Certificate  | NTLM/Kerberos  |
| ---------------- | --------- | ---------- | -------------- | ------------ | -------------- |
| Setup Complexity | ⭐        | ⭐⭐       | ⭐⭐⭐⭐       | ⭐⭐⭐⭐⭐   | ⭐⭐⭐         |
| Security Level   | ⚠️ Low    | ⚠️ Medium  | ✅ High        | ✅ Very High | ✅ High        |
| Rotation Ease    | ❌ Manual | ❌ Manual  | ✅ Automated   | ⚠️ Semi-Auto | ✅ Auto (Kerb) |
| Multi-User       | ❌ No     | ⚠️ Limited | ✅ Yes         | ✅ Yes       | ✅ Yes         |
| Audit Trail      | ❌ No     | ❌ No      | ✅ Yes         | ✅ Yes       | ✅ Yes         |
| Cost             | Free      | Free       | 💰 Paid        | Free         | Free           |
| Cross-Platform   | ✅ Yes    | ✅ Yes     | ✅ Yes         | ✅ Yes       | ⚠️ Windows     |

---

## Recommendations by Environment

### Development (Local Workstation)

**Recommended**: Inline credentials or .netrc

- Quick setup
- Low security risk (disposable dev credentials)
- Easy troubleshooting

### CI/CD Pipelines

**Recommended**: Secret Manager

- Automated credential retrieval
- No credentials in code/config
- Audit logging
- Works across different CI platforms

### Production (Kubernetes/Docker)

**Recommended**: Secret Manager + Certificate-based (if available)

- Highest security
- Automated rotation
- Integration with secret management platforms
- Compliance requirements met

### Windows Enterprise

**Recommended**: NTLM/Kerberos with fallback to certificate-based

- Native Windows integration
- Single Sign-On support
- Active Directory management

---

## Next Steps

1. **Identify Your Proxy Type**: Contact IT to determine authentication method (Basic, NTLM, Kerberos, Certificate)

2. **Get Credentials**: Obtain username/password, certificate, or confirm Active Directory integration

3. **Choose Method**: Based on environment and security requirements (see Recommendations above)

4. **Test Connectivity**: Use curl/wget to verify proxy authentication before configuring Claude Code

5. **Configure Claude Code**: Set HTTPS_PROXY and provider credentials

6. **Verify**: Run `claude /status` to confirm end-to-end connectivity

## Related Documentation

- `proxy-only-config.yaml` - Proxy-only deployment pattern examples
- `proxy-gateway-config.yaml` - Combined proxy + gateway configuration
- `examples/us4-corporate-proxy-setup.md` - Step-by-step setup guide
- `examples/us4-https-proxy-config.md` - HTTPS_PROXY detailed configuration
- `examples/us4-proxy-troubleshooting.md` - Common issues and solutions
