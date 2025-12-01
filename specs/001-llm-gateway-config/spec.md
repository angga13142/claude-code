# Feature Specification: LLM Gateway Configuration Assistant

**Feature Branch**: `001-llm-gateway-config`  
**Created**: 2025-12-01  
**Status**: Draft  
**Input**: User description: "LLM Gateway Configuration Assistant"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic LiteLLM Gateway Setup (Priority: P1)

A developer wants to configure Claude Code to use a LiteLLM proxy for centralized API key management and usage tracking. They need step-by-step guidance to set up the gateway locally and configure Claude Code to connect through it.

**Why this priority**: Most common gateway setup for small teams and individual developers. Provides immediate value for cost tracking and basic security without complex infrastructure.

**Independent Test**: Can be fully tested by setting up a local LiteLLM instance, configuring Claude Code with the gateway URL, and successfully executing a Claude Code command that routes through the gateway with usage logged.

**Acceptance Scenarios**:

1. **Given** a developer has LiteLLM installed, **When** they request LiteLLM configuration help, **Then** the assistant provides a complete config.yaml template, startup commands, and Claude Code environment variable setup
2. **Given** Claude Code is configured with LiteLLM base URL, **When** the developer runs `claude /status`, **Then** the custom base URL is displayed confirming the gateway connection
3. **Given** a working LiteLLM gateway, **When** the developer executes a Claude Code command, **Then** the request routes through LiteLLM and usage is logged in the LiteLLM dashboard

---

### User Story 2 - Enterprise Gateway Integration (Priority: P2)

An enterprise architect needs to integrate Claude Code with their existing enterprise gateway solution (TrueFoundry, Zuplo, or custom) that handles authentication, rate limiting, and compliance policies. They need configuration guidance specific to their gateway's authentication requirements.

**Why this priority**: Critical for enterprise adoption where security policies mandate centralized gateway usage. Enables compliance with organizational standards.

**Independent Test**: Can be tested by configuring Claude Code with the enterprise gateway endpoint, verifying authentication token handling, and confirming requests pass through enterprise security controls.

**Acceptance Scenarios**:

1. **Given** an enterprise gateway requiring custom authentication headers, **When** the architect requests configuration help, **Then** the assistant provides environment variable setup including ANTHROPIC_BASE_URL and ANTHROPIC_AUTH_TOKEN with header forwarding requirements
2. **Given** Claude Code configured for enterprise gateway, **When** a request is made, **Then** all required headers (anthropic-beta, anthropic-version) are correctly forwarded through the gateway
3. **Given** enterprise gateway with rate limiting, **When** rate limits are exceeded, **Then** Claude Code displays clear error messages indicating the gateway policy enforcement

---

### User Story 3 - Multi-Provider Gateway Configuration (Priority: P3)

A platform engineer wants to configure Claude Code to work with a gateway that supports multiple LLM providers (Anthropic, Bedrock, Vertex AI) and needs to understand provider-specific environment variables and authentication bypass settings.

**Why this priority**: Advanced use case for teams using multiple model providers. Enables flexibility and cost optimization across providers.

**Independent Test**: Can be tested by configuring Claude Code with provider-specific base URLs (Bedrock and Vertex), setting authentication bypass flags, and successfully routing requests to different providers through the gateway.

**Acceptance Scenarios**:

1. **Given** a multi-provider gateway supporting Bedrock, **When** the engineer requests Bedrock gateway configuration, **Then** the assistant provides ANTHROPIC_BEDROCK_BASE_URL and CLAUDE_CODE_SKIP_BEDROCK_AUTH=1 setup
2. **Given** Claude Code configured for Vertex AI through gateway, **When** ANTHROPIC_VERTEX_BASE_URL and CLAUDE_CODE_SKIP_VERTEX_AUTH=1 are set, **Then** Claude Code routes Vertex AI requests through the gateway without attempting direct Vertex authentication
3. **Given** multiple provider configurations, **When** the engineer switches between providers, **Then** each provider correctly routes through the appropriate gateway endpoint

---

### User Story 4 - Corporate Proxy Configuration (Priority: P4)

A developer working behind a corporate proxy needs to configure Claude Code to route all requests through the HTTP/HTTPS proxy while also potentially using an LLM gateway.

**Why this priority**: Common in enterprise environments with network security policies. Essential for developers who cannot directly access external APIs.

**Independent Test**: Can be tested by setting HTTPS_PROXY environment variable, attempting Claude Code requests, and verifying successful proxy traversal with gateway routing if applicable.

**Acceptance Scenarios**:

