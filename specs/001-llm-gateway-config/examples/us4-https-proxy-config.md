# HTTPS_PROXY Configuration Reference

**Purpose**: Complete reference for configuring HTTP/HTTPS proxy environment variables for Claude Code and LiteLLM gateway.

## Overview

Claude Code and LiteLLM respect standard proxy environment variables used by most CLI tools and libraries:

- `HTTPS_PROXY` / `https_proxy` - Proxy for HTTPS connections
- `HTTP_PROXY` / `http_proxy` - Proxy for HTTP connections
- `NO_PROXY` / `no_proxy` - Bypass proxy for specified hosts
- `ALL_PROXY` / `all_proxy` - Proxy for all protocols (fallback)

**Precedence**: Uppercase variables take precedence over lowercase.

## Basic Configuration

### Simple Proxy (No Authentication)

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
```

### Proxy with Authentication

```bash
# Basic authentication
export HTTPS_PROXY="http://username:password@proxy.example.com:8080"

# URL-encoded credentials (for special characters)
export HTTPS_PROXY="http://user%40domain:p%40ss%21word@proxy.example.com:8080"
```

### HTTPS Proxy (Secure Proxy Connection)

```bash
# Proxy connection itself uses HTTPS
export HTTPS_PROXY="https://proxy.example.com:8443"
```

### SOCKS Proxy

```bash
# SOCKS5 proxy
export HTTPS_PROXY="socks5://proxy.example.com:1080"

# With authentication
export HTTPS_PROXY="socks5://username:password@proxy.example.com:1080"
```

## Proxy Bypass (NO_PROXY)

### Basic NO_PROXY

```bash
# Bypass proxy for localhost
export NO_PROXY="localhost,127.0.0.1"
```

### Domain Suffix Matching

```bash
# Bypass for all *.internal domains
export NO_PROXY="localhost,127.0.0.1,.internal"

# Multiple domain suffixes
export NO_PROXY="localhost,.internal,.corp,.local"
```

### IP Address Ranges

```bash
# Bypass for IP range (CIDR notation - not supported by all tools)
export NO_PROXY="localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8"

# Specific IPs
export NO_PROXY="localhost,127.0.0.1,10.0.0.5,10.0.0.6"
```

### Wildcard Matching

```bash
# Bypass all subdomains
export NO_PROXY="localhost,.example.com"  # Matches *.example.com

# Bypass specific hosts
export NO_PROXY="localhost,api.internal,gateway.corp,redis.local"
```

### Complete Example

```bash
export NO_PROXY="localhost,127.0.0.1,.internal,.corp,.local,192.168.0.0/16"
```

## Proxy URL Formats

### Standard HTTP Proxy

```
Format: http://[username:password@]host:port
Example: http://proxy.example.com:8080
Example: http://user:pass@proxy.example.com:8080
```

### HTTPS Proxy

```
Format: https://[username:password@]host:port
Example: https://secure-proxy.example.com:8443
```

### SOCKS4 Proxy

```
Format: socks4://[username:password@]host:port
Example: socks4://proxy.example.com:1080
```

### SOCKS5 Proxy

```
Format: socks5://[username:password@]host:port
Example: socks5://proxy.example.com:1080
Example: socks5://user:pass@proxy.example.com:1080
```

### SOCKS5 with Hostname Resolution

```
Format: socks5h://[username:password@]host:port
Example: socks5h://proxy.example.com:1080
Note: 'h' suffix means DNS resolution happens through proxy
```

## Special Characters in Credentials

### URL Encoding

When passwords contain special characters, they must be URL-encoded:

| Character | Encoded | Example                         |
| --------- | ------- | ------------------------------- |
| `@`       | `%40`   | `user@domain` → `user%40domain` |
| `:`       | `%3A`   | `pass:word` → `pass%3Aword`     |
| `/`       | `%2F`   | `pass/word` → `pass%2Fword`     |
| `#`       | `%23`   | `pass#word` → `pass%23word`     |
| `?`       | `%3F`   | `pass?word` → `pass%3Fword`     |
| `&`       | `%26`   | `pass&word` → `pass%26word`     |
| `=`       | `%3D`   | `pass=word` → `pass%3Dword`     |
| `+`       | `%2B`   | `pass+word` → `pass%2Bword`     |
| `space`   | `%20`   | `pass word` → `pass%20word`     |

