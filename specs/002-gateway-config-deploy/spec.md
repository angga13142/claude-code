# Feature Specification: LLM Gateway Configuration Deployment to ~/.claude

**Feature Branch**: `002-gateway-config-deploy`  
**Created**: 2025-12-02  
**Status**: Draft  
**Input**: User description: "saya ingin mengimplementasikan config di folder 001-llm-gateway-config ke direktori konfigurasi claude code disini ~/home/.claude"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quick Deploy Base Configuration (Priority: P1) 🎯 MVP

User wants to quickly deploy a working LiteLLM gateway configuration to their Claude Code home directory with minimal setup.

**Why this priority**: Enables immediate use of gateway features without manual file copying. Provides fastest path to value for users who want to try the gateway integration.

**Independent Test**: Run deployment command, verify files copied to ~/.claude/gateway/, start LiteLLM with deployed config, test with `claude /status`

**Acceptance Scenarios**:

1. **Given** user has completed LLM Gateway Configuration Assistant in specs/001-llm-gateway-config, **When** user runs deployment command with `--preset basic`, **Then** base configuration files are copied to `~/.claude/gateway/` directory with proper permissions

2. **Given** user has GCP credentials configured, **When** deployment command runs, **Then** environment variables are auto-detected and populated in deployed config files

3. **Given** deployment completes successfully, **When** user starts LiteLLM with deployed config, **Then** proxy starts without errors and all 8 Vertex AI models are accessible

4. **Given** LiteLLM is running with deployed config, **When** user runs `claude /status`, **Then** Claude Code successfully connects to gateway and shows model availability

---

### User Story 2 - Deploy with Custom Model Selection (Priority: P2)

User wants to deploy only specific models they plan to use, reducing configuration complexity and potential quota issues.

**Why this priority**: Allows users to customize deployment for their specific needs and avoid unnecessary model configurations that might not be available in their GCP region.

**Independent Test**: Run deployment with `--models gemini-2.5-flash,deepseek-r1` flag, verify only selected models are in deployed config

**Acceptance Scenarios**:

1. **Given** user wants to deploy only Gemini models, **When** user runs deployment with `--models gemini-2.5-flash,gemini-2.5-pro`, **Then** only specified models are included in deployed litellm_config.yaml

2. **Given** user has selected custom models, **When** deployment validates configuration, **Then** command warns about missing models but proceeds with valid selections

3. **Given** user provides invalid model name, **When** deployment runs, **Then** command shows available model list and exits with clear error message

---

### User Story 3 - Deploy Enterprise Gateway Configuration (Priority: P2)

User wants to deploy configuration for connecting to existing enterprise gateway (TrueFoundry, Zuplo, custom) instead of local LiteLLM.

**Why this priority**: Enables enterprise users to integrate Claude Code with their organization's centralized gateway infrastructure.

**Independent Test**: Run deployment with `--gateway-type truefoundry --gateway-url https://gateway.company.com`, verify Claude Code config points to enterprise gateway

**Acceptance Scenarios**:

1. **Given** user has enterprise gateway URL and auth token, **When** user runs deployment with `--gateway-type enterprise --gateway-url <URL> --auth-token <TOKEN>`, **Then** Claude Code settings.json is updated with correct gateway endpoint

2. **Given** enterprise gateway requires custom headers, **When** user provides header configuration, **Then** deployed config includes header forwarding settings

3. **Given** enterprise gateway is deployed, **When** user tests connection, **Then** deployment command runs health check and confirms successful connection

---

### User Story 4 - Deploy Multi-Provider Configuration (Priority: P3)

User wants to deploy configuration that routes to multiple providers (Anthropic direct, Bedrock, Vertex AI) based on model name.

**Why this priority**: Advanced use case for users who want provider diversity or cost optimization across multiple cloud platforms.

**Independent Test**: Deploy multi-provider config, verify routing works for models from different providers (claude-3.5-sonnet → Anthropic, gemini-2.5-flash → Vertex AI)

**Acceptance Scenarios**:

1. **Given** user has credentials for multiple providers, **When** user runs deployment with `--multi-provider`, **Then** config includes routing rules for Anthropic, Bedrock, and Vertex AI models

2. **Given** multi-provider config is deployed, **When** user requests Anthropic model, **Then** request routes directly to Anthropic API (bypassing gateway for native models)

3. **Given** multi-provider config includes fallback, **When** primary provider fails, **Then** request automatically falls back to configured secondary provider

---

### User Story 5 - Update Existing Deployment (Priority: P3)

