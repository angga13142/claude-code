# Corporate Proxy Troubleshooting Guide

**Purpose**: Comprehensive troubleshooting guide for Claude Code + LiteLLM Gateway + Corporate Proxy integration.

## Quick Diagnostic Flow

```
START
  │
  ├─ Can ping proxy? ──NO──> Check network/VPN connection
  │   │
  │   YES
  │   ↓
  ├─ Proxy returns 407? ──YES──> Check proxy credentials
  │   │
  │   NO
  │   ↓
  ├─ SSL certificate error? ──YES──> Install corporate CA certificate
  │   │
  │   NO
  │   ↓
  ├─ Gateway responds? ──NO──> Start LiteLLM gateway
  │   │
  │   YES
  │   ↓
  ├─ Provider API works? ──NO──> Check API keys/network
  │   │
  │   YES
  │   ↓
  SUCCESS - System working
```

## Common Issues & Solutions

### Issue 1: "Connection refused" to Proxy

**Symptoms**:

```
curl: (7) Failed to connect to proxy.corp.example.com port 8080: Connection refused
```

**Root Causes**:

1. Proxy server is down
2. Wrong proxy URL/port
3. Not connected to corporate network/VPN
4. Firewall blocking connection

**Solutions**:

**Step 1**: Verify proxy is reachable

```bash
# Test network connectivity
ping proxy.corp.example.com

# Test port is open
telnet proxy.corp.example.com 8080
# or
nc -zv proxy.corp.example.com 8080
```

**Step 2**: Check proxy URL

```bash
# Verify environment variable
echo $HTTPS_PROXY
# Expected: http://proxy.corp.example.com:8080

# Common ports: 8080, 3128, 8888, 80
```

**Step 3**: Verify VPN connection

```bash
# Check if on corporate network
ip addr show | grep "inet "
# Look for internal IP (e.g., 10.x.x.x, 192.168.x.x)

# Test VPN connectivity
ping internal-server.corp
```

**Step 4**: Check firewall rules

```bash
# Linux: Check iptables
sudo iptables -L -n | grep 8080

# macOS: Check firewall
sudo pfctl -s rules | grep 8080
```

---

### Issue 2: "407 Proxy Authentication Required"

**Symptoms**:

```
HTTP/1.1 407 Proxy Authentication Required
Proxy-Authenticate: Basic realm="Corporate Proxy"
```

**Root Causes**:

1. Missing proxy credentials
2. Wrong username/password
3. Special characters not URL-encoded
4. Authentication method mismatch (NTLM, Kerberos)

**Solutions**:

**Step 1**: Add credentials to proxy URL

```bash
# Basic format
export HTTPS_PROXY="http://username:password@proxy.corp.example.com:8080"

# Test
curl -x $HTTPS_PROXY https://httpbin.org/ip
```

**Step 2**: URL-encode special characters

```bash
# If password contains @ : / # ? & = + or space
python3 -c "import urllib.parse; print(urllib.parse.quote('p@ss:w/rd!', safe=''))"
# Output: p%40ss%3Aw%2Frd%21

export HTTPS_PROXY="http://username:p%40ss%3Aw%2Frd%21@proxy:8080"
```

**Step 3**: Handle domain usernames

```bash
# Windows domain authentication
export HTTPS_PROXY="http://DOMAIN%5Cusername:password@proxy:8080"
# %5C is encoded backslash for DOMAIN\username

# Alternative format
export HTTPS_PROXY="http://username%40domain.com:password@proxy:8080"
# For username@domain.com format
```

**Step 4**: Use authentication helper for NTLM/Kerberos

```bash
# Install cntlm (for NTLM authentication)
sudo apt-get install cntlm  # Linux
brew install cntlm           # macOS

# Configure /etc/cntlm.conf
Username    DOMAIN\username
Domain      CORP
Password    your-password
Proxy       proxy.corp.example.com:8080
Listen      3128

# Start cntlm
sudo service cntlm start

# Use local cntlm proxy
export HTTPS_PROXY="http://localhost:3128"
```

---

### Issue 3: "SSL certificate verify failed"

**Symptoms**:

