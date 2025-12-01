# Deployment Pattern Decision Tree

**Feature**: LLM Gateway Configuration Assistant  
**Purpose**: Help users choose the right deployment pattern for their needs  
**Date**: 2025-12-01

---

## Quick Decision Guide

Answer these questions to find your ideal deployment pattern:

```
┌─────────────────────────────────────────────┐
│ Do you need cost tracking or usage          │
│ analytics for LLM API calls?                │
└──────────────┬──────────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
       YES           NO
        │             │
        ├─────────────┴─────────────────┐
        │                               │
        ▼                               ▼
┌───────────────────┐        ┌──────────────────┐
│ Does your network │        │ Does your network│
│ require a proxy?  │        │ require a proxy? │
└────────┬──────────┘        └────────┬─────────┘
         │                            │
   ┌─────┴─────┐                ┌────┴────┐
  YES          NO               YES       NO
   │           │                 │         │
   ▼           ▼                 ▼         ▼
Pattern D   Pattern C        Pattern B  Pattern A
```

---

## Pattern A: Direct Provider Access

### Architecture

```
┌──────────────┐
│  Claude Code │
└──────┬───────┘
       │ HTTPS
       ▼
┌──────────────────────────────┐
│ Provider API                 │
│ • Anthropic API              │
│ • AWS Bedrock                │
│ • Google Vertex AI           │
└──────────────────────────────┘
```

### When to Use

✅ **Use this pattern when:**

- You only need a single provider (Anthropic, Bedrock, or Vertex AI)
- You don't need centralized cost tracking or usage analytics
- You're doing personal development or small-scale usage
- You want the simplest possible setup

❌ **Don't use this pattern when:**

- You need to track costs across teams or projects
- You want to use multiple model providers
- You need load balancing or fallback strategies
- You're in an enterprise requiring audit trails

### Configuration

**Minimal setup** - Claude Code works out of the box with Anthropic API:

```bash
# No configuration needed for Anthropic API
# Claude Code uses https://api.anthropic.com by default

# For Bedrock:
export ANTHROPIC_BEDROCK_BASE_URL="https://bedrock-runtime.us-west-2.amazonaws.com"

# For Vertex AI:
export ANTHROPIC_VERTEX_BASE_URL="https://us-central1-aiplatform.googleapis.com"
gcloud auth application-default login
```

### Pros & Cons

**Advantages:**

- 🚀 Minimal configuration (works out of the box)
- ⚡ Lowest latency (direct connection)
- 🔒 Simple security model (just API keys)
- 💰 No additional infrastructure costs

**Disadvantages:**

- 📊 No usage tracking or cost analytics
- 🔄 No automatic failover or load balancing
- 👥 Manual API key distribution for teams
- 🎯 Single provider only

### Estimated Setup Time

**5 minutes** or less

---

## Pattern B: Corporate Proxy

### Architecture

```
┌──────────────┐
│  Claude Code │
└──────┬───────┘
       │ HTTP/HTTPS
       ▼
┌─────────────────┐
│ Corporate Proxy │
│ (Squid, etc.)   │
└────────┬────────┘
         │ HTTPS
         ▼
┌────────────────────┐
│ Provider API       │
│ • Anthropic        │
│ • Bedrock          │
│ • Vertex AI        │
└────────────────────┘
```

### When to Use

✅ **Use this pattern when:**

- Your organization requires all internet traffic through a proxy
- You need network-level audit trails and compliance
- You want to enforce security policies at the network layer
- Your firewall blocks direct API access

❌ **Don't use this pattern when:**

- You're on an open network (Pattern A is simpler)
- You need usage analytics (add Pattern C for gateway)
- Proxy adds unacceptable latency to API calls

### Configuration

```bash
# Set proxy environment variables
export HTTPS_PROXY="http://proxy.company.com:8080"
export HTTP_PROXY="http://proxy.company.com:8080"

# Optional: Bypass proxy for local services
export NO_PROXY="localhost,127.0.0.1,.company.com"

# For authenticated proxies
export HTTPS_PROXY="http://username:password@proxy.company.com:8080"
```

**Alternative: System-level proxy** (varies by OS)

### Pros & Cons

**Advantages:**

- 🔒 Network-level security enforcement
- 📝 Centralized audit logs at proxy level
- 🏢 Complies with corporate security policies
- 🛡️ Can inspect/filter traffic (if SSL interception configured)

**Disadvantages:**