1. **Given** a corporate network requiring proxy, **When** the developer requests proxy configuration help, **Then** the assistant provides HTTPS_PROXY environment variable setup and verification steps
2. **Given** Claude Code configured with both proxy and gateway, **When** a request is made, **Then** the request routes through corporate proxy to the LLM gateway to the provider
3. **Given** proxy authentication requirements, **When** proxy credentials are configured, **Then** Claude Code successfully authenticates to proxy and completes requests

---

### Edge Cases

- What happens when the gateway endpoint is unreachable or returns 5xx errors? (System must display clear connectivity error with troubleshooting guidance)
- How does the system handle gateway authentication token expiration? (Must detect 401/403 responses and prompt for token refresh)
- What happens when the gateway doesn't properly forward required headers (anthropic-beta, anthropic-version)? (Must detect API compatibility issues and suggest header forwarding configuration)
- How does the assistant handle conflicting configurations (e.g., both direct provider config and gateway config set)? (Must detect conflicts and recommend resolution with priority order)
- What happens when a user tries to configure a gateway that doesn't meet Claude Code API requirements? (Must validate gateway capabilities and warn about incompatibilities)
- How does the system handle cases where ANTHROPIC_BASE_URL is set but ANTHROPIC_AUTH_TOKEN is missing? (Must detect incomplete configuration and prompt for missing credentials)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Assistant MUST provide configuration templates for LiteLLM gateway setup including YAML config, startup commands, and environment variables
- **FR-002**: Assistant MUST guide users through setting ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, and provider-specific base URLs
- **FR-003**: Assistant MUST explain when to use authentication bypass flags (CLAUDE_CODE_SKIP_BEDROCK_AUTH, CLAUDE_CODE_SKIP_VERTEX_AUTH)
- **FR-004**: Assistant MUST provide verification steps using `claude /status` and debug logging (ANTHROPIC_LOG=debug)
- **FR-005**: Assistant MUST distinguish between user-level configuration (~/.claude/settings.json) and project-level configuration (.claude/settings.json)
- **FR-006**: Assistant MUST validate that suggested gateway solutions meet Claude Code API format requirements (Messages API endpoints, header forwarding)
- **FR-007**: Assistant MUST warn users when recommending third-party gateway solutions that are outside Anthropic's control
- **FR-008**: Assistant MUST provide security best practices including avoiding hardcoded API keys and using secret management tools
- **FR-009**: Assistant MUST assess user requirements (team size, security needs, multi-provider, cost tracking) before recommending specific gateway solutions
- **FR-010**: Assistant MUST provide troubleshooting guidance for common gateway configuration issues (connectivity, authentication, header forwarding)
- **FR-011**: Assistant MUST explain deployment patterns (Direct Provider Access, Corporate Proxy, LLM Gateway) with use case recommendations
- **FR-012**: Assistant MUST support configuration guidance for major gateway solutions (LiteLLM, TrueFoundry, Zuplo, MintMCP, custom enterprise)
- **FR-013**: Assistant MUST provide both environment variable and settings.json configuration examples
- **FR-014**: Assistant MUST explain the relationship between corporate proxies (HTTPS_PROXY) and LLM gateways when both are needed
- **FR-015**: Assistant MUST structure responses with Quick Answer, Configuration Block, Verification Steps, and Additional Context sections
- **FR-016**: Assistant MUST provide requirements for YAML configuration structure (litellm_config.yaml) with schema validation rules
- **FR-017**: Assistant MUST document settings.json schema requirements for Claude Code integration at user and project levels
- **FR-018**: Assistant MUST define token expiration handling requirements with detection and refresh prompts
- **FR-019**: Assistant MUST distinguish between service account and gcloud auth requirements with use case recommendations
- **FR-020**: Assistant MUST provide diagnostic command requirements for health checks and troubleshooting
- **FR-021**: Assistant MUST specify requirements for multi-region deployment configurations with fallback strategies
- **FR-022**: Assistant MUST define requirements for gateway modification and migration scenarios
- **FR-023**: Assistant MUST specify configuration inheritance rules (user→project→environment precedence)
- **FR-024**: Assistant MUST define requirements for routing strategies (simple-shuffle, least-busy, usage-based, latency-based)
- **FR-025**: Assistant MUST specify quota exceeded and permission denied error handling requirements
- **FR-026**: Assistant MUST define fallback model routing and retry policy requirements
- **FR-027**: Assistant MUST specify configuration rollback and credential rotation requirements
- **FR-028**: Assistant MUST define availability, scalability, and observability requirements for production deployments
- **FR-029**: Assistant MUST specify boundary condition requirements (zero models, max models, path lengths, special characters)
- **FR-030**: Assistant MUST define provider-specific edge cases (region unavailability, quota limits, API version mismatches)
- **FR-031**: Assistant MUST specify configuration validation requirements (YAML syntax, required fields, circular dependencies)
- **FR-032**: Assistant MUST enumerate prerequisite knowledge and skill level requirements
- **FR-033**: Assistant MUST define Messages API endpoint format requirements with specific structure
- **FR-034**: Assistant MUST explicitly list required headers (anthropic-beta, anthropic-version) with forwarding rules
- **FR-035**: Assistant MUST specify authentication bypass flag values (1, true) with consistent usage
- **FR-036**: Assistant MUST define assessment criteria for user requirements evaluation
- **FR-037**: Assistant MUST enumerate security best practices (credentials, secrets, IAM, rotation)
- **FR-038**: Assistant MUST define warning message formats for third-party gateway solutions
- **FR-039**: Assistant MUST structure troubleshooting guidance (steps, commands, expected output, troubleshooting)
- **FR-040**: Assistant MUST define gateway capability validation criteria with specific compatibility checks

