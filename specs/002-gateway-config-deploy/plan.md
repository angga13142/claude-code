# Implementation Plan: Gateway Configuration Deployment to ~/.claude

**Branch**: `002-gateway-config-deploy` | **Date**: 2025-12-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-gateway-config-deploy/spec.md`

## Summary

Build a deployment tool that automatically deploys LLM Gateway configurations from `specs/001-llm-gateway-config/` to `~/.claude/gateway/` directory. The tool will copy templates, populate environment variables, validate configurations, create startup scripts, and integrate with Claude Code settings. Primary approach uses bash script with Python validation utilities for safety and reliability.

**Key Deliverables:**

- Deployment script (`deploy-gateway-config.sh`) with interactive and non-interactive modes
- Configuration merger for custom model selection
- Environment variable auto-detection and population
- Backup and rollback mechanisms
- Post-deployment validation and health checks
- Integration with existing validation scripts from spec 001

## Technical Context

**Language/Version**: Bash 4.0+ (deployment script), Python 3.9+ (validation utilities)  
**Primary Dependencies**: PyYAML, jq, tar, existing scripts from spec 001  
**Storage**: File system (`~/.claude/gateway/`), no database required  
**Testing**: Bash unit tests (bats), integration tests with actual deployment  
**Target Platform**: macOS and Linux (bash/zsh environments)  
**Project Type**: CLI deployment tool  
**Performance Goals**:

- Deployment completion <5 minutes (SC-001)
- First-attempt success rate >95% (SC-002)
- Rollback <30 seconds (SC-005)  
**Constraints**:
- Must preserve user customizations during updates
- Cannot require sudo for normal operations
- Must validate before making any changes  
**Scale/Scope**:
- Single-user deployment per system
- 8 model configurations available
- 4 gateway types supported
- 6 deployment scenarios (user stories P1-P4)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Before Research)

✅ **I. Code Quality Standards**

- **Status**: PASS - Bash script with clear structure
- **Compliance**: Following bash best practices, error handling, function decomposition
- **Action**: Use shellcheck for linting, comprehensive error messages

✅ **II. Testing Standards**

- **Status**: PASS - Comprehensive testing strategy defined
- **Compliance**:
  - Unit tests: bats framework for bash functions
  - Integration tests: End-to-end deployment scenarios
  - Validation tests: Config file validation
  - Rollback tests: Backup and restore verification
- **Coverage**: >80% of deployment scenarios

✅ **III. User Experience Consistency**

- **Status**: PASS - Clear UX pattern defined
- **Compliance**:
  - Interactive mode with clear prompts
  - Progress indicators at each step
  - Color-coded output (green=success, red=error, yellow=warning)
  - Verbose mode for debugging
  - Clear error messages with remediation steps
- **Accessibility**: Terminal-based, screen reader compatible

✅ **IV. Performance Requirements**

- **Status**: PASS - Performance targets achievable
- **Compliance**:
  - File operations are fast (<1s for copy)
  - Validation runs in parallel where possible
  - Backup creation optimized (tar with compression)
  - No network operations in critical path (optional health check)
- **Monitoring**: Deployment log tracks timing for each operation

## Audit Results: Available Assets from Spec 001

### Scripts Available for Reuse (15 scripts)

**Validation Scripts** ✅:
- `validate-config.py` - YAML validation with comprehensive checks (321 lines)
- `validate-gateway-compatibility.py` - Gateway type validation
- `validate-provider-env-vars.py` - Environment variable validation
- `validate-proxy-auth.py` - Proxy authentication validation

**Health Check Scripts** ✅:
- `check-prerequisites.sh` - System requirements verification (358 lines)
- `check-status.sh` - Gateway status checking
- `health-check.sh` - Endpoint health verification
- `check-proxy-connectivity.sh` - Proxy connectivity testing

**Utility Scripts** ✅:
- `troubleshooting-utils.sh` - Common functions (print_success, print_error, etc.)
- `start-litellm-proxy.sh` - LiteLLM startup script
- `rollback-config.sh` - Configuration rollback (existing, can be enhanced)
- `migrate-config.py` - Config migration utilities
- `debug-auth.sh` - Authentication debugging

**Model Management** ✅:
- `check-model-availability.py` - Model availability checker

### Templates Available (24+ files)

**Base Configurations** ✅:
- `templates/litellm-base.yaml` - Minimal working config (38 lines)
- `templates/litellm-complete.yaml` - Full 8-model config (165 lines)
- `templates/settings-schema.json` - Claude Code settings schema (142 lines)
- `templates/env-vars-reference.md` - Environment variable documentation
- `templates/deployment-patterns.md` - Architecture patterns

**Model Templates** ✅ (8 models):
- `templates/models/gemini-2.5-flash.yaml`
- `templates/models/gemini-2.5-pro.yaml`
- `templates/models/deepseek-r1.yaml`
- `templates/models/llama3-405b.yaml`
- `templates/models/codestral.yaml`
- `templates/models/qwen3-coder-480b.yaml`
- `templates/models/qwen3-235b.yaml`
- `templates/models/gpt-oss-20b.yaml`

**Enterprise Templates** ✅:
- `templates/enterprise/truefoundry-config.yaml`
- `templates/enterprise/zuplo-config.yaml`
- `templates/enterprise/custom-gateway-config.yaml`
- `templates/enterprise/auth-token-setup.md`
- `templates/enterprise/header-forwarding.md`

**Multi-Provider Templates** ✅:
- `templates/multi-provider/multi-provider-config.yaml`
- `templates/multi-provider/bedrock-config.yaml`
- `templates/multi-provider/vertex-ai-config.yaml`
- `templates/multi-provider/anthropic-config.yaml`

**Proxy Templates** ✅:
- `templates/proxy/proxy-gateway-config.yaml`
- `templates/proxy/proxy-only-config.yaml`
- `templates/proxy/proxy-auth.md`

### Documentation Available (29+ guides)

**User Story Guides** ✅:
- US1: `examples/us1-quickstart-basic.md`, `us1-env-vars-setup.md`, `us1-gcloud-auth.md`, `us1-troubleshooting.md`, `us1-verification-checklist.md`
- US2: `examples/us2-enterprise-integration.md`, `us2-security-best-practices.md`, `us2-compatibility-checklist.md`, `us2-compliance-guide.md`
- US3: `examples/us3-multi-provider-setup.md`, `us3-provider-env-vars.md`, `us3-cost-optimization.md`, `us3-provider-selection.md`, `us3-auth-bypass-guide.md`
- US4: `examples/us4-corporate-proxy-setup.md`, `examples/us4-proxy-troubleshooting.md`, etc.

**Technical Docs** ✅:
- `docs/configuration-reference.md` - Complete config reference
- `docs/environment-variables.md` - Env var documentation
- `docs/security-best-practices.md` - Security guidance
- `docs/troubleshooting-guide.md` - Troubleshooting procedures

### Test Suite Available (13 test scripts)

**Test Scripts** ✅:
- `tests/test-all-models.py` - End-to-end model testing
- `tests/test-yaml-schemas.py` - YAML validation tests
- `tests/test-env-vars.py` - Environment variable tests
- `tests/test-multi-provider-routing.py` - Multi-provider tests
- `tests/test-proxy-gateway.py` - Proxy integration tests
- `tests/run-all-tests.sh` - Master test runner

## Project Structure

### New Files (this feature)

```text
specs/002-gateway-config-deploy/
├── plan.md                    # This file ✅
├── research.md                # Phase 0 output (to be created)
├── data-model.md              # Phase 1 output (to be created)
├── quickstart.md              # Phase 1 output (to be created)
├── contracts/                 # Phase 1 output (to be created)
│   └── deployment-api.md      # Deployment tool interface contracts
├── checklists/
│   ├── requirements.md        # ✅ COMPLETE
│   └── implementation-readiness.md  # Phase 2 output (to be created)
└── tasks.md                   # Phase 2 output (to be created)
```

### Scripts to Create

```text
specs/001-llm-gateway-config/scripts/
├── deploy-gateway-config.sh   # ⭐ Main deployment script (NEW)
└── lib/                       # ⭐ Deployment libraries (NEW)
    ├── deployment-core.sh     # Core deployment functions
    ├── backup-manager.sh      # Backup/rollback functions
    ├── config-merger.sh       # Config merging functions
    ├── env-detector.sh        # Environment variable detection
    └── settings-updater.sh    # Claude Code settings.json updater
