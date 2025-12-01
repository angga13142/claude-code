# Corporate Proxy Troubleshooting Flowchart

**Purpose**: Diagnostic decision tree for resolving corporate proxy issues when using Claude Code with LLM gateways

**Audience**: Developers, DevOps engineers troubleshooting proxy connectivity

**How to Use**: Start at "Issue Symptoms" and follow YES/NO paths to identify root cause and solution

---

## 🔍 Issue Symptoms

**What error are you seeing?**

```
├─ "407 Proxy Authentication Required" ─────────► Go to: [AUTHENTICATION ISSUES]
├─ "Connection refused" or "Connection timeout" ► Go to: [CONNECTIVITY ISSUES]
├─ "SSL certificate verification failed" ──────► Go to: [CERTIFICATE ISSUES]
├─ "403 Forbidden" or "502 Bad Gateway" ───────► Go to: [PROXY POLICY ISSUES]
├─ "Works with curl, fails with Claude Code" ──► Go to: [APPLICATION ISSUES]
├─ "Slow performance / timeouts" ──────────────► Go to: [PERFORMANCE ISSUES]
└─ "No error, but requests don't route through proxy" ► Go to: [BYPASS ISSUES]
```

---

## 🔐 AUTHENTICATION ISSUES

**Error: 407 Proxy Authentication Required**

### Step 1: Verify Credentials

**Q: Are username and password correct?**

```bash
# Test with curl
curl -x "http://username:password@proxy:8080" https://google.com
```

- ✅ **YES** (works with curl) → Go to Step 2
- ❌ **NO** (401/407 error) → **SOLUTION**: Contact IT for correct credentials

### Step 2: Check Special Characters