```
SSLCertVerificationError: [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate
```

**Root Causes**:

1. Corporate proxy uses self-signed certificate
2. Proxy performs SSL inspection (MITM)
3. Missing corporate CA certificate
4. Incorrect CA bundle path

**Solutions**:

**Step 1**: Obtain corporate CA certificate

```bash
# Contact IT department for certificate
# Common filenames:
# - corporate-ca-bundle.crt
# - ca-certificates.crt
# - corp-root-ca.pem
```

**Step 2**: Install system-wide (recommended)

```bash
# Linux (Debian/Ubuntu)
sudo cp corporate-ca-bundle.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Linux (RHEL/CentOS)
sudo cp corporate-ca-bundle.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# macOS
sudo security add-trusted-cert -d -r trustRoot \\
     -k /Library/Keychains/System.keychain \\
     corporate-ca-bundle.crt
```

**Step 3**: Set environment variables (per-user)

```bash
# For Python/requests
export REQUESTS_CA_BUNDLE="/path/to/corporate-ca-bundle.crt"

# For curl
export CURL_CA_BUNDLE="/path/to/corporate-ca-bundle.crt"

# For Node.js
export NODE_EXTRA_CA_CERTS="/path/to/corporate-ca-bundle.crt"

# General SSL
export SSL_CERT_FILE="/path/to/corporate-ca-bundle.crt"
```

**Step 4**: Verify installation

```bash
# Test with curl
curl --cacert /path/to/corporate-ca-bundle.crt \\
     -x $HTTPS_PROXY \\
     https://api.anthropic.com

# Test certificate chain
openssl s_client -connect api.anthropic.com:443 \\
     -proxy proxy.corp.example.com:8080 \\
     -CAfile /path/to/corporate-ca-bundle.crt
```

**Step 5**: Last resort (NOT RECOMMENDED for production)

```bash
# Disable SSL verification (INSECURE!)
export PYTHONHTTPSVERIFY=0
export NODE_TLS_REJECT_UNAUTHORIZED=0
curl --insecure ...  # -k flag

# ⚠️ WARNING: This exposes you to MITM attacks!
# Only use for testing, never in production
```

---

### Issue 4: Gateway Not Responding

**Symptoms**:

```
curl: (7) Failed to connect to localhost port 4000: Connection refused
```

**Root Causes**:

1. LiteLLM gateway not running
2. Wrong port configuration
3. Gateway crashed
4. Firewall blocking local port

**Solutions**:

**Step 1**: Check if gateway is running

```bash
# Check process
ps aux | grep litellm

# Check port listening
netstat -tuln | grep 4000
# or
lsof -i :4000
# or
ss -tuln | grep 4000
```

**Step 2**: Start gateway

```bash
# Start LiteLLM
litellm --config config/litellm-proxy.yaml --port 4000

# Run in background
nohup litellm --config config/litellm-proxy.yaml --port 4000 > gateway.log 2>&1 &

# Check logs
tail -f gateway.log
```

**Step 3**: Check gateway configuration

```bash
# Verify config file exists
ls -l config/litellm-proxy.yaml

# Validate YAML syntax
python3 scripts/validate-config.py config/litellm-proxy.yaml

# Check for errors in logs
grep -i error gateway.log
```

**Step 4**: Test gateway health

```bash
# Health check
curl http://localhost:4000/health
# Expected: {"status": "healthy"}

# List models
curl http://localhost:4000/models

# Test completion
curl -X POST http://localhost:4000/v1/chat/completions \\
     -H "Content-Type: application/json" \\
     -d '{
       "model": "claude-3-5-sonnet-20241022",
       "messages": [{"role": "user", "content": "test"}],
       "max_tokens": 50
     }'
```

---

### Issue 5: Timeout Errors

**Symptoms**:

```
TimeoutError: Request timeout after 30 seconds
```

**Root Causes**:

1. Proxy latency high
2. Provider API slow
3. Network congestion
4. Rate limiting
5. Timeout configuration too low

**Solutions**:

**Step 1**: Measure latency

