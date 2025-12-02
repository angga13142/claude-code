# US3: Provider Selection Decision Tree

**User Story**: US3 - Multi-Provider Gateway Configuration (Priority: P3)  
**Purpose**: Framework for choosing the right provider(s) for your use case  
**Audience**: Platform engineers, technical architects, engineering managers

---

## Quick Decision Flow

```
START: Which Claude provider should I use?
│
├─ Q1: Are you already on a cloud platform?
│  ├─ AWS → **Consider Bedrock** (seamless IAM integration)
│  ├─ GCP → **Consider Vertex AI** (unified billing)
│  └─ No → Continue to Q2
│
├─ Q2: What's your primary optimization goal?
│  ├─ **Lowest cost** → Anthropic Direct + Prompt Caching
│  ├─ **Highest availability** → Multi-provider (all three)
│  ├─ **Simplest setup** → Anthropic Direct only
│  └─ **Compliance/governance** → Continue to Q3
│
├─ Q3: Do you need specific compliance certifications?
│  ├─ **SOC 2 Type II** → All providers support
│  ├─ **HIPAA** → Bedrock or Vertex AI (BAA available)
│  ├─ **FedRAMP** → Bedrock GovCloud
│  └─ **GDPR** → All support, choose EU regions
│
└─ Q4: What's your request volume?
   ├─ <1000 req/day → Anthropic Direct (simple, cost-effective)
   ├─ 1k-100k req/day → Anthropic Direct + one backup provider
   └─ >100k req/day → Multi-provider with load balancing
```

---

## Provider Comparison Matrix

| Criteria                  | Anthropic Direct | AWS Bedrock        | Google Vertex AI      |
| ------------------------- | ---------------- | ------------------ | --------------------- |
| **Cost (base)**           | ★★★ Lowest       | ★★★ Same as Direct | ★★ 10-20% markup      |
| **Cost (with caching)**   | ★★★★ Cheapest    | ★★ No caching      | ★★ No caching         |
| **Setup Complexity**      | ★★★ Simplest     | ★★ Moderate (IAM)  | ★★ Moderate (IAM)     |
| **Availability SLA**      | 99.9%            | 99.9%              | 99.9%                 |
| **Latency**               | ★★★ Lowest       | ★★ Regional        | ★★ Regional           |
| **Regional Coverage**     | Global           | 8 regions          | 6 regions             |
| **IAM Integration**       | ❌ None          | ✅ AWS IAM         | ✅ GCP IAM            |
| **Billing Integration**   | Separate         | AWS Consolidated   | GCP Billing           |
| **HIPAA/BAA**             | ❌ No            | ✅ Yes             | ✅ Yes                |
| **FedRAMP**               | ❌ No            | ✅ GovCloud        | ❌ No                 |
| **Multi-Model Access**    | Claude only      | Claude + others    | Claude + Model Garden |
| **Prompt Caching**        | ✅ Yes           | ❌ No              | ❌ No                 |
| **Rate Limits (default)** | Tier-based       | Account-based      | Project-based         |
| **Monitoring**            | Console only     | CloudWatch         | Cloud Monitoring      |

---

## Decision Scenarios

### Scenario 1: Startup / Small Team (< 10 engineers)

**Requirements**:

- Low volume (< 1000 requests/day)
- Cost-sensitive
- Fast setup
- No compliance requirements

**Recommendation**: **Anthropic Direct Only**

**Configuration**:

```yaml
model_list:
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
```

**Rationale**:

- ✅ Simplest setup (single API key)
- ✅ Lowest cost (prompt caching available)
- ✅ No cloud account needed
- ✅ Fast time-to-value

**Estimated Monthly Cost**: $50-200 (depending on usage)

---

### Scenario 2: AWS-Native Company

**Requirements**:

- Already using AWS extensively
- Need consolidated billing
- IAM-based access control
- Compliance certifications (SOC 2, HIPAA)

**Recommendation**: **AWS Bedrock Primary + Anthropic Direct Fallback**

**Configuration**:

```yaml
model_list:
  - model_name: claude-3-5-sonnet-bedrock
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    priority: 10 # Primary

  - model_name: claude-3-5-sonnet-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 1 # Fallback
```