**Q: Does password contain special characters (@, :, /, ?, #, etc.)?**

- ✅ **YES** → **SOLUTION**: URL-encode credentials

  ```bash
  # Python helper to encode
  python3 << EOF
  from urllib.parse import quote
  username = "user@domain.com"
  password = "P@ssw0rd!"
  print(f"http://{quote(username)}:{quote(password)}@proxy:8080")
  EOF
  # Copy output to HTTPS_PROXY
  ```

- ❌ **NO** → Go to Step 3

### Step 3: Verify Environment Variable

**Q: Is HTTPS_PROXY correctly exported?**

```bash
# Check variable is set
echo $HTTPS_PROXY
# Should show: http://username:password@proxy:8080

# Verify in same shell where Claude Code runs
echo $HTTPS_PROXY && claude /status
```

- ✅ **YES** (variable set correctly) → Go to Step 4
- ❌ **NO** (variable empty or different shell) → **SOLUTION**: Export in correct shell/profile

  ```bash
  # Add to ~/.bashrc or ~/.zshrc
  export HTTPS_PROXY="http://user:pass@proxy:8080"

  # Reload shell config
  source ~/.bashrc
  ```

### Step 4: Test .netrc Method

**Q: Using .netrc for credentials?**

- ✅ **YES** → Verify .netrc configuration:

  ```bash
  # Check file exists and has correct permissions
  ls -la ~/.netrc  # Should show: -rw------- (600)

  # Fix permissions if wrong
  chmod 600 ~/.netrc

  # Verify format (exact spacing matters)
  cat ~/.netrc
  # Should show:
  # machine proxy.company.com
  # login username
  # password yourpassword

  # Test with curl (should work without -x credentials)
  curl https://api.anthropic.com
  ```

  - Still fails → Some HTTP libraries don't respect .netrc → Use inline credentials or secret manager

- ❌ **NO** → Go to Step 5

### Step 5: Check Proxy Type

**Q: Does proxy use NTLM or Kerberos authentication?**

```bash
# Check proxy response headers
curl -v -x proxy:8080 https://google.com 2>&1 | grep -i "Proxy-Authenticate"
# Look for: NTLM, Negotiate, or Kerberos
```

- ✅ **YES** (NTLM/Kerberos) → **SOLUTION**: Use cntlm or configure Kerberos

  **For NTLM**:

  ```bash
  # Install cntlm
  # macOS: brew install cntlm
  # Ubuntu: sudo apt-get install cntlm

  # Configure cntlm
  cat > ~/.cntlm.conf << EOF
  Username    youruser
  Domain      COMPANY
  Password    yourpassword
  Proxy       proxy.company.com:8080
  Listen      3128
  EOF

  chmod 600 ~/.cntlm.conf
  cntlm -c ~/.cntlm.conf &

  # Use local cntlm proxy
  export HTTPS_PROXY="http://localhost:3128"
  ```

  **For Kerberos**:

  ```bash
  # Obtain Kerberos ticket
  kinit youruser@COMPANY.COM

  # Verify ticket
  klist

  # Some proxies auto-detect Kerberos
  export HTTPS_PROXY="http://proxy.company.com:8080"
  ```

- ❌ **NO** (Basic auth) → **SOLUTION**: Check with IT - may be account issue

---

## 🔌 CONNECTIVITY ISSUES

**Error: Connection refused or Connection timeout**

### Step 1: Verify Proxy is Reachable

```bash
# Test connectivity to proxy
nc -zv proxy.company.com 8080
# Or: telnet proxy.company.com 8080
```

- ✅ **Connection succeeded** → Go to Step 2
- ❌ **Connection failed** → **SOLUTION**: Network/firewall issue

  **Diagnostic steps**:

  ```bash
  # 1. Verify proxy hostname resolves
  nslookup proxy.company.com
  dig proxy.company.com

  # 2. Check route to proxy
  traceroute proxy.company.com

  # 3. Check firewall rules
  # Contact IT if proxy is unreachable

  # 4. Verify you're on corporate network
  # VPN connected? Correct network segment?
  ```

### Step 2: Check Proxy Port

**Q: Is proxy port correct?**

```bash
# Common proxy ports: 8080, 3128, 8888, 8443 (HTTPS)
# Verify with IT or check proxy auto-config (PAC) file

# Test different ports
for port in 8080 3128 8888 8443; do
  echo "Testing port $port..."
  nc -zv proxy.company.com $port
done
```

- Finds open port → Update `HTTPS_PROXY` with correct port
- No open ports → **SOLUTION**: Contact IT for correct proxy endpoint

### Step 3: Test Basic Proxy Functionality

```bash
# Test HTTP request through proxy
curl -v -x "http://proxy:8080" http://example.com

# Test HTTPS request through proxy
curl -v -x "http://proxy:8080" https://google.com
```

- ✅ **Works** → Proxy functional, issue is with application config → Go to [APPLICATION ISSUES]
- ❌ **Fails** → Proxy not working → Contact IT

### Step 4: Check NO_PROXY Settings

**Q: Could NO_PROXY be interfering?**

```bash
# Check NO_PROXY variable
echo $NO_PROXY
# Example: localhost,127.0.0.1,*.internal

# Does it include provider domain by mistake?
echo $NO_PROXY | grep -i "anthropic\|amazonaws\|googleapis"
```

- ✅ **YES** (provider in NO_PROXY) → **SOLUTION**: Remove provider from NO_PROXY

  ```bash
  # Fix: Exclude only internal hosts
  export NO_PROXY="localhost,127.0.0.1,*.internal,*.company.com"
  ```

- ❌ **NO** → Go to Step 5

### Step 5: Verify Gateway is Running (if using LiteLLM)

```bash
# Check LiteLLM gateway is running
curl http://localhost:4000/health

# Check gateway logs
# Look for proxy connection errors
```

- Gateway not running → Start gateway: `litellm --config config.yaml`
- Gateway errors → Check gateway logs for proxy connectivity issues

---

## 🔒 CERTIFICATE ISSUES

**Error: SSL certificate verification failed**

### Step 1: Identify SSL Interception

**Q: Does corporate proxy perform SSL inspection?**

```bash
# Check certificate chain
curl -v https://api.anthropic.com 2>&1 | grep -i "issuer"

# If issuer is corporate CA (not Let's Encrypt/DigiCert), SSL is intercepted
```

- ✅ **YES** (corporate CA in chain) → **SOLUTION**: Install proxy CA certificate
- ❌ **NO** → Go to Step 2

### Installing Proxy CA Certificate

**macOS**:

```bash
# Obtain proxy-ca.crt from IT department

# Add to system trust store
sudo security add-trusted-cert \
  -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  proxy-ca.crt

# Verify
security find-certificate -c "Your Company CA" -a
```

**Linux (Debian/Ubuntu)**:

```bash
# Copy CA certificate
sudo cp proxy-ca.crt /usr/local/share/ca-certificates/

# Update trust store
sudo update-ca-certificates

# Verify
ls /etc/ssl/certs/ | grep proxy
```

**Linux (RHEL/CentOS/Amazon Linux)**:

```bash
# Copy CA certificate
sudo cp proxy-ca.crt /etc/pki/ca-trust/source/anchors/

# Update trust store
sudo update-ca-trust

# Verify
trust list | grep -i "company"
```

### Step 2: Certificate Validation Disabled?

**⚠️ NOT RECOMMENDED FOR PRODUCTION**

```bash
# Temporary workaround (development only)
export CURL_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""
export SSL_CERT_FILE=""

# Test
curl https://api.anthropic.com
```

- Works → Certificate issue confirmed → Install proper CA certificate (above)
- Still fails → Different issue → Go to Step 3

### Step 3: Check Python SSL Configuration

```python
# Test Python SSL verification
python3 << EOF
import ssl
import urllib.request

# Check default CA bundle location
print("CA bundle:", ssl.get_default_verify_paths())

# Test HTTPS connection
try:
    context = ssl.create_default_context()
    urllib.request.urlopen('https://api.anthropic.com', context=context)
    print("✓ SSL verification passed")
except ssl.SSLError as e:
    print(f"✗ SSL error: {e}")
except Exception as e:
    print(f"✗ Error: {e}")
EOF
```

- SSL error → **SOLUTION**: Point Python to CA bundle

  ```bash
  # Find system CA bundle
  python3 -c "import ssl; print(ssl.get_default_verify_paths())"

  # Set environment variable
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt  # Linux
  # or
  export SSL_CERT_FILE=/etc/ssl/cert.pem  # macOS
  ```

---

## 🚫 PROXY POLICY ISSUES

**Error: 403 Forbidden or 502 Bad Gateway**

### Step 1: Check Domain Whitelist

**Q: Is AI provider domain allowed by proxy?**

```bash
# Test direct curl through proxy
curl -x "$HTTPS_PROXY" https://api.anthropic.com/v1/messages

# Common blocked domains:
# - api.anthropic.com
# - bedrock-runtime.*.amazonaws.com
# - aiplatform.googleapis.com
```

- ❌ **403 Forbidden** → **SOLUTION**: Request IT to whitelist domains

  **Domains to whitelist**:

  - Anthropic: `api.anthropic.com`
  - AWS Bedrock: `bedrock-runtime.*.amazonaws.com`, `*.bedrock-runtime.amazonaws.com`
  - Vertex AI: `*.aiplatform.googleapis.com`, `aiplatform.googleapis.com`

- ✅ **200 OK** → Proxy allows domain → Issue is elsewhere → Go to Step 2

### Step 2: Check URL Filtering

**Q: Does proxy block AI/LLM-related URLs?**

```bash
# Check proxy logs (if accessible)
# Contact IT to review proxy policy for AI service blocking

# Common proxy filtering categories that block AI:
# - "Artificial Intelligence"
# - "ChatGPT/LLM Services"
# - "Generative AI"
# - "High Bandwidth Applications"
```

- Blocked category found → **SOLUTION**: Request exemption or policy change from IT
- Not blocked → Go to Step 3

### Step 3: Check Request Size Limits

```bash
# Some proxies have payload size limits
# Test with minimal request
curl -x "$HTTPS_PROXY" https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

- Small request works, large fails → **SOLUTION**: Increase proxy payload limit or use streaming
- All requests fail → Go to Step 4

### Step 4: Check Proxy Logs

```bash
# Request proxy logs from IT
# Look for:
# - Policy violations
# - Rate limiting
# - Quota exceeded
# - Blocked by DLP (Data Loss Prevention)
```

**Common Issues in Logs**:

- "Content-Type application/json blocked" → Request JSON whitelist
- "Rate limit exceeded" → Request higher limits or use quota management
- "DLP violation: API key detected" → Encrypt request bodies or use different auth method

---

## 🔧 APPLICATION ISSUES

**Works with curl, fails with Claude Code**

### Step 1: Verify Environment Variables in Same Shell

```bash
# Print all proxy-related variables
env | grep -i proxy

# Should show:
# HTTPS_PROXY=http://user:pass@proxy:8080
# HTTP_PROXY=http://user:pass@proxy:8080
# (optionally NO_PROXY=...)

# Test in same shell where Claude Code runs
echo "Proxy: $HTTPS_PROXY"
claude /status
```

- Variables missing → **SOLUTION**: Export variables in shell startup file

  ```bash
  # Add to ~/.bashrc or ~/.zshrc
  export HTTPS_PROXY="http://user:pass@proxy:8080"
  export HTTP_PROXY="$HTTPS_PROXY"

  # Reload
  source ~/.bashrc

  # Verify persistent
  exec $SHELL  # Start new shell
  echo $HTTPS_PROXY  # Should still show proxy URL
  ```

### Step 2: Check Claude Code Proxy Support

```bash
# Enable debug logging
export ANTHROPIC_LOG=debug
export LITELLM_LOG=DEBUG

# Run Claude Code
claude /status 2>&1 | tee claude-debug.log

# Look for proxy-related log lines
grep -i proxy claude-debug.log
```

- No proxy in logs → Claude Code not using proxy → **SOLUTION**: Check SDK version
- Proxy connection error in logs → Go to Step 3

### Step 3: Test Python Requests Library (LiteLLM dependency)

```python
import os
import requests

# Set proxy
os.environ['HTTPS_PROXY'] = 'http://user:pass@proxy:8080'

# Test request
try:
    response = requests.get('https://api.anthropic.com/v1/messages',
                           headers={'x-api-key': os.environ['ANTHROPIC_API_KEY']},
                           timeout=10)
    print(f"Status: {response.status_code}")
except requests.exceptions.ProxyError as e:
    print(f"Proxy error: {e}")
except Exception as e:
    print(f"Error: {e}")
```

- Proxy error → Proxy authentication issue → Go back to [AUTHENTICATION ISSUES]
- Connection error → Go back to [CONNECTIVITY ISSUES]
- Works → Claude Code issue → Check Claude Code configuration

### Step 4: Verify LiteLLM Gateway Configuration (if using)

```yaml
# In litellm config.yaml, verify proxy settings

litellm_settings:
  proxy:
    http_proxy: os.environ/HTTP_PROXY
    https_proxy: os.environ/HTTPS_PROXY
    no_proxy: os.environ/NO_PROXY
```

- Missing proxy config → Add to litellm config
- Config present → Check environment variables are set when starting LiteLLM

---

## ⚡ PERFORMANCE ISSUES

**Slow responses or frequent timeouts**

### Step 1: Measure Latency

```bash
# Test direct vs proxy latency
# Direct (if possible from non-corporate network)
time curl https://api.anthropic.com

# Through proxy
time curl -x "$HTTPS_PROXY" https://api.anthropic.com
```

- Proxy adds >2 seconds → Proxy is slow → Go to Step 2
- Similar latency → Issue not proxy-related

### Step 2: Check Proxy Health

```bash
# Test proxy responsiveness
for i in {1..10}; do
  time curl -x "$HTTPS_PROXY" https://google.com -o /dev/null -s
done

# Calculate average latency
```

- Proxy latency high (>500ms) → **SOLUTION**: Contact IT about proxy performance
- Proxy latency OK → Go to Step 3

### Step 3: Increase Timeouts

```yaml
# In LiteLLM config
litellm_settings:
  request_timeout: 600 # 10 minutes (default: 300)

router_settings:
  timeout: 300 # 5 minutes per provider attempt
```

```bash
# For Claude Code SDK
export ANTHROPIC_TIMEOUT=600  # 10 minutes
```

### Step 4: Check for Rate Limiting

```bash
# Monitor for 429 errors (Too Many Requests)
claude /status 2>&1 | grep -i "429\|rate limit"

# Check proxy logs for throttling
```

- Rate limiting detected → **SOLUTION**:
  - Implement request queuing
  - Use multiple API keys (if allowed)
  - Contact IT for higher rate limits
  - Add retry logic with exponential backoff

---

## 🔀 BYPASS ISSUES

**Requests don't go through proxy (bypass unintentionally)**

### Step 1: Verify Proxy is Being Used

```bash
# Check with network monitoring
sudo tcpdump -i any -n host proxy.company.com

# In another terminal
curl https://api.anthropic.com

# Should see packets to proxy.company.com
```

- No traffic to proxy → Proxy bypassed → Go to Step 2
- Traffic seen → Proxy is being used

### Step 2: Check NO_PROXY Configuration

```bash
echo $NO_PROXY | grep -i "anthropic\|amazonaws\|googleapis"
```

- Provider domain in NO_PROXY → **SOLUTION**: Remove from NO_PROXY

  ```bash
  # Keep only internal domains
  export NO_PROXY="localhost,127.0.0.1,*.internal,*.company.com"
  ```

### Step 3: Check System-Wide Proxy Settings

**macOS**:

```bash
# Check System Preferences > Network > Advanced > Proxies
# May override environment variables

# Disable system proxy if conflicts with HTTPS_PROXY
```

**Linux**:

```bash
# Check /etc/environment
cat /etc/environment | grep -i proxy

# Check system-wide proxy settings
gsettings get org.gnome.system.proxy mode  # GNOME
```

### Step 4: Check Application-Specific Bypass

```bash
# Some applications have their own proxy settings
# Check Claude Code configuration files
cat ~/.claude/settings.json | grep -i proxy

# Check LiteLLM configuration
grep -i proxy litellm-config.yaml
```

---

## 📊 Quick Diagnostic Script

Run this script to gather information for troubleshooting:

```bash
#!/bin/bash
# Save as: diagnose-proxy.sh

echo "===== Environment Variables ====="
env | grep -i proxy

echo -e "\n===== DNS Resolution ====="
nslookup api.anthropic.com
nslookup $(echo $HTTPS_PROXY | sed 's/.*@//;s/:.*//')  # Proxy hostname

echo -e "\n===== Proxy Connectivity ====="
PROXY_HOST=$(echo $HTTPS_PROXY | sed 's/.*@//;s/:.*//')
PROXY_PORT=$(echo $HTTPS_PROXY | sed 's/.*://;s/\/.*//')
nc -zv $PROXY_HOST $PROXY_PORT 2>&1

echo -e "\n===== Test with curl ====="
curl -v -x "$HTTPS_PROXY" https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":1,"messages":[{"role":"user","content":"Hi"}]}' \
  2>&1 | head -30

echo -e "\n===== Python Requests Test ====="
python3 << 'PYEOF'
import os, requests
try:
    r = requests.get('https://api.anthropic.com', timeout=5)
    print(f"✓ Python requests OK (status: {r.status_code})")
except Exception as e:
    print(f"✗ Python requests failed: {e}")
PYEOF

echo -e "\n===== SSL Certificate Chain ====="
openssl s_client -connect api.anthropic.com:443 -showcerts < /dev/null 2>&1 | grep -i issuer

echo -e "\n===== Done ====="
echo "Share output with IT or support team for troubleshooting"
```

Usage:

```bash
chmod +x diagnose-proxy.sh
./diagnose-proxy.sh > proxy-diagnostic-$(date +%Y%m%d-%H%M%S).log
```

---

## 🆘 Escalation Path

If all troubleshooting steps fail:

1. **Gather Information**:

   - Run diagnostic script above
   - Copy error messages (full stack traces)
   - Note what works vs. what doesn't

2. **Contact Internal IT**:

   - Proxy logs (timestamps of failures)
   - Proxy configuration (authentication method, ports)
   - Domain whitelist status for AI providers
   - Network policies affecting AI services

3. **Contact Claude Code Support** (if gateway/SDK issue):

   - Provide diagnostic script output
   - Claude Code version: `claude --version`
   - LiteLLM version: `litellm --version`
   - Python version: `python3 --version`
   - Operating system and version

4. **Contact Provider Support** (if provider API issue):
   - Provider API status page
   - Authentication working from non-corporate network?
   - API key valid and has correct permissions?

---

## Related Documentation

- `proxy-auth.md` - Authentication methods in detail
- `proxy-only-config.yaml` - Proxy-only deployment examples
- `proxy-gateway-config.yaml` - Combined proxy + gateway configuration
- `examples/us4-proxy-troubleshooting.md` - Extended troubleshooting guide
- `examples/us4-firewall-considerations.md` - Network security best practices
