# Troubleshooting Guide - LLM Gateway Configuration

**Consolidated troubleshooting guide for all common issues across all deployment patterns.**

---

## Quick Diagnostic Commands

```bash
# Check environment variables
env | grep -E '(ANTHROPIC|AWS|VERTEX|PROXY|SSL)'

# Test network connectivity
curl -v https://api.anthropic.com

# Test proxy
curl -x $HTTPS_PROXY https://httpbin.org/ip

# Test gateway
curl http://localhost:4000/health

# Check gateway logs
tail -f ~/.litellm/logs/litellm.log

# Run comprehensive tests
python tests/test-proxy-gateway.py
bash scripts/check-prerequisites.sh
```

---

## Connection Issues

### Issue: "Connection refused" to Gateway

**Symptoms**:

```
curl: (7) Failed to connect to localhost port 4000: Connection refused
```

**Diagnose**:

```bash
# Is gateway running?
ps aux | grep litellm

# Is port listening?
netstat -tuln | grep 4000
# or
lsof -i :4000
```

**Fix**:

```bash
# Start gateway
litellm --config config/litellm-complete.yaml --port 4000

# Or run in background
nohup litellm --config config/litellm-complete.yaml --port 4000 > gateway.log 2>&1 &
```

**Related**: `examples/us1-troubleshooting.md#gateway-not-responding`

### Issue: "Connection refused" to Proxy

**Symptoms**:

```
curl: (7) Failed to connect to proxy.corp.example.com port 8080
```

**Diagnose**:

````bash
# Can reach proxy server?
ping proxy.corp.example.com

# Is port open?
telnet proxy.corp.example.com 8080
# or
nc -zv proxy.corp.example.com 8080