### Key Entities

- **Gateway Configuration**: Represents the complete setup including gateway endpoint URL, authentication method, required headers, and provider-specific settings
- **Environment Variables**: Key-value pairs (ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, provider base URLs, auth bypass flags) that control Claude Code's gateway connection
- **Gateway Solution**: Specific gateway implementation (LiteLLM, TrueFoundry, Zuplo, etc.) with its unique configuration requirements and capabilities
- **Deployment Pattern**: Architecture approach (Direct, Proxy, Gateway) that determines how requests flow from Claude Code to model providers
- **Provider Configuration**: Provider-specific settings (Bedrock, Vertex AI) including base URLs and authentication bypass requirements

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully configure Claude Code with a LiteLLM gateway in under 10 minutes using provided templates
- **SC-002**: 90% of users successfully verify their gateway configuration on first attempt using `claude /status` verification steps
- **SC-003**: Assistant provides accurate configuration templates that work without modification for standard gateway deployments
- **SC-004**: Users receive clear differentiation between deployment patterns (Direct, Proxy, Gateway) with use case recommendations in under 3 sentences
- **SC-005**: Configuration guidance includes all required environment variables with no missing critical parameters
- **SC-006**: Security warnings about API key management appear in 100% of configuration responses
- **SC-007**: Users can identify whether their gateway meets Claude Code compatibility requirements through provided validation criteria
- **SC-008**: Troubleshooting steps resolve 80% of common gateway configuration issues without requiring additional support

### Non-Functional Requirements

- **NFR-001**: Gateway endpoints MUST maintain 99.5% availability during business hours
- **NFR-002**: Multi-instance deployments MUST support horizontal scaling to 10+ proxy instances
- **NFR-003**: System MUST provide observability through logging, monitoring (Prometheus), and metrics collection
- **NFR-004**: All communications MUST use TLS 1.2+ encryption for data in transit
- **NFR-005**: Configuration changes MUST complete within 30 seconds without service interruption
- **NFR-006**: System MUST support Claude Code versions 1.0.0 and above
- **NFR-007**: System MUST support LiteLLM versions 1.x and above with version pinning recommendations
- **NFR-008**: System MUST support Python 3.9+ for all scripts and utilities
- **NFR-009**: Documentation MUST be accessible in English with WCAG 2.1 AA compliance
- **NFR-010**: All configuration templates MUST validate against defined schemas before deployment

### Deployment Pattern Definitions

**Pattern 1: Direct Provider Access**
- Description: Claude Code connects directly to provider API (Anthropic/Bedrock/Vertex AI)
- Use Case: Simple single-provider setup, no centralized control needed
- Configuration: Provider API key only

**Pattern 2: Corporate Proxy**
- Description: Claude Code → HTTP/HTTPS Proxy → Provider API
- Use Case: Enterprise network policies require proxy
- Configuration: HTTPS_PROXY + provider credentials

**Pattern 3: LLM Gateway**
- Description: Claude Code → LiteLLM Proxy → Multiple Provider APIs
- Use Case: Cost tracking, multi-provider, load balancing, team management
- Configuration: ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN + gateway config

**Pattern 4: Proxy + Gateway**
- Description: Claude Code → Corporate Proxy → LiteLLM Gateway → Provider APIs
- Use Case: Enterprise with both proxy requirements AND gateway benefits
- Configuration: HTTPS_PROXY + ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN + gateway config

### Gateway Compatibility Criteria

A gateway is compatible with Claude Code if it meets ALL of the following:
1. Supports Messages API endpoints (/v1/messages, /v1/chat/completions)
2. Forwards required headers: anthropic-beta, anthropic-version, anthropic-client-version
3. Preserves request/response body format without modification
4. Returns standard HTTP status codes (200, 401, 403, 429, 500, 503)
5. Supports streaming responses with Server-Sent Events (SSE) format
6. Handles authentication via Bearer token in Authorization header
7. Maintains request timeout of minimum 60 seconds for long completions

