# Feature Specification: Project State Engine

**Feature Branch**: `001-project-state-engine`
**Created**: 2026-04-03
**Status**: Draft
**Input**: Extracted from discovery deliverables (M-09, G-06, CU-17/18/19, ADR-005)

## User Stories

### User Story 1 - Create and Activate a Project (Priority: P1)

As the operator, I want to create a named project via Telegram
so that all subsequent interactions are associated with a
persistent context and I never have to re-explain my project
from scratch.

**Why this priority**: Project creation is the foundation of
all project-scoped operations. Without it, no other feature
(HIL, artifacts, memory, analytics) can associate work to a
project. This is the single most blocking capability (G-06,
0% implemented).

**Independent Test**: Send a "create project Acme Proposal"
message to the bot and verify a project document is created
with correct initial state. Delivers immediate value: the
operator has a named container for work.

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
   completes, **Then** the response time is under 3 seconds and
   the operator receives confirmation with the project name.

---

### User Story 2 - Retrieve Project Context (Priority: P1)

As the operator, I want to resume a conversation about a
previous project and have the bot recall its full context
(decisions, tasks, artifacts, compressed history) so that I
do not lose ~60 hours/year repeating context to prompts.

**Why this priority**: Context retrieval is the core value
proposition that differentiates Nexus from "ChatGPT in
Telegram". Without it, every session starts from zero.

**Independent Test**: Create a project, add context over
several interactions, wait 5+ days, then resume the project
and verify context is retrieved accurately.

**Acceptance Scenarios**:

1. **Given** an existing project with compressed_context and
   prior interactions, **When** the operator mentions the
   project name, **Then** the system loads compressed_context
   (<=500 tokens) and short_term_memory (last 15 turns) within
   3 seconds.

2. **Given** a project name that partially matches multiple
   projects (e.g., "Acme"), **When** the operator references it,
   **Then** the system lists all matching projects and asks the
   operator to disambiguate — never auto-selects.

3. **Given** a project with empty compressed_context (new or
   never compressed), **When** context is retrieved, **Then**
   the system degrades gracefully with available short-term
   memory only — no errors.

4. **Given** a project inactive for 30+ days (ARCHIVED),
   **When** the operator references it, **Then** the system
   retrieves and reactivates it.

---

### User Story 3 - Archive Inactive Projects (Priority: P2)

As the system (CRON job), I want to automatically archive
projects with no interaction for a configurable number of days
(default 30) so that active context retrieval stays fast and
the operator's project list remains manageable.

**Why this priority**: Archival prevents context bloat (R-13)
and keeps the active list clean. Lower priority because the
system functions without it in the short term.

**Independent Test**: Create a project, simulate 30+ days of
inactivity, run the CRON job, and verify status changes to
ARCHIVED without data loss.

**Acceptance Scenarios**:

1. **Given** a project whose last_interaction exceeds
   auto_archive_after_days (default 30), **When** the archival
   CRON runs, **Then** the project status changes to ARCHIVED
   and it is excluded from default context retrieval.

2. **Given** an ARCHIVED project, **When** the operator
   explicitly searches for it, **Then** it appears in results
   and can be reactivated.

3. **Given** a project is archived, **Then** no data is
   deleted — status change only. All compressed_context,
   knowledge_anchors, open_tasks, and artifacts are preserved.

---

### User Story 4 - Zero Cross-Project Contamination (Priority: P1)

As the operator working across multiple projects, I want
absolute guarantee that context from Project A never leaks
into Project B so that proposals, research, and decisions
are never contaminated with wrong-project data.

**Why this priority**: Cross-project contamination is a
reputational and data-integrity risk. The discovery marks
"0 cross-project contamination" as a non-negotiable invariant.

**Independent Test**: Create two projects with distinct
contexts, switch between them, and verify responses reference
only the active project's context.

**Acceptance Scenarios**:

