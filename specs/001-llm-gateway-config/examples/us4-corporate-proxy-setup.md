# Corporate Proxy Setup Guide - Claude Code with LLM Gateway

**Time Estimate**: 15-20 minutes  
**Difficulty**: Intermediate  
**Prerequisites**: Network access, proxy credentials (if required), basic CLI knowledge

## Overview

This guide helps developers behind corporate firewalls configure Claude Code to route requests through a corporate HTTP/HTTPS proxy while using an LLM gateway.

**Architecture**:

```
Claude Code → Corporate Proxy → LLM Gateway (LiteLLM) → Provider APIs
```

**Use Cases**:

- Corporate networks with mandatory proxy
- Air-gapped environments with controlled internet access
- Compliance requirements for network monitoring
- MITM inspection for security scanning

## Prerequisites

Before starting, gather:

1. **Proxy Information**:

   - Proxy URL (e.g., `proxy.corp.example.com:8080`)
   - Proxy protocol (HTTP/HTTPS/SOCKS5)
   - Authentication method (none, basic, NTLM, Kerberos)
   - Proxy credentials (username/password if required)

2. **Network Access**:

   - Can reach corporate proxy from your machine
   - Proxy allows outbound HTTPS to provider APIs
   - Firewall rules permit gateway traffic

3. **Certificates** (if applicable):

   - Corporate CA certificate bundle
   - Self-signed certificate for proxy

4. **LLM Gateway**:
   - Gateway URL (local or internal server)
   - Gateway authentication token (if required)

## Step 1: Verify Proxy Connectivity (5 minutes)

### 1.1 Test Proxy Connection

```bash
# Test basic connectivity
curl -x http://proxy.corp.example.com:8080 https://httpbin.org/ip

# Expected: Returns your external IP (proxied)
```

### 1.2 Test with Authentication (if required)

```bash
# With username and password
curl -x http://username:password@proxy.corp.example.com:8080 https://httpbin.org/ip

# If password contains special characters, URL-encode them:
# @ → %40
# : → %3A
# / → %2F
# Example: pass@word:123 → pass%40word%3A123
```

### 1.3 Test HTTPS through Proxy

```bash
# Test API access
curl -x http://proxy.corp.example.com:8080 https://api.anthropic.com

# Expected: Connection successful (may return 401 without API key)
```

**Troubleshooting**:

- **"Connection refused"**: Check proxy URL and port
- **"407 Proxy Authentication Required"**: Add credentials to proxy URL
- **"SSL certificate verify failed"**: Install corporate CA certificate (see Step 2)

## Step 2: Install Corporate CA Certificate (if needed)

If your proxy uses self-signed certificates or performs SSL inspection:

### 2.1 Obtain CA Certificate

Ask your IT department for the corporate CA certificate bundle. Common names:

- `corporate-ca-bundle.crt`
- `ca-certificates.crt`
- `corp-root-ca.pem`

### 2.2 Install CA Certificate

**Linux/macOS**:

```bash
# Copy to system certificate directory
sudo cp corporate-ca-bundle.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates  # Linux
# or
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain corporate-ca-bundle.crt  # macOS
```

**Environment Variables** (alternative):

```bash
# For Python/requests library
export REQUESTS_CA_BUNDLE=/path/to/corporate-ca-bundle.crt

# For curl
export CURL_CA_BUNDLE=/path/to/corporate-ca-bundle.crt

# For Node.js
export NODE_EXTRA_CA_CERTS=/path/to/corporate-ca-bundle.crt

# General SSL
export SSL_CERT_FILE=/path/to/corporate-ca-bundle.crt
```

### 2.3 Verify Certificate Installation

```bash
# Test HTTPS through proxy with custom CA
curl --cacert /path/to/corporate-ca-bundle.crt \\
     -x http://proxy.corp.example.com:8080 \\
     https://api.anthropic.com

# Should succeed without SSL errors
```

## Step 3: Configure Proxy Environment Variables (2 minutes)

### 3.1 Set System-Wide Proxy

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`):

```bash
# HTTP/HTTPS proxy
export HTTP_PROXY="http://proxy.corp.example.com:8080"
export HTTPS_PROXY="http://proxy.corp.example.com:8080"

