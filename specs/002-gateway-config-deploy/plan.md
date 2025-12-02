# Implementation Plan: LLM Gateway Configuration Deployment

**Branch**: `002-gateway-config-deploy` | **Date**: 2025-12-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-gateway-config-deploy/spec.md`

**Note**: This plan deploys the complete LLM Gateway Configuration Assistant (001-llm-gateway-config) to ~/.claude directory for immediate use.

## Summary

Deploy the comprehensive LLM Gateway Configuration Assistant from specs/001-llm-gateway-config to the user's Claude Code home directory (~/.claude/gateway/). The deployment tool will intelligently copy templates, scripts, documentation, and configurations while providing preset-based deployment (basic, enterprise, multi-provider, proxy), model selection, configuration validation, automatic backup, and health checks. This enables users to quickly adopt the gateway infrastructure without manual file management.

## Technical Context

**Language/Version**: Bash 4.0+ (deployment scripts), Python 3.7+ (validation utilities)  
**Primary Dependencies**: 
- Bash built-ins (cp, mkdir, tar, sed, awk)
- Python standard library (argparse, yaml, json, pathlib)
- Optional: yq (for YAML manipulation), jq (for JSON processing)

**Storage**: Filesystem-based deployment to ~/.claude/gateway/ with backups in ~/.claude/gateway/backups/  
**Testing**: pytest for Python validation, bats for bash script testing  
**Target Platform**: Linux (primary), macOS (compatible), WSL2 (compatible)  
**Project Type**: Single CLI tool deployment system  
**Performance Goals**: 
- Deployment completes in <10 seconds for basic preset
- Validation runs in <5 seconds
- Backup creation <2 seconds

**Constraints**: 
- Must preserve existing user configurations
- Zero downtime for running LiteLLM instances (warn before deployment)
- File permissions must be secure (0700 for directories, 0600 for .env files)

**Scale/Scope**: 
- Deploy 80+ files (templates, scripts, docs, examples)
- Support 4 deployment presets (basic, enterprise, multi-provider, proxy)
- Handle 8 Vertex AI model configurations
- Backup rotation (keep last 5 backups, auto-cleanup)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Code Quality Standards - ✅ PASS

- **Readability**: Bash scripts use clear function names, Python validation utilities follow PEP 8
- **Maintainability**: Deployment tool follows single responsibility (copy, validate, backup as separate functions)
- **Consistency**: Bash follows Google Shell Style Guide, Python follows PEP 8 with Black formatting
- **Modularity**: Reusable validation library in Python, sourced utility functions in Bash
- **Error Handling**: Comprehensive error checks with exit codes, rollback on failure
- **Documentation**: All functions have header comments explaining purpose, parameters, expected behavior

### II. Testing Standards - ✅ PASS

- **Coverage Minimum**: Target 80% for Python validation utilities (pytest), 70% for Bash (bats framework)
- **Test Pyramid**: 70% unit (file operations, config parsing), 20% integration (end-to-end deployment), 10% E2E (real ~/.claude deployment)
- **TDD/BDD**: Write tests for validation logic before implementation (pytest fixtures for filesystem mocking)
- **CI/CD Integration**: GitHub Actions run tests on PR, deployment validation on merge
- **Edge Cases**: Test existing config preservation, permission failures, disk space, corrupt YAML
- **Test Quality**: Independent tests with tmpdir fixtures, deterministic results, <1s unit tests

### III. User Experience Consistency - ✅ PASS (CLI-focused)

- **Responsive Design**: N/A (CLI tool)
- **Accessibility**: Clear error messages, progress indicators (ASCII spinner), color-coded output (green/red/yellow)
- **Interface Patterns**: Consistent flag naming (--preset, --models, --gateway-type), follows GNU conventions
- **Performance Perception**: Progress indicators during file copy, "Validating..." spinner during checks
- **Error Feedback**: Actionable messages ("Missing GCP credentials. Run: gcloud auth application-default login")
- **Design System**: Follows Claude Code CLI conventions for command structure and output formatting

### IV. Performance Requirements - ✅ PASS (adjusted for CLI)

- **Load Time Targets**: N/A (CLI tool)
- **Optimization**: Use rsync for large file copies, parallel validation of multiple YAML files
- **Database Efficiency**: N/A (filesystem only)
- **Caching**: Cache validation results during single run, reuse parsed YAML across functions
- **Bundle Size**: N/A (scripts deployed directly)
- **Performance Monitoring**: Log deployment time, file count, validation duration for troubleshooting

**Gate Status**: ✅ ALL GATES PASS - Proceed to Phase 0 Research

## Project Structure

### Documentation (this feature)

```text
specs/002-gateway-config-deploy/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - deployment strategy research
├── data-model.md        # Phase 1 output - configuration entities
├── quickstart.md        # Phase 1 output - quick deployment guide
├── contracts/           # Phase 1 output - CLI interface contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (deployment tool in specs/001-llm-gateway-config)