```

### Files to Update

```text
specs/001-llm-gateway-config/
├── README.md                  # Add deployment section
├── scripts/rollback-config.sh # Enhance for deployment use
└── quickstart.md              # Add quick deploy instructions
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No Violations Identified** - Feature maintains simplicity:

- Reuses existing validation scripts (no duplication)
- Clear separation: deployment logic vs validation logic
- Bash script is maintainable (<500 lines with libraries)
- No complex dependencies (uses standard Unix tools)

---

## Implementation Phases

### Phase 0: Research & Requirements Clarification ⏳ PENDING

**Objective**: Research deployment patterns, validate approach, identify risks

**Research Topics**:
1. **Bash Best Practices**: Error handling, file operations, user input validation
2. **Backup Strategies**: tar vs rsync, compression options, atomic operations
3. **Settings.json Handling**: Safe JSON manipulation without breaking existing config
4. **Environment Variable Detection**: Shell profile parsing, precedence rules
5. **Cross-platform Compatibility**: macOS vs Linux differences

**Questions to Answer**:
- How to safely update settings.json without corrupting it? → Use `jq` for JSON manipulation
- How to detect if LiteLLM is running? → Check process list and port 4000
- Best backup rotation strategy? → Keep last 5 backups, delete older
- How to handle symlinks in ~/.claude? → Follow symlinks during backup
- Atomic file operations to prevent corruption? → Write to temp, validate, then move

