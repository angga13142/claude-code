# Deployment Patterns Comparison

**Decision matrix for choosing the right Claude Code + LLM Gateway deployment pattern.**

---

## Quick Decision Matrix

| Factor                   | Direct     | Local Gateway | Corp Proxy | Proxy+Gateway | Enterprise Gateway |
| ------------------------ | ---------- | ------------- | ---------- | ------------- | ------------------ |
| **Setup Time**           | 5 min      | 10-15 min     | 15-20 min  | 20-30 min     | 30-60 min          |
| **Complexity**           | Low        | Low           | Medium     | Medium        | High               |
| **Model Switching**      | Manual     | Easy          | Manual     | Easy          | Easy               |
| **Caching**              | No         | Yes           | No         | Yes           | Yes                |
| **Cost Optimization**    | No         | Yes           | No         | Yes           | Yes                |
| **Corporate Compliance** | No         | No            | Yes        | Yes           | Yes                |
| **Multi-Provider**       | No         | Yes           | Limited    | Yes           | Yes                |
| **Team Sharing**         | No         | No            | No         | Optional      | Yes                |
| **Best For**             | Individual | Developer     | Corporate  | Enterprise    | Large Teams        |

---

## Pattern 1: Direct Provider Access

### Architecture

```
┌─────────────┐
│ Claude Code │
└──────┬──────┘
       │
       ↓
┌─────────────────┐
│ Provider API    │
│ (Anthropic)     │
└─────────────────┘
```

### Configuration

```bash
# No gateway needed
export ANTHROPIC_API_KEY="sk-ant-api03-..."
# ANTHROPIC_BASE_URL not set (uses default)
```

### Characteristics

**Pros**:

- ✅ Simplest setup (5 minutes)
- ✅ Lowest latency (direct connection)
- ✅ No infrastructure maintenance
- ✅ Official support from provider

**Cons**:

- ❌ No caching (repeated requests cost money)
- ❌ No model switching without code changes
- ❌ No cost optimization
- ❌ Hard to add fallback providers
- ❌ No usage analytics
- ❌ Single provider lock-in

**Use Cases**:

- Individual developers
- Quick prototyping
- Single-provider scenarios
- No corporate requirements

**Cost Impact**: Baseline (100%)

---

## Pattern 2: Local Gateway

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Claude Code │────→│   LiteLLM    │────→│ Provider(s) │
│             │     │   Gateway    │     │             │
└─────────────┘     │ (localhost)  │     └─────────────┘
                    └──────────────┘
```

### Configuration

```bash
# Claude Code
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_API_KEY="sk-local-gateway"

# Start gateway
litellm --config templates/litellm-complete.yaml --port 4000
```

### Characteristics

**Pros**:

- ✅ Easy model switching (config change only)
- ✅ Response caching (60-90% cost savings)
- ✅ Multi-provider support (8 models)
- ✅ Usage analytics built-in
- ✅ Fallback/retry logic
- ✅ Local control (no network dependency)

**Cons**:

- ❌ Requires gateway setup/maintenance
- ❌ Gateway must run locally
- ❌ Uses local resources (memory/CPU)
- ❌ No team sharing

**Use Cases**:

- Developers wanting flexibility
- Cost-conscious individuals
- Multi-model experimentation
- Local development environments

**Cost Impact**: 40-70% (with caching)

**Setup Guide**: `examples/us1-quickstart-basic.md`

---

## Pattern 3: Corporate Proxy Only

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Claude Code │────→│  Corporate   │────→│ Provider    │
│             │     │    Proxy     │     │   API       │
└─────────────┘     │ (mandatory)  │     └─────────────┘
                    └──────────────┘
```

### Configuration

```bash
# Proxy configuration
export HTTPS_PROXY="http://proxy.corp.example.com:8080"
export NO_PROXY="localhost,127.0.0.1,.internal"

# Provider API key
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Characteristics

**Pros**:

- ✅ Meets corporate firewall requirements
- ✅ Audit logging (network level)
- ✅ Compliance ready
- ✅ Simple (just proxy config)

**Cons**:

- ❌ No caching (full costs)
- ❌ No model switching
- ❌ Added latency (~20-50ms)
- ❌ SSL inspection complexity
- ❌ Proxy authentication required

**Use Cases**:

- Corporate networks with mandatory proxy
- Compliance-required environments
- Quick corporate setup without gateway

**Cost Impact**: 100% (baseline, no optimization)

**Setup Guide**: `examples/us4-corporate-proxy-setup.md`

---

## Pattern 4: Proxy + Gateway (Recommended Enterprise)

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│ Claude Code │────→│   LiteLLM    │────→│  Corporate   │────→│ Provider(s) │
│             │     │   Gateway    │     │    Proxy     │     │             │
└─────────────┘     │ (localhost)  │     │ (firewall)   │     └─────────────┘
                    └──────────────┘     └──────────────┘
```