```bash
# Test proxy latency
time curl -x $HTTPS_PROXY https://httpbin.org/ip

# Test provider API latency
time curl -x $HTTPS_PROXY \\
     -H "x-api-key: $ANTHROPIC_API_KEY" \\
     https://api.anthropic.com/v1/messages

# Trace route
traceroute -n api.anthropic.com
```

**Step 2**: Increase timeout in gateway config

```yaml
# config/litellm-proxy.yaml
litellm_settings:
  request_timeout: 600 # Increase from 30 to 600 seconds
  num_retries: 3 # Add retries
  retry_after: 10 # Wait 10s between retries
```

**Step 3**: Configure Claude Code timeout

```bash
# Set higher timeout (if supported)
export CLAUDE_CODE_TIMEOUT=600
```

**Step 4**: Check for rate limiting

```bash
# Look for 429 responses in logs
grep "429" gateway.log

# Check provider dashboards for rate limits
# Anthropic: https://console.anthropic.com
# AWS Bedrock: CloudWatch metrics
```

---

### Issue 6: NO_PROXY Not Working

**Symptoms**:

- Local gateway still uses proxy
- Internal URLs routed through proxy
- Bypass patterns not matching

**Root Causes**:

1. Incorrect NO_PROXY pattern
2. Lowercase vs uppercase variable conflict
3. Pattern matching issues
4. Tool doesn't respect NO_PROXY

**Solutions**:

**Step 1**: Check NO_PROXY value

```bash
# Print current value
echo $NO_PROXY
echo $no_proxy

# Unset lowercase (use uppercase)
unset no_proxy http_proxy https_proxy
export HTTPS_PROXY="http://proxy:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"
```

**Step 2**: Fix pattern syntax

```bash
# Correct patterns
export NO_PROXY="localhost,127.0.0.1"        # Exact match
export NO_PROXY="localhost,.internal"         # Domain suffix
export NO_PROXY="localhost,192.168.1.0/24"   # IP range (not all tools)

# Common mistakes
export NO_PROXY="localhost .internal"         # ❌ Space-separated (should be comma)
export NO_PROXY="localhost,*.internal"        # ❌ Wildcard (* not needed)
export NO_PROXY="localhost, 127.0.0.1"       # ❌ Space after comma
```

**Step 3**: Test pattern matching

```bash
# Run bypass test script
bash tests/test-proxy-bypass.sh

# Manual test
python3 << 'EOF'
import os
from urllib.request import proxy_bypass_environment

os.environ['NO_PROXY'] = 'localhost,127.0.0.1,.internal'

print('Bypass localhost:', proxy_bypass_environment('localhost'))
print('Bypass 127.0.0.1:', proxy_bypass_environment('127.0.0.1'))
print('Bypass api.internal:', proxy_bypass_environment('api.internal'))
print('Bypass example.com:', proxy_bypass_environment('example.com'))
EOF
```

**Step 4**: Force direct connection

```bash
# Bypass proxy completely
unset HTTPS_PROXY HTTP_PROXY

# Or use no_proxy wildcard
export NO_PROXY="*"

# curl --noproxy flag
curl --noproxy "*" http://localhost:4000/health
```

---

### Issue 7: API Key Errors

**Symptoms**:

```
401 Unauthorized: Invalid API key
```

**Root Causes**:

1. Wrong API key
2. API key not set
3. API key for wrong provider
4. Key expired or revoked

**Solutions**:

**Step 1**: Verify API key is set

```bash
# Check environment variable
echo $ANTHROPIC_API_KEY
# Should start with: sk-ant-

# AWS Bedrock
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Vertex AI
gcloud auth application-default print-access-token
```

**Step 2**: Test API key directly

```bash
# Test Anthropic key
curl https://api.anthropic.com/v1/messages \\
  -H "Content-Type: application/json" \\
  -H "x-api-key: $ANTHROPIC_API_KEY" \\
  -H "anthropic-version: 2023-06-01" \\
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Hi"}]
  }'

# Should return completion (not 401)
```

**Step 3**: Check key in gateway config

```yaml
# config/litellm-proxy.yaml
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      api_key: os.environ/ANTHROPIC_API_KEY # ✓ Correct
      # api_key: $ANTHROPIC_API_KEY           # ❌ Wrong syntax
      # api_key: sk-ant-hardcoded             # ❌ Insecure
```