1. **Given** two active projects with distinct contexts,
   **When** the operator switches from Project A to Project B,
   **Then** only Project B's compressed_context and
   short_term_memory are loaded — zero leakage from Project A.

2. **Given** a multi-project environment, **When** the
   orchestrator assembles context (CU-06), **Then** it filters
   strictly by active_context_id and project_id.

---

### Edge Cases

- Operator creates a project with a name identical to an
  existing project: system presents existing match and asks
  operator to confirm new creation (with suffix) or switch.
- Concurrent project operations cause write conflicts: atomic
  transactions with max 3 retries and optimistic versioning.
- compressed_context exceeds 500 tokens after retrieval:
  trigger immediate re-compression before injecting into
  prompt (invariant I-1).
- CRON archival job fails mid-execution: transactional
  per-project archival — partial failures do not affect other
  projects.
- Operator has 100+ projects: paginated retrieval with
  most-recent-first ordering.
- Operator references a project by ambiguous abbreviation:
  always disambiguate, never auto-select.

## Requirements

### Functional Requirements

- **FR-001**: System MUST create a project document with:
  name, owner_id, status (ACTIVE), compressed_context (empty),
  knowledge_anchors (empty array — reserved, no business logic
  in this feature per P-V), open_tasks (empty array — reserved),
  artifacts (empty array — reserved), compression_log (empty
  array), auto_archive_after_days (default 30), created_at, and
  last_interaction timestamp.

- **FR-002**: System MUST set the newly created project as the
  operator's active_context_id in their operator profile.

- **FR-003**: System MUST retrieve project context via two
  modes: (a) implicit detection from the intent router's
  extracted_project_name, presented as a suggestion requiring
  operator confirmation before switching, and (b) explicit
  command (e.g., "/project <name>") that executes a
  deterministic transition. Both modes filter by owner_id.

- **FR-004**: System MUST load compressed_context (<=500 tokens)
  and short_term_memory (last 15 turns, filtered strictly by
  project_id) into the orchestrator's context assembly within
  3 seconds (p95 processing time, measured from webhook received
  to response sent to Telegram API).

- **FR-005**: System MUST present disambiguation options when a
  project name matches multiple projects — never auto-select.

- **FR-006**: System MUST enforce zero cross-project
  contamination by filtering all queries strictly by
  active_context_id and owner_id.

- **FR-007**: System MUST run a daily CRON job (once per 24h)
  that evaluates last_interaction against auto_archive_after_days
  and archives qualifying projects. Archival resolution is 24
  hours — a project may remain ACTIVE up to ~24h beyond its
  threshold until the next CRON execution.

- **FR-008**: System MUST preserve all project data when
  archiving — status change only, never delete.

- **FR-009**: System MUST allow reactivation of ARCHIVED
  projects when the operator explicitly references them.

- **FR-010**: System MUST log all project lifecycle events
  (create, retrieve, archive, reactivate) to audit_log with
  operator_id, action, and timestamp.

- **FR-011**: System MUST reject project names that are empty,
  exceed 100 characters, or contain only whitespace.

- **FR-012**: System MUST handle duplicate project names by
  presenting existing matches and asking the operator to
  confirm or switch.

### Key Entities

- **Project**: Central entity representing a named work context.
  Attributes: project_id, name, owner_id, status
  (ACTIVE/ARCHIVED), compressed_context, knowledge_anchors,
  open_tasks, artifacts, compression_log,
  auto_archive_after_days, created_at, last_interaction.
  Belongs to one operator, contains many artifacts and tasks.

- **Operator**: The human user. Relevant attribute:
  active_context_id (FK to project). Owns many projects, has
  one active context at a time.

- **Audit Log Entry**: Immutable record of project lifecycle
  events. Attributes: log_id, operator_id, action, level,
  result, details, timestamp.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Operator can create a project and receive
  confirmation within 3 seconds (p95 processing time:
  webhook received → response sent to Telegram API).