### Common Configuration Issues (For FR-010 & SC-008)

1. **Gateway Unreachable** - Connection refused, timeout, or network errors
2. **Authentication Failure** - 401/403 errors from incorrect or expired tokens
3. **Missing Header Forwarding** - Gateway strips required headers causing API incompatibility
4. **Conflicting Configurations** - Both direct and gateway configs set simultaneously
5. **Incomplete Configuration** - Missing ANTHROPIC_AUTH_TOKEN when ANTHROPIC_BASE_URL is set
6. **Quota Exceeded** - 429 errors when provider rate limits reached
7. **Permission Denied** - 403 errors from insufficient IAM roles or service account permissions
8. **Invalid YAML Syntax** - Configuration file parsing errors
9. **Model Not Found** - Vertex AI model not deployed in specified region
10. **Circular Fallback** - Model A falls back to B, which falls back to A

### Required Environment Variables (For SC-005)

**Required (Gateway Setup)**:
- ANTHROPIC_BASE_URL - Gateway endpoint URL
- ANTHROPIC_AUTH_TOKEN - Gateway authentication token
- GCP_PROJECT_ID - Google Cloud project ID (for Vertex AI)
- LITELLM_MASTER_KEY - LiteLLM proxy master key

**Optional**:
- GOOGLE_APPLICATION_CREDENTIALS - Service account JSON path
- ANTHROPIC_BEDROCK_BASE_URL - Bedrock gateway endpoint
- ANTHROPIC_VERTEX_BASE_URL - Vertex AI gateway endpoint
- CLAUDE_CODE_SKIP_BEDROCK_AUTH - Bypass Bedrock auth (values: 1, true)
- CLAUDE_CODE_SKIP_VERTEX_AUTH - Bypass Vertex auth (values: 1, true)
- ANTHROPIC_LOG - Debug logging (value: debug)
- LITELLM_LOG - LiteLLM logging (value: DEBUG)
- HTTPS_PROXY - Corporate proxy URL
- REDIS_HOST - Redis host for multi-instance
- REDIS_PASSWORD - Redis authentication
- REDIS_PORT - Redis port (default: 6379)

### Security Best Practices (For FR-008, SC-006, FR-037)

1. **Never hardcode API keys** in configuration files - use environment variables or secret managers
2. **Use least-privilege IAM roles** - Grant only roles/aiplatform.user minimum permission
3. **Rotate service account keys** every 90 days maximum
4. **Store secrets in secret managers** - Use Google Secret Manager, AWS Secrets Manager, or HashiCorp Vault
5. **Enable audit logging** for all API calls and configuration changes
6. **Use TLS 1.2+ encryption** for all network communications
7. **Implement secret scanning** in CI/CD pipelines to prevent credential leaks
8. **Separate environments** - Use different GCP projects for dev/staging/production
9. **Enable MFA** for accounts with gateway administration access
10. **Monitor for anomalies** - Alert on unusual usage patterns or access attempts

### Prerequisite Knowledge (For FR-032)

**Required Knowledge**:
- YAML syntax and structure
- Environment variables and shell configuration
- Command-line interface (CLI) basics
- HTTP/HTTPS protocols and status codes

**Recommended Knowledge**:
- Docker and containerization (for production deployments)
- Google Cloud Platform basics
- API authentication patterns (Bearer tokens, service accounts)
- Load balancing concepts

**Skill Level**: Intermediate developer with 1+ years experience

### Third-Party Gateway Warning Template (For FR-007, FR-038)

```
⚠️ THIRD-PARTY NOTICE
This configuration uses [GATEWAY_NAME], a third-party solution not developed or maintained by Anthropic.
- Anthropic does not provide support for [GATEWAY_NAME]
- Configuration may change without notice
- For issues, contact [GATEWAY_NAME] support or community
- Review [GATEWAY_NAME] security and privacy policies before use
```

### Assessment Criteria for User Requirements (For FR-009, FR-036)

When assessing user needs, evaluate:
1. **Team Size**: 1-10 (small), 10-100 (medium), 100+ (enterprise)
2. **Security Requirements**: Basic (API keys), Enterprise (SSO, audit logs), Compliance (SOC2, HIPAA)
3. **Multi-Provider Needs**: Single provider, 2-3 providers, 5+ providers
4. **Cost Tracking Priority**: Low (optional), Medium (monthly reports), High (real-time dashboards)
5. **Deployment Environment**: Local development, staging, production, multi-region
6. **Existing Infrastructure**: Greenfield, existing gateway, corporate proxy required
7. **Support Level**: Self-service documentation, community support, enterprise support SLA

