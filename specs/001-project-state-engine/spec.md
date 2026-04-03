# Feature Specification: Project State Engine

**Feature Branch**: `001-project-state-engine`
**Created**: 2026-04-03
**Status**: Specified (Constitution v1.1.0 aligned)
**Input**: Discovery deliverables (M-09, G-06, CU-17/18/19, ADR-005),
Architecture TO-BE (A4), Risk Register (A8), Feasibility Think Tank (05b)
**Constitution**: v1.1.0 — P-I, P-IV, P-V, P-VI, P-VII + RP-3, RP-7

## User Stories

### User Story 1 — Create and Activate a Project (Priority: P1)

As the operator, I want to create a named project via Telegram
so that all subsequent interactions are associated with a
persistent context and I never have to re-explain my project
from scratch.

**Why this priority**: Project creation is the foundation of all
project-scoped operations. Without it, no other feature (HIL,
artifacts, memory, analytics) can associate work to a project.
This is the single most blocking capability (G-06, 0% implemented).
[DOC: A4 section 3, G-06 closure criteria]

**Independent Test**: Send "create project Acme Proposal" to the
bot → verify project document created with correct initial state.
Delivers immediate value: operator has a named container for work.

**Acceptance Scenarios**:

1. **Given** an authenticated operator with no active project,
   **When** the operator sends "create project Acme Proposal",
   **Then** a project is created with name="Acme Proposal",
   status=ACTIVE, empty compressed_context, and it becomes the
   operator's active_context_id.

2. **Given** an authenticated operator with an existing active
   project, **When** the operator creates a new project,
   **Then** the previous project remains accessible and the new
   project becomes the active context.

3. **Given** an operator creates a project, **When** creation
   completes, **Then** the response time is under 3 seconds
   (p95 processing time: webhook received → Telegram API
   response sent) and the operator receives confirmation with
   the project name.

---

### User Story 2 — Retrieve Project Context (Priority: P1)

As the operator, I want to resume a conversation about a
previous project and have the bot recall its full context
(decisions, tasks, artifacts, compressed history) so that I
do not lose ~60 hours/year repeating context to prompts.
[DOC: discovery pain point analysis, 05b Sage 3]

**Why this priority**: Context retrieval is the core value
proposition that differentiates Nexus from "ChatGPT in Telegram".
Without it, every session starts from zero.

**Independent Test**: Create a project, add context over several
interactions, wait 5+ days, resume the project → verify context
retrieved accurately within 3 seconds.

**Acceptance Scenarios**:

1. **Given** an existing project with compressed_context and
   prior interactions, **When** the operator mentions the project
   name, **Then** the system loads compressed_context (<=500
   tokens per RP-3) and short_term_memory (last 15 turns,
   filtered strictly by project_id) within 3 seconds p95.

2. **Given** a project name that partially matches multiple
   projects (e.g., "Acme"), **When** the operator references it,
   **Then** the system lists all matching projects and asks the
   operator to disambiguate — never auto-selects.

3. **Given** a project with empty compressed_context (new or
   never compressed), **When** context is retrieved, **Then**
   the system degrades gracefully with available short-term
   memory only — no errors (RP-7: fail-open for reads).

4. **Given** a project inactive for 30+ days (ARCHIVED),
   **When** the operator explicitly references it, **Then** the
   system retrieves and reactivates it to ACTIVE within 3s p95.

5. **Given** the operator sends "/project Acme Proposal"
   (explicit command), **When** the system processes it,
   **Then** it switches to "Acme Proposal" deterministically
   without confirmation (P-I: deterministic transition).

6. **Given** the intent router detects a project name implicitly
   in the operator's message, **When** the system proposes it,
   **Then** it presents the project as a suggestion requiring
   operator confirmation before switching — never auto-switches.

---

### User Story 3 — Archive Inactive Projects (Priority: P2)