**Deliverable**: `research.md` with findings and technical decisions

---

### Phase 1: Design & Architecture ⏳ PENDING

**Objective**: Create detailed design documents

**Tasks**:
1. Create `data-model.md` defining:
   - Deployment manifest structure (JSON)
   - Backup metadata format
   - Config merge rules
   
2. Create `contracts/deployment-api.md` defining:
   - Command-line interface (flags, arguments)
   - Exit codes and error handling
   - Output format (interactive vs non-interactive)
   - Logging format
   
3. Create `quickstart.md` with:
   - Quick deployment guide (copy-paste commands)
   - Common scenarios (basic, enterprise, multi-provider)
   - Troubleshooting quick reference

**Deliverable**: Complete design documents

---

### Phase 2: Task Breakdown ⏳ PENDING

**Objective**: Break implementation into granular tasks

**Deliverable**: `tasks.md` with ~30-40 tasks covering:
- Core deployment functions
- Backup/rollback implementation
- Config merging logic
- Environment variable handling
- Settings.json updates
- Validation integration
- Testing implementation
- Documentation updates

---

### Phase 3-8: Implementation ⏳ PENDING

Will be defined in `tasks.md` after Phase 2 completion.

**High-Level Phases** (estimated):
- **Phase 3**: Core deployment engine (file copying, directory creation)
- **Phase 4**: Backup and rollback system
- **Phase 5**: Config merging and customization
- **Phase 6**: Environment variable detection and population
- **Phase 7**: Settings.json integration
- **Phase 8**: Validation, testing, and documentation

---

## Implementation Strategy

### Core Deployment Flow

```
1. Pre-flight Checks
   ├── Verify prerequisites (check-prerequisites.sh)
   ├── Detect existing deployment
   └── Prompt for confirmation if overwriting

2. Backup (if existing config)
   ├── Create timestamped backup directory
   ├── Archive ~/.claude/gateway/ to tar.gz
   ├── Store backup metadata
   └── Verify backup integrity

3. Environment Detection
   ├── Read current shell environment
   ├── Parse shell profiles (~/.bashrc, ~/.zshrc)
   ├── Read existing ~/.claude/.env
   └── Detect GCP credentials (gcloud CLI)

4. Configuration Preparation
   ├── Select models (based on --models flag or interactive prompt)
   ├── Merge model templates into litellm_config.yaml
   ├── Populate environment variables in templates
   └── Validate merged config (validate-config.py)

5. Deployment
   ├── Create ~/.claude/gateway/ directory (0700 permissions)
   ├── Copy litellm_config.yaml
   ├── Create .env file (0600 permissions)
   ├── Generate start-gateway.sh script
   ├── Generate stop-gateway.sh script
   ├── Create deployment-manifest.json
   └── Set file permissions

6. Claude Code Integration
   ├── Backup existing settings.json
   ├── Update ANTHROPIC_BASE_URL
   ├── Update auth bypass flags if needed
   └── Validate settings.json syntax

7. Post-Deployment Validation
   ├── Run YAML validation
   ├── Check file permissions
   ├── Verify environment variables
   ├── Run health check (optional, if gateway URL provided)
   └── Log deployment completion

8. User Communication
   ├── Show deployment summary
   ├── Show next steps (start LiteLLM command)
   └── Show validation command (claude /status)
```

### Script Organization

