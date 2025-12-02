# Tasks: LLM Gateway Configuration Deployment

**Input**: Design documents from `/specs/002-gateway-config-deploy/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in spec.md, therefore test tasks are EXCLUDED from this breakdown per template guidelines.

**Organization**: Tasks grouped by user story for independent implementation and delivery.

## Format: `- [ ] [ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1, US2, US3, US4, US5, US6)
- File paths are relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [X] T001 Create scripts/ directory structure: scripts/lib/ for library functions
- [X] T002 Create tests/deploy/ directory for deployment test files
- [X] T003 [P] Create .shellcheckrc configuration file in repository root
- [X] T004 [P] Add bats testing framework to development dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core library functions that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 [P] Implement color output functions in scripts/lib/deploy-output.sh (echo_success, echo_error, echo_warning, echo_info)
- [X] T006 [P] Implement file permission functions in scripts/lib/deploy-perms.sh (set_file_perms, validate_perms)
- [X] T007 [P] Implement environment variable detection in scripts/lib/deploy-env.sh (detect_env_vars, merge_env_sources)
- [X] T008 Implement core preset loading in scripts/lib/deploy-presets.sh (load_preset_definition, validate_preset)
- [X] T009 Implement model validation in scripts/lib/deploy-models.sh (validate_model_names, filter_models_by_preset)
- [X] T010 Implement FR-036 validation: backup functions in scripts/lib/deploy-backup.sh (create_backup, list_backups, validate_backup_integrity)
- [X] T011 Implement rollback functions in scripts/lib/deploy-backup.sh (rollback_from_backup, create_safety_backup)
- [X] T012 Implement FR-030 validation: pre-deployment validation in scripts/lib/deploy-validate.sh (validate_source_directory, validate_disk_space, validate_permissions, validate_preset, validate_models)
- [X] T013 Implement FR-030 validation: post-deployment validation in scripts/lib/deploy-validate.sh (validate_yaml_config, validate_file_count, validate_env_file_permissions)
- [X] T014 Implement FR-033 validation: deployment logging in scripts/lib/deploy-log.sh (write_deployment_log to ~/.claude/gateway/deployment.log, append_to_log)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Quick Deploy Base Configuration (Priority: P1) 🎯 MVP

**Goal**: Deploy working LiteLLM gateway with all 8 Vertex AI models to ~/.claude/gateway/

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh --preset basic`, verify files in ~/.claude/gateway/, start LiteLLM, test with `claude /status`

### Implementation for User Story 1

- [X] T015 [P] [US1] Create main CLI entry point in scripts/deploy-gateway-config.sh with FR-031, FR-032 validation: argument parsing (--preset, --models, --dry-run, --force, --verbose, --help)
- [X] T016 [P] [US1] Implement install command handler in scripts/deploy-gateway-config.sh (calls deploy_basic function)
- [X] T017 [US1] Implement deploy_basic function in scripts/lib/deploy-core.sh (orchestrates: validate pre → backup → copy files → generate config → validate post)
- [X] T018 [US1] Implement copy_template_files function in scripts/lib/deploy-core.sh (copy templates/, scripts/, docs/, examples/ from source to target)
- [X] T019 [US1] Implement generate_env_file function in scripts/lib/deploy-core.sh (detect env vars, write to ~/.claude/gateway/.env with 0600 permissions)
- [X] T020 [US1] Implement generate_startup_script function in scripts/lib/deploy-core.sh (create ~/.claude/gateway/start-gateway.sh with correct paths)
- [X] T021 [US1] Implement create_directory_structure function in scripts/lib/deploy-core.sh (mkdir -p config/, templates/, scripts/, docs/, examples/, backups/)
- [X] T022 [US1] Add FR-001 validation: verify all template files copied to ~/.claude/gateway/templates/
- [X] T023 [US1] Add FR-002 validation: verify ~/.claude/gateway/ created with 0700 permissions
- [X] T024 [US1] Add FR-003 validation: run validate-config.py on deployed litellm.yaml
- [X] T025 [US1] Add FR-004 validation: verify environment variables detected from shell, rc files, existing .env
- [X] T026 [US1] Add FR-005 validation: verify ~/.claude/gateway/.env created with required variables (LITELLM_MASTER_KEY, GOOGLE_APPLICATION_CREDENTIALS)
- [X] T026b [US1] Add FR-006 validation: verify ~/.claude/settings.json updated with gateway endpoint URL
- [X] T027 [US1] Add FR-007 validation: verify start-gateway.sh generated and executable (0755)
- [X] T028 [US1] Add FR-008 validation: verify backup created in ~/.claude/gateway/backups/ as gateway-backup-YYYYMMDD-HHMMSS.tar.gz

**Checkpoint**: User Story 1 complete - basic deployment working end-to-end

---

## Phase 4: User Story 2 - Deploy with Custom Model Selection (Priority: P2)

**Goal**: Enable users to deploy only specific models instead of all 8

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh --preset basic --models gemini-2.5-flash,deepseek-r1`, verify only selected models in config

