# Acceptance Criteria — Project State Engine
Generated from spec.md (Constitution v1.1.0 aligned) | 2026-04-03

## Success Criteria Checklist
- [ ] SC-001: Project creation within 3s p95 — Target: webhook→Telegram <3000ms
- [ ] SC-002: Context retrieval within 3s p95 after 5+ days — Target: webhook→Telegram <3000ms
- [ ] SC-003: Zero cross-project contamination — Target: 0 leaks across 100 switches
- [ ] SC-004: CRON archives 100% qualifying projects — Target: 0 missed, 0 data loss
- [ ] SC-005: Archived project reactivation within 3s p95 — Target: webhook→Telegram <3000ms
- [ ] SC-006: All lifecycle events in audit_log — Target: 100% events logged correctly
- [ ] SC-007: Disambiguation for ambiguous names — Target: 100% prompt rate, 0 auto-selections

## Invariant Verification
- [ ] I-1: compressed_context ≤ 500 tokens in every prompt assembly
- [ ] I-2: Only ACTIVE ↔ ARCHIVED transitions (no other states)
- [ ] I-3: Zero hard deletes of project data
- [ ] I-4: Zero cross-project contamination (triple-filter verified)
- [ ] I-5: All lifecycle events have audit_log entries
- [ ] I-6: active_context_id transitions are atomic with project operations

## Non-Functional Requirements Verification
- [ ] NFR-001: Latency — create/retrieve/reactivate <3s p95; context assembly <200ms
- [ ] NFR-002: Cost — zero LLM token cost per project operation
- [ ] NFR-003: Resilience — fail-closed writes (3 retries), fail-open reads
- [ ] NFR-004: Auditability — 100% events logged, append-only, 90+ day retention
- [ ] NFR-005: Data integrity — Firestore rules: owner_id only, delete NEVER

## Traceability
| SC | Linked FR | Linked NFR | Linked Invariant | Verifiable By |
|----|-----------|------------|------------------|---------------|
| SC-001 | FR-001, FR-002 | NFR-001 | I-6 | Unit test + perf benchmark |
| SC-002 | FR-003, FR-004 | NFR-001 | I-1, I-4 | Integration test + perf |
| SC-003 | FR-006 | NFR-005 | I-4 | Integration test (100 switches) |
| SC-004 | FR-007, FR-008 | NFR-003 | I-3 | Unit test + CRON simulation |
| SC-005 | FR-009 | NFR-001 | I-2 | Unit test + perf |
| SC-006 | FR-010 | NFR-004 | I-5 | Contract test |
| SC-007 | FR-005 | — | — | Unit test |

## DoD Gate Mapping
| DoD Category | Acceptance Items | Verification |
|-------------|-----------------|--------------|
| Code Quality (5) | TS strict, Zod, 80%+ coverage, BDD green, no lint | T033, T035 |
| Integration (4) | RP-1 async, RP-2 state, RP-6 idemp, isolation | T030, T019 |
| Security (4) | CP1, CP2, CP3, IAM | T031, T036 |
| Performance (4) | <2s ACK, <3s context, <200ms Firestore, token budget | T033 |
| Ops Readiness (4) | Audit log, monitoring, CRON, rollback | T032, T034 |
| Documentation (3) | Constitution map, evidence tags, edge cases | spec.md, plan.md |