**Main Script** (`deploy-gateway-config.sh`):
```bash
#!/bin/bash
# Main deployment orchestrator
# - Parses command-line arguments
# - Loads library functions
# - Executes deployment flow
# - Handles errors and cleanup
```

**Library Modules**:
1. `deployment-core.sh`: File operations, directory management
2. `backup-manager.sh`: Backup creation, rollback, cleanup
3. `config-merger.sh`: YAML merging, template processing
4. `env-detector.sh`: Environment variable detection
5. `settings-updater.sh`: settings.json manipulation with jq

### Reuse Strategy

**Scripts to Reuse** (no modification needed):
- ✅ `validate-config.py` - YAML validation
- ✅ `check-prerequisites.sh` - Prerequisites checking
- ✅ `health-check.sh` - Health checking
- ✅ `troubleshooting-utils.sh` - Utility functions

**Scripts to Extend**:
- ⚠️ `rollback-config.sh` - Add deployment manifest awareness
- ⚠️ `start-litellm-proxy.sh` - Add deployment path awareness

**Templates to Transform**:
- 📝 All model YAML files → merge into single config
- 📝 litellm-base.yaml → populate with actual values
- 📝 settings-schema.json → validate against during update

### Error Handling Strategy

**Levels**:
1. **Fatal Errors** (exit immediately, no changes):
   - Missing prerequisites
   - No write permissions
   - Invalid command-line arguments
   
2. **Recoverable Errors** (prompt user):
   - Existing deployment found (offer backup)
   - Invalid model name (show available list)
   - Running LiteLLM process (offer to stop)
   
3. **Warnings** (continue with notice):
   - Missing optional environment variables
   - Model not available in region
   - Network unavailable for health check

**Rollback Triggers**:
- YAML validation failure after merge
- Settings.json corruption
- File permission errors during deployment
- User interruption (Ctrl+C)

### Testing Strategy

**Unit Tests** (bats framework):
```bash
tests/unit/
├── test-deployment-core.bats
├── test-backup-manager.bats
├── test-config-merger.bats
├── test-env-detector.bats
└── test-settings-updater.bats
```

**Integration Tests**:
```bash
tests/integration/
├── test-basic-deployment.sh       # P1: Basic deployment
├── test-custom-models.sh          # P2: Custom model selection
├── test-enterprise-gateway.sh     # P2: Enterprise deployment
├── test-multi-provider.sh         # P3: Multi-provider
├── test-update-deployment.sh      # P3: Update existing
├── test-rollback.sh               # All: Rollback capability
└── test-dry-run.sh                # All: Dry-run mode
```

**Test Coverage Goals**:
- >80% function coverage
- All user stories tested end-to-end
- All edge cases have test scenarios
- Rollback tested for each deployment type

### Security Considerations

**Credential Handling**:
- ✅ Store credentials in ~/.claude/gateway/.env with 0600 permissions
- ✅ Never log credential values (sanitize before logging)
- ✅ Backup archives exclude .env files by default (use --include-secrets flag)
- ✅ Clear variables from memory after use

**File Permissions**:
- ~/.claude/ directory: 0700 (owner only)
- ~/.claude/gateway/.env: 0600 (owner read/write)
- litellm_config.yaml: 0644 (owner write, others read)
- Scripts (.sh files): 0755 (executable)
- Backups: 0600 (owner only)