```text
specs/001-llm-gateway-config/   # SOURCE - Configuration to deploy
├── templates/                   # YAML configurations (24 files)
│   ├── litellm-base.yaml
│   ├── litellm-complete.yaml
│   ├── models/                 # 8 Vertex AI model configs
│   ├── enterprise/             # TrueFoundry, Zuplo, custom
│   ├── multi-provider/         # Multi-cloud routing
│   └── proxy/                  # Corporate proxy configs
├── scripts/                    # Validation & operations (17 scripts)
│   ├── validate-config.py
│   ├── validate-all.sh
│   ├── health-check.sh
│   ├── start-litellm-proxy.sh
│   ├── migrate-config.py
│   └── rollback-config.sh
├── tests/                      # Test suites (14 test files)
│   ├── test-all-models.py
│   ├── test-proxy-gateway.py
│   └── run-all-tests.sh
├── docs/                       # Reference documentation (12 docs)
│   ├── configuration-reference.md
│   ├── troubleshooting-guide.md
│   └── security-best-practices.md
├── examples/                   # User story guides (20 examples)
│   ├── us1-quickstart-basic.md
│   ├── us2-enterprise-integration.md
│   ├── us3-multi-provider-setup.md
│   └── us4-corporate-proxy-setup.md
└── quickstart.md              # Main integration guide

# NEW - Deployment tool to be created
scripts/deploy-gateway-config.sh    # Main deployment CLI
scripts/lib/
├── deploy-core.sh              # Core deployment functions
├── deploy-validate.sh          # Pre/post deployment validation
├── deploy-backup.sh            # Backup/restore operations
└── deploy-presets.sh           # Preset configurations

tests/deploy/
├── test-deploy-basic.bats      # Basic deployment tests
├── test-deploy-presets.bats    # Preset-specific tests
├── test-deploy-validation.bats # Validation tests
└── test-deploy-rollback.bats   # Rollback tests

# TARGET - User's home directory after deployment
~/.claude/
└── gateway/
    ├── config/
    │   └── litellm.yaml        # Active configuration
    ├── templates/              # All source templates (copy)
    ├── scripts/                # All validation scripts (copy)
    ├── docs/                   # All documentation (copy)
    ├── examples/               # All examples (copy)
    ├── backups/                # Automated backups
    │   ├── gateway-backup-20251202-103045.tar.gz
    │   └── gateway-backup-20251202-095030.tar.gz
    ├── .env                    # Environment variables
    ├── start-gateway.sh        # Generated startup script
    └── deployment.log          # Deployment history
```

**Structure Decision**: Single CLI tool architecture. The deployment script resides in the repository (scripts/deploy-gateway-config.sh) and deploys content from specs/001-llm-gateway-config/ to ~/.claude/gateway/. This separates source configurations (version controlled) from deployed instances (user-specific). The tool supports idempotent deployments with automatic backup before any destructive operations.

## Complexity Tracking

> **No Constitution Violations - No Justifications Required**

All design decisions align with constitution principles. No complexity justification needed.

---

## Phase Execution Summary

### ✅ Phase 0: Research (COMPLETED)