As the system (CRON job), I want to automatically archive
projects with no interaction for a configurable number of days
(default 30) so that active context retrieval stays fast and
the operator's project list remains manageable.
[DOC: R-13 mitigation strategy, A8 risk register]

**Why this priority**: Archival prevents context bloat (R-13,
risk score 9) and keeps the active list clean. Lower priority
because the system functions without it in the short term.

**Independent Test**: Create a project, simulate 30+ days of
inactivity, run CRON job → verify status changes to ARCHIVED
without data loss.

**Acceptance Scenarios**:

1. **Given** a project whose last_interaction exceeds
   auto_archive_after_days (default 30), **When** the daily
   archival CRON runs (24h resolution), **Then** the project
   status changes to ARCHIVED and it is excluded from default
   context retrieval.

2. **Given** an ARCHIVED project, **When** the operator
   explicitly searches for it, **Then** it appears in results
   and can be reactivated.

3. **Given** a project is archived, **Then** no data is
   deleted — status change only. All compressed_context,
   knowledge_anchors, open_tasks, and artifacts are preserved
   (FR-008: never delete).

4. **Given** a project with custom auto_archive_after_days
   (e.g., 7), **When** last_interaction exceeds that threshold,
   **Then** the CRON respects the per-project setting.

5. **Given** the operator's active project is archived by CRON,
   **Then** the operator's active_context_id is set to null.
   No notification is sent — FR-009 reactivates instantly on
   next reference (clarification: no consequence from silence).

---

### User Story 4 — Zero Cross-Project Contamination (Priority: P1)

As the operator working across multiple projects, I want
absolute guarantee that context from Project A never leaks
into Project B so that proposals, research, and decisions
are never contaminated with wrong-project data.
[DOC: SC-003 non-negotiable invariant, A4 section 4]

**Why this priority**: Cross-project contamination is a
reputational and data-integrity risk. The discovery marks
"0 cross-project contamination" as a non-negotiable invariant.

**Independent Test**: Create two projects with distinct
contexts, switch 100 times → verify every response references
only the active project's context.

**Acceptance Scenarios**:

1. **Given** two active projects with distinct contexts,
   **When** the operator switches from Project A to Project B,
   **Then** only Project B's compressed_context and
   short_term_memory are loaded — zero leakage from Project A.

2. **Given** a multi-project environment, **When** the
   orchestrator assembles context, **Then** it filters strictly
   by active_context_id and owner_id (triple-filter: query-level,
   assertion-level, defensive-level).

3. **Given** short_term_memory for projects Alpha (10 turns)
   and Beta (5 turns), **When** the operator switches from Alpha
   to Beta, **Then** only Beta's turns appear — zero Alpha turns
   in context.

4. **Given** a new project "Brand New" created while "Existing"
   has 15 turns, **Then** short_term_memory for "Brand New"
   contains zero turns — no leakage from "Existing".

---

### Edge Cases

| ID | Case | Handling | Source |
|----|------|----------|--------|
| EC-01 | Duplicate project name | Present existing match; ask operator to confirm new creation or switch (FR-012) | CB-06 |
| EC-02 | Concurrent write conflict | Atomic Firestore transactions, max 3 retries, optimistic versioning (_version), fail-closed (RP-7) | CB-06, R-01 |
| EC-03 | compressed_context > 500 tokens | context-assembler triggers immediate re-compression before prompt injection (RP-3 invariant) | CB-11, R-13 |
| EC-04 | CRON archival partial failure | Per-project transactions — failure on one does not affect others; retry next cycle | CB-11 |
| EC-05 | Operator has 100+ projects | Paginated retrieval, most-recent-first ordering | — |
| EC-06 | Ambiguous project abbreviation | Always disambiguate, never auto-select (FR-005, SC-007) | — |

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST create a project document with:
  name, owner_id, status (ACTIVE), compressed_context (empty),
  knowledge_anchors (empty array — reserved per P-V, no business
  logic in this feature), open_tasks (empty array — reserved),
  artifacts (empty array — reserved), compression_log (empty
  array), auto_archive_after_days (default 30), created_at, and
  last_interaction timestamp. [DOC: A6 canonical data model]

