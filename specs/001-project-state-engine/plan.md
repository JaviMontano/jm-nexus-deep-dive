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

## Complexity Tracking

No constitution violations detected. No complexity justifications needed.

| Decision | Simplicity Check | Result |
|----------|-----------------|--------|
| 2-state model (ACTIVE/ARCHIVED) | Simpler than multi-state | PASS — P-VII satisfied |
| Firestore-only (no Redis) | Per ADR-002 | PASS — sufficient for H1 |
| Single module under ecosystem/ | Follows existing pattern | PASS — P-VII extension |
| Zod validation (not custom) | Industry standard | PASS — already in codebase |
| CRON via Cloud Scheduler | Managed service, no infra | PASS — P-I deterministic |