- **SC-002**: Operator can resume a project after 5+ days of
  inactivity with context retrieved accurately within 3 seconds
  (p95 processing time: webhook received → response sent to
  Telegram API).

- **SC-003**: Zero cross-project contamination across 100
  consecutive project switches (verified via audit log).

- **SC-004**: CRON archival correctly archives 100% of projects
  exceeding auto_archive_after_days without data loss.

- **SC-005**: Archived projects are accessible via explicit
  search and reactivatable within 3 seconds (p95 processing
  time: webhook received → response sent to Telegram API).

- **SC-006**: All project lifecycle events appear in audit_log
  with correct operator_id, action type, and ISO timestamp.

- **SC-007**: Disambiguation prompt appears for ambiguous
  project names 100% of the time — zero auto-selections.

### Constraints

- H1 targets assume single-operator usage. Multi-operator
  concurrency targets deferred to H3 spec (feature 008:
  Multi-Tenant Isolation).

## Clarifications

### Session 2026-04-03

- Q: How does the operator switch to a project — implicit
  NLP detection, explicit command, or both? -> A: Both.
  Implicit detection from router (CU-04) proposes project
  as suggestion requiring confirmation — never auto-switches.
  Explicit command (`/project <name>`) executes deterministic
  transition without confirmation. Both pass through FR-005
  disambiguation for ambiguous matches.
  [FR-003, FR-005, US-2, SC-002]

- Q: Should the Project entity have states beyond
  ACTIVE/ARCHIVED (e.g., SUSPENDED, COMPLETED, DELETED)?
  -> A: No. Two states (ACTIVE/ARCHIVED) are sufficient for
  H1 per ADR-005 and canonical data model (A6). FR-008
  "never delete" is a behavioral constraint, not a state.
  Additional states deferred to H3 via constitutional
  amendment (P-VII requires ADR for interface changes).
  [FR-001, FR-007, FR-008, FR-009, Key Entity: Project]

- Q: What concurrency and scale targets apply? -> A: H1
  assumes single-operator. No concurrency SC added. Constraint
  documented: multi-operator targets deferred to feature 008.
  Satisfies P-VII (no overengineering) and P-VI (traceability).
  [SC-001, SC-002, FR-004, FR-006]

- Q: How often should the archival CRON job run (FR-007)?
  -> A: Once daily (24h resolution). P-VII prohibits
  overengineering for a 30-day threshold. A ~24h window
  between threshold breach and archival has no user-facing
  cost since archival is non-destructive (FR-008) and
  reactivation is instant (FR-009). P-I satisfied by
  documenting the 24h resolution. P-VI satisfied by CRON
  execution logging to audit_log.
  [FR-007, FR-008, FR-009, FR-010, SC-004]

- Q: What happens to short_term_memory when switching
  projects? -> A: short_term_memory is strictly per-project,
  filtered by project_id. On switch, only the target project's
  turns are loaded — zero turns from prior project. New
  projects with 0 turns degrade gracefully per US-2 SC-3.
  Cross-project context assembly deferred to feature 008.
  P-IV (persistent project context) and FR-006 (zero
  contamination) both require per-project isolation.
  [FR-004, FR-006, US-2, US-4, SC-003]

- Q: Are knowledge_anchors, open_tasks, and artifacts in
  scope for business logic? -> A: No. FR-001 initializes
  them as empty schema placeholders. No read/write/query
  logic in this feature. Each requires its own feature
  specification per P-V (SDD). Documented as "reserved for
  future feature" to prevent unspecified usage.
  [FR-001, Key Entity: Project, P-V, P-VII]

- Q: What does "3 seconds" mean in SC-001, SC-002, SC-005?
  -> A: p95 processing time, measured from webhook received
  to response sent to Telegram API. Excludes Telegram
  delivery latency (not controllable). p95 balances P-I
  (cost-bounded determinism) with P-VII (no tail-latency
  overengineering for H1 single-operator).
  [SC-001, SC-002, SC-005, FR-004]
