# Third-Party Gateway Warning Template

**Purpose**: Standardized warning message for third-party gateway configurations  
**Usage**: Include this warning in ALL third-party gateway documentation and templates  
**Requirement**: FR-007, FR-038 - 100% appearance in third-party gateway content (SC-006)

---

## Standard Warning Text

```
⚠️ THIRD-PARTY NOTICE

This configuration uses [GATEWAY_NAME], a third-party solution not developed
or maintained by Anthropic.

- Anthropic does not provide support for [GATEWAY_NAME]
- Configuration may change without notice as [GATEWAY_NAME] updates
- For issues, bugs, or questions, contact [GATEWAY_NAME] support or community
- Review [GATEWAY_NAME] security and privacy policies before use
- Anthropic cannot guarantee compatibility with future [GATEWAY_NAME] versions

For official Anthropic support, use direct API access or Anthropic-supported
deployment patterns documented at: https://docs.anthropic.com
```

---

## Gateway-Specific Warnings

### LiteLLM

```
⚠️ THIRD-PARTY NOTICE

This configuration uses LiteLLM, a third-party proxy not developed or
maintained by Anthropic.

- Anthropic does not provide support for LiteLLM
- LiteLLM configuration may change without notice
- For issues, contact LiteLLM support: https://github.com/BerriAI/litellm
- Review LiteLLM security practices before production use
- Anthropic cannot guarantee compatibility with future LiteLLM versions

For official Anthropic support, use direct API access.
```

### TrueFoundry

```
⚠️ THIRD-PARTY NOTICE

This configuration uses TrueFoundry LLM Gateway, a third-party solution not
developed or maintained by Anthropic.

- Anthropic does not provide support for TrueFoundry
- TrueFoundry configuration may change without notice
- For issues, contact TrueFoundry support: support@truefoundry.com
- Review TrueFoundry security and privacy policies before use
- Anthropic cannot guarantee compatibility with future TrueFoundry versions

For official Anthropic support, use direct API access.
```

### Zuplo

```
⚠️ THIRD-PARTY NOTICE

This configuration uses Zuplo API Gateway, a third-party solution not
developed or maintained by Anthropic.

- Anthropic does not provide support for Zuplo
- Zuplo configuration may change without notice
- For issues, contact Zuplo support: support@zuplo.com
- Review Zuplo security and privacy policies before use: https://zuplo.com/legal
- Anthropic cannot guarantee compatibility with future Zuplo versions

For official Anthropic support, use direct API access.
```

### MintMCP

```
⚠️ THIRD-PARTY NOTICE

This configuration uses MintMCP, a third-party Model Context Protocol gateway
not developed or maintained by Anthropic.

- Anthropic does not provide support for MintMCP
- MintMCP configuration may change without notice
- For issues, contact MintMCP community: https://github.com/mintmcp
- Review MintMCP security practices before production use
- Anthropic cannot guarantee compatibility with future MintMCP versions

For official Anthropic support, use direct API access.
```

### Custom Enterprise Gateway

```
⚠️ THIRD-PARTY NOTICE

This configuration is for custom enterprise gateways not developed or
maintained by Anthropic.

- Anthropic does not provide support for your custom gateway
- Gateway configuration is your organization's responsibility
- For issues, contact your internal platform/DevOps team
- Ensure your gateway meets Anthropic API compatibility requirements
- Anthropic cannot guarantee compatibility with custom gateway implementations

For official Anthropic support, use direct API access.

Required Compatibility Criteria:
- Support Messages API endpoints (/v1/messages)
- Forward required headers (anthropic-version, anthropic-beta)
- Support Server-Sent Events (SSE) for streaming
- Preserve request/response body JSON structure
- Return standard HTTP status codes

See gateway compatibility checklist: examples/us2-compatibility-checklist.md
```

---

## Usage Guidelines

### When to Include Warning

Include this warning in:

- ✅ **ALL** third-party gateway configuration files (YAML, JSON)
- ✅ **ALL** third-party gateway documentation (Markdown, README)
- ✅ **ALL** third-party gateway setup guides and quickstarts
- ✅ **ALL** third-party gateway examples and templates
- ✅ **ALL** responses from LLM Gateway Configuration Assistant about third-party solutions

Do NOT include warning for:

- ❌ Direct Anthropic API access
- ❌ Anthropic-developed tools (Claude Code itself)
- ❌ Official Anthropic documentation