- **FR-002**: System MUST set the newly created project as the
  operator's active_context_id in their operator profile.
  Transaction MUST be atomic with project creation. [INFERENCIA:
  P-I requires deterministic state transitions]

- **FR-003**: System MUST retrieve project context via two modes:
  (a) implicit detection from the intent router's
  extracted_project_name, presented as a suggestion requiring
  operator confirmation before switching (never auto-switches),
  and (b) explicit command ("/project <name>") that executes a
  deterministic transition without confirmation. Both modes
  filter by owner_id. [DOC: CU-04 router classification]

- **FR-004**: System MUST load compressed_context (<=500 tokens
  per RP-3) and short_term_memory (last 15 turns, filtered
  strictly by project_id) into the orchestrator's context
  assembly within 3 seconds (p95 processing time, measured from
  webhook received to response sent to Telegram API).
  [DOC: A4 context assembly contract]

- **FR-005**: System MUST present disambiguation options when a
  project name matches multiple projects — never auto-select.
  [DOC: SC-007 requirement, TD-06 Telegram inline buttons]

- **FR-006**: System MUST enforce zero cross-project
  contamination by filtering all queries strictly by
  active_context_id and owner_id. Triple-filter: query-level
  (Firestore WHERE clauses), assertion-level (post-query
  ownership validation), defensive-level (mismatched turn
  filtering with warning log). [INFERENCIA: defense-in-depth
  per T1 Transversal Seguridad]

- **FR-007**: System MUST run a daily CRON job (once per 24h,
  02:00 UTC) that evaluates last_interaction against
  auto_archive_after_days and archives qualifying projects.
  Archival resolution is 24 hours — a project may remain
  ACTIVE up to ~24h beyond its threshold. Per-project
  transactions with partial failure isolation.
  [DOC: TD-03 Cloud Scheduler]

- **FR-008**: System MUST preserve all project data when
  archiving — status change only, never delete. No DELETED
  state exists (2-state model per ADR-005).
  [DOC: ADR-005, A6 canonical model]

- **FR-009**: System MUST allow reactivation of ARCHIVED
  projects when the operator explicitly references them.
  Reactivation sets status=ACTIVE, updates last_interaction,
  sets active_context_id, and logs to audit_log. [INFERENCIA:
  state machine reversal per P-I]

- **FR-010**: System MUST log all project lifecycle events
  (create, retrieve, archive, reactivate) to audit_log with
  operator_id, action_type, resource (type + id + before/after
  status), status (success/failure), reason (on failure),
  metadata (trigger: operator|cron), and ISO timestamp.
  [DOC: TD-07 audit logging strategy, P-VI traceability]

- **FR-011**: System MUST reject project names that are empty,
  exceed 100 characters, or contain only whitespace. Validation
  via Zod schema (TD-02). [CODIGO: existing Zod pattern in
  ecosystem/loader.ts]

- **FR-012**: System MUST handle duplicate project names by
  presenting existing matches and asking the operator to
  confirm new creation or switch. [DOC: TD-06 disambiguation]

### Non-Functional Requirements

- **NFR-001**: Latency — project create, retrieve, and
  reactivate MUST complete within 3 seconds p95 (webhook
  received → Telegram API response). Context assembly
  sub-component MUST complete within 200ms. [DOC: A4 latency
  targets, Constitution DoD item 14-16]

- **NFR-002**: Cost — project CRUD operations MUST incur zero
  LLM token cost (Firestore operations only). No delegation
  mode budget consumed. [INFERENCIA: RP-8 token budget;
  project state is infrastructure, not agent work]

- **NFR-003**: Resilience — write operations MUST use Firestore
  transactions with max 3 retries and fail-closed on persistent
  failure (RP-7). Read operations MUST degrade gracefully
  (RP-7: fail-open). [DOC: Constitution RP-7]