**Rationale**:

- ✅ Seamless IAM integration
- ✅ Unified AWS billing
- ✅ CloudWatch monitoring
- ✅ HIPAA/BAA support
- ✅ Fallback to Anthropic Direct for high availability

**Estimated Monthly Cost**: Same as Anthropic Direct (no markup) + AWS overhead

---

### Scenario 3: GCP-Native Company

**Requirements**:

- Already using GCP extensively
- Need access to Model Garden models
- Unified billing with GCP
- Multi-model experimentation

**Recommendation**: **Vertex AI Primary + Anthropic Direct Fallback**

**Configuration**:

```yaml
model_list:
  # Claude via Vertex AI
  - model_name: claude-3-5-sonnet-vertex
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    priority: 10

  # Model Garden models
  - model_name: gemini-2.5-pro
    litellm_params:
      model: vertex_ai/gemini-2.5-pro
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: us-central1
    priority: 5

  # Fallback to Anthropic Direct
  - model_name: claude-3-5-sonnet-anthropic
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 1
```

**Rationale**:

- ✅ Access to Gemini, DeepSeek, Llama, etc.
- ✅ Unified GCP billing
- ✅ Cloud Monitoring integration
- ✅ Workload Identity for GKE deployments
- ⚠ 10-20% cost markup (acceptable for unified platform)

**Estimated Monthly Cost**: Base price + 10-20% Vertex AI markup

---

### Scenario 4: Enterprise with Compliance Requirements

**Requirements**:

- HIPAA compliance mandatory
- SOC 2 Type II required
- High availability (99.95%+)
- Multi-region deployment
- Audit logging

**Recommendation**: **Multi-Provider with Geographic Distribution**

**Configuration**:

```yaml
model_list:
  # US: AWS Bedrock (HIPAA-compliant)
  - model_name: claude-us-east
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
    priority: 10

  - model_name: claude-us-west
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-west-2
    priority: 9

  # EU: Vertex AI (GDPR-compliant)
  - model_name: claude-eu
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: europe-west1
    priority: 10

  # Global fallback
  - model_name: claude-global
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 1

router_settings:
  routing_strategy: least-busy
  allowed_fails: 2
  cooldown_time: 60
```

**Rationale**:

- ✅ HIPAA/BAA through Bedrock
- ✅ GDPR compliance via EU regions
- ✅ Multi-region redundancy
- ✅ Automatic failover
- ✅ Provider diversity reduces vendor lock-in

**Estimated Monthly Cost**: Higher due to multi-provider overhead, but justified by compliance and availability requirements

---

### Scenario 5: Cost-Optimized High Volume

**Requirements**:

- > 100,000 requests/day
- Cost is primary concern
- Performance is secondary
- Simple use cases (Q&A, summaries)

**Recommendation**: **Model Tiering + Anthropic Direct with Caching**

**Configuration**:

```yaml
litellm_settings:
  anthropic_beta: "prompt-caching-2024-07-31"

model_list:
  # Tier 1: High-volume simple tasks (80% of traffic)
  - model_name: claude-3-haiku
    litellm_params:
      model: anthropic/claude-3-haiku-20240307
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 10
    rpm: 200

  # Tier 2: Medium complexity (15% of traffic)
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 5
    rpm: 50

  # Tier 3: Complex tasks (5% of traffic)
  - model_name: claude-3-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
    priority: 1
    rpm: 20
```

**Application Logic**:

```python
def select_model(task_complexity: str) -> str:
    if task_complexity == "simple":
        return "claude-3-haiku"
    elif task_complexity == "medium":
        return "claude-3-5-sonnet"
    else:
        return "claude-3-opus"
```

**Rationale**:

- ✅ 80%+ cost reduction via model tiering
- ✅ Prompt caching for repeated contexts
- ✅ Anthropic Direct (no markup)
- ✅ Simple architecture (single provider)

**Estimated Monthly Cost**: $2,000-5,000 (vs $15,000+ without optimization)

---

### Scenario 6: Multi-Region Global Application

**Requirements**:

- Users across US, EU, APAC
- Low latency critical
- High availability required
- Compliance with regional data laws

**Recommendation**: **Geographic Provider Distribution**

**Configuration**:

```yaml
model_list:
  # US Region: Bedrock US East
  - model_name: claude-us
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1

  # EU Region: Vertex AI Europe
  - model_name: claude-eu
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: europe-west1

  # APAC Region: Vertex AI Asia
  - model_name: claude-apac
    litellm_params:
      model: vertex_ai/claude-3-5-sonnet@20241022
      vertex_project: os.environ/VERTEX_PROJECT_ID
      vertex_location: asia-southeast1
```

**Application-Level Routing**:

```python
REGION_MODELS = {
    "US": "claude-us",
    "EU": "claude-eu",
    "APAC": "claude-apac"
}

def get_model_for_user(user_region: str) -> str:
    return REGION_MODELS.get(user_region, "claude-us")  # Default to US
```

**Rationale**:

- ✅ 50-200ms latency reduction via regional endpoints
- ✅ GDPR compliance (EU data stays in EU)
- ✅ Provider diversity (reduces single point of failure)
- ✅ Cost optimization per region

---

## Provider Selection Checklist

### Step 1: Assess Current Infrastructure

- [ ] What cloud providers are you already using?
- [ ] Do you have existing IAM/authentication systems?
- [ ] What's your current billing/cost tracking setup?
- [ ] Do you have compliance certifications in place?

### Step 2: Define Requirements

- [ ] Expected request volume (requests/day)?
- [ ] Latency requirements (ms)?
- [ ] Availability requirements (%)?
- [ ] Compliance needs (HIPAA, FedRAMP, GDPR)?
- [ ] Budget constraints ($/month)?

### Step 3: Evaluate Options

- [ ] Single provider vs multi-provider?
- [ ] Need for fallback/redundancy?
- [ ] Geographic distribution required?
- [ ] Model variety needed (Gemini, Llama, etc.)?

### Step 4: Pilot & Measure

- [ ] Set up pilot configuration
- [ ] Measure cost, latency, availability
- [ ] Test failover scenarios
- [ ] Validate compliance requirements

### Step 5: Optimize & Scale

- [ ] Adjust routing strategy based on data
- [ ] Implement cost optimization (caching, tiering)
- [ ] Add monitoring and alerting
- [ ] Document runbooks for incidents

---

## Common Pitfalls to Avoid

### 1. Over-Engineering

**Symptom**: Setting up multi-provider from day 1 with <100 requests/day

**Solution**: Start simple (Anthropic Direct), add providers only when needed

---

### 2. Ignoring Latency

**Symptom**: Using single US-based provider for global users

**Solution**: Deploy regional endpoints, measure latency improvements

---

### 3. Not Testing Failover

**Symptom**: Multi-provider setup, but failover never tested

**Solution**: Run `tests/test-provider-fallback.py` regularly

---

### 4. Cost Blindness

**Symptom**: Using Opus for all tasks, monthly bill unexpectedly high

**Solution**: Implement model tiering, monitor costs weekly

---

## Next Steps

1. **Identify your scenario** from the 6 examples above
2. **Follow the setup guide**: [examples/us3-multi-provider-setup.md](./us3-multi-provider-setup.md)
3. **Configure cost optimization**: [examples/us3-cost-optimization.md](./us3-cost-optimization.md)
4. **Set up monitoring**: Enable LiteLLM analytics and provider dashboards
5. **Test thoroughly**: Run routing, fallback, and auth bypass tests

---

## Decision Support Resources

- **Provider Comparison**: See matrix at top of this document
- **Cost Calculator**: Use examples in [us3-cost-optimization.md](./us3-cost-optimization.md)
- **Setup Guides**: Provider-specific templates in `templates/multi-provider/`
- **Routing Strategies**: [templates/multi-provider/routing-strategies.md](../templates/multi-provider/routing-strategies.md)
- **Environment Variables**: [examples/us3-provider-env-vars.md](./us3-provider-env-vars.md)

---

## Additional Resources

- [Anthropic Provider Comparison](https://docs.anthropic.com/claude/docs/providers)
- [AWS Bedrock Features](https://aws.amazon.com/bedrock/features/)
- [Vertex AI Claude](https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude)
- [LiteLLM Multi-Provider Setup](https://docs.litellm.ai/docs/providers)
