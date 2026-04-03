# Tasks: Project State Engine

**Input**: Design documents from `/specs/001-project-state-engine/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, tests/features/
**TDD**: Mandatory (P-V: Specification-Driven Development)

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[USn]**: Which user story this task belongs to
- Test tasks reference .feature scenario IDs (TS-XXX)
- Implementation tasks follow TDD: red (test) → green (code) → refactor

---

## Phase 1: Setup

**Purpose**: Create module structure and verify dependencies

- [ ] T001 Create directory structure: src/ecosystem/project-state/, tests/unit/, tests/integration/, tests/contract/
- [ ] T002 [P] Verify Zod dependency in package.json (already in codebase per TD-02)
- [ ] T003 [P] Verify Vitest test framework configuration

**Checkpoint**: Directory structure and tooling ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Types, validation schemas, and data access layer shared by ALL user stories

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 [P] Define TypeScript interfaces and ProjectStatus enum in src/ecosystem/project-state/project-types.ts
- [ ] T005 [P] Define Zod validation schemas (CreateProjectInput, ProjectDocument, ProjectStatus) in src/ecosystem/project-state/project-validators.ts
- [ ] T006 [P] Write unit tests for project-validators in tests/unit/project-validators.test.ts [TS-013, TS-014, TS-015]
- [ ] T007 [P] Write unit tests for project-repository in tests/unit/project-repository.test.ts
- [ ] T008 Implement project-repository.ts with Firestore CRUD (create, getById, getByOwnerAndName, updateStatus, updateLastInteraction) in src/ecosystem/project-state/project-repository.ts
- [ ] T009 [P] Implement audit-logger utility for project lifecycle events (project.create, project.retrieve, project.archive, project.reactivate) in src/ecosystem/project-state/audit-logger.ts

**Checkpoint**: Foundation ready — types, validation, data access, and audit logging available for all stories

---

## Phase 3: US1 — Create and Activate a Project (Priority: P1) MVP

**Goal**: Operator creates a named project via Telegram, receives confirmation, project becomes active context
**Independent Test**: Send "create project Acme Proposal" → verify project document created with correct initial state

### Tests (Red Phase)

- [ ] T010 [US1] Write unit tests for createProject in tests/unit/project-service.test.ts [TS-001, TS-002, TS-003, TS-016, TS-017]

### Implementation (Green Phase)

- [ ] T011 [US1] Implement createProject in src/ecosystem/project-state/project-service.ts: create project document (FR-001), set active_context_id (FR-002), audit log, Firestore transaction [TS-001, TS-002, TS-003]
- [ ] T012 [US1] Implement duplicate name detection and disambiguation prompt (FR-012) in project-service.ts [TS-016]

**Checkpoint**: Operator can create projects. Verify: T010 tests pass green.

---

## Phase 4: US2 — Retrieve Project Context (Priority: P1)

**Goal**: Operator resumes a project and context (compressed + short-term memory) is loaded accurately
**Independent Test**: Create project, add context, resume after delay → verify context retrieved

### Tests (Red Phase)

- [ ] T013 [US2] Write unit tests for retrieveProject in tests/unit/project-service.test.ts [TS-004, TS-005, TS-006, TS-007, TS-008, TS-010, TS-011]
- [ ] T014 [P] [US2] Write unit tests for context-assembler in tests/unit/context-assembler.test.ts [TS-009, TS-028]

### Implementation (Green Phase)

- [ ] T015 [US2] Implement retrieveProject in src/ecosystem/project-state/project-service.ts: explicit command mode (FR-003a), implicit suggestion mode (FR-003b), disambiguation (FR-005) [TS-004, TS-005, TS-006, TS-007, TS-008]
- [ ] T016 [US2] Implement context-assembler.ts: batch Firestore read (compressed_context + 15 turns), token counting, re-compression guard (>500 tokens) in src/ecosystem/project-state/context-assembler.ts [TS-009, TS-028]
- [ ] T017 [US2] Implement reactivateProject in project-service.ts: status ARCHIVED→ACTIVE, set active_context_id, audit log [TS-010]
- [ ] T018 [US2] Implement paginated project listing (most-recent-first) in project-repository.ts [TS-011]

**Checkpoint**: Operator can resume projects with context. Verify: T013, T014 tests pass green.

---

## Phase 5: US4 — Zero Cross-Project Contamination (Priority: P1)

**Goal**: Absolute guarantee that context from Project A never leaks into Project B
**Independent Test**: Create two projects with distinct contexts, switch 100 times, verify zero leakage

### Tests (Red Phase)

- [ ] T019 [US4] Write integration tests for cross-contamination in tests/integration/cross-contamination.test.ts [TS-023, TS-024, TS-025, TS-026, TS-027]

### Implementation (Green Phase)

- [ ] T020 [US4] Implement triple-filter contamination guards in context-assembler.ts: query-level (owner_id + project_id filter), assertion-level (ownership validation), defensive-level (mismatched turn filtering) [TS-023, TS-024, TS-025, TS-026, TS-027]

**Checkpoint**: Zero-contamination guarantee enforced. Verify: T019 integration tests pass green.

---

## Phase 6: US3 — Archive Inactive Projects (Priority: P2)

**Goal**: CRON automatically archives projects inactive for 30+ days; all data preserved
**Independent Test**: Create project, simulate 30+ days inactivity, run CRON → verify ARCHIVED status, data intact

### Tests (Red Phase)

- [ ] T021 [US3] Write unit tests for archiveProject in tests/unit/project-service.test.ts [TS-013-A, TS-022]
- [ ] T022 [P] [US3] Write unit tests for archival-cron in tests/unit/archival-cron.test.ts [TS-012, TS-018, TS-019, TS-021]

### Implementation (Green Phase)

- [ ] T023 [US3] Implement archiveProject in project-service.ts: status ACTIVE→ARCHIVED, preserve all data (FR-008), clear active_context_id if matches (FR-002) [TS-013-A, TS-022]
- [ ] T024 [US3] Implement archival-cron.ts Cloud Function: query ACTIVE projects, evaluate last_interaction vs threshold, per-project transactions, partial failure isolation [TS-012, TS-018, TS-019, TS-021]
- [ ] T025 [US3] Implement searchable archived projects in project-repository.ts [TS-020]

**Checkpoint**: Archival lifecycle complete. Verify: T021, T022 tests pass green.

---

## Phase 7: Audit Logging (Cross-Cutting)

**Purpose**: Verify all lifecycle events produce correct audit trail entries

### Tests (Red Phase)

- [ ] T026 Write contract tests for audit logging in tests/contract/project-crud.contract.test.ts [TS-029, TS-030, TS-031, TS-032, TS-033, TS-034]

### Implementation (Green Phase)

- [ ] T027 Integrate audit-logger calls into all project-service operations (create, retrieve, archive, reactivate) with correct action_type, resource, status, and metadata fields [TS-029, TS-030, TS-031, TS-032, TS-033, TS-034]

**Checkpoint**: All lifecycle events audited. Verify: T026 contract tests pass green.

---

## Phase 8: Integration & Router

**Purpose**: Wire project-state module into existing Nexus control plane

- [ ] T028 Modify src/ecosystem/router.ts: add PROJECT_QUERY intent to enum, route to project-service (explicit commands parsed deterministically, implicit via LLM classification)
- [ ] T029 Modify src/ecosystem/prompt-composer.ts: integrate context-assembler output into prompt assembly pipeline
- [ ] T030 Write project-lifecycle integration test (create→retrieve→archive→reactivate full flow) in tests/integration/project-lifecycle.test.ts

**Checkpoint**: End-to-end flow works through Nexus pipeline. Verify: T030 integration test passes.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Security, infrastructure, and coverage hardening

- [ ] T031 [P] Add Firestore security rules for projects collection: read/write by owner_id, delete NEVER (FR-008)
- [ ] T032 [P] Configure Cloud Scheduler job for daily archival CRON at 02:00 UTC per archival-cron.md contract
- [ ] T033 Verify 80% global test coverage, 100% for routing + security paths, and p95 <3s for project create/retrieve/reactivate (SC-001, SC-002, SC-005)
- [ ] T034 Run quickstart.md validation scenarios end-to-end
- [ ] T035 [P] Validate DoD checklist (Constitution v1.1.0): code quality (5 items), integration (4), security (4), performance (4), ops readiness (4), documentation (3)
- [ ] T036 [P] Verify Zod name validation blocks CP1-equivalent injection patterns (regex, deny-list, 4096 char cap) in project-validators.ts [FR-011]
- [ ] T037 Verify RP-7 fail-closed behavior: Firestore transaction failure after 3 retries surfaces error to operator, no partial writes persist

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──▶ Phase 2 (Foundational) ──▶ Phase 3 (US1)
                                                     │
                                                     ▼
                                               Phase 4 (US2)
                                                     │
                                                     ▼
                                               Phase 5 (US4)
                                                     │
                                                     ▼
                                               Phase 6 (US3)
                                                     │
                                                     ▼
                                               Phase 7 (Audit)
                                                     │
                                                     ▼
                                               Phase 8 (Integration)
                                                     │
                                                     ▼
                                               Phase 9 (Polish)
```