### Implementation for User Story 2

- [X] T029 [P] [US2] Add --models flag parsing to scripts/deploy-gateway-config.sh CLI argument parser
- [X] T030 [US2] Implement filter_models_by_selection function in scripts/lib/deploy-models.sh (parse comma-separated list, validate against AVAILABLE_MODELS)
- [X] T031 [US2] Implement merge_model_configs function in scripts/lib/deploy-core.sh (read model YAML files from templates/models/, merge into litellm.yaml)
- [X] T032 [US2] Add model validation to deploy_basic: if --models specified, filter before copying
- [X] T033 [US2] Add FR-009 validation: warn about invalid model names but proceed with valid ones
- [X] T034 [US2] Add FR-010 validation: validate model names against available model list
- [X] T034b [US2] Add FR-011 validation: show available model list with descriptions on invalid model error
- [X] T035 [US2] Add FR-012 validation: update generate_config function to merge selected model configs into single litellm.yaml

**Checkpoint**: User Story 2 complete - model selection working

---

## Phase 5: User Story 3 - Deploy Enterprise Gateway Configuration (Priority: P2)

**Goal**: Deploy config for connecting to enterprise gateway instead of local LiteLLM

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh --preset enterprise --gateway-url https://gateway.company.com --auth-token sk-xxx`, verify Claude Code settings.json updated

### Implementation for User Story 3

- [X] T036 [P] [US3] Add --preset enterprise support to load_preset_definition in scripts/lib/deploy-presets.sh
- [X] T037 [P] [US3] Add --gateway-type, --gateway-url, --auth-token flags to scripts/deploy-gateway-config.sh CLI parser
- [X] T038 [US3] Implement deploy_enterprise function in scripts/lib/deploy-core.sh (copy enterprise templates, skip local LiteLLM setup)
- [X] T039 [US3] Implement update_claude_settings function in scripts/lib/deploy-core.sh (update ~/.claude/settings.json with gateway URL)
- [X] T040 [US3] Implement copy_enterprise_templates function in scripts/lib/deploy-core.sh (copy from templates/enterprise/ based on gateway type)
- [X] T041 [US3] Add FR-014 validation: verify enterprise gateway URL is valid HTTPS
- [X] T042 [US3] Add FR-015 validation: verify auth token is non-empty when gateway-url provided
- [X] T043 [US3] Add FR-016 validation: update settings.json with enterprise gateway endpoint
- [X] T043b [US3] Add FR-017 validation: run health check against gateway URL /health endpoint if reachable

**Checkpoint**: User Story 3 complete - enterprise gateway deployment working

---

## Phase 6: User Story 4 - Deploy Multi-Provider Configuration (Priority: P3)

**Goal**: Deploy config that routes to multiple providers (Anthropic, Bedrock, Vertex AI)

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh --preset multi-provider`, verify routing config includes all providers

### Implementation for User Story 4

- [ ] T044 [P] [US4] Add --preset multi-provider support to load_preset_definition in scripts/lib/deploy-presets.sh
- [ ] T045 [US4] Implement deploy_multi_provider function in scripts/lib/deploy-core.sh (copy multi-provider templates)
- [ ] T046 [US4] Implement copy_multi_provider_templates function in scripts/lib/deploy-core.sh (copy from templates/multi-provider/)
- [ ] T047 [US4] Add multi-provider env var detection: ANTHROPIC_API_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
- [ ] T048 [US4] Add FR-020 validation: set provider-specific environment variables for each provider
- [ ] T049 [US4] Add FR-021 validation: configure auth bypass flags when appropriate (e.g., ANTHROPIC_VERTEX_AUTH_BYPASS=1)

**Checkpoint**: User Story 4 complete - multi-provider deployment working

---

## Phase 7: User Story 5 - Update Existing Deployment (Priority: P3)

**Goal**: Update deployed config with new models/settings without starting from scratch

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh update --add-models llama3-405b` on existing deployment, verify model added without losing existing