- **NFR-004**: Auditability — 100% of lifecycle events logged
  with immutable audit trail. Append-only; 90+ day retention.
  [DOC: TD-07, Constitution P-VI]

- **NFR-005**: Data integrity — zero cross-project contamination
  (SC-003). Verified via triple-filter in context assembly.
  Firestore security rules: read/write by owner_id only,
  delete NEVER. [DOC: A4 isolation model, FR-006, FR-008]

---

## Key Entities

### Project

Central entity representing a named work context.

| Attribute | Type | Constraint | Notes |
|-----------|------|-----------|-------|
| project_id | string | PK, UUID v4 | Auto-generated |
| name | string | 1-100 chars, trimmed, non-whitespace | FR-011 |
| owner_id | string | FK → operators.id | Telegram user_id |
| status | enum | ACTIVE \| ARCHIVED | 2-state model (ADR-005) |
| compressed_context | string | <=500 tokens (RP-3) | LLM summary |
| knowledge_anchors | string[] | Default [] | Reserved — no logic (P-V) |
| open_tasks | string[] | Default [] | Reserved — no logic (P-V) |
| artifacts | string[] | Default [] | Reserved — no logic (P-V) |
| compression_log | object[] | Append-only | date, before_tokens, after_tokens, dropped_topics |
| auto_archive_after_days | number | Default 30, min 1 | Per-project threshold |
| created_at | Timestamp | Server-generated | Immutable |
| last_interaction | Timestamp | Updated per operation | Used by archival CRON |
| _version | number | Default 1, atomic increment | Optimistic locking |

**Relationships**: Belongs to one Operator. Generates many Audit Log Entries.
**Indexes**: owner_id + status (dashboard), owner_id + name (disambiguation).
**Security**: Read/write by owner_id only. Delete: NEVER (FR-008).

### Operator (MODIFY — add field)

The human user. This feature adds one field.

| Attribute | Type | Constraint | Change |
|-----------|------|-----------|--------|
| active_context_id | string \| null | FK → projects.id | ADD |

**Transition logic**: Set on create (FR-002), switch (FR-003),
reactivate (FR-009). Clear on archive if matches (FR-007).
All updates transactional with the project operation.

### Audit Log Entry (EXTEND — add action types)

Immutable lifecycle trail. Adds project action types.

| Attribute | Type | Notes |
|-----------|------|-------|
| id | string | UUID v4 |
| timestamp | Timestamp | Server-generated |
| operator_id | string | FK → operators.id |
| action_type | string | project.create, project.retrieve, project.archive, project.reactivate |
| resource | object | { type: 'project', id, before?, after } |
| status | string | success \| failure |
| reason | string? | Error description on failure |
| metadata | object | { trigger: 'operator' \| 'cron' } |

**Rules**: Append-only. No update. No delete. 90+ day retention.

---

## Invariants

Non-negotiable constraints enforced at all times:

| ID | Invariant | Enforcement | Source |
|----|-----------|-------------|--------|
| I-1 | compressed_context ≤ 500 tokens in prompt | context-assembler guard clause; re-compress if exceeded | RP-3, R-13 |
| I-2 | Status transitions: only ACTIVE↔ARCHIVED | Zod enum validation; no DELETED/SUSPENDED/COMPLETED | ADR-005, P-I |
| I-3 | No hard delete of project data | Firestore security rules: delete NEVER | FR-008 |
| I-4 | Zero cross-project contamination | Triple-filter in context assembly | FR-006, SC-003 |
| I-5 | All lifecycle events audited | audit-logger integration in every operation | FR-010, P-VI |
| I-6 | Atomic active_context_id transitions | Firestore transaction with project operation | P-I, RP-7 |

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Operator can create a project and receive
  confirmation within 3 seconds (p95: webhook → Telegram API).
  DoD items 14-16. [DOC: A4 latency targets]