- 🐌 Adds latency (proxy hop overhead)
- ⚙️ Requires proxy infrastructure and maintenance
- 🔧 More complex troubleshooting (network layer issues)
- 📊 Still no usage/cost tracking

### Estimated Setup Time

**10-15 minutes** (depends on proxy configuration complexity)

---

## Pattern C: LLM Gateway (Recommended)

### Architecture

```
┌──────────────┐
│  Claude Code │
└──────┬───────┘
       │ HTTP
       ▼
┌─────────────────────────────────┐
│ LiteLLM Proxy Gateway           │
│ • Cost tracking                 │
│ • Load balancing                │
│ • Multi-provider routing        │
│ • Usage analytics               │
└──────┬─────────────────┬────────┘
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│ Anthropic API│  │ Vertex AI    │
└──────────────┘  └──────────────┘
```

### When to Use

✅ **Use this pattern when:**

- You need cost tracking and usage analytics
- You want to use multiple model providers
- You need load balancing or automatic failover
- You're managing LLM access for a team or organization
- You want centralized rate limiting and quotas

❌ **Don't use this pattern when:**

- You only need a single API call occasionally (Pattern A is simpler)
- You can't run an additional service (resource constraints)
- Your network forbids local proxies (use enterprise gateway)

### Configuration

**1. Install LiteLLM:**

```bash
pip install litellm google-cloud-aiplatform
```

**2. Create config file (`litellm_config.yaml`):**

```yaml
model_list:
  - model_name: gemini-2.5-flash
    litellm_params:
      model: vertex_ai/gemini-2.5-flash
      vertex_project: YOUR_PROJECT_ID
      vertex_location: us-central1

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
```

**3. Start gateway:**

```bash
export LITELLM_MASTER_KEY="sk-1234567890"
litellm --config litellm_config.yaml --port 4000
```

**4. Configure Claude Code:**

```bash
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-1234567890"
```

### Pros & Cons

**Advantages:**

- 📊 Complete usage tracking and cost analytics
- 🔄 Automatic load balancing and failover
- 🌍 Multi-provider support (Anthropic, Bedrock, Vertex, OpenAI)
- 💰 Cost optimization through routing strategies
- 👥 Team management with per-user API keys
- 🎛️ Centralized rate limiting and quotas
- 📈 Real-time monitoring and dashboards

**Disadvantages:**

- ⚙️ Additional service to run and maintain
- 💻 Requires compute resources (minimal: ~100MB RAM)
- 🔍 One more component to troubleshoot
- 🌐 Single point of failure (mitigate with HA deployment)

### Estimated Setup Time

**15-20 minutes** for basic setup (see quickstart.md)

---

## Pattern D: Corporate Proxy + LLM Gateway (Enterprise)

### Architecture

```
┌──────────────┐
│  Claude Code │
└──────┬───────┘
       │ HTTP
       ▼
┌─────────────────┐
│ Corporate Proxy │
└────────┬────────┘
         │ HTTPS
         ▼
┌────────────────────────────┐
│ LiteLLM Gateway (Hosted)   │
│ • Enterprise authentication│
│ • SSO integration          │
│ • Compliance policies      │
└──────┬───────────┬─────────┘
       │           │
       ▼           ▼
┌──────────┐  ┌─────────────┐
│ Bedrock  │  │ Vertex AI   │
└──────────┘  └─────────────┘
```

### When to Use

✅ **Use this pattern when:**

- You need BOTH proxy compliance AND gateway features
- Your organization has strict network security policies
- You want centralized LLM access control across the enterprise
- You need SOC2, HIPAA, or similar compliance
- Multiple teams need shared gateway infrastructure

❌ **Don't use this pattern when:**

- You're doing personal development (Pattern C is simpler)
- You don't have proxy requirements (use Pattern C directly)
- Setup complexity outweighs benefits for your use case

### Configuration

**1. Corporate Proxy:**

```bash
export HTTPS_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1"
```

**2. Gateway (Hosted by IT/Platform team):**

```yaml
# litellm_config.yaml (on gateway server)
model_list:
  - model_name: gemini-flash
    litellm_params:
      model: vertex_ai/gemini-2.5-flash
      vertex_project: company-prod-project
      vertex_location: us-central1

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  # Optional: Database for request logging
  database_url: postgresql://user:pass@db-server/litellm
```

**3. Claude Code:**