# With authentication
export HTTP_PROXY="http://username:password@proxy.corp.example.com:8080"
export HTTPS_PROXY="http://username:password@proxy.corp.example.com:8080"

# Bypass proxy for local/internal hosts
export NO_PROXY="localhost,127.0.0.1,.internal,.corp,.local"

# CA certificate (if needed)
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
export REQUESTS_CA_BUNDLE="/path/to/corporate-ca-bundle.crt"
```

### 3.2 Apply Configuration

```bash
# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc

# Verify variables are set
echo $HTTPS_PROXY
echo $NO_PROXY
```

### 3.3 Test Proxy Configuration

```bash
# Should work automatically now
curl https://httpbin.org/ip

# Test provider API
curl https://api.anthropic.com
```

## Step 4: Configure LiteLLM Gateway (5 minutes)

### 4.1 Copy Configuration Template

```bash
# Copy template
cp templates/proxy/proxy-gateway-config.yaml config/litellm-proxy.yaml

# Or for proxy-only (no gateway)
cp templates/proxy/proxy-only-config.yaml config/litellm-direct.yaml
```

### 4.2 Set Provider Credentials

```bash
# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# AWS Bedrock (if using)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"

# Google Vertex AI (if using)
export VERTEX_PROJECT_ID="your-project-id"
export VERTEX_LOCATION="us-central1"
# Run: gcloud auth application-default login
```

### 4.3 Start LiteLLM Gateway

```bash
# Gateway will automatically use HTTPS_PROXY environment variable
litellm --config config/litellm-proxy.yaml --port 4000

# Verify startup
# Expected log: "Proxy running on http://0.0.0.0:4000"
```

### 4.4 Test Gateway Health

```bash
# Should work without proxy (local)
curl http://localhost:4000/health

# Expected: {"status": "healthy"}
```

## Step 5: Configure Claude Code (3 minutes)

### 5.1 Set Gateway URL

```bash
# Point Claude Code to local gateway
export ANTHROPIC_BASE_URL="http://localhost:4000"

# Use dummy API key (gateway handles auth)
export ANTHROPIC_API_KEY="sk-local-gateway"

# Proxy settings (already set in Step 3)
# Claude Code will automatically use HTTPS_PROXY for external calls
```

### 5.2 Add to Shell Profile

```bash
# Add to ~/.bashrc or ~/.zshrc
cat >> ~/.bashrc << 'EOF'

# Claude Code with LiteLLM Gateway + Corporate Proxy
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1"
EOF

source ~/.bashrc
```

### 5.3 Verify Claude Code Configuration

```bash
# Check status
claude /status

# Expected output should show:
# - Gateway URL: http://localhost:4000
# - Connection: OK
# - Models: [list of available models]
```

## Step 6: Test End-to-End Flow (5 minutes)

### 6.1 Run Basic Test

```bash
# Simple command
claude "What is 2+2?"

# Expected: Claude responds correctly
```

### 6.2 Run Comprehensive Tests

```bash
# Run proxy integration tests
python tests/test-proxy-gateway.py

# Run proxy bypass tests
bash tests/test-proxy-bypass.sh
```

### 6.3 Test Multiple Providers (if configured)

```bash
# Test Anthropic
claude --model claude-3-5-sonnet-20241022 "Hello"

# Test Bedrock (if configured)
claude --model bedrock-claude-sonnet "Hello"

# Test Vertex AI (if configured)
claude --model gemini-2.0-flash "Hello"
```

## Step 7: Verification Checklist

- [ ] Proxy connection successful (`curl -x $HTTPS_PROXY https://httpbin.org/ip`)
- [ ] CA certificate installed (if required)
- [ ] HTTPS_PROXY, NO_PROXY environment variables set
- [ ] LiteLLM gateway starts without errors
- [ ] Gateway health check returns OK (`curl http://localhost:4000/health`)
- [ ] Claude Code connects to gateway (`claude /status`)
- [ ] Basic command works (`claude "test"`)
- [ ] Test scripts pass (`python tests/test-proxy-gateway.py`)