### Story Dependencies

| Story | Depends On | Reason |
|-------|-----------|--------|
| US1 (Create) | Foundational only | No story dependencies — entry point |
| US2 (Retrieve) | US1 | Retrieve requires existing projects |
| US4 (Contamination) | US2 | Guards are in context-assembler (US2) |
| US3 (Archive) | US1, US2 | Archive/reactivate require create + retrieve |

### Parallel Opportunities

| Batch | Tasks | Condition |
|-------|-------|-----------|
| Foundational parallel (types) | T004, T005, T009 | Different files, no dependencies |
| Foundational parallel (tests) | T006, T007 | Different test files, both depend on T004+T005 only |
| US2 test parallel | T013, T014 | Different test files |
| US3 test parallel | T021, T022 | Different test files |
| Polish parallel | T031, T032 | Independent infrastructure |

### Critical Path

T001 → T004 → T007 → T008 → T010 → T011 → T013 → T015 → T016 → T019 → T020 → T026 → T027 → T028 → T029 → T030 → T033

**Length**: 17 tasks on critical path

---

## MVP Scope

**Minimum viable**: Phase 1 + Phase 2 + Phase 3 (US1: Create) = T001–T012
Delivers: operator can create named projects with validation, persistence, and active context switching.

**Recommended MVP**: Through Phase 5 (US4) = T001–T020
Delivers: full CRUD with context retrieval and contamination guarantees — the core value proposition.