User wants to update their deployed gateway configuration with new models or settings without starting from scratch.

**Why this priority**: Enables iterative configuration refinement and addition of new models as they become available.

**Independent Test**: Run deployment with `--update` flag on existing deployment, verify new settings merge with existing without losing custom modifications

**Acceptance Scenarios**:

1. **Given** user has existing gateway deployment, **When** user runs deployment with `--update --add-models llama3-405b`, **Then** new model is added to existing config without removing current models

2. **Given** user has custom environment variables set, **When** update deployment runs, **Then** existing custom settings are preserved and only specified changes are applied

3. **Given** deployment detects breaking changes, **When** update runs, **Then** command creates backup of existing config before applying updates

---

### User Story 6 - Proxy Configuration Deployment (Priority: P4)

User behind corporate proxy wants to deploy gateway config that includes proxy settings for all outbound connections.

**Why this priority**: Necessary for enterprise users in restricted network environments but less common use case.

**Independent Test**: Deploy with `--proxy https://proxy.company.com:8080`, verify LiteLLM and Claude Code both route through proxy

**Acceptance Scenarios**:

1. **Given** user is behind corporate proxy, **When** user runs deployment with `--proxy <URL> --proxy-auth <USER:PASS>`, **Then** proxy settings are configured in both LiteLLM and Claude Code configs

2. **Given** proxy requires authentication, **When** deployment configures proxy, **Then** credentials are stored securely and not logged

3. **Given** proxy config is deployed, **When** user tests connection, **Then** all gateway requests successfully traverse corporate proxy

---

### Edge Cases

- What happens when ~/.claude directory doesn't exist? → Create it with proper permissions (0700)
- What happens when deployment finds existing gateway config? → Prompt user: overwrite, backup, or merge
- What happens when GCP credentials are missing? → Show clear error with link to authentication guide
- What happens when deployed config has invalid YAML? → Validate before writing, rollback on error
- What happens when LiteLLM is already running during deployment? → Warn user to stop service first or offer restart
- What happens when user doesn't have write permissions to ~/.claude? → Show permission error with sudo suggestion
- What happens when model specified is not available in user's GCP region? → Warn but allow deployment with note in config comments
- What happens when network is unavailable during validation? → Skip online checks, warn user to validate manually later

## Requirements *(mandatory)*

### Functional Requirements

#### Deployment Core (P1 - MVP)

- **FR-001**: System MUST copy configuration templates from `specs/001-llm-gateway-config/templates/` to `~/.claude/gateway/` directory
- **FR-002**: System MUST create `~/.claude/gateway/` directory if it doesn't exist with permissions 0700 (owner read/write/execute only)
- **FR-003**: System MUST validate all YAML configuration files before deployment using existing `validate-config.py` script
- **FR-004**: System MUST populate environment variables in deployed configs by reading from:
  - Current shell environment
  - ~/.bashrc, ~/.zshrc, ~/.profile
  - Existing ~/.claude/.env file (if present)