### Encoding Script

```bash
#!/bin/bash
# URL-encode password
urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1', safe=''))"
}

# Usage
PASSWORD="p@ss:w/rd!"
ENCODED=$(urlencode "$PASSWORD")
export HTTPS_PROXY="http://username:${ENCODED}@proxy.example.com:8080"
```

## Configuration by Tool

### Claude Code

```bash
# Claude Code uses system proxy automatically
export HTTPS_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1"

# Point to local gateway (bypass proxy)
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

### LiteLLM Proxy

```bash
# LiteLLM respects HTTPS_PROXY for provider API calls
export HTTPS_PROXY="http://proxy.example.com:8080"

# Start proxy
litellm --config config.yaml --port 4000
```

### Python (requests library)

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export REQUESTS_CA_BUNDLE="/path/to/ca-bundle.crt"  # Custom CA
```

### curl

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export CURL_CA_BUNDLE="/path/to/ca-bundle.crt"  # Custom CA

# Or use -x flag
curl -x http://proxy.example.com:8080 https://api.anthropic.com
```

### Node.js

```bash
export HTTPS_PROXY="http://proxy.example.com:8080"
export NODE_EXTRA_CA_CERTS="/path/to/ca-bundle.crt"  # Custom CA
```

### Git

```bash
# Git proxy configuration
git config --global http.proxy http://proxy.example.com:8080
git config --global https.proxy http://proxy.example.com:8080

# Or use environment variables
export HTTPS_PROXY="http://proxy.example.com:8080"
```

## Platform-Specific Configuration

### Linux

```bash
# Add to ~/.bashrc or ~/.bash_profile
cat >> ~/.bashrc << 'EOF'
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"
export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
EOF

source ~/.bashrc
```

### macOS

```bash
# Add to ~/.zshrc or ~/.bash_profile
cat >> ~/.zshrc << 'EOF'
export HTTPS_PROXY="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"
export SSL_CERT_FILE="/etc/ssl/cert.pem"
EOF

source ~/.zshrc
```

### Windows (PowerShell)

```powershell
# Set for current session
$env:HTTPS_PROXY = "http://proxy.example.com:8080"
$env:HTTP_PROXY = "http://proxy.example.com:8080"
$env:NO_PROXY = "localhost,127.0.0.1"

# Set permanently (requires admin)
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://proxy.example.com:8080", "User")
```

### Docker

```bash
# Set proxy for Docker daemon
# /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Corporate Proxy Patterns

### Pattern 1: Simple Proxy (No Auth)

```bash
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"
```

**Use Case**: Internal proxy with IP-based authentication

### Pattern 2: Authenticated Proxy

```bash
export HTTPS_PROXY="http://employee:password@proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"
```

**Use Case**: Proxy requires user credentials

### Pattern 3: PAC File Proxy

```bash
# Use cntlm or px-proxy to handle PAC file
# Install cntlm: apt-get install cntlm
# Configure: /etc/cntlm.conf
export HTTPS_PROXY="http://localhost:3128"  # cntlm local port
```

**Use Case**: Automatic proxy configuration (PAC)

### Pattern 4: NTLM/Kerberos Proxy

```bash
# Use cntlm for NTLM authentication
# /etc/cntlm.conf:
# Username    DOMAIN\username
# Domain      CORP
# Password    <password or hash>
# Proxy       proxy.corp.example.com:8080

export HTTPS_PROXY="http://localhost:3128"
```

**Use Case**: Windows-integrated authentication

### Pattern 5: Multi-Proxy Environment

```bash
# Internal proxy for corporate APIs
export INTERNAL_PROXY="http://internal-proxy.corp:8080"

# External proxy for internet
export EXTERNAL_PROXY="http://external-proxy.corp:8080"

# Use appropriate proxy based on destination
# (Requires custom routing logic)
```