**Objective**: Audit 001-llm-gateway-config and establish deployment architecture

**Deliverables**:
- ✅ `research.md` - Complete audit of 80+ files in 001-llm-gateway-config
- ✅ Technology decisions: Bash + Python hybrid approach
- ✅ 4 preset definitions: basic, enterprise, multi-provider, proxy
- ✅ Deployment architecture with validation gates
- ✅ Backup/rollback strategy with 5-backup rotation
- ✅ Environment variable detection and merging logic

**Key Findings**:
- Source contains 24 templates, 17 scripts, 14 tests, 32 docs/examples
- All 98 tasks from 001 completed with 100% validation coverage
- Reuse proven validation scripts (validate-config.py, health-check.sh)
- Deploy 4 presets covering 80% use cases

---

### ✅ Phase 1: Design & Contracts (COMPLETED)

**Objective**: Define data model, API contracts, and user documentation

**Deliverables**:
- ✅ `data-model.md` - 7 entities with validation rules
  - DeploymentConfig (main configuration)
  - Preset (4 preset definitions)
  - Model (8 Vertex AI models)
  - BackupMetadata (backup tracking)
  - ValidationResult (multi-layer validation)
  - EnvironmentVariable (auto-detection)
  - DeploymentLog (audit trail)
- ✅ `contracts/cli-interface.md` - Complete CLI specification
  - 4 commands: install, update, rollback, list-backups
  - Exit code contracts (0-6)
  - Error message format
  - Dry-run and interactive mode contracts
- ✅ `quickstart.md` - User-facing deployment guide
  - 5-10 minute quick start
  - 4 preset examples
  - Verification steps
  - Troubleshooting guide

**Constitution Check Re-evaluation**: ✅ ALL GATES STILL PASS

---

## Next Steps

### Phase 2: Tasks Breakdown

**Command**: `/speckit.tasks` 

This will generate `tasks.md` with:
- Detailed task breakdown for implementation
- Test-first development workflow
- Priority assignments (P0-P3)
- Time estimates per task
- Dependencies between tasks

**Note**: Phase 2 is NOT executed by `/speckit.plan`. Run `/speckit.tasks` separately.

---

## Implementation Preview

Based on this plan, implementation will create:

**New Files** (~10 files):
```
scripts/deploy-gateway-config.sh          # Main CLI (500-700 LOC)
scripts/lib/deploy-core.sh                # Core functions (300-400 LOC)
scripts/lib/deploy-validate.sh            # Validation (200-300 LOC)
scripts/lib/deploy-backup.sh              # Backup operations (150-200 LOC)
scripts/lib/deploy-presets.sh             # Preset logic (200-250 LOC)
tests/deploy/test-deploy-basic.bats       # Basic tests (100-150 LOC)
tests/deploy/test-deploy-presets.bats     # Preset tests (150-200 LOC)
tests/deploy/test-deploy-validation.bats  # Validation tests (100-150 LOC)
tests/deploy/test-deploy-rollback.bats    # Rollback tests (100-150 LOC)
tests/deploy/test-integration.bats        # E2E tests (200-300 LOC)
```

**Total Estimated LOC**: ~2,000-2,500 lines of Bash + BATS

**Test Coverage Target**: 80% (per constitution)
- 70% unit tests (function-level, mocked filesystem)
- 20% integration tests (real file operations in tmpdir)
- 10% E2E tests (actual ~/.claude deployment in test environment)

---

## Success Criteria

This plan is complete when:

✅ All research questions resolved  
✅ Technology stack chosen (Bash + Python)  
✅ Data model defined with 7 entities  
✅ CLI interface contract specified  
✅ User documentation (quickstart) created  
✅ Constitution compliance verified  
✅ Agent context updated with new technology

**Status**: ✅ **PLAN PHASE COMPLETE**

**Branch**: `002-gateway-config-deploy`  
**Plan File**: `/home/senarokalie/claude-code/specs/002-gateway-config-deploy/plan.md`  
**Next Command**: `/speckit.tasks` (to generate tasks.md)