### Warning Placement

**In YAML/JSON Configuration Files**:

```yaml
# ===================================================================
# ⚠️ THIRD-PARTY NOTICE
# This configuration uses [GATEWAY_NAME], a third-party solution not
# developed or maintained by Anthropic.
# - Anthropic does not provide support for [GATEWAY_NAME]
# - For issues, contact [GATEWAY_NAME] support
# - Review [GATEWAY_NAME] security and privacy policies before use
# ===================================================================

model_list:
  - model_name: claude-3-5-sonnet-20241022
    ...
```

**In Markdown Documentation**:

```markdown
## Quick Start

1. Deploy [GATEWAY_NAME]
2. Set environment variables
3. Verify connection

⚠️ **THIRD-PARTY NOTICE**

This configuration uses [GATEWAY_NAME], a third-party solution not developed
or maintained by Anthropic. Anthropic does not provide support for
[GATEWAY_NAME]. For issues, contact [GATEWAY_NAME] support.

## Configuration Steps
...
```

**In Assistant Responses**:

```
I can help you configure Claude Code with [GATEWAY_NAME].

⚠️ IMPORTANT: [GATEWAY_NAME] is a third-party solution. Anthropic does not
provide support for [GATEWAY_NAME]. For issues, contact [GATEWAY_NAME] support.

Here's the configuration...
```

---

## Legal Disclaimer Template

For production documentation, consider adding this legal disclaimer:

```
LEGAL DISCLAIMER

The information provided for third-party gateway configuration is offered "as
is" without warranty of any kind, express or implied. Anthropic PBC makes no
representations or warranties regarding the accuracy, reliability, or
completeness of third-party gateway configurations.

USE AT YOUR OWN RISK: Third-party gateways are not controlled, endorsed, or
supported by Anthropic. Users assume all risks associated with third-party
gateway usage, including but not limited to:

- Service availability and uptime
- Data security and privacy
- API compatibility and breaking changes
- Configuration errors and misconfigurations
- Cost and billing accuracy

INDEMNIFICATION: Users agree to indemnify and hold harmless Anthropic PBC from
any claims, damages, or liabilities arising from the use of third-party
gateways.

For supported configurations, please use direct Anthropic API access as
documented at: https://docs.anthropic.com
```

---

## Verification Checklist

Use this checklist to ensure compliance with FR-038 and SC-006:

- [ ] Warning appears in ALL third-party gateway configuration files
- [ ] Warning appears in ALL third-party gateway documentation
- [ ] Warning appears at the top of setup guides (within first 3 sections)
- [ ] Warning clearly states Anthropic does not support the third-party solution
- [ ] Warning directs users to third-party support channels
- [ ] Warning includes security/privacy policy review recommendation
- [ ] Warning mentions potential for breaking changes
- [ ] Legal disclaimer included in production documentation (optional but recommended)

---

## Examples of Compliant Usage

### Example 1: Configuration File Header

```yaml
# TrueFoundry LLM Gateway Configuration for Claude Code
# Purpose: Enterprise-grade gateway with centralized authentication
# Documentation: https://www.truefoundry.com/docs/llm-gateway
#
# ⚠️ THIRD-PARTY NOTICE
# TrueFoundry is a third-party solution not developed or maintained by Anthropic.
# - Anthropic does not provide support for TrueFoundry
# - Configuration may change without notice
# - For issues, contact TrueFoundry support
# - Review TrueFoundry security and privacy policies before use
# ===================================================================

model_list:
  - model_name: claude-3-5-sonnet-20241022
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_base: ${ANTHROPIC_BASE_URL}
      api_key: ${ANTHROPIC_AUTH_TOKEN}
```

### Example 2: Setup Guide

```markdown
# Setting Up Claude Code with Zuplo Gateway

This guide shows how to configure Claude Code to use Zuplo API Gateway
for centralized API management.

## Prerequisites

- Zuplo account with API Gateway deployed
- Claude Code installed
- Basic knowledge of environment variables

⚠️ **THIRD-PARTY NOTICE**

Zuplo is a third-party solution not developed or maintained by Anthropic.
Anthropic does not provide support for Zuplo. For issues, contact
Zuplo support at support@zuplo.com. Review Zuplo's security and privacy
policies before use.

## Step 1: Configure Environment Variables
...
```

### Example 3: Assistant Response

```
User: How do I configure Claude Code with LiteLLM?