**Use Case**: Different proxies for internal/external traffic

## Testing Proxy Configuration

### Test 1: Basic Connectivity

```bash
curl -x $HTTPS_PROXY https://httpbin.org/ip
# Expected: Returns external IP
```

### Test 2: Authentication

```bash
curl -x http://user:pass@proxy.example.com:8080 https://httpbin.org/ip
# Expected: No 407 error
```

### Test 3: SSL/TLS

```bash
curl -x $HTTPS_PROXY https://api.anthropic.com
# Expected: No SSL errors
```

### Test 4: NO_PROXY Bypass

```bash
# Should NOT use proxy
curl http://localhost:4000/health

# Should use proxy
curl https://api.anthropic.com
```

### Test 5: Complete Integration

```bash
python tests/test-proxy-gateway.py --proxy $HTTPS_PROXY
```

## Troubleshooting

### Issue: "Connection refused"

**Check**:

```bash
# Verify proxy is reachable
ping proxy.example.com
telnet proxy.example.com 8080
```

### Issue: "407 Proxy Authentication Required"

**Check**:

```bash
# Test credentials
curl -x http://user:pass@proxy:8080 https://httpbin.org/ip

# URL-encode password
python3 -c "import urllib.parse; print(urllib.parse.quote('p@ss:w/rd!'))"
```

### Issue: "SSL certificate verify failed"

**Check**:

```bash
# Set CA bundle
export SSL_CERT_FILE="/path/to/ca-bundle.crt"
export REQUESTS_CA_BUNDLE="/path/to/ca-bundle.crt"

# Test
curl --cacert /path/to/ca-bundle.crt -x $HTTPS_PROXY https://api.anthropic.com
```

### Issue: NO_PROXY not working

**Check**:

```bash
# Print current value
echo $NO_PROXY

# Test pattern matching
python3 -c "
import os
from urllib.request import getproxies_environment, proxy_bypass_environment
print('Proxies:', getproxies_environment())
print('Bypass localhost:', proxy_bypass_environment('localhost'))
print('Bypass internal.com:', proxy_bypass_environment('api.internal.com'))
"
```

## Best Practices

1. **Use Uppercase Variables**: `HTTPS_PROXY` not `https_proxy` (more reliable)
2. **Include NO_PROXY**: Always bypass proxy for localhost/internal hosts
3. **URL-Encode Credentials**: Special characters must be encoded
4. **Use HTTPS Proxy**: Prefer `https://` proxy URLs when available
5. **Test Thoroughly**: Verify connectivity before deploying
6. **Document Configuration**: Keep proxy settings documented for team
7. **Rotate Credentials**: Change passwords regularly
8. **Monitor Access**: Watch for suspicious proxy usage

## Security Warnings

⚠️ **WARNING**: Proxy credentials in environment variables

- Visible in process listings (`ps aux | grep HTTPS_PROXY`)
- May be logged in shell history
- Accessible to all processes running as your user

**Mitigation**:

- Use credential managers (e.g., 1Password CLI)
- Set variables in shell profile (not command line)
- Use authentication proxies (cntlm) to avoid storing credentials

⚠️ **WARNING**: Corporate proxy logging

- All traffic may be logged and inspected
- API requests/responses visible to network admins
- Consider end-to-end encryption requirements

## References

- **RFC 7230**: HTTP/1.1 Proxy Specifications
- **curl Documentation**: https://curl.se/docs/manual.html
- **Python requests**: https://docs.python-requests.org/en/latest/user/advanced/#proxies
- **Node.js HTTP**: https://nodejs.org/api/http.html#httprequestoptions-callback

## Related Documentation

- `examples/us4-corporate-proxy-setup.md` - Setup guide
- `examples/us4-proxy-troubleshooting.md` - Troubleshooting
- `templates/proxy/proxy-auth.md` - Authentication methods
- `scripts/check-proxy-connectivity.sh` - Testing script