---

## Notes

- TDD mandatory per P-V: write tests (red), then implement (green), then refactor
- All .feature files are locked (hash: 4c5478b...) — fix code to pass tests, never modify features
- Single-operator H1: no concurrency tests needed (deferred to feature 008)
- File paths reference target Nexus repo structure per plan.md — adjust if repo layout differs

## Clarifications

### Session 2026-04-03

- Q: ASCII dependency graph shows US1, US2, US4 starting in parallel from Phase 2, but Story Dependencies table says US2→US1 and US4→US2 — which is correct? -> A: Table is correct. US2 (Retrieve) needs existing projects from US1 (Create). US4 (Contamination) needs context-assembler from US2. Graph fixed to sequential flow. [Phase Dependencies graph, Story Dependencies table]

- Q: T007 (repository implementation) comes before T008 (repository tests) — this violates TDD mandatory ordering per P-V. -> A: Swapped. T007 is now repository tests (red), T008 is implementation (green). TDD ordering enforced in Foundational phase same as story phases. Critical path updated to include T008. [T007, T008, Critical Path]

- Q: T006 (validator tests) and T007 (repository tests) both depend on T004+T005 but not each other — should they be parallel? -> A: Yes. Added [P] marker to both. They work on different test files with no shared state. [T006, T007, Parallel Opportunities]

- Q: Analysis F-003: No dedicated performance benchmark task for SC-001/SC-002 (3s p95). -> A: Expanded T033 to include p95 latency verification for create/retrieve/reactivate alongside coverage checks. BDD scenarios (TS-003, TS-004) assert timing in functional tests; T033 now validates it as a Polish gate. Sufficient for H1 single-operator. [T033, SC-001, SC-002, SC-005]

- Q: Analysis F-004: T009 (audit-logger) has no TS-xxx reference. -> A: Intentional. audit-logger is a utility consumed by project-service operations. It is integration-tested via T026/T027 (contract tests for TS-029 through TS-034). Isolated unit testing of a simple logger wrapper would be testing the framework, not business logic. P-VII satisfied: no unnecessary test infrastructure. [T009, T026, T027]
