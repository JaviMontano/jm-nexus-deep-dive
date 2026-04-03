# Research: Project State Engine

**Feature**: 001-project-state-engine
**Date**: 2026-04-03
**Status**: Complete — all decisions resolved

## Technology Decisions

### TD-01: Firestore as Project Store

**Decision**: Use Firestore (already in stack) as the sole persistence layer for the projects collection.

**Rationale**: [CODIGO] The existing codebase uses Firestore exclusively (ADR-002). [DOC] The discovery explicitly recommends "single persistent store (Firestore), no Redis in H1" with review at H3 for vector DB. [INFERENCIA] Adding a second store for a single-operator H1 system would violate P-VII (incremental extension) and add unnecessary operational complexity.

**Alternatives Considered**:
| Alternative | Why Rejected |
|------------|-------------|
| Redis (session cache) | Premature optimization per ADR-002; Cloud Functions cold starts acceptable for H1 scale |
| PostgreSQL | Paradigm shift from document store; migration cost unjustified for H1 |
| DynamoDB | Vendor mismatch (Google Cloud ecosystem) |

**Risk**: Possible bottleneck on semantic queries at H2/H3 scale. Mitigation: evaluate VDB at G-H2 gate.

---

### TD-02: Zod for Runtime Validation

**Decision**: Use Zod schemas for all project document validation (create, update, archive transitions).

**Rationale**: [CODIGO] Zod is already used in the codebase for skill.yaml validation (ecosystem/loader.ts). [DOC] FR-011 requires name validation (empty, >100 chars, whitespace-only). [INFERENCIA] Zod provides TypeScript-native schema validation with zero additional dependencies.

**Alternatives Considered**:
| Alternative | Why Rejected |
|------------|-------------|
| io-ts | Less ergonomic, smaller ecosystem |
| Joi | Not TypeScript-native, heavier bundle |
| Manual validation | Error-prone, no schema reuse |

---

### TD-03: Cloud Scheduler for Archival CRON

**Decision**: Use Google Cloud Scheduler to trigger a Cloud Function daily for project archival (FR-007).

**Rationale**: [DOC] The discovery specifies "CRON nocturno" for context compression and archival. [INFERENCIA] Cloud Scheduler is the managed GCP equivalent — no crontab to maintain, integrates with Cloud Functions v2, supports retry policies. [CONFIG] Already available in the Firebase project (no additional enablement needed).

**Alternatives Considered**:
| Alternative | Why Rejected |
|------------|-------------|
| Firebase Extensions (scheduled functions) | Less control over retry/error handling |
| In-process timer (setInterval) | Doesn't survive Cloud Function cold starts; anti-pattern for serverless |
| External CRON service (cron-job.org) | Unnecessary external dependency; violates P-VII |

---

### TD-04: Atomic Transactions for State Transitions

**Decision**: Use Firestore transactions for all write operations that modify project state (create, archive, reactivate) and cross-collection updates (operators.active_context_id + projects).

**Rationale**: [DOC] The discovery data model specifies "atomic transactions + retry (max 3), optimistic versioning, fail-closed" for write conflicts (CB-11). [CODIGO] FR-006 requires zero cross-project contamination, which demands atomic active_context_id switches. [INFERENCIA] Firestore transactions provide serializable isolation for document operations within a single database.

**Retry Policy**: Max 3 retries with exponential backoff (Firestore default). On persistent failure: fail-closed (reject operation), log to audit_log.

---

### TD-05: Context Assembly Strategy

**Decision**: Context assembly loads compressed_context (<=500 tokens) from projects collection + last 15 turns from short_term_memory (filtered by project_id) in a single Firestore batch read.

**Rationale**: [DOC] FR-004 requires <3s p95 for context retrieval. [CODIGO] The existing prompt-composer.ts reads operator profile and context separately. [INFERENCIA] Batch reads (getAll) are more efficient than sequential gets and fit within Firestore's 500ms target for document reads. Two documents (project + memory subcollection) in a batch read is well within latency budget.

**Alternatives Considered**:
| Alternative | Why Rejected |
|------------|-------------|
| Denormalize memory into project doc | Exceeds 1MB Firestore document limit at scale; violates separation of concerns |
| Cache in Cloud Memorystore (Redis) | Premature per ADR-002; adds infra complexity |
| Lazy load (context on second message) | Poor UX; violates P-IV |

---

### TD-06: Project Name Disambiguation

**Decision**: When a project name query matches multiple projects, present all matches as Telegram inline buttons and require operator selection. Never auto-select.

**Rationale**: [DOC] FR-005 explicitly requires disambiguation — "never auto-select." [DOC] SC-007 requires 100% disambiguation rate. [INFERENCIA] Telegram inline buttons provide a natural selection UI within the existing channel. Case-insensitive substring matching via Firestore `>=` and `<` range query on name field.

**Implementation**: Query `projects` where `owner_id == operator_id` AND `name >= query` AND `name < query + '\uf8ff'` (Firestore prefix match). If >1 result: present buttons. If 1: auto-load. If 0: suggest creation.

---

### TD-07: Audit Logging Strategy

**Decision**: All project lifecycle events (create, retrieve, archive, reactivate) write to the existing audit_log collection with structured entries per FR-010.

**Rationale**: [CODIGO] The audit_log collection already exists in the data model (collection #10). [DOC] The discovery requires append-only, immutable logging with 90+ day retention. [INFERENCIA] Using the existing collection maintains consistency and avoids a parallel logging system.

**Log Entry Schema** (subset for this feature):
```typescript
{
  operator_id: string,
  action_type: 'project.create' | 'project.retrieve' | 'project.archive' | 'project.reactivate',
  resource: { type: 'project', id: string, before?: ProjectStatus, after: ProjectStatus },
  status: 'success' | 'failure',
  timestamp: Timestamp
}
```

## Open Questions (Resolved)

All questions from spec clarification session are resolved. No NEEDS CLARIFICATION items remain.

| Question | Resolution | Evidence |
|----------|-----------|----------|
| Implicit vs explicit project switch | Both supported (FR-003) | Spec clarification 2026-04-03 |
| States beyond ACTIVE/ARCHIVED | No, 2 states sufficient for H1 | ADR-005, spec clarification |
| Concurrency targets | Single-operator H1, deferred to H3 | Spec constraint section |
| CRON frequency | Daily (24h resolution) | Spec clarification |
| short_term_memory on switch | Strictly per-project, filtered by project_id | Spec clarification, FR-006 |
| knowledge_anchors/open_tasks/artifacts | Schema placeholders only, no business logic | Spec clarification, P-V |
| "3 seconds" definition | p95 processing time, webhook→Telegram API response | Spec clarification |