**Step 4**: Regenerate key if needed

```bash
# Anthropic: https://console.anthropic.com/settings/keys
# AWS: IAM Console → Users → Security Credentials
# GCP: Cloud Console → IAM → Service Accounts
```

---

## Advanced Troubleshooting

### Enable Debug Logging

**LiteLLM Gateway**:

```yaml
# config/litellm-proxy.yaml
litellm_settings:
  set_verbose: true # Enable debug logs
```

**Python/requests**:

```bash
export PYTHONVERBOSE=1
export REQUESTS_DEBUG=1
```

**curl**:

```bash
curl -v -x $HTTPS_PROXY https://api.anthropic.com
# -v for verbose output
```

### Network Packet Capture

```bash
# Capture traffic on port 8080 (proxy)
sudo tcpdump -i any port 8080 -w proxy-traffic.pcap

# Analyze with Wireshark
wireshark proxy-traffic.pcap
```

### Test Each Layer Independently

**Layer 1: Claude Code → Gateway**

```bash
curl http://localhost:4000/health
```

**Layer 2: Gateway → Proxy**

```bash
# From gateway machine
curl -x $HTTPS_PROXY https://httpbin.org/ip
```

**Layer 3: Proxy → Provider**

```bash
curl -x $HTTPS_PROXY \\
     -H "x-api-key: $ANTHROPIC_API_KEY" \\
     https://api.anthropic.com/v1/messages
```

### Check System Resources

```bash
# CPU usage
top -b -n 1 | head -20

# Memory usage
free -h

# Disk space
df -h

# Network connections
netstat -tunap | grep litellm
```

## Diagnostic Scripts

### Run All Diagnostics

```bash
# Check prerequisites
bash scripts/check-prerequisites.sh

# Test proxy connectivity
bash scripts/check-proxy-connectivity.sh

# Validate proxy authentication
python scripts/validate-proxy-auth.py

# Test gateway integration
python tests/test-proxy-gateway.py

# Test proxy bypass
bash tests/test-proxy-bypass.sh
```

### Generate Diagnostic Report

```bash
#!/bin/bash
echo "=== Diagnostic Report ===" > diagnostic-report.txt
echo "Date: $(date)" >> diagnostic-report.txt
echo "" >> diagnostic-report.txt

echo "Environment Variables:" >> diagnostic-report.txt
env | grep -i proxy >> diagnostic-report.txt
env | grep -i ssl >> diagnostic-report.txt
env | grep -i anthropic >> diagnostic-report.txt

echo "" >> diagnostic-report.txt
echo "Network Connectivity:" >> diagnostic-report.txt
ping -c 3 proxy.corp.example.com >> diagnostic-report.txt 2>&1

echo "" >> diagnostic-report.txt
echo "Gateway Status:" >> diagnostic-report.txt
curl -s http://localhost:4000/health >> diagnostic-report.txt 2>&1

echo "Report saved to diagnostic-report.txt"
```

## Getting Help

If issues persist after troubleshooting:

1. **Collect diagnostics**:

   - Run diagnostic scripts
   - Capture relevant logs
   - Note exact error messages

2. **Check documentation**:

   - Setup guide: `examples/us4-corporate-proxy-setup.md`
   - Architecture: `examples/us4-proxy-gateway-architecture.md`
   - HTTPS_PROXY reference: `examples/us4-https-proxy-config.md`

3. **Contact support**:
   - Internal IT (proxy issues)
   - LiteLLM community (gateway issues)
   - Provider support (API issues)

## Quick Reference

```bash
# Test proxy
curl -x $HTTPS_PROXY https://httpbin.org/ip

# Test gateway
curl http://localhost:4000/health

# Test provider API
curl -x $HTTPS_PROXY -H "x-api-key: $ANTHROPIC_API_KEY" https://api.anthropic.com

# Check variables
echo $HTTPS_PROXY $NO_PROXY $SSL_CERT_FILE

# Run full test
python tests/test-proxy-gateway.py
```

---

**Last Updated**: 2025-12-01