## Common Issues & Solutions

### Issue 1: "Connection refused" to proxy

**Symptoms**: Cannot reach proxy server

**Solutions**:

1. Verify proxy URL: `ping proxy.corp.example.com`
2. Check port is correct (usually 8080 or 3128)
3. Confirm you're on corporate network (VPN connected)
4. Test with curl: `curl -x http://proxy:8080 https://httpbin.org/ip`

### Issue 2: "407 Proxy Authentication Required"

**Symptoms**: Proxy requires credentials

**Solutions**:

1. Add credentials to proxy URL: `http://user:pass@proxy:8080`
2. URL-encode special characters in password
3. Check if NTLM/Kerberos authentication required (use tools like `cntlm`)
4. Verify credentials: `curl -x http://user:pass@proxy:8080 https://httpbin.org/ip`

### Issue 3: "SSL certificate verify failed"

**Symptoms**: HTTPS connections fail with SSL errors

**Solutions**:

1. Install corporate CA certificate (see Step 2)
2. Set SSL_CERT_FILE environment variable
3. Verify certificate: `openssl s_client -connect api.anthropic.com:443 -CAfile /path/to/ca-bundle.crt`
4. Last resort (NOT RECOMMENDED): `export PYTHONHTTPSVERIFY=0` (security risk)

### Issue 4: Gateway timeout errors

**Symptoms**: Requests timeout through proxy

**Solutions**:

1. Increase timeout in `litellm-proxy.yaml`: `request_timeout: 600`
2. Check proxy latency: `time curl -x $HTTPS_PROXY https://api.anthropic.com`
3. Add retry configuration: `num_retries: 3`
4. Verify no rate limiting on proxy

### Issue 5: Gateway bypasses proxy (goes direct)

**Symptoms**: Requests don't go through proxy

**Solutions**:

1. Verify HTTPS_PROXY is set: `echo $HTTPS_PROXY`
2. Check NO_PROXY doesn't include provider domains
3. Unset http_proxy/https_proxy (lowercase): `unset http_proxy https_proxy`
4. Test: `curl -v https://api.anthropic.com` (should show "Using proxy")

For more troubleshooting, see: `examples/us4-proxy-troubleshooting.md`

## Security Best Practices

1. **Credential Management**:

   - Store proxy credentials in secrets manager (e.g., 1Password, LastPass)
   - Use environment variables, not hardcoded in files
   - Rotate credentials regularly

2. **Certificate Validation**:

   - Always install proper CA certificates
   - Never disable SSL verification in production
   - Keep certificates up to date

3. **Network Monitoring**:

   - Understand that proxy logs all traffic
   - API requests/responses visible to network admins
   - Use encryption where possible

4. **Access Control**:
   - Use least-privilege proxy accounts
   - Monitor for suspicious access patterns
   - Follow corporate security policies

## Next Steps

1. **Optimize Performance**: See `examples/us3-cost-optimization.md`
2. **Add More Providers**: See `examples/us3-multi-provider-setup.md`
3. **Enterprise Integration**: See `examples/us2-enterprise-integration.md`
4. **Advanced Proxy Config**: See `templates/proxy/proxy-auth.md`

## Additional Resources

- **Proxy Troubleshooting**: `examples/us4-proxy-troubleshooting.md`
- **HTTPS_PROXY Configuration**: `examples/us4-https-proxy-config.md`
- **Architecture Diagram**: `examples/us4-proxy-gateway-architecture.md`
- **Firewall Considerations**: `examples/us4-firewall-considerations.md`
- **Validation Scripts**: `scripts/check-proxy-connectivity.sh`, `tests/test-proxy-gateway.py`

## Support

If you encounter issues:

1. Check troubleshooting guide: `examples/us4-proxy-troubleshooting.md`
2. Run diagnostic script: `bash scripts/check-proxy-connectivity.sh`
3. Verify configuration: `python scripts/validate-proxy-auth.py`
4. Review logs: Check LiteLLM proxy logs for detailed errors

---

**Estimated Setup Time**: 15-20 minutes  
**Success Criteria**: Claude Code successfully routes through proxy to gateway to provider APIs