### Implementation for User Story 5

- [ ] T050 [P] [US5] Add update command to scripts/deploy-gateway-config.sh CLI (separate from install)
- [ ] T051 [P] [US5] Add --add-models and --remove-models flags to update command parser
- [ ] T052 [US5] Implement deploy_update function in scripts/lib/deploy-core.sh (detect existing, merge changes)
- [ ] T053 [US5] Implement merge_existing_config function in scripts/lib/deploy-core.sh (read existing litellm.yaml, add/remove models, preserve custom settings)
- [ ] T054 [US5] Implement preserve_custom_settings function in scripts/lib/deploy-core.sh (detect user modifications in .env, preserve during update)
- [ ] T055 [US5] Add FR-022 validation: verify --update flag and detect existing deployment before update
- [ ] T056 [US5] Add FR-025 validation: create incremental backup before any update operation
- [ ] T057 [US5] Add FR-024 validation: preserve user customizations in config files during updates

**Checkpoint**: User Story 5 complete - updates working without data loss

---

## Phase 8: User Story 6 - Proxy Configuration Deployment (Priority: P4)

**Goal**: Deploy with corporate proxy settings for restricted networks

**Independent Test**: Run `bash scripts/deploy-gateway-config.sh --preset proxy --proxy https://proxy.company.com:8080 --proxy-auth user:pass`, verify proxy configured

### Implementation for User Story 6

- [ ] T058 [P] [US6] Add --preset proxy support to load_preset_definition in scripts/lib/deploy-presets.sh
- [ ] T059 [P] [US6] Add --proxy and --proxy-auth flags to scripts/deploy-gateway-config.sh CLI parser
- [ ] T060 [US6] Implement deploy_proxy function in scripts/lib/deploy-core.sh (copy proxy templates, configure HTTPS_PROXY)
- [ ] T061 [US6] Implement copy_proxy_templates function in scripts/lib/deploy-core.sh (copy from templates/proxy/)
- [ ] T062 [US6] Add FR-028 validation: set HTTP_PROXY, HTTPS_PROXY environment variables in deployed configs
- [ ] T063 [US6] Add FR-026 validation: verify proxy URL is valid HTTP/HTTPS
- [ ] T064 [US6] Add FR-027 validation: warn if proxy credentials in URL (security risk), support --proxy-auth flag
- [ ] T065 [US6] Add FR-029 validation: configure LiteLLM to use proxy for upstream provider connections

**Checkpoint**: User Story 6 complete - proxy deployment working

---

## Phase 9: Additional Commands & Features

**Purpose**: Rollback, list-backups, dry-run mode, and error handling

- [ ] T066 [P] Add FR-034 validation: add rollback command to scripts/deploy-gateway-config.sh (rollback [BACKUP_NAME])
- [ ] T067 [P] Add FR-035 validation: add list-backups command to scripts/deploy-gateway-config.sh (shows all backups with metadata)
- [ ] T068 Add FR-031 validation: implement dry_run mode in scripts/lib/deploy-core.sh (show would-be actions without executing)
- [ ] T069 Implement print_dry_run_summary function in scripts/lib/deploy-output.sh (display deployment preview for FR-031)
- [ ] T070 Add --force flag support to skip all confirmation prompts (CI/CD mode - enhancement feature)
- [ ] T071 Implement interactive confirmations for: existing deployment overwrite, LiteLLM running warning
- [ ] T072 Add error trapping with trap 'handle_error $? $LINENO' ERR in main script
- [ ] T073 Implement handle_error function in scripts/lib/deploy-core.sh (automatic rollback on failure)
- [ ] T074 Add exit code constants (0-6) for different failure modes per contracts/cli-interface.md
- [ ] T075 Implement print_help function in scripts/deploy-gateway-config.sh (comprehensive help text)
- [ ] T076 Implement print_version function in scripts/deploy-gateway-config.sh (show version info)

