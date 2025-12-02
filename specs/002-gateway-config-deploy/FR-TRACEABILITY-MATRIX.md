# FR-to-Task Traceability Matrix

**Feature**: 002-gateway-config-deploy  
**Date**: 2025-12-02  
**Status**: ✅ COMPLETE - All 36 FRs mapped to tasks

---

## Complete Mapping (FR → Tasks)

| FR ID | Requirement Summary | Mapped Task(s) | Phase | Status |
|-------|---------------------|----------------|-------|--------|
| **FR-001** | Copy templates to ~/.claude/gateway/ | T018, T022 | 3 (US1) | ✅ Mapped |
| **FR-002** | Create directory with 0700 permissions | T021, T023 | 3 (US1) | ✅ Mapped |
| **FR-003** | Validate YAML before deployment | T024 | 3 (US1) | ✅ Mapped |
| **FR-004** | Populate environment variables | T007, T025 | 2, 3 | ✅ Mapped |
| **FR-005** | Create .env file | T019, T026 | 3 (US1) | ✅ Mapped |
| **FR-006** | Update settings.json with gateway endpoint | T026b | 3 (US1) | ✅ Mapped |
| **FR-007** | Generate start-gateway.sh | T020, T027 | 3 (US1) | ✅ Mapped |
| **FR-008** | Create backup before overwriting | T010, T028 | 2, 3 | ✅ Mapped |
| **FR-009** | Support --models flag | T029, T033 | 4 (US2) | ✅ Mapped |
| **FR-010** | Validate model names | T030, T034 | 4 (US2) | ✅ Mapped |
| **FR-011** | Show available model list | T034b | 4 (US2) | ✅ Mapped |
| **FR-012** | Merge model configs | T031, T034b, T035 | 4 (US2) | ✅ Mapped |
| **FR-013** | Support --gateway-type flag | T037 | 5 (US3) | ✅ Mapped |
| **FR-014** | Accept --gateway-url flag | T037, T041 | 5 (US3) | ✅ Mapped |
| **FR-015** | Accept --auth-token flag | T037, T042 | 5 (US3) | ✅ Mapped |
| **FR-016** | Update settings.json for enterprise | T039, T043 | 5 (US3) | ✅ Mapped |
| **FR-017** | Run health check | T043b | 5 (US3) | ✅ Mapped |
| **FR-018** | Support --multi-provider flag | T044 | 6 (US4) | ✅ Mapped |
| **FR-019** | Deploy multi-provider config | T045, T046 | 6 (US4) | ✅ Mapped |
| **FR-020** | Set provider env vars | T047, T048 | 6 (US4) | ✅ Mapped |
| **FR-021** | Configure auth bypass | T047, T049 | 6 (US4) | ✅ Mapped |
| **FR-022** | Support --update flag | T050, T055 | 7 (US5) | ✅ Mapped |
| **FR-023** | Support --add-models flag | T051 | 7 (US5) | ✅ Mapped |
| **FR-024** | Preserve user customizations | T053, T054, T057 | 7 (US5) | ✅ Mapped |
| **FR-025** | Create incremental backups | T056 | 7 (US5) | ✅ Mapped |
| **FR-026** | Support --proxy flag | T059, T063 | 8 (US6) | ✅ Mapped |
| **FR-027** | Support --proxy-auth flag | T059, T064 | 8 (US6) | ✅ Mapped |
| **FR-028** | Set HTTP_PROXY env vars | T062 | 8 (US6) | ✅ Mapped |
| **FR-029** | Configure LiteLLM proxy | T060, T061, T065 | 8 (US6) | ✅ Mapped |
| **FR-030** | Post-deployment validation checks | T012, T013, T022-T028 | 2, 3 | ✅ Mapped |
| **FR-031** | Provide --dry-run flag | T015, T068, T069 | 3, 9 | ✅ Mapped |
| **FR-032** | Provide --verbose flag | T015 | 3 (US1) | ✅ Mapped |
| **FR-033** | Log to deployment.log | T014 | 2 (Found) | ✅ Mapped |
| **FR-034** | Support --rollback flag | T066 | 9 (Add) | ✅ Mapped |
| **FR-035** | List backups with --list-backups | T067 | 9 (Add) | ✅ Mapped |
| **FR-036** | Verify backup integrity | T010, T011 | 2 (Found) | ✅ Mapped |

---

## Summary Statistics

**Total Functional Requirements**: 36  
**Total Tasks with FR Mappings**: 41 tasks  
**Coverage**: 100% (all FRs mapped)

**Tasks Added**:
- T026b: FR-006 (settings.json update)
- T034b: FR-011 + FR-012 (model list display + merge)
- T043: FR-016 (enterprise settings.json)
- T043b: FR-017 (health check)

**Distribution by Priority**:
- P1 (MVP): FR-001 to FR-008 → 14 tasks in US1
- P2: FR-009 to FR-017 → 16 tasks in US2 + US3
- P3: FR-018 to FR-025 → 14 tasks in US4 + US5
- P4: FR-026 to FR-029 → 8 tasks in US6
- All: FR-030 to FR-036 → 9 tasks in Foundation + Additional

