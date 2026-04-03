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
  knowledge_anchors (empty array), open_tasks (empty array),
  artifacts (empty array), compression_log (empty array),
  auto_archive_after_days (default 30), created_at, and
  last_interaction timestamp.

- **FR-002**: System MUST set the newly created project as the
  operator's active_context_id in their operator profile.

- **FR-003**: System MUST retrieve project context by matching
  project_name from the intent router's extracted_project_name,
  filtering by owner_id.

- **FR-004**: System MUST load compressed_context (<=500 tokens)
  and short_term_memory (last 15 turns) into the orchestrator's
  context assembly within 3 seconds.

- **FR-005**: System MUST present disambiguation options when a
  project name matches multiple projects — never auto-select.

- **FR-006**: System MUST enforce zero cross-project
  contamination by filtering all queries strictly by
  active_context_id and owner_id.

- **FR-007**: System MUST run a CRON job that evaluates
  last_interaction against auto_archive_after_days and archives
  qualifying projects.

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
  confirmation within 3 seconds.

- **SC-002**: Operator can resume a project after 5+ days of
  inactivity with context retrieved accurately within 3 seconds.

- **SC-003**: Zero cross-project contamination across 100
  consecutive project switches (verified via audit log).

- **SC-004**: CRON archival correctly archives 100% of projects
  exceeding auto_archive_after_days without data loss.

- **SC-005**: Archived projects are accessible via explicit
  search and reactivatable within 3 seconds.

- **SC-006**: All project lifecycle events appear in audit_log
  with correct operator_id, action type, and ISO timestamp.

- **SC-007**: Disambiguation prompt appears for ambiguous
  project names 100% of the time — zero auto-selections.