# On VPN?
ip addr | grep \"inet \"  # Check for internal IP\n```\n\n**Fix**:\n1. Connect to corporate VPN\n2. Verify proxy URL/port\n3. Check firewall rules\n4. Contact IT if proxy is down\n\n**Related**: `examples/us4-proxy-troubleshooting.md#connection-refused`\n\n### Issue: Timeout Errors\n\n**Symptoms**:\n```\nTimeoutError: Request timeout after 30 seconds\n```\n\n**Diagnose**:\n```bash\n# Measure latency\ntime curl -x $HTTPS_PROXY https://api.anthropic.com\n\n# Check for rate limiting\ngrep \"429\" ~/.litellm/logs/litellm.log\n```\n\n**Fix**:\n```yaml\n# Increase timeout in config\nlitellm_settings:\n  request_timeout: 600  # 10 minutes\n  num_retries: 3\n  retry_after: 10\n```\n\n**Related**: `examples/us4-proxy-troubleshooting.md#timeout-errors`\n\n---\n\n## Authentication Issues\n\n### Issue: \"401 Unauthorized\" from Provider\n\n**Symptoms**:\n```\n401 Unauthorized: Invalid API key\n```\n\n**Diagnose**:\n```bash\n# Check API key is set\necho $ANTHROPIC_API_KEY\n\n# Verify key format\n# Anthropic: sk-ant-api03-...\n# AWS: AKIA...\n\n# Test key directly\ncurl https://api.anthropic.com/v1/messages \\\n  -H \"Content-Type: application/json\" \\\n  -H \"x-api-key: $ANTHROPIC_API_KEY\" \\\n  -H \"anthropic-version: 2023-06-01\" \\\n  -d '{\"model\":\"claude-3-5-sonnet-20241022\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}'\n```\n\n**Fix**:\n1. Regenerate API key from provider console\n2. Update environment variable or secrets manager\n3. Restart gateway\n4. Test again\n\n**Related**: `examples/us1-troubleshooting.md#api-key-errors`\n\n### Issue: \"407 Proxy Authentication Required\"\n\n**Symptoms**:\n```\nHTTP/1.1 407 Proxy Authentication Required\n```\n\n**Diagnose**:\n```bash\n# Test proxy auth\ncurl -x http://username:password@proxy:8080 https://httpbin.org/ip\n\n# Check for special characters in password\necho $HTTPS_PROXY | grep '@'\n```\n\n**Fix**:\n```bash\n# URL-encode password\npython3 -c \"import urllib.parse; print(urllib.parse.quote('p@ss:w/rd!', safe=''))\"\n# Output: p%40ss%3Aw%2Frd%21\n\nexport HTTPS_PROXY=\"http://username:p%40ss%3Aw%2Frd%21@proxy:8080\"\n```\n\n**Related**: `examples/us4-proxy-troubleshooting.md#407-auth-required`\n\n### Issue: AWS Credentials Not Found\n\n**Symptoms**:\n```\nNoCredentialsError: Unable to locate credentials\n```\n\n**Diagnose**:\n```bash\n# Check env vars\necho $AWS_ACCESS_KEY_ID\necho $AWS_SECRET_ACCESS_KEY\n\n# Check credentials file\ncat ~/.aws/credentials\n\n# Test credentials\naws sts get-caller-identity\n```\n\n**Fix**:\n```bash\n# Set credentials\nexport AWS_ACCESS_KEY_ID=\"AKIA...\"\nexport AWS_SECRET_ACCESS_KEY=\"...\"\nexport AWS_REGION=\"us-east-1\"\n\n# Or configure AWS CLI\naws configure\n```\n\n### Issue: Google Cloud Authentication Failed\n\n**Symptoms**:\n```\nDefaultCredentialsError: Could not automatically determine credentials\n```\n\n**Fix**:\n```bash\n# Method 1: Application Default Credentials\ngcloud auth application-default login\n\n# Method 2: Service Account Key\nexport GOOGLE_APPLICATION_CREDENTIALS=\"/path/to/service-account.json\"\n\n# Verify\ngcloud auth application-default print-access-token\n```\n\n---\n\n## SSL/Certificate Issues\n\n### Issue: \"SSL certificate verify failed\"\n\n**Symptoms**:\n```\nSSLCertVerificationError: certificate verify failed: unable to get local issuer certificate\n```\n\n**Diagnose**:\n```bash\n# Test certificate validation\nopenssl s_client -connect api.anthropic.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt\n\n# Check for proxy SSL inspection\ncurl -v https://api.anthropic.com 2>&1 | grep 'issuer'\n```\n\n**Fix**:\n```bash\n# Install corporate CA certificate\nsudo cp corporate-ca-bundle.crt /usr/local/share/ca-certificates/\nsudo update-ca-certificates\n\n# Or set environment variables\nexport SSL_CERT_FILE=\"/path/to/corporate-ca-bundle.crt\"\nexport REQUESTS_CA_BUNDLE=\"/path/to/corporate-ca-bundle.crt\"\nexport CURL_CA_BUNDLE=\"/path/to/corporate-ca-bundle.crt\"\n```\n\n**Related**: `examples/us4-proxy-troubleshooting.md#ssl-certificate-verify-failed`\n\n---\n\n## Configuration Issues\n\n### Issue: Invalid YAML Syntax\n\n**Symptoms**:\n```\nYAML parsing error: mapping values are not allowed here\n```\n\n**Diagnose**:\n```bash\n# Validate YAML\npython3 -c \"import yaml; yaml.safe_load(open('config.yaml'))\"\n\n# Or use validation script\npython scripts/validate-config.py config.yaml\n```\n\n**Common Errors**:\n```yaml\n# ❌ Wrong indentation\nmodel_list:\n- model_name: claude\n litellm_params:  # Should be indented 2 more spaces\n\n# ✅ Correct\nmodel_list:\n  - model_name: claude\n    litellm_params:\n```\n\n### Issue: Environment Variable Not Resolved\n\n**Symptoms**:\n```\nKeyError: 'ANTHROPIC_API_KEY'\n```\n\n**Fix**:\n```yaml\n# ❌ Wrong syntax\napi_key: $ANTHROPIC_API_KEY\napi_key: ${ANTHROPIC_API_KEY}\n\n# ✅ Correct syntax\napi_key: os.environ/ANTHROPIC_API_KEY\n```\n\n### Issue: Model Not Found\n\n**Symptoms**:\n```\nModelNotFoundError: model 'claude-sonnet' not found\n```\n\n**Diagnose**:\n```bash\n# List available models\ncurl http://localhost:4000/models\n\n# Check config file\ngrep -A 5 \"model_name:\" config.yaml\n```\n\n**Fix**:\n1. Use exact model name from config\n2. Check spelling/capitalization\n3. Verify model is enabled in provider account\n\n---\n\n## Performance Issues\n\n### Issue: Slow Response Times\n\n**Diagnose**:\n```bash\n# Measure latency by component\ntime curl http://localhost:4000/health  # Gateway\ntime curl -x $HTTPS_PROXY https://httpbin.org/ip  # Proxy\ntime curl https://api.anthropic.com  # Provider\n\n# Check cache hit rate\ngrep \"cache_hit\" ~/.litellm/logs/litellm.log | wc -l\ngrep \"cache_miss\" ~/.litellm/logs/litellm.log | wc -l\n```\n\n**Fix**:\n1. Enable caching (if not already)\n2. Optimize proxy latency\n3. Use regional provider endpoints\n4. Check network bandwidth\n\n### Issue: High Memory Usage\n\n**Diagnose**:\n```bash\n# Check process memory\nps aux | grep litellm | awk '{print $4 \" \" $6}'\n\n# Monitor over time\ntop -p $(pgrep litellm)\n```\n\n**Fix**:\n```yaml\n# Limit cache size\ncache_params:\n  type: \"redis\"\n  max_size_mb: 1000  # 1GB limit\n  ttl: 3600\n```\n\n---\n\n## Proxy-Specific Issues\n\n### Issue: NO_PROXY Not Working\n\n**Diagnose**:\n```bash\n# Check NO_PROXY value\necho $NO_PROXY\n\n# Test pattern matching\npython3 << 'EOF'\nimport os\nfrom urllib.request import proxy_bypass_environment\n\nos.environ['NO_PROXY'] = 'localhost,127.0.0.1,.internal'\nprint('Bypass localhost:', proxy_bypass_environment('localhost'))\nprint('Bypass api.internal:', proxy_bypass_environment('api.internal'))\nprint('Bypass example.com:', proxy_bypass_environment('example.com'))\nEOF\n```\n\n**Fix**:\n```bash\n# Correct patterns (comma-separated, no spaces)\nexport NO_PROXY=\"localhost,127.0.0.1,.internal,.corp,.local\"\n\n# Unset lowercase variants\nunset no_proxy http_proxy https_proxy\n```\n\n**Related**: `examples/us4-proxy-troubleshooting.md#no-proxy-not-working`\n\n---\n\n## Provider-Specific Issues\n\n### Issue: Vertex AI \"Permission Denied\"\n\n**Symptoms**:\n```\n403 Forbidden: Permission denied on project\n```\n\n**Fix**:\n```bash\n# Check project ID\necho $VERTEX_PROJECT_ID\n\n# Verify permissions\ngcloud projects get-iam-policy $VERTEX_PROJECT_ID\n\n# Enable Vertex AI API\ngcloud services enable aiplatform.googleapis.com --project=$VERTEX_PROJECT_ID\n\n# Grant required role\ngcloud projects add-iam-policy-binding $VERTEX_PROJECT_ID \\\n  --member=\"user:you@example.com\" \\\n  --role=\"roles/aiplatform.user\"\n```\n\n### Issue: Bedrock \"Model Not Accessible\"\n\n**Symptoms**:\n```\nAccessDeniedException: Model access not granted\n```\n\n**Fix**:\n1. Go to AWS Bedrock console\n2. Request model access for Claude models\n3. Wait for approval (usually instant for Anthropic)\n4. Verify region supports model\n5. Retry request\n\n---\n\n## Diagnostic Scripts\n\n### Run All Checks\n\n```bash\n# Prerequisites\nbash scripts/check-prerequisites.sh\n\n# Configuration validation\npython scripts/validate-config.py config.yaml\n\n# Environment variables\npython scripts/validate-provider-env-vars.py\n\n# Proxy connectivity\nbash scripts/check-proxy-connectivity.sh\n\n# Gateway health\nbash scripts/health-check.sh\n\n# End-to-end tests\npython tests/test-all-models.py\npython tests/test-proxy-gateway.py\n```\n\n### Generate Diagnostic Report\n\n```bash\n#!/bin/bash\nREPORT=\"diagnostic-report-$(date +%Y%m%d-%H%M%S).txt\"\n\necho \"=== Diagnostic Report ===\" > $REPORT\necho \"Date: $(date)\" >> $REPORT\necho \"\" >> $REPORT\n\necho \"Environment:\" >> $REPORT\nenv | grep -E '(ANTHROPIC|AWS|VERTEX|PROXY|SSL)' >> $REPORT\necho \"\" >> $REPORT\n\necho \"Network:\" >> $REPORT\ncurl -s http://localhost:4000/health >> $REPORT 2>&1\necho \"\" >> $REPORT\n\necho \"Logs (last 50 lines):\" >> $REPORT\ntail -50 ~/.litellm/logs/litellm.log >> $REPORT 2>&1\n\necho \"Report: $REPORT\"\n```\n\n---\n\n## Getting Help\n\n### Before Asking for Help\n\n1. **Run diagnostic scripts** (above)\n2. **Check logs**: `~/.litellm/logs/litellm.log`\n3. **Search documentation**: This file + examples/\n4. **Try solutions** from this guide\n5. **Collect information**:\n   - Exact error message\n   - Configuration files (redact keys!)\n   - Environment variables (redact keys!)\n   - Steps to reproduce\n\n### Support Channels\n\n**Internal**:\n- IT Helpdesk (proxy/network issues)\n- Security Team (auth/compliance issues)\n- DevOps Team (infrastructure issues)\n\n**External**:\n- LiteLLM Docs: https://docs.litellm.ai/\n- LiteLLM GitHub: https://github.com/BerriAI/litellm/issues\n- Provider Support:\n  - Anthropic: https://support.anthropic.com/\n  - AWS: https://console.aws.amazon.com/support/\n  - Google Cloud: https://cloud.google.com/support/\n\n---\n\n## Quick Reference\n\n### Most Common Issues (80% of problems)\n\n1. **API key not set or invalid** → Check `$ANTHROPIC_API_KEY`\n2. **Gateway not running** → Start with `litellm --config ...`\n3. **Proxy authentication failed** → URL-encode password\n4. **SSL certificate error** → Install corporate CA\n5. **Wrong model name** → Check `curl localhost:4000/models`\n\n### Emergency Troubleshooting\n\n**Gateway won't start**:\n```bash\n# Check config syntax\npython3 -c \"import yaml; yaml.safe_load(open('config.yaml'))\"\n\n# Start with debug logging\nexport LITELLM_LOG=DEBUG\nlitellm --config config.yaml --debug\n```\n\n**Complete reset**:\n```bash\n# Kill gateway\npkill -9 litellm\n\n# Clear cache\nredis-cli FLUSHALL\n\n# Clear logs\nrm ~/.litellm/logs/*\n\n# Restart fresh\nlitellm --config config.yaml --port 4000\n```\n\n---\n\n## References\n\n- **User Story 1 Troubleshooting**: `examples/us1-troubleshooting.md`\n- **User Story 4 Proxy Troubleshooting**: `examples/us4-proxy-troubleshooting.md`\n- **Configuration Reference**: `docs/configuration-reference.md`\n- **Security Best Practices**: `docs/security-best-practices.md`\n- **FAQ**: `docs/faq.md`\n\n---\n\n**Last Updated**: 2025-12-01  \n**Version**: 1.0.0\n
````