- **SC-002**: Operator can resume a project after 5+ days of
  inactivity with context retrieved accurately within 3 seconds
  (p95: webhook → Telegram API). DoD items 6, 9.
  [DOC: G-06 closure criteria]

- **SC-003**: Zero cross-project contamination across 100
  consecutive project switches (verified via audit log + context
  inspection). DoD item 9. Non-negotiable.
  [DOC: A4 isolation invariant]

- **SC-004**: CRON archival correctly archives 100% of projects
  exceeding auto_archive_after_days without data loss. DoD
  item 20. [DOC: R-13 mitigation verification]

- **SC-005**: Archived projects accessible via explicit search
  and reactivatable within 3 seconds (p95: webhook → Telegram
  API). DoD items 14-16.

- **SC-006**: All project lifecycle events appear in audit_log
  with correct operator_id, action_type, and ISO timestamp.
  DoD item 18. [DOC: TD-07, P-VI]

- **SC-007**: Disambiguation prompt appears for ambiguous
  project names 100% of the time — zero auto-selections.
  [DOC: TD-06 disambiguation strategy]

### Constraints

- H1 targets assume single-operator usage. Multi-operator
  concurrency targets deferred to H3 spec (feature 008:
  Multi-Tenant Isolation). [DOC: 05b feasibility C2]
- Feasibility constraint C1: founder must prioritize Nexus
  over LifeSync in H1. This is the #1 H1 priority (G-06).

---

## Constitutional Alignment (v1.1.0)

### Governance Principles

| Principle | Status | Evidence |
|-----------|--------|----------|
| P-I State Machine Determinism | ALIGNED | ACTIVE ↔ ARCHIVED. Max 1 transition per operation. No loops. |
| P-II Human-in-the-Loop | EXEMPT | Internal state management only. No external side effects. |
| P-IV Persistent Project Context | ALIGNED | This IS the P-IV implementation. |
| P-V Specification-Driven | ALIGNED | This spec with 12 FRs, 7 SCs, 6 invariants, 6 edge cases. |
| P-VI Traceability and Evidence | ALIGNED | Evidence tags on all claims. Audit logging (FR-010). |
| P-VII Incremental Extension | ALIGNED | Extends P4 plane. No rewrites. Additive changes only. |

### Runtime Principles

| Principle | Status | Evidence |
|-----------|--------|----------|
| RP-3 Context Compression | ALIGNED | 500-token cap (I-1). CRON daily. Alert at 800. |
| RP-7 Fail-Closed Writes | ALIGNED | Firestore transactions + retry max 3. Fail-open reads (US-2 SC-3). |
| RP-1, RP-2, RP-4–RP-6, RP-8 | N/A | Not in webhook path; no agent execution; no LLM calls. |

### Security & Risk

| Check | Status | Evidence |
|-------|--------|----------|
| CP1/CP2/CP3 | N/A | No direct user input parsing, no prompt composition, no LLM output. |
| R-13 Context Bloat | MITIGATED | RP-3 cap + CRON + alert. |
| R-10 Webhook Timeout | N/A | Async worker path. |
| C1 Founder Focus | COMPLIANT | #1 H1 priority. |
| C2 No H3 Before H1 | COMPLIANT | Single-operator only. |

### DoR Compliance

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Specification exists | YES — this document |
| 2 | Plan exists | YES — plan.md |
| 3 | ACs measurable | YES — all SCs have numeric thresholds |
| 4 | Edge cases documented | YES — 6 cases mapped to CB-xx |
| 5 | Security checkpoint mapping | YES — CP1/CP2/CP3 assessed (N/A) |
| 6 | Token budget impact | YES — zero LLM cost (NFR-002) |
| 7 | Risk registry check | YES — R-13, R-10 assessed |
| 8 | Feasibility constraints | YES — C1, C2 verified |
| 9 | Feature files exist | YES — 5 files, 34 scenarios, hash-locked |
| 10 | Tasks generated | YES — 37 tasks, TDD ordered |
