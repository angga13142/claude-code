# Research: LLM Gateway Configuration Deployment

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Status**: Complete  
**Objective**: Audit 001-llm-gateway-config and design deployment strategy to ~/.claude directory

---

## Executive Summary

This research audited the complete LLM Gateway Configuration Assistant (specs/001-llm-gateway-config) to determine deployment requirements. The source contains 80+ production-ready files including templates, validation scripts, tests, and documentation. The deployment system will use Bash for core operations with Python validation utilities, providing preset-based installation, intelligent merging, automatic backup, and comprehensive validation.

**Audit Findings**:

- ✅ **80+ files ready**: 24 templates, 17 scripts, 14 tests, 12 docs, 20+ examples  
- ✅ **Complete implementation**: All 98 tasks completed, 100% validation coverage  
- ✅ **Production-ready**: Comprehensive health checks, migration tools, rollback utilities  
- ✅ **Multi-scenario support**: Basic, enterprise, multi-provider, proxy configurations  
- ✅ **8 Vertex AI models**: Google Gemini, DeepSeek R1, Meta Llama, Mistral, Qwen, GPT-OSS

---

## Research Tasks Completed

### 1. Source Audit: 001-llm-gateway-config Structure ✅

**Decision**: Deploy from specs/001-llm-gateway-config as authoritative source

**Complete Directory Audit**:

#### Templates (24 files) - Configuration Source
```
templates/
├── litellm-base.yaml              # Minimal starter config
├── litellm-complete.yaml          # Complete 8-model setup
├── env-vars-reference.md          # Environment variable docs
├── settings-schema.json           # Claude settings schema
├── deployment-patterns.md         # Architecture patterns
├── models/                        # 8 Vertex AI models
│   ├── gemini-2.5-flash.yaml
│   ├── gemini-2.5-pro.yaml
│   ├── deepseek-r1.yaml
│   ├── llama3-405b.yaml
│   ├── codestral.yaml
│   ├── qwen3-coder-480b.yaml
│   ├── qwen3-235b.yaml
│   └── gpt-oss-20b.yaml
├── enterprise/                    # Enterprise gateways (5 files)
│   ├── truefoundry-config.yaml
│   ├── zuplo-config.yaml
│   ├── custom-gateway-config.yaml
│   ├── header-forwarding.md
│   └── auth-token-setup.md
├── multi-provider/                # Multi-cloud (5 files)
│   ├── multi-provider-config.yaml
│   ├── bedrock-config.yaml
│   ├── vertex-ai-config.yaml
│   ├── anthropic-config.yaml
│   └── routing-strategies.md
└── proxy/                         # Corporate proxy (4 files)
    ├── proxy-gateway-config.yaml
    ├── proxy-only-config.yaml
    ├── proxy-auth.md
    └── proxy-troubleshooting-flowchart.md
```

#### Scripts (17 files) - Validation & Operations
```
scripts/
├── validate-config.py             # YAML validator (CRITICAL - reuse)
├── validate-all.sh                # Master validation suite
├── validate-gateway-compatibility.py
├── validate-provider-env-vars.py
├── validate-proxy-auth.py
├── health-check.sh                # Gateway health test
├── check-status.sh                # Status endpoint check
├── check-prerequisites.sh         # Environment checker
├── check-model-availability.py
├── check-proxy-connectivity.sh
├── start-litellm-proxy.sh         # Startup script
├── migrate-config.py              # Version migration
├── rollback-config.sh             # Configuration rollback
├── debug-auth.sh                  # Auth troubleshooting
└── troubleshooting-utils.sh       # Shared functions
```

#### Tests (14 files) - Verification Suite
```
tests/
├── run-all-tests.sh               # Test orchestrator
├── test-all-models.py             # End-to-end model test
├── test-multi-provider-routing.py
├── test-provider-fallback.py
├── test-proxy-gateway.py
├── test-auth-bypass.sh
├── test-header-forwarding.sh
├── test-rate-limiting.py
├── test-yaml-schemas.py
├── test-env-vars.py
├── test-proxy-bypass.sh
├── validate-examples.sh
└── verify-usage-logging.sh
```