### Configuration

```bash
# Claude Code → Gateway (bypass proxy for local)
export ANTHROPIC_BASE_URL="http://localhost:4000"
export NO_PROXY="localhost,127.0.0.1"

# Gateway → Providers (via proxy)
export HTTPS_PROXY="http://proxy.corp.example.com:8080"

# Start gateway
litellm --config templates/proxy/proxy-gateway-config.yaml --port 4000
```

### Characteristics

**Pros**:

- ✅ Best of both worlds (gateway + compliance)
- ✅ Caching benefits (40-70% savings)
- ✅ Corporate compliance
- ✅ Multi-provider support
- ✅ Fallback/retry logic
- ✅ Usage analytics

**Cons**:

- ❌ Most complex setup
- ❌ Proxy + gateway latency
- ❌ Requires proxy auth management
- ❌ SSL certificate handling

**Use Cases**:

- **Most common enterprise setup**
- Corporate developers needing flexibility
- Cost optimization + compliance
- Multi-provider scenarios

**Cost Impact**: 40-70% (with caching)

**Setup Guide**: `examples/us4-corporate-proxy-setup.md`

---

## Pattern 5: Shared Enterprise Gateway

### Architecture

```
┌────────────┐  ┌────────────┐  ┌────────────┐
│Developer 1 │  │Developer 2 │  │Developer 3 │
└─────┬──────┘  └─────┬──────┘  └─────┬──────┘
      │               │               │
      └───────────────┼───────────────┘
                      ↓
            ┌─────────────────┐
            │ Shared LiteLLM  │
            │ Gateway Server  │
            │ (internal.corp) │
            └────────┬────────┘
                     │
                     ↓
            ┌─────────────────┐
            │   Provider(s)   │
            └─────────────────┘
```

### Configuration

```bash
# All developers use same gateway
export ANTHROPIC_BASE_URL="http://gateway.internal.corp:4000"
export ANTHROPIC_API_KEY="team-shared-token"
```

### Characteristics

**Pros**:

- ✅ Centralized management
- ✅ Shared cache (team-wide savings)
- ✅ Consistent configuration
- ✅ Easier updates/rollouts
- ✅ Better monitoring
- ✅ Cost pooling

**Cons**:

- ❌ Single point of failure
- ❌ Network dependency
- ❌ Requires infrastructure team
- ❌ Higher latency vs local
- ❌ Authentication/authorization needed

**Use Cases**:

- Teams of 10+ developers
- Enterprise deployments
- Centralized cost control
- Compliance/audit requirements

**Cost Impact**: 50-80% (shared cache benefits)

**Setup Guide**: `examples/us2-enterprise-integration.md`

---

## Decision Tree

```
START
  │
  ├─ Need corporate compliance?
  │   │
  │   YES → Corporate proxy required
  │   │     │
  │   │     ├─ Need cost optimization?
  │   │     │   YES → Pattern 4: Proxy + Gateway ✅
  │   │     │   NO  → Pattern 3: Proxy Only
  │   │     │
  │   │     └─ Team of 10+ people?
  │   │         YES → Pattern 5: Shared Gateway
  │   │
  │   NO  → No proxy required
  │         │
  │         ├─ Need multi-model or caching?
  │         │   YES → Pattern 2: Local Gateway ✅
  │         │   NO  → Pattern 1: Direct
  │         │
  │         └─ Team deployment?
  │             YES → Pattern 5: Shared Gateway
```

---

## Comparison by Use Case

### Solo Developer (No Corporate Requirements)

**Recommended**: Pattern 2 (Local Gateway)

**Reasoning**:

- Easy setup (10-15 min)
- Model switching flexibility
- Cost savings from caching
- No infrastructure requirements

**Alternative**: Pattern 1 (Direct) if only using Anthropic

### Corporate Developer (Mandatory Proxy)

**Recommended**: Pattern 4 (Proxy + Gateway)

**Reasoning**:

- Meets compliance requirements
- Maintains cost optimization
- Supports multiple providers
- Caching despite proxy

**Alternative**: Pattern 3 (Proxy Only) for quick setup

### Enterprise Team (10+ Developers)

**Recommended**: Pattern 5 (Shared Gateway)

**Reasoning**:

- Centralized control
- Shared cache benefits
- Easier management
- Better monitoring

**Alternative**: Pattern 4 (Proxy + Gateway) per developer if infrastructure not available

### Startup/Small Team (Cost-Sensitive)

**Recommended**: Pattern 2 (Local Gateway)

**Reasoning**:

- Maximum cost savings (caching)
- No infrastructure costs
- Flexibility to experiment
- Easy to scale later

