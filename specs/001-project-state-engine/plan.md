# Implementation Plan: Project State Engine

**Branch**: `001-project-state-engine` | **Date**: 2026-04-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-project-state-engine/spec.md`
**Constitution**: CONSTITUTION.md v1.0.0 (P-I through P-VII enforced)

## Summary

Implement the Project State Engine — Nexus's core persistence layer for
project lifecycle management (create, retrieve, archive, reactivate) with
zero cross-project contamination, context-bounded retrieval (<=500 tokens +
15 turns), and full audit logging. This is the keystone H1 deliverable
(ADR-005, PRIORITY MAXIMUM) — all downstream features depend on it.

Technical approach: TypeScript Cloud Functions extending the existing P4
(Persistencia) plane with Firestore collections (projects, operators update),
a daily CRON via Cloud Scheduler, and deterministic state-machine transitions
per P-I.

## Technical Context

**Language/Version**: TypeScript (strict mode) on Node.js (Cloud Functions v2)
**Primary Dependencies**: Firebase Admin SDK, Firestore, Cloud Scheduler, Pub/Sub, Zod (runtime validation)
**Storage**: Firestore (document store) — single persistence per ADR-002
**Testing**: Vitest (unit + integration), 80% global coverage, 100% for routing + security
**Target Platform**: Google Cloud Functions v2 (serverless)
**Project Type**: Single project (Firebase monorepo with functional planes)
**Performance Goals**: Project creation <3s p95 (webhook→response), context retrieval <3s p95, context assembly <200ms
**Constraints**: <=500 tokens compressed_context, 15-turn short_term_memory, single-operator H1, Firestore transactions for writes
**Scale/Scope**: ~100 conversations/day (H1), single operator, 6 agents, <$20/day token cost

## Constitution Check

*GATE: Passed — all technical decisions validated against P-I through P-VII.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| P-I State Machine Determinism | PASS | Project lifecycle is a state machine: ACTIVE ↔ ARCHIVED. No loops. All transitions auditable. Cost-bounded (Firestore ops only, no LLM). |
| P-II HIL for External Actions | PASS | Project CRUD is internal state management (read/write to Firestore). No external side effects. Exempt per P-II ("internal read-only operations exempt"). Archive/reactivate are internal state changes. |
| P-III Constitutional Governance | PASS | This feature operates under all 8 operational principles. No conflicts identified. |
| P-IV Persistent Project Context | PASS | This IS P-IV implementation. Context persistence is the core deliverable. |
| P-V Specification-Driven | PASS | spec.md exists with 12 FRs, 7 SCs, 6 edge cases, 6 clarifications. Quality score 10/10. |
| P-VI Traceability | PASS | All claims in this plan carry evidence tags. Audit logging (FR-010) ensures runtime traceability. |
| P-VII Incremental Extension | PASS | Extends P4 (Persistencia) plane. No rewrites. projects collection is new; operators collection gets active_context_id field (additive). |

## Project Structure

### Documentation (this feature)

```text
specs/001-project-state-engine/
  spec.md              # Feature specification (complete, 10/10)
  plan.md              # This file
  research.md          # Technology decisions & rationale
  data-model.md        # Entity definitions with fields, types, constraints
  quickstart.md        # Test scenarios & dev setup
  contracts/           # API contracts (internal message contracts)
    project-crud.md    # Create/retrieve/archive/reactivate contracts
    archival-cron.md   # CRON job contract
    context-assembly.md # Context retrieval contract
```

### Source Code (repository root — target Nexus repo)

```text
src/
  ecosystem/
    project-state/
      project-service.ts       # Core CRUD: create, retrieve, archive, reactivate
      project-repository.ts    # Firestore data access (projects collection)
      context-assembler.ts     # Load compressed_context + short_term_memory
      archival-cron.ts         # Cloud Scheduler handler (daily)
      project-validators.ts    # Zod schemas + name validation (FR-011)
      project-types.ts         # TypeScript interfaces + state enum
    prompt-composer.ts         # MODIFY: integrate context-assembler output
    router.ts                  # MODIFY: route PROJECT_QUERY to project-service

tests/
  unit/
    project-service.test.ts
    project-repository.test.ts
    context-assembler.test.ts
    archival-cron.test.ts
    project-validators.test.ts
  integration/
    project-lifecycle.test.ts  # Full create→retrieve→archive→reactivate flow
    cross-contamination.test.ts # FR-006 zero-leakage verification
  contract/
    project-crud.contract.test.ts
```

**Structure Decision**: Extends existing `src/ecosystem/` structure (P-VII).
New `project-state/` module under ecosystem, following the declarative
pattern of existing agent modules. Tests mirror source structure.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌───────────────────┐
│  Telegram     │────▶│  Cloud Fn     │────▶│  Pub/Sub          │
│  Webhook      │     │  (P1 Ingesta) │     │  (async queue)    │
└──────────────┘     └──────────────┘     └───────┬───────────┘
                                                   │
                                                   ▼
                                          ┌──────────────────┐
                                          │  Worker (P2)      │
                                          │  Router/Orchestr. │
                                          └───────┬──────────┘
                                                   │
                              ┌─────────────────────┼─────────────────┐
                              ▼                     ▼                 ▼
                     ┌────────────────┐   ┌────────────────┐  ┌──────────────┐
                     │ Project Service │   │ Agent Pool     │  │ HIL Gate     │
                     │ (NEW - P3/P4)   │   │ (P3 existing)  │  │ (future)     │
                     └───────┬────────┘   └────────────────┘  └──────────────┘
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
      ┌──────────────┐ ┌──────────┐ ┌──────────────┐
      │  Firestore    │ │ Firestore│ │  Firestore   │
      │  projects     │ │ operators│ │  audit_log   │
      │  (NEW)        │ │ (MODIFY) │ │  (EXTEND)    │
      └──────────────┘ └──────────┘ └──────────────┘

      ┌──────────────────────────────────────────────┐
      │  Cloud Scheduler (CRON daily)                 │
      │  → archival-cron.ts                           │
      │  → evaluates last_interaction vs threshold    │
      │  → archives qualifying projects               │
      └──────────────────────────────────────────────┘
```