---

## Phase 10: Edge Cases & Robustness

**Purpose**: Handle all edge cases from spec.md

- [ ] T077 [P] Handle ~/.claude directory missing: create with 0700 permissions (edge case 1)
- [ ] T078 [P] Handle existing gateway config: prompt user (overwrite/backup/merge) or --force (edge case 2)
- [ ] T079 Handle GCP credentials missing: show error with authentication guide link (edge case 3)
- [ ] T080 Handle invalid YAML in deployed config: validate before write, rollback on error (edge case 4)
- [ ] T081 Handle LiteLLM already running: warn user to stop service first or offer restart (edge case 5)
- [ ] T082 Handle permission denied to ~/.claude: show clear error with chmod suggestion (edge case 6)
- [ ] T083 Handle model not available in user's GCP region: warn but allow deployment with comment in config (edge case 7)
- [ ] T084 Handle network unavailable during validation: skip online checks, warn to validate manually (edge case 8)
- [ ] T085 Handle disk space insufficient: check before deployment, fail with clear error (edge case 9)
- [ ] T086 Handle source directory missing/corrupted: validate source integrity before starting (edge case 10)

---

## Phase 11: Polish & Documentation

**Purpose**: Final touches for production readiness

- [ ] T087 [P] Add shellcheck linting to all bash scripts (fix warnings)
- [ ] T088 [P] Add comprehensive function header comments to all library functions (purpose, params, returns, example)
- [ ] T089 [P] Create deployment example output in docs/ showing successful deployment
- [ ] T090 [P] Create error message examples in docs/ for all error codes
- [ ] T091 Add progress indicators: spinner during file copy, "Validating..." during checks
- [ ] T092 Add deployment summary output: files copied count, models deployed, backup location
- [ ] T093 Add color-coded validation output: green ✓ for pass, red ✗ for fail, yellow ⚠ for warn
- [ ] T094 Verify all error messages follow contract format from contracts/cli-interface.md
- [ ] T095 Add timing information: log deployment duration, validation duration
- [ ] T096 Verify quickstart.md instructions match actual CLI behavior
- [ ] T097 Test all 4 presets end-to-end: basic, enterprise, multi-provider, proxy
- [ ] T098 Test all edge cases manually: missing dirs, invalid configs, permission errors
- [ ] T099 Run complete deployment → rollback → re-deploy cycle to verify backup integrity
- [ ] T100 Update README.md with deployment tool usage and examples

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup → BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational → MVP delivery
- **User Story 2 (Phase 4)**: Depends on Foundational + US1 (reuses deploy_basic)
- **User Story 3 (Phase 5)**: Depends on Foundational (independent of US1/US2)
- **User Story 4 (Phase 6)**: Depends on Foundational (independent of US1/US2/US3)
- **User Story 5 (Phase 7)**: Depends on US1 complete (updates existing deployment)
- **User Story 6 (Phase 8)**: Depends on Foundational (independent of other stories)
- **Additional Features (Phase 9)**: Can start after US1, run parallel to other stories
- **Edge Cases (Phase 10)**: Depends on all core user stories complete
- **Polish (Phase 11)**: Depends on all implementation complete

### User Story Dependencies

- **US1 (P1)**: MVP - No dependencies on other stories, only Foundational
- **US2 (P2)**: Extends US1 - adds model filtering to basic deployment
- **US3 (P2)**: Independent - enterprise deployment is separate path
- **US4 (P3)**: Independent - multi-provider is separate path
- **US5 (P3)**: Depends on US1 - updates existing basic deployment
- **US6 (P4)**: Independent - proxy deployment is separate path

### Within Each User Story

1. Implement core deployment function (deploy_basic, deploy_enterprise, etc.)
2. Implement helper functions (copy, generate, merge)
3. Add validations (FR-xxx requirements)
4. Test independently before proceeding

### Parallel Opportunities (by phase)