### Compliance-Heavy Organization (Finance, Healthcare)

**Recommended**: Pattern 5 (Shared Gateway) with Pattern 3 (Proxy)

**Reasoning**:

- Centralized audit logging
- Network-level controls
- Consistent security policies
- DLP integration

---

## Migration Paths

### Direct → Local Gateway

**Steps**:

1. Install LiteLLM: `pip install litellm`
2. Copy template: `cp templates/litellm-complete.yaml config/`
3. Set env vars: `export ANTHROPIC_BASE_URL="http://localhost:4000"`
4. Start gateway: `litellm --config config/litellm-complete.yaml --port 4000`
5. Test: `claude /status`

**Time**: 15 minutes  
**Risk**: Low (can revert by unsetting ANTHROPIC_BASE_URL)

### Local Gateway → Proxy + Gateway

**Steps**:

1. Configure proxy env vars: `export HTTPS_PROXY="..."`
2. Install CA certificate (if needed)
3. Update gateway config to use proxy
4. Add NO_PROXY for localhost
5. Restart gateway
6. Test: `python tests/test-proxy-gateway.py`

**Time**: 30 minutes  
**Risk**: Medium (proxy authentication issues)

### Proxy + Gateway → Shared Gateway

**Steps**:

1. Deploy gateway to internal server
2. Configure network access (firewall rules)
3. Set up authentication (API keys)
4. Update all developers: `export ANTHROPIC_BASE_URL="http://gateway.internal:4000"`
5. Test from multiple machines
6. Migrate gradually (A/B test)

**Time**: 2-4 hours  
**Risk**: High (network, authentication, rollout)

---

## Cost Comparison (100 Developers, 1M tokens/day each)

| Pattern                     | Monthly Cost        | Savings  | Notes           |
| --------------------------- | ------------------- | -------- | --------------- |
| Direct (Pattern 1)          | $1,500,000          | Baseline | No optimization |
| Local Gateway (Pattern 2)   | $450,000 - $900,000 | 40-70%   | Per-user cache  |
| Proxy Only (Pattern 3)      | $1,500,000          | 0%       | No caching      |
| Proxy + Gateway (Pattern 4) | $450,000 - $900,000 | 40-70%   | Per-user cache  |
| Shared Gateway (Pattern 5)  | $300,000 - $750,000 | 50-80%   | Shared cache    |

**Assumptions**:

- Anthropic Claude Sonnet: $3/$15 per 1M tokens (input/output)
- Average input/output ratio: 1:2
- Cache hit rate: 30% (conservative) to 60% (optimized)
- Shared cache provides 10-20% additional benefit

---

## Performance Comparison

| Pattern                    | Latency (P50) | Latency (P99) | Throughput |
| -------------------------- | ------------- | ------------- | ---------- |
| Direct                     | 400ms         | 800ms         | High       |
| Local Gateway (cached)     | 50ms          | 100ms         | Very High  |
| Local Gateway (uncached)   | 420ms         | 850ms         | High       |
| Proxy Only                 | 450ms         | 900ms         | Medium     |
| Proxy + Gateway (cached)   | 70ms          | 150ms         | High       |
| Proxy + Gateway (uncached) | 480ms         | 950ms         | Medium     |
| Shared Gateway (cached)    | 100ms         | 200ms         | High       |
| Shared Gateway (uncached)  | 500ms         | 1000ms        | Medium     |

**Notes**:

- Cache hit latency: ~50-100ms
- Proxy overhead: ~20-50ms
- Network to shared gateway: ~50ms
- Provider API: ~400ms baseline

---

## Recommendation Summary

**Default Recommendation**: **Pattern 4 (Proxy + Gateway)**

**Why**:

- Works in most corporate environments
- Provides cost optimization
- Supports compliance requirements
- Flexible for multi-provider
- Proven at scale

**When to Choose Others**:

- **Pattern 1**: Non-corporate, single provider, minimal setup
- **Pattern 2**: No corporate proxy, want flexibility
- **Pattern 3**: Corporate mandated, temporary/quick setup
- **Pattern 5**: Large teams (10+), have infrastructure

---

## References

- **Pattern 1 Guide**: Direct API access (official Anthropic docs)
- **Pattern 2 Guide**: `examples/us1-quickstart-basic.md`
- **Pattern 3 Guide**: `examples/us4-corporate-proxy-setup.md` (proxy-only section)
- **Pattern 4 Guide**: `examples/us4-corporate-proxy-setup.md`
- **Pattern 5 Guide**: `examples/us2-enterprise-integration.md`
- **Cost Optimization**: `examples/us3-cost-optimization.md`
- **Architecture**: `examples/us4-proxy-gateway-architecture.md`

---

**Last Updated**: 2025-12-01  
**Version**: 1.0.0