- **FR-005**: System MUST create `~/.claude/gateway/.env` file with required environment variables (LITELLM_MASTER_KEY, GOOGLE_APPLICATION_CREDENTIALS, etc.)
- **FR-006**: System MUST update `~/.claude/settings.json` with gateway endpoint URL (default: http://localhost:4000)
- **FR-007**: System MUST generate startup script `~/.claude/gateway/start-gateway.sh` with correct paths and environment loading
- **FR-008**: System MUST create backup of existing configuration before overwriting (format: `gateway-backup-YYYYMMDD-HHMMSS.tar.gz`)

#### Model Selection (P2)

- **FR-009**: System MUST support `--models` flag to deploy only specified models (comma-separated list)
- **FR-010**: System MUST validate model names against available model list from templates/models/ directory
- **FR-011**: System MUST show available model list with descriptions when invalid model name is provided
- **FR-012**: System MUST merge selected model configs into single litellm_config.yaml file

#### Enterprise Gateway Integration (P2)

- **FR-013**: System MUST support `--gateway-type` flag with values: `local`, `enterprise`, `truefoundry`, `zuplo`, `custom`
- **FR-014**: System MUST accept `--gateway-url` flag for custom gateway endpoint URLs
- **FR-015**: System MUST accept `--auth-token` flag and store it securely in ~/.claude/gateway/.env (not in version control)
- **FR-016**: System MUST update settings.json with enterprise gateway endpoint when `--gateway-type enterprise` is used
- **FR-017**: System MUST run health check against deployed gateway URL using `scripts/health-check.sh`

#### Multi-Provider Support (P3)

- **FR-018**: System MUST support `--multi-provider` flag to deploy multi-provider routing configuration
- **FR-019**: System MUST deploy multi-provider config from `templates/multi-provider/multi-provider-config.yaml`
- **FR-020**: System MUST set provider-specific environment variables (ANTHROPIC_BASE_URL, ANTHROPIC_BEDROCK_BASE_URL, etc.)
- **FR-021**: System MUST configure auth bypass flags when appropriate (ANTHROPIC_VERTEX_AUTH_BYPASS=1)

#### Configuration Updates (P3)

- **FR-022**: System MUST support `--update` flag to merge changes with existing deployment
- **FR-023**: System MUST support `--add-models` flag to append new models without removing existing
- **FR-024**: System MUST preserve user customizations in config files during updates (comments, custom settings)
- **FR-025**: System MUST create incremental backups on each update operation

#### Proxy Configuration (P4)

- **FR-026**: System MUST support `--proxy` flag to configure HTTP/HTTPS proxy for all connections
- **FR-027**: System MUST support `--proxy-auth` flag for proxy authentication (format: username:password)
- **FR-028**: System MUST set HTTP_PROXY, HTTPS_PROXY environment variables in deployed configs
- **FR-029**: System MUST configure LiteLLM to use proxy for upstream provider connections

#### Validation & Testing (All Priorities)

- **FR-030**: System MUST run post-deployment validation checks:
  - YAML syntax validation
  - Environment variable presence check
  - File permissions verification
  - Gateway connectivity test (if gateway URL provided)
- **FR-031**: System MUST provide `--dry-run` flag to preview changes without applying them
- **FR-032**: System MUST provide verbose output mode with `--verbose` flag showing all operations
- **FR-033**: System MUST log all deployment actions to `~/.claude/gateway/deployment.log`

#### Rollback & Safety (All Priorities)

- **FR-034**: System MUST support `--rollback` flag to restore previous configuration from backup
- **FR-035**: System MUST list available backups with `--list-backups` flag
- **FR-036**: System MUST verify backup integrity before rollback operation
- **FR-037**: System MUST stop running LiteLLM process before applying configuration changes (with user confirmation)

### Key Entities

- **Deployment Configuration**: Represents complete deployment state
  - Target directory path (~/.claude/gateway/)
  - Selected models list
  - Gateway type and URL
  - Environment variables mapping
  - Backup metadata (timestamp, file path)

- **Gateway Configuration**: LiteLLM proxy configuration
  - Model list with provider settings
  - Authentication settings
  - Proxy configuration
  - Rate limiting settings
  - Logging configuration

- **Claude Code Settings**: User-level Claude Code configuration
  - Gateway endpoint URL
  - Authentication bypass flags
  - Provider-specific base URLs
  - Custom headers configuration

- **Deployment Manifest**: Record of what was deployed
  - Deployment timestamp
  - Source spec version (001-llm-gateway-config)
  - Deployed files list with checksums
  - Environment variables used
  - User-provided flags/options

## Success Criteria *(mandatory)*

- **SC-001**: User can deploy working gateway configuration in under 5 minutes with single command
- **SC-002**: 95% of deployments succeed on first attempt without manual intervention
- **SC-003**: Deployed configuration passes all validation checks (YAML syntax, env vars, permissions)
- **SC-004**: Post-deployment health check confirms gateway connectivity and model availability
- **SC-005**: Rollback restores previous working state within 30 seconds
- **SC-006**: Deployment command provides clear progress indicators and error messages at each step
- **SC-007**: User can update deployment with new models without service interruption (zero-downtime updates)
- **SC-008**: All sensitive data (auth tokens, credentials) are stored with proper file permissions (0600)

## Out of Scope *(optional)*

- Automatic installation of LiteLLM or Python dependencies (user must have prerequisites from 001 spec)
- Migration of existing non-standard gateway configurations
- GUI/web interface for deployment (CLI only)
- Windows-specific deployment paths (macOS/Linux only)
- Automatic DNS/hostname resolution for gateway URLs
- Integration with Docker/Kubernetes deployment (manual container setup only)
- Monitoring/alerting setup (covered in observability docs, not deployment)
- Credential rotation automation (manual process documented)

## Assumptions *(optional)*

- User has completed prerequisites from spec 001 (Python 3.9+, gcloud CLI, Claude Code installed)
- User has read access to specs/001-llm-gateway-config directory
- User has write permissions to ~/.claude directory
- User's shell environment is bash or zsh (standard Linux/macOS shells)
- LiteLLM package is already installed (`pip install litellm`)
- User has basic understanding of environment variables and command-line tools
- GCP project is set up with Vertex AI API enabled (if using Vertex AI models)
- Network connectivity to gateway URLs for validation checks

## Dependencies *(optional)*

- **Prerequisite Features**: 
  - Spec 001: LLM Gateway Configuration Assistant (must be completed)
- **External Dependencies**:
  - LiteLLM 1.x+ (Python package)
  - gcloud CLI (for GCP authentication)
  - Claude Code 2.0.56+ (for gateway integration support)
  - Python 3.9+ with PyYAML, requests libraries
- **Files/Systems**:
  - Read access: specs/001-llm-gateway-config/templates/, scripts/, examples/
  - Write access: ~/.claude/, ~/.claude/gateway/, ~/.claude/settings.json
  - Existing scripts: validate-config.py, health-check.sh, check-prerequisites.sh

## Open Questions *(optional but recommended)*

1. Should deployment command be integrated as `/gateway:deploy` Claude Code command or standalone script?
   - **Lean towards**: Standalone bash script for easier testing and iteration
   
2. Should we support deploying to custom directory paths (not just ~/.claude)?
   - **Consider**: Add `--install-dir` flag for advanced users
   
3. How should we handle version mismatches between deployed config and spec updates?
   - **Proposal**: Add version field to deployment manifest, warn on mismatch

4. Should deployment automatically start LiteLLM after successful deployment?
   - **Consider**: Add `--start` flag to optionally start service immediately

5. How should we handle multi-user systems where multiple users want different configs?
   - **Current approach**: Per-user deployment in each user's ~/.claude directory

6. Should we validate GCP quotas/permissions before deploying Vertex AI models?
   - **Consider**: Add `--validate-quota` flag for pre-deployment checks (may be slow)

## Notes *(optional)*

### Implementation Strategy

This deployment feature should be implemented as a standalone bash script (`deploy-gateway-config.sh`) that:

1. Lives in `specs/001-llm-gateway-config/scripts/` directory
2. Can be run directly: `bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh`
3. Provides both interactive mode (prompts) and non-interactive mode (all flags provided)
4. Uses existing validation scripts from spec 001
5. Generates idempotent deployment manifest for tracking

### User Experience Flow

**Quick Start (P1 - MVP)**:
```bash
# Single command deployment with defaults
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh

# Prompts user for:
# - Which models to deploy (or "all")
# - Whether to start LiteLLM after deployment
# - Confirmation before overwriting existing config
```

**Advanced Usage**:
```bash
# Non-interactive with all flags
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --models gemini-2.5-flash,deepseek-r1 \
  --gateway-url http://localhost:4000 \
  --backup \
  --start \
  --verbose

# Enterprise gateway
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --gateway-type enterprise \
  --gateway-url https://gateway.company.com \
  --auth-token $ENTERPRISE_TOKEN

# Multi-provider
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --multi-provider \
  --models gemini-2.5-flash,claude-3.5-sonnet

# Update existing deployment
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --update \
  --add-models llama3-405b,qwen3-coder-480b

# Rollback
bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --rollback \
  --backup-date 20251202-143000
```

### File Structure After Deployment

```
~/.claude/
├── gateway/
│   ├── litellm_config.yaml          # Main LiteLLM configuration
│   ├── .env                          # Environment variables (secured)
│   ├── start-gateway.sh              # Startup script
│   ├── stop-gateway.sh               # Shutdown script
│   ├── deployment-manifest.json      # What was deployed, when, by whom
│   ├── deployment.log                # Deployment history
│   └── backups/
│       ├── gateway-backup-20251201-120000.tar.gz
│       └── gateway-backup-20251202-143000.tar.gz
├── settings.json                     # Claude Code settings (updated)
└── .env                              # User-level environment variables
```

### Security Considerations

- **FR-005**: .env files must have 0600 permissions (owner read/write only)
- **FR-015**: Auth tokens never logged or displayed in output
- **FR-037**: Sensitive data never committed to git (add to .gitignore)
- Backup archives encrypted if they contain credentials
- Deployment log sanitizes sensitive values before writing

### Backward Compatibility

- Deployment script should detect existing non-standard configs and offer migration
- Support for both old and new Claude Code settings.json formats
- Graceful handling of deprecated environment variables with warnings