## State Machine (Project Lifecycle)

```
                    ┌─────────┐
     create ───────▶│  ACTIVE  │◀──── reactivate
                    └────┬────┘
                         │
              CRON (30d) │ or manual
                         ▼
                    ┌──────────┐
                    │ ARCHIVED  │
                    └──────────┘
```

**Transitions**:
- `∅ → ACTIVE`: Operator creates project (FR-001)
- `ACTIVE → ARCHIVED`: CRON daily or manual archive (FR-007)
- `ARCHIVED → ACTIVE`: Operator explicit reference (FR-009)

**Invariants**:
- No `DELETED` state — projects are never removed (FR-008)
- Only 2 states: ACTIVE, ARCHIVED (per clarification session)
- All transitions logged to audit_log (FR-010)

## Requirements Traceability

**Evidence delegation**: Technical rationale for all decisions is in research.md (TD-01 through TD-07) with inline evidence tags per P-VI. This plan references research.md for evidence provenance.

| Requirement | Plan Coverage | Evidence Source |
|-------------|--------------|-----------------|
| FR-001 | State Machine: `∅ → ACTIVE` | research.md TD-01, TD-04 |
| FR-002 | Architecture: operators.active_context_id update | research.md TD-04 |
| FR-003 | Clarifications: dual-mode router (explicit + implicit) | research.md TD-06 |
| FR-004 | Technical Context: context retrieval <3s p95 | research.md TD-05 |
| FR-005 | Architecture: disambiguation via Telegram inline buttons | research.md TD-06 |
| FR-006 | Architecture: context-assembler triple-filter | research.md TD-05 |
| FR-007 | State Machine: CRON daily archive | research.md TD-03 |
| FR-008 | State Machine: no DELETED state | research.md TD-01 |
| FR-009 | State Machine: `ARCHIVED → ACTIVE` | research.md TD-04 |
| FR-010 | State Machine: all transitions logged | research.md TD-07 |
| FR-011 | Foundational: Zod validation schemas | research.md TD-02 |
| FR-012 | Architecture: duplicate name detection | research.md TD-06 |

## Complexity Tracking

No constitution violations detected. No complexity justifications needed.

| Decision | Simplicity Check | Result |
|----------|-----------------|--------|
| 2-state model (ACTIVE/ARCHIVED) | Simpler than multi-state | PASS — P-VII satisfied |
| Firestore-only (no Redis) | Per ADR-002 | PASS — sufficient for H1 |
| Single module under ecosystem/ | Follows existing pattern | PASS — P-VII extension |
| Zod validation (not custom) | Industry standard | PASS — already in codebase |
| CRON via Cloud Scheduler | Managed service, no infra | PASS — P-I deterministic |

## Clarifications

### Session 2026-04-03

- Q: What does the orchestrator do when Project Service returns TRANSACTION_FAILED after 3 Firestore retries? -> A: Surface error to operator via Telegram with a user-friendly message ("Something went wrong, please try again"). No orchestrator-level retry. Rationale: operation is idempotent (no data persisted, no side effects per P-II), operator can trivially retry, adding retry layers risks breaching 3s p95 SLA (SC-001) and violates P-VII (no overengineering). P-I satisfied: deterministic response to a deterministic failure. [Architecture, Trade-offs, contracts/project-crud.md]

- Q: What version pinning strategy applies to dependencies (Firebase Admin SDK, Zod, etc.)? -> A: Caret ranges (`^x.y.z`) in package.json with `package-lock.json` committed to repo. Lockfile guarantees deterministic installs (P-I). Caret ranges allow controlled patch/minor updates via explicit `npm update`. Exact pinning deferred — justified only for multi-team production systems, not H1 single-operator. P-VII satisfied: standard Node.js practice, no extra tooling. [Technical Context, Dependency Risks]

- Q: How does the router classify PROJECT_QUERY intent to hand off to Project Service? -> A: Dual-mode per FR-003. (1) Explicit commands (`/project <name>`, "create project X") are parsed deterministically by the router before LLM classification — fast, no token cost, P-I compliant. (2) Implicit mentions (e.g., "let's work on Acme") go through the router's existing LLM intent classification, which adds `PROJECT_QUERY` as a recognized intent category. Router modification is incremental: add PROJECT_QUERY to the intent enum and route to project-service. P-VII satisfied: reuses existing classification pipeline. [Architecture, Integration Points, Project Structure: router.ts MODIFY]

- Q: Analysis F-001: FR-002, FR-004, FR-005, FR-006, FR-011, FR-012 not referenced by ID in plan.md body — how to resolve? -> A: Added Requirements Traceability table mapping all 12 FRs to plan sections and research.md evidence sources. Explicit delegation pattern: plan.md references research.md TD-xx for evidence provenance per P-VI. [Requirements Traceability section, all FR-xxx]

- Q: Analysis F-002: P-VI evidence tags delegated to research.md rather than inline in plan.md — acceptable? -> A: Yes. Evidence delegation is documented in the new Requirements Traceability section header. research.md carries [CODIGO]/[DOC]/[INFERENCIA] tags on all 7 technical decisions. plan.md references research.md for provenance. This satisfies P-VI traceability without duplicating evidence tags across artifacts. [Requirements Traceability, P-VI]