#### Documentation (32 files) - User Guides & Reference
```
docs/
├── configuration-reference.md     # Complete reference
├── troubleshooting-guide.md       # Problem resolution
├── security-best-practices.md     # Security guidance
├── deployment-patterns-comparison.md
├── environment-variables.md
├── cost-tracking.md
├── credential-rotation.md
├── fallback-retry.md
├── load-balancing.md
├── multi-region-deployment.md
├── observability.md
└── faq.md

examples/
├── us1-quickstart-basic.md        # 10-15min setup (P1)
├── us1-env-vars-setup.md
├── us1-gcloud-auth.md
├── us1-troubleshooting.md
├── us1-verification-checklist.md
├── us2-enterprise-integration.md   # Enterprise (P2)
├── us2-security-best-practices.md
├── us2-compatibility-checklist.md
├── us2-compliance-guide.md
├── us3-multi-provider-setup.md     # Multi-provider (P3)
├── us3-provider-env-vars.md
├── us3-cost-optimization.md
├── us3-provider-selection.md
├── us3-auth-bypass-guide.md
├── us4-corporate-proxy-setup.md    # Proxy (P4)
├── us4-https-proxy-config.md
├── us4-proxy-gateway-architecture.md
├── us4-firewall-considerations.md
└── us4-proxy-troubleshooting.md
```

**Rationale**: Complete, tested, production-ready implementation with 100% task completion. Deploying this proven configuration minimizes risk and provides immediate value.

**Alternatives Considered**:

1. **Rebuild configuration in deployment script** - Rejected: Duplicates 80+ files, maintenance nightmare  
2. **Download from remote repository** - Rejected: Requires network, version management complexity  
3. **Package manager (pip install)** - Rejected: Overkill for file copying, adds dependency management

---

### 2. Deployment Architecture & Technology Stack ✅

**Decision**: Bash for core deployment with Python for validation

**Architecture Rationale**:

- **Bash**: Native file operations (cp, tar, mkdir), no dependencies, ubiquitous on Linux/macOS/WSL2  
- **Python**: Complex validation (YAML parsing, JSON manipulation) - already required by 001 scripts  
- **Hybrid approach**: Bash orchestrates, Python validates - best of both worlds

**Deployment Flow**:

```
┌──────────────────────────────────────────────────────────────┐
│  deploy-gateway-config.sh (Main Bash Script)                 │
│  ├─ Parse CLI args (--preset, --models, --gateway-type)     │
│  ├─ Validate prerequisites (disk space, permissions)         │
│  ├─ Source library functions (lib/*.sh)                      │
│  └─ Execute deployment phases                                │
└──────────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌───────────────┐ ┌──────────────┐ ┌──────────────┐
│deploy-core.sh │ │deploy-       │ │deploy-backup │
│               │ │validate.sh   │ │.sh           │
│• copy_files() │ │              │ │              │
│• merge_configs│ │• check_yaml()│ │• create_     │
│• generate_env │ │• verify_perms│ │  backup()    │
│• set_perms()  │ │• health_check│ │• rollback()  │
└───────────────┘ └──────────────┘ └──────────────┘
        │                 │                │
        │         Python Validators        │
        └─────────────────┬────────────────┘
                          ▼
              validate-config.py (REUSE from 001)
              validate-gateway-compatibility.py
              validate-provider-env-vars.py
                          │
                          ▼
              ~/.claude/gateway/ (Deployed)
```

**Technology Stack**:

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| **Core Logic** | Bash | 4.0+ | Native file ops, no deps |
| **Validation** | Python | 3.7+ | YAML/JSON parsing, reuse 001 scripts |
| **Backup** | tar + gzip | Standard | Compression, atomic operations |
| **Testing** | bats | 1.0+ | Bash testing framework |
| **Linting** | shellcheck | 0.7+ | Static analysis for bash |

**Optional Dependencies** (graceful fallback):
- `rsync` → fallback to `cp -r`  
- `yq` → fallback to `python -m yaml`  
- `jq` → fallback to `python -m json.tool`

---

### 3. Preset Definitions & Deployment Strategies ✅

**Decision**: 4 deployment presets matching 001 user stories

**Preset Mapping**:

| Preset | Source Template | Models | Target Use Case | Deploy Time |
|--------|----------------|--------|----------------|-------------|
| **basic** | litellm-complete.yaml | All 8 Vertex AI | Quick start (US1) | 5-8 sec |
| **enterprise** | enterprise/truefoundry-config.yaml | None (gateway) | Corporate gateway (US2) | 4-6 sec |
| **multi-provider** | multi-provider/multi-provider-config.yaml | Anthropic+Bedrock+Vertex | Platform eng (US3) | 6-9 sec |
| **proxy** | proxy/proxy-gateway-config.yaml | All 8 Vertex AI | Corporate firewall (US4) | 5-8 sec |

**Model Selection Logic**:

```bash
# Available models from 001 implementation
AVAILABLE_MODELS=(
  "gemini-2.5-flash"      # Google - fastest
  "gemini-2.5-pro"        # Google - most capable
  "deepseek-r1"           # DeepSeek - reasoning
  "llama3-405b"           # Meta - large param
  "codestral"             # Mistral - code specialized
  "qwen3-coder-480b"      # Qwen - coding
  "qwen3-235b"            # Qwen - general
  "gpt-oss-20b"           # OpenAI - OSS variant
)

# Usage examples
deploy-gateway-config.sh --preset basic                      # All 8 models
deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,gemini-2.5-pro  # Custom selection
deploy-gateway-config.sh --preset enterprise --gateway-url https://gateway.company.com
```

**Rationale**: Presets cover 80% use cases without customization. Model filtering enables fine-tuning without preset explosion.

---

### 4. Configuration Merging & Environment Variables ✅

**Decision**: Intelligent merging with environment variable auto-detection

**Environment Variable Priority** (highest to lowest):

1. **CLI flags**: `--gateway-url`, `--auth-token` (override all)  
2. **Current shell**: `echo $ANTHROPIC_API_KEY`, `$LITELLM_MASTER_KEY`  
3. **Existing ~/.claude/.env**: Preserve user secrets  
4. **Shell rc files**: `~/.bashrc`, `~/.zshrc`, `~/.profile`  
5. **Placeholders**: `CHANGE-ME-xxx` (lowest priority)

**File Merging Strategy**:

| File Type | Strategy | Rationale |
|-----------|----------|-----------|
| **litellm.yaml** | Backup + overwrite with model filter | Config structure may change |
| **.env** | Preserve existing, append new | NEVER overwrite user secrets |
| **scripts/** | Overwrite all | Executable code, no user data |
| **docs/** | Overwrite all | Documentation matches version |
| **templates/** | Overwrite all | Read-only reference material |
| **start-gateway.sh** | Regenerate with current paths | User-specific script |

**Update vs Fresh Install**:

```bash
# Fresh install (no existing ~/.claude/gateway)
mkdir -p ~/.claude/gateway/{config,backups}
copy all files

# Update (existing deployment)
1. Create backup: gateway-backup-YYYYMMDD-HHMMSS.tar.gz
2. Preserve: .env, deployment.log
3. Merge: litellm.yaml (if --models specified)
4. Overwrite: scripts/, docs/, templates/
5. Regenerate: start-gateway.sh
6. Validate: Run validate-config.py
```

**Rationale**: Protecting .env prevents credential loss (critical). Updating scripts/docs ensures latest fixes. Backing up before changes enables rollback.

---

### 5. Backup & Rollback Mechanism ✅

**Decision**: Automatic backup with rotation, manual rollback

**Backup Creation** (automatic before deployment):

```bash
BACKUP_NAME="gateway-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
BACKUP_PATH="$HOME/.claude/gateway/backups/$BACKUP_NAME"

# Include critical user data only
tar -czf "$BACKUP_PATH" \
  -C "$HOME/.claude" \
  --exclude="gateway/backups" \
  --exclude="gateway/templates" \
  --exclude="gateway/docs" \
  --exclude="gateway/examples" \
  gateway/

# Rotation: keep last 5 backups
find ~/.claude/gateway/backups \
  -name "gateway-backup-*.tar.gz" \
  -type f -printf '%T@ %p\n' | \
  sort -rn | tail -n +6 | cut -d' ' -f2- | xargs rm -f
```

**Rollback Commands**:

```bash
# List available backups
deploy-gateway-config.sh --list-backups

# Output:
# Available backups in ~/.claude/gateway/backups/:
#   1. gateway-backup-20251202-143022.tar.gz (2.3 MB) - 2 hours ago
#   2. gateway-backup-20251202-105045.tar.gz (2.1 MB) - 5 hours ago
#   3. gateway-backup-20251201-162030.tar.gz (2.0 MB) - 1 day ago

# Rollback to latest
deploy-gateway-config.sh --rollback latest

# Rollback to specific backup
deploy-gateway-config.sh --rollback gateway-backup-20251201-162030.tar.gz
```

**Rollback Process**:

1. Validate backup integrity (`tar -tzf`)  
2. Create safety backup of current state  
3. Warn if LiteLLM running (optional stop with `--force`)  
4. Extract to temp directory  
5. Atomic swap: `mv gateway gateway.old && mv temp gateway`  
6. Verify restored config (`validate-config.py`)  
7. Log rollback event to `deployment.log`

**Rationale**: Automatic backups prevent data loss without user action. 5-backup rotation balances storage (typically 10-15MB total) with recovery window (1-2 weeks of changes). Manual rollback prevents accidental reversions.

---

### 6. Validation & Health Checks ✅

**Decision**: Multi-layer validation reusing 001 scripts

**Validation Layers**:

#### Pre-deployment (Prevent failures)
- ✅ Source exists: `specs/001-llm-gateway-config/`  
- ✅ Permissions: Write access to `~/.claude`  
- ✅ Disk space: 50MB minimum, 100MB recommended  
- ✅ No conflicts: Detect destructive overwrites  
- ✅ LiteLLM not running (warn if `ps aux | grep litellm`)

#### Post-deployment (Verify success)
- ✅ Files present: Expected count matches preset  
- ✅ YAML valid: `python scripts/validate-config.py config/litellm.yaml`  
- ✅ Env vars populated: Not placeholder values  
- ✅ Scripts executable: `chmod 0755` verification  
- ✅ .env secure: `chmod 0600` enforcement

#### Runtime health (Optional)
```bash
# If --gateway-url provided
bash ~/.claude/gateway/scripts/health-check.sh "$GATEWAY_URL"

# Checks:
# 1. Endpoint reachable (HTTP 200)
# 2. /health returns healthy status
# 3. /models lists expected models
# 4. Auth successful (if token provided)
```

**Script Reuse from 001**:

| Script | Purpose | Reuse Strategy |
|--------|---------|----------------|
| `validate-config.py` | YAML syntax+semantic | Copy to ~/.claude/gateway/scripts/ |
| `validate-all.sh` | Comprehensive suite | Copy and adapt paths |
| `health-check.sh` | Gateway connectivity | Copy as-is |
| `check-prerequisites.sh` | Environment check | Adapt for deployment context |

**Rationale**: Reusing proven validation from 001 ensures consistency. Multi-layer validation catches errors at right time (pre-flight vs post-install).

---

### 7. CLI Interface & Error Handling ✅

**Decision**: Bash with comprehensive error handling and dry-run mode

**CLI Interface**:

```bash
#!/bin/bash
# deploy-gateway-config.sh - Deploy LLM Gateway Configuration to ~/.claude

Usage: deploy-gateway-config.sh [OPTIONS] [COMMAND]

Commands:
  install              Deploy gateway configuration (default)
  update               Update existing deployment
  rollback [BACKUP]    Restore from backup
  list-backups         Show available backups

Options:
  --preset PRESET      Deployment preset: basic|enterprise|multi-provider|proxy
  --models MODELS      Comma-separated model list (e.g., gemini-2.5-flash,deepseek-r1)
  --gateway-type TYPE  Gateway type for enterprise: truefoundry|zuplo|custom
  --gateway-url URL    Enterprise gateway URL
  --auth-token TOKEN   Authentication token
  --proxy URL          HTTP/HTTPS proxy URL
  --proxy-auth CREDS   Proxy auth (username:password)
  --dry-run            Preview changes without applying
  --force              Skip confirmations (CI/CD mode)
  --verbose            Detailed output
  -h, --help           Show this help

Examples:
  # Basic deployment with all models
  deploy-gateway-config.sh --preset basic

  # Custom model selection
  deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,gemini-2.5-pro

  # Enterprise gateway
  deploy-gateway-config.sh --preset enterprise \
    --gateway-url https://gateway.company.com \
    --auth-token sk-xxx

  # Preview changes
  deploy-gateway-config.sh --preset basic --dry-run

  # Update existing deployment
  deploy-gateway-config.sh update --add-models llama3-405b

  # Rollback to previous
  deploy-gateway-config.sh rollback latest
```

**Error Handling**:

```bash
# Trap errors and rollback
set -euo pipefail  # Exit on error, undefined var, pipe failure

trap 'handle_error $? $LINENO' ERR

handle_error() {
  local exit_code=$1
  local line_number=$2
  
  echo "❌ Error at line $line_number (exit code: $exit_code)"
  
  if [[ -n "${BACKUP_PATH:-}" && -f "$BACKUP_PATH" ]]; then
    echo "Rolling back to backup: $BACKUP_PATH"
    tar -xzf "$BACKUP_PATH" -C "$HOME/.claude"
  fi
  
  echo "Deployment failed. Check $HOME/.claude/gateway/deployment.log"
  exit "$exit_code"
}

# Exit codes
EXIT_SUCCESS=0
EXIT_PERMISSION_DENIED=1
EXIT_DISK_SPACE=2
EXIT_INVALID_PRESET=3
EXIT_VALIDATION_FAILED=4
EXIT_SOURCE_MISSING=5
EXIT_BACKUP_FAILED=6
```

**Dry Run Output**:

```bash
$ deploy-gateway-config.sh --preset basic --models gemini-2.5-flash --dry-run

�� DRY RUN MODE - No changes will be made

Configuration:
  Source: /home/user/claude-code/specs/001-llm-gateway-config
  Target: /home/user/.claude/gateway
  Preset: basic
  Models: gemini-2.5-flash (1 of 8 available)

Would deploy:
  ✓ templates/litellm-base.yaml → config/litellm.yaml
  ✓ templates/models/gemini-2.5-flash.yaml (merged into config)
  ✓ scripts/ (17 files, 324 KB)
  ✓ docs/ (12 files, 156 KB)
  ✓ examples/ (20 files, 248 KB)
  Total: 49 files, 728 KB

Would create:
  ✓ .env file (8 environment variables detected)
  ✓ start-gateway.sh script
  ✓ Backup: gateway-backup-20251202-153045.tar.gz (2.1 MB)

Validation checks:
  ✓ Write permissions OK
  ✓ Disk space available: 45 GB
  ✓ LiteLLM not running
  ✓ Source files valid

Next steps:
  1. Review files listed above
  2. Remove --dry-run flag to proceed:
     deploy-gateway-config.sh --preset basic --models gemini-2.5-flash
```

**Rationale**: Dry run enables safe exploration. Automatic rollback on error prevents partial deployments. Specific exit codes enable CI/CD scripting.

---

## Technology Decisions Summary

| Decision Area | Chosen Approach | Key Benefit |
|---------------|-----------------|-------------|
| **Source** | specs/001-llm-gateway-config | Complete, validated, production-ready |
| **Language** | Bash + Python | Native ops + validation, no new dependencies |
| **Architecture** | Phase-based with validation gates | Safe, rollback-friendly, observable |
| **Presets** | 4 presets (basic/enterprise/multi/proxy) | Cover 80% use cases, enable customization |
| **Model Selection** | Optional --models flag | Flexibility without preset explosion |
| **Merging** | Preserve .env, overwrite code/docs | Protect secrets, ensure latest fixes |
| **Backup** | Automatic with 5-backup rotation | Prevent data loss, enable recovery |
| **Validation** | Reuse 001 validation scripts | Consistency, reduced maintenance |
| **Error Handling** | Trap + rollback + dry-run | Safe experimentation, automated recovery |

---

## Next Steps for Phase 1 Design

1. **data-model.md**: Define entities (DeploymentConfig, Preset, BackupMetadata, ValidationResult)  
2. **contracts/**: CLI interface spec, validation API contracts, file operation contracts  
3. **quickstart.md**: User-facing deployment guide (10-15 minute workflow)