**Phase 1 Setup**: All 4 tasks can run in parallel  
**Phase 2 Foundational**: T005, T006, T007 can run in parallel (different files)

**Phase 3 US1**: T015, T016 can run in parallel (different functions in same file - careful merge needed)

**Phase 4 US2**: T029, T030 can run in parallel  
**Phase 5 US3**: T036, T037 can run in parallel  
**Phase 6 US4**: T044, T045 can run in parallel  
**Phase 7 US5**: T050, T051 can run in parallel  
**Phase 8 US6**: T058, T059 can run in parallel

**Phase 9 Additional**: T066, T067 can run in parallel (different commands)

**Phase 10 Edge Cases**: T077, T078, T079 can run in parallel (different error handlers)

**Phase 11 Polish**: T087, T088, T089, T090 can run in parallel (different files/tasks)

---

## Parallel Example: User Story 1 Implementation

```bash
# Can launch together (different files):
T015: "Create main CLI entry point in scripts/deploy-gateway-config.sh"
T018: "Implement copy_template_files in scripts/lib/deploy-core.sh"
T019: "Implement generate_env_file in scripts/lib/deploy-core.sh"
T020: "Implement generate_startup_script in scripts/lib/deploy-core.sh"

# Must be sequential (same function, data flow):
T017: "Implement deploy_basic" (orchestrates other functions)
  ↓ (depends on T018, T019, T020 complete)
T022-T028: Validation tasks (verify deploy_basic works)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

**Goal**: Working basic deployment in ~2-3 days

1. **Day 1**: Complete Phase 1 (Setup) + Phase 2 (Foundational) - ~6 hours
   - T001-T014: All library functions ready
2. **Day 2**: Complete Phase 3 (User Story 1) - ~8 hours
   - T015-T028: Basic deployment working end-to-end
3. **Day 3**: Validation + fixes - ~4 hours
   - Test with actual 001-llm-gateway-config source
   - Fix any issues found
   - **DEMO READY**: Users can deploy with --preset basic

### Incremental Delivery

1. **Week 1**: US1 (basic) → Deploy MVP
2. **Week 2**: US2 (model selection) + US3 (enterprise) → Add flexibility
3. **Week 3**: US4 (multi-provider) + US5 (updates) → Power user features
4. **Week 4**: US6 (proxy) + Edge cases + Polish → Production ready

### Parallel Team Strategy

**3 developers, 2 weeks**:

**Week 1** (Foundation + MVP):
- All: Complete Phase 1 + Phase 2 together (Day 1-2)
- Dev A: US1 (basic deployment) - Phase 3
- Dev B: US3 (enterprise) - Phase 5
- Dev C: US6 (proxy) - Phase 8

**Week 2** (Features + Polish):
- Dev A: US2 (model selection) + US5 (updates) - Phases 4, 7
- Dev B: US4 (multi-provider) - Phase 6
- Dev C: Additional commands + Edge cases - Phases 9, 10
- All: Polish together - Phase 11

---

## Task Count Summary

- **Setup**: 4 tasks
- **Foundational**: 10 tasks (CRITICAL PATH)
- **US1 (P1 MVP)**: 14 tasks
- **US2 (P2)**: 7 tasks
- **US3 (P2)**: 8 tasks
- **US4 (P3)**: 6 tasks
- **US5 (P3)**: 8 tasks
- **US6 (P4)**: 8 tasks
- **Additional Features**: 11 tasks
- **Edge Cases**: 10 tasks
- **Polish**: 14 tasks

**Total**: 100 tasks

**MVP Scope** (US1 only): 28 tasks (Setup + Foundational + US1)  
**Full Feature Complete**: 100 tasks

---

## Notes

- No test tasks included per template guidelines (tests not explicitly requested in spec.md)
- All tasks follow strict checkbox format: `- [ ] [TaskID] [P?] [Story?] Description with file path`
- [P] marker indicates parallelizable tasks (different files, no dependencies)
- [Story] marker (US1-US6) maps tasks to user stories for traceability
- Each user story is independently testable and deliverable
- MVP (US1) delivers immediate value: working basic deployment
- Incremental delivery enables early feedback and validation
- Edge cases handled in dedicated phase after core functionality stable
- Polish phase ensures production-ready quality