```bash
export ANTHROPIC_BASE_URL="https://llm-gateway.company.com"
export ANTHROPIC_AUTH_TOKEN="<enterprise-token-from-vault>"
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1  # Gateway handles auth
```

### Pros & Cons

**Advantages:**

- 🏢 Maximum compliance (network + application layers)
- 🔒 Enterprise-grade security (SSO, audit trails)
- 📊 Centralized governance and cost tracking
- 👥 Multi-team support with proper isolation
- 🔍 Complete visibility and control
- 🛡️ Defense in depth (multiple security layers)

**Disadvantages:**

- 🔧 Most complex setup and maintenance
- 🐌 Highest latency (multiple hops)
- 💰 Most expensive (proxy + gateway infrastructure)
- 👥 Requires coordination between teams (network, platform, security)
- 🔍 Complex troubleshooting (multiple failure points)

### Estimated Setup Time

**30-60 minutes** (plus coordination time with IT/networking teams)

---

## Decision Matrix

| Criteria                     | Pattern A | Pattern B | Pattern C | Pattern D |
|------------------------------|:---------:|:---------:|:---------:|:---------:|
| **Setup Complexity**         | ⭐        | ⭐⭐      | ⭐⭐⭐    | ⭐⭐⭐⭐  |
| **Maintenance Effort**       | ⭐        | ⭐⭐      | ⭐⭐⭐    | ⭐⭐⭐⭐  |
| **Cost Tracking**            | ❌        | ❌        | ✅        | ✅        |
| **Multi-Provider Support**   | ❌        | ❌        | ✅        | ✅        |
| **Load Balancing**           | ❌        | ❌        | ✅        | ✅        |
| **Corporate Compliance**     | ❌        | ✅        | ❌        | ✅        |
| **Network Audit Trails**     | ❌        | ✅        | ❌        | ✅        |
| **Response Latency**         | Lowest    | +20-50ms  | +10-30ms  | +30-100ms |
| **Infrastructure Cost**      | $0        | $-$$      | $         | $$-$$$    |
| **Best For**                 | Personal  | Enterprise| Teams     | Enterprise|

---

## Migration Paths

### From Pattern A → Pattern C

**Add gateway for cost tracking:**

1. Install LiteLLM locally
2. Create config with your current provider
3. Update `ANTHROPIC_BASE_URL` to point to gateway
4. No changes to API calls or code

**Rollback:** Simply remove `ANTHROPIC_BASE_URL` environment variable

### From Pattern B → Pattern D

**Add gateway behind proxy:**

1. Deploy LiteLLM gateway (local or hosted)
2. Configure gateway to use proxy for outbound calls
3. Update Claude Code to point to gateway instead of API
4. Proxy configuration remains unchanged

### From Pattern C → Pattern D

**Add proxy requirement:**

1. Set `HTTPS_PROXY` environment variable
2. Add gateway URL to `NO_PROXY` if local
3. No gateway configuration changes needed

---

## FAQs

### Q: Which pattern is most common?

**A:** Pattern C (LLM Gateway) is most common for teams and organizations. Pattern A (Direct) is common for individual developers.

### Q: Can I use multiple patterns?

**A:** Yes! For example:

- Dev environment: Pattern A (direct access)
- Staging: Pattern C (local gateway)
- Production: Pattern D (enterprise setup)

### Q: What if I'm unsure which pattern to choose?

**A:** Start with **Pattern A** for simplicity. If you later need cost tracking or multi-provider support, migrate to **Pattern C**. Enterprise requirements naturally lead to **Pattern D**.

### Q: How do I test if my chosen pattern works?

**A:** Run these verification steps:

```bash
# 1. Check configuration
./scripts/check-status.sh

# 2. Test gateway health (Patterns C & D)
./scripts/health-check.sh

# 3. Test end-to-end
claude "Hello, test!"
```

---

## Next Steps

Once you've chosen a pattern:

1. **Pattern A**: No additional setup needed
2. **Pattern B**: Configure proxy settings, then test connectivity
3. **Pattern C**: Follow the [Basic LiteLLM Setup Guide](../examples/us1-quickstart-basic.md)
4. **Pattern D**: Coordinate with IT team, then follow [Enterprise Integration Guide](../examples/us2-enterprise-integration.md)

---

## Related Documentation

- [Environment Variables Reference](./env-vars-reference.md)
- [Security Best Practices](../examples/us2-security-best-practices.md)
- [Troubleshooting Guide](../examples/us1-troubleshooting.md)
- [Quickstart Guide](../quickstart.md)