**Input Validation**:
- Sanitize all user inputs (model names, URLs, paths)
- Validate URLs before using (no file:// or javascript: schemes)
- Prevent path traversal (reject ../ in paths)
- Validate YAML before writing (prevent injection)

### Deployment Manifest Schema

```json
{
  "version": "1.0",
  "deployment_id": "dep-20251202-143022",
  "timestamp": "2025-12-02T14:30:22Z",
  "source_spec": "001-llm-gateway-config",
  "deployed_by": "username",
  "gateway_type": "local",
  "gateway_url": "http://localhost:4000",
  "models": [
    "gemini-2.5-flash",
    "deepseek-r1"
  ],
  "files": {
    "litellm_config.yaml": "sha256:abc123...",
    ".env": "sha256:def456...",
    "start-gateway.sh": "sha256:ghi789..."
  },
  "environment_variables": {
    "LITELLM_MASTER_KEY": "set",
    "GOOGLE_APPLICATION_CREDENTIALS": "set",
    "VERTEX_PROJECT": "protean-tooling-476420-i8",
    "VERTEX_LOCATION": "us-central1"
  },
  "backup_path": "~/.claude/gateway/backups/gateway-backup-20251202-143020.tar.gz",
  "flags_used": [
    "--models=gemini-2.5-flash,deepseek-r1",
    "--backup",
    "--verbose"
  ]
}
```

### User Experience Examples

**Interactive Mode**:
```bash
$ bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh

🚀 LLM Gateway Configuration Deployment
========================================

📋 Checking prerequisites...
✓ Python 3.13.5 found
✓ Claude Code 2.0.56 installed
✓ gcloud CLI configured
✓ LiteLLM installed

📂 Checking existing deployment...
⚠️  Found existing deployment at ~/.claude/gateway/
   Last deployed: 2025-12-01 12:00:00
   Models: gemini-2.5-flash, gemini-2.5-pro

What would you like to do?
  1) Backup and overwrite
  2) Update existing deployment (merge)
  3) Cancel
Choice [1-3]: 1

📦 Creating backup...
✓ Backup created: gateway-backup-20251202-143022.tar.gz

🎯 Select models to deploy:
  [x] 1. gemini-2.5-flash (Google Gemini 2.5 Flash)
  [x] 2. gemini-2.5-pro (Google Gemini 2.5 Pro)
  [ ] 3. deepseek-r1 (DeepSeek R1 - Reasoning)
  [ ] 4. llama3-405b (Meta Llama 3 405B)
  ...
  [a] Select all
  [n] None
  [c] Continue with selection

Selection [1-8,a,n,c]: 1,3,c

🔧 Detecting environment...
✓ VERTEX_PROJECT: protean-tooling-476420-i8
✓ VERTEX_LOCATION: us-central1
✓ GOOGLE_APPLICATION_CREDENTIALS: /home/user/.config/gcloud/...

📝 Merging configuration...
✓ Merged 2 models into litellm_config.yaml
✓ Configuration validated successfully

🚀 Deploying to ~/.claude/gateway/...
✓ Created directory structure
✓ Copied litellm_config.yaml
✓ Created .env file (0600 permissions)
✓ Generated start-gateway.sh
✓ Generated stop-gateway.sh
✓ Created deployment manifest

⚙️  Updating Claude Code settings...
✓ Updated ANTHROPIC_BASE_URL: http://localhost:4000
✓ Settings validated successfully

✅ Deployment completed successfully!

📋 Deployment Summary:
   Models deployed: gemini-2.5-flash, deepseek-r1
   Gateway type: local
   Gateway URL: http://localhost:4000
   Backup: ~/.claude/gateway/backups/gateway-backup-20251202-143022.tar.gz

🚀 Next Steps:
   1. Start the gateway:
      bash ~/.claude/gateway/start-gateway.sh

   2. Verify connection:
      claude /status

   3. View logs:
      tail -f ~/.claude/gateway/litellm.log

💡 Need help? See: specs/001-llm-gateway-config/examples/us1-quickstart-basic.md
```

**Non-Interactive Mode**:
```bash
$ bash specs/001-llm-gateway-config/scripts/deploy-gateway-config.sh \
  --models gemini-2.5-flash,deepseek-r1 \
  --backup \
  --start \
  --verbose

[2025-12-02 14:30:22] INFO: Starting deployment...
[2025-12-02 14:30:22] INFO: Prerequisites check passed
[2025-12-02 14:30:23] INFO: Created backup: gateway-backup-20251202-143022.tar.gz
[2025-12-02 14:30:23] INFO: Detected VERTEX_PROJECT: protean-tooling-476420-i8
[2025-12-02 14:30:24] INFO: Merged 2 models into configuration
[2025-12-02 14:30:24] INFO: Configuration validated successfully
[2025-12-02 14:30:25] INFO: Deployed to ~/.claude/gateway/
[2025-12-02 14:30:25] INFO: Updated settings.json
[2025-12-02 14:30:26] INFO: Starting LiteLLM proxy...
[2025-12-02 14:30:28] INFO: LiteLLM proxy started (PID: 12345)
[2025-12-02 14:30:28] SUCCESS: Deployment completed in 6 seconds
```

## Success Criteria Validation Plan

**SC-001**: User can deploy in <5 minutes
- ✅ Test: Time end-to-end deployment with default options
- ✅ Target: <5 minutes from command run to verification

**SC-002**: 95% success rate on first attempt
- ✅ Test: Run 20 deployments on clean systems
- ✅ Target: ≥19 successful without manual intervention

**SC-003**: Validation passes
- ✅ Test: Run validate-config.py on deployed configs
- ✅ Target: 100% validation pass rate

**SC-004**: Health check confirms connectivity
- ✅ Test: Run health-check.sh after deployment
- ✅ Target: Gateway responds with 200 OK

**SC-005**: Rollback in <30 seconds
- ✅ Test: Time rollback operation
- ✅ Target: <30 seconds to restore

**SC-006**: Clear progress indicators
- ✅ Test: User testing feedback
- ✅ Target: >90% users understand each step

**SC-007**: Zero-downtime updates
- ✅ Test: Update while LiteLLM running
- ✅ Target: No connection interruptions

**SC-008**: Secure credential storage
- ✅ Test: Check file permissions
- ✅ Target: .env files have 0600 permissions

---

## Risk Assessment

### High Risk Items

1. **Settings.json Corruption**
   - **Risk**: jq errors could corrupt Claude Code settings
   - **Mitigation**: Always backup before modification, validate after update, rollback on failure
   - **Owner**: deployment-core.sh validation logic

2. **Credential Exposure**
   - **Risk**: Credentials visible in logs or backups
   - **Mitigation**: Sanitize logs, encrypt backups, proper file permissions
   - **Owner**: Security review before release

### Medium Risk Items

3. **LiteLLM Process Management**
   - **Risk**: Unable to detect or stop running LiteLLM
   - **Mitigation**: Multiple detection methods (ps, lsof, netstat), clear user prompts
   - **Owner**: deployment-core.sh process handling

4. **Cross-platform Compatibility**
   - **Risk**: Script behavior differs between macOS and Linux
   - **Mitigation**: Test on both platforms, use portable commands, feature detection
   - **Owner**: Testing phase validation

### Low Risk Items

5. **Backup Storage Growth**
   - **Risk**: Unlimited backups consume disk space
   - **Mitigation**: Automatic cleanup (keep last 5), user warning if space low
   - **Owner**: backup-manager.sh rotation logic

---

## Dependencies & Handoffs

**External Dependencies**:
- spec 001 completion (✅ COMPLETE)
- LiteLLM package installed (user responsibility)
- gcloud CLI configured (user responsibility)

**Internal Dependencies**:
- troubleshooting-utils.sh (✅ exists)
- validate-config.py (✅ exists)
- check-prerequisites.sh (✅ exists)

**Handoffs**:
- After Phase 2: Task list to implementation team
- After Phase 8: Documentation to users (README update)
- After testing: Deployment script to production (merge to main)

---

## Timeline Estimate

**Phase 0**: Research (1-2 days)
**Phase 1**: Design (1-2 days)
**Phase 2**: Task Breakdown (1 day)
**Phase 3-8**: Implementation (5-7 days)
**Total**: 8-12 days for complete implementation

---

## Notes

### Key Design Decisions

1. **Bash over Python**: Bash chosen for main script because:
   - Native file operations more straightforward
   - Easier process management (start/stop LiteLLM)
   - Better shell integration (environment variables, profiles)
   - Python utilities used for complex validation only

2. **Library Organization**: Functions grouped by domain:
   - Improves testability (unit test each library)
   - Enables code reuse across scripts
   - Simplifies maintenance

3. **Backup Strategy**: Always backup before changes:
   - Reduces user anxiety about breaking existing setup
   - Enables quick rollback on failure
   - Provides deployment history audit trail

4. **Two-Phase Validation**: Validate before and after:
   - Pre-deployment: Catch errors early (fail fast)
   - Post-deployment: Verify actual deployed state
   - Rollback trigger: Post-validation failure

5. **Manifest Tracking**: Deployment manifest enables:
   - Idempotent deployments (detect what's already deployed)
   - Smart updates (only change what's different)
   - Troubleshooting (what was deployed, when, by whom)

### Implementation Priorities

**Must Have** (P1 - MVP):
- Basic deployment (copy templates, populate env vars)
- Backup and rollback
- Config validation
- Settings.json update

**Should Have** (P2):
- Custom model selection
- Enterprise gateway support
- Interactive prompts

**Nice to Have** (P3-P4):
- Multi-provider deployment
- Update existing deployments
- Proxy configuration

### Future Enhancements

Post-MVP features to consider:
- [ ] Web UI for deployment (graphical alternative)
- [ ] Automatic LiteLLM installation
- [ ] Configuration migration from other tools
- [ ] Deployment to multiple users (admin tool)
- [ ] Integration with Docker/Kubernetes
- [ ] Configuration version control (git integration)