---

## Task Distribution by Phase

### Phase 2: Foundational (Blocks All)
**FRs Covered**: FR-004, FR-008, FR-030, FR-033, FR-036

- T007: FR-004 (env var detection)
- T010: FR-008, FR-036 (backup + integrity)
- T011: FR-036 (rollback)
- T012: FR-030 (pre-deployment validation)
- T013: FR-030 (post-deployment validation)
- T014: FR-033 (logging)

### Phase 3: User Story 1 (MVP)
**FRs Covered**: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, FR-030, FR-031, FR-032

- T015: FR-031, FR-032 (CLI flags)
- T018: FR-001 (copy templates)
- T019: FR-005 (generate .env)
- T020: FR-007 (generate startup script)
- T021: FR-002 (create directory)
- T022: FR-001 validation
- T023: FR-002 validation
- T024: FR-003 validation
- T025: FR-004 validation
- T026: FR-005 validation
- T026b: FR-006 validation
- T027: FR-007 validation
- T028: FR-008 validation

### Phase 4: User Story 2 (Model Selection)
**FRs Covered**: FR-009, FR-010, FR-011, FR-012

- T029: FR-009 (--models flag)
- T030: FR-010 (validate models)
- T031: FR-012 (merge configs)
- T033: FR-009 validation
- T034: FR-010 validation
- T034b: FR-011 + FR-012 validation
- T035: FR-012 validation

### Phase 5: User Story 3 (Enterprise)
**FRs Covered**: FR-013, FR-014, FR-015, FR-016, FR-017

- T037: FR-013, FR-014, FR-015 (CLI flags)
- T039: FR-016 (update settings.json)
- T041: FR-014 validation
- T042: FR-015 validation
- T043: FR-016 validation
- T043b: FR-017 validation

### Phase 6: User Story 4 (Multi-Provider)
**FRs Covered**: FR-018, FR-019, FR-020, FR-021

- T044: FR-018 (--preset flag)
- T045: FR-019 (deploy function)
- T046: FR-019 (copy templates)
- T047: FR-020, FR-021 (env vars)
- T048: FR-020 validation
- T049: FR-021 validation

### Phase 7: User Story 5 (Updates)
**FRs Covered**: FR-022, FR-023, FR-024, FR-025

- T050: FR-022 (update command)
- T051: FR-023 (--add-models flag)
- T053: FR-024 (merge config)
- T054: FR-024 (preserve settings)
- T055: FR-022 validation
- T056: FR-025 validation
- T057: FR-024 validation

### Phase 8: User Story 6 (Proxy)
**FRs Covered**: FR-026, FR-027, FR-028, FR-029

- T059: FR-026, FR-027 (CLI flags)
- T060: FR-029 (deploy function)
- T061: FR-029 (copy templates)
- T062: FR-028 (env vars)
- T063: FR-026 validation
- T064: FR-027 validation
- T065: FR-029 validation

### Phase 9: Additional Commands
**FRs Covered**: FR-031, FR-034, FR-035

- T066: FR-034 (rollback command)
- T067: FR-035 (list-backups command)
- T068: FR-031 (dry-run mode)
- T069: FR-031 (dry-run summary)

---

## Verification Checklist

### Completeness
- [x] All 36 FRs have at least one task mapping
- [x] No orphaned FRs (FRs without tasks)
- [x] No unmapped tasks (tasks without FR reference)
- [x] Critical FRs (P1) all mapped to US1

### Correctness
- [x] FR-001 to FR-008: Correct mapping to US1 tasks
- [x] FR-009 to FR-012: Correct mapping to US2 tasks
- [x] FR-013 to FR-017: Correct mapping to US3 tasks
- [x] FR-018 to FR-021: Correct mapping to US4 tasks
- [x] FR-022 to FR-025: Correct mapping to US5 tasks
- [x] FR-026 to FR-029: Correct mapping to US6 tasks
- [x] FR-030 to FR-036: Correct mapping to Foundation + Additional

### Implementation Readiness
- [x] Each FR has validation task or implementation task
- [x] MVP scope (FR-001 to FR-008) fully covered
- [x] Dependencies between FRs reflected in task ordering
- [x] Parallel opportunities identified with [P] markers

---

## Usage During Implementation

**When implementing a task**:
1. Check this matrix to see which FR(s) it implements
2. Read FR requirements from spec.md
3. Ensure implementation satisfies all FR criteria
4. Run validation for mapped FR(s)
5. Update task checkbox when complete

**When testing**:
1. For each FR, find mapped tasks in this matrix
2. Verify all mapped tasks completed
3. Run acceptance tests from spec.md user stories
4. Confirm FR requirement satisfied

**When reviewing**:
1. Cross-reference PR tasks against this matrix
2. Ensure no FRs are missed
3. Verify validation tasks include FR checks
4. Confirm constitution compliance

---

**Traceability Matrix Complete** | Ready for implementation ✅
