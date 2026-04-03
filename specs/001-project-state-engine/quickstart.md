# Quickstart: Project State Engine

**Feature**: 001-project-state-engine
**Date**: 2026-04-03

## Prerequisites

- Node.js (Cloud Functions v2 compatible)
- Firebase CLI (`firebase-tools`)
- Firebase project with Firestore enabled
- Vitest configured
- Environment variables: `TELEGRAM_BOT_TOKEN`, `GOOGLE_CLOUD_PROJECT`

## Dev Setup

```bash
# Install dependencies (from repo root)
npm install

# Start Firestore emulator for local development
firebase emulators:start --only firestore,pubsub

# Run tests
npx vitest run tests/unit/project-*.test.ts
npx vitest run tests/integration/project-*.test.ts
```

## Test Scenarios

### TS-01: Create Project (Happy Path)

**Maps to**: US-1 SC-1, FR-001, FR-002, SC-001

```
GIVEN: Authenticated operator (telegram_id: "12345") with no active project
WHEN:  Operator sends "create project Acme Proposal"
THEN:
  - projects collection has new doc: { name: "Acme Proposal", status: "ACTIVE", owner_id: "12345", compressed_context: "" }
  - operators/12345.active_context_id == new_project.id
  - audit_log has entry: { action_type: "project.create", operator_id: "12345" }
  - Response sent to Telegram within 3s
```

### TS-02: Create Project with Existing Active (Context Switch)

**Maps to**: US-1 SC-2, FR-002

```
GIVEN: Operator "12345" has active project "Alpha" (id: "aaa")
WHEN:  Operator sends "create project Beta"
THEN:
  - New project "Beta" created with status: "ACTIVE"
  - operators/12345.active_context_id == beta_project.id (switched)
  - Project "Alpha" remains ACTIVE and accessible
  - audit_log has "project.create" entry
```

### TS-03: Create Project with Invalid Name (FR-011)

**Maps to**: FR-011, edge case

```
GIVEN: Authenticated operator
WHEN:  Operator sends "create project" (empty name)
THEN:  Error response: "Project name cannot be empty"
       No project created, no audit log entry

WHEN:  Operator sends "create project    " (whitespace-only)
THEN:  Error response: "Project name cannot be whitespace-only"

WHEN:  Operator sends "create project <101-char-name>"
THEN:  Error response: "Project name cannot exceed 100 characters"
```

### TS-04: Create Project with Duplicate Name (FR-012)

**Maps to**: FR-012, edge case

```
GIVEN: Operator "12345" has project "Acme Proposal"
WHEN:  Operator sends "create project Acme Proposal"
THEN:
  - Response: "Project 'Acme Proposal' already exists. Switch to it or create with a different name?"
  - Telegram inline buttons: [Switch to existing] [Create anyway]
  - No project created until operator confirms
```

### TS-05: Retrieve Project (Single Match)

**Maps to**: US-2 SC-1, FR-003, FR-004, SC-002

```
GIVEN: Operator "12345" has project "Acme Proposal" with compressed_context and 10 turns of history
WHEN:  Operator sends "/project Acme Proposal"
THEN:
  - compressed_context loaded (<=500 tokens)
  - short_term_memory: last 15 turns filtered by project_id
  - operators/12345.active_context_id set to acme.id
  - Response within 3s with project status summary
  - audit_log: "project.retrieve"
```

### TS-06: Retrieve Project (Disambiguation)

**Maps to**: US-2 SC-2, FR-005, SC-007

```
GIVEN: Operator "12345" has projects "Acme Proposal" and "Acme Research"
WHEN:  Operator sends "/project Acme"
THEN:
  - Response: "Multiple projects match. Please select:"
  - Telegram inline buttons: [Acme Proposal] [Acme Research]
  - NO auto-selection (FR-005)
  - active_context_id NOT changed until selection
```

### TS-07: Retrieve Archived Project (Reactivation)

**Maps to**: US-2 SC-4, US-3 SC-2, FR-009, SC-005

```
GIVEN: Operator "12345" has ARCHIVED project "Old Client"
WHEN:  Operator sends "/project Old Client"
THEN:
  - Project reactivated: status → ACTIVE
  - operators/12345.active_context_id set to old_client.id
  - last_interaction updated to now
  - audit_log: "project.reactivate"
  - Response within 3s
```

### TS-08: CRON Archival (Happy Path)

**Maps to**: US-3 SC-1, FR-007, FR-008, SC-004

```
GIVEN: 3 ACTIVE projects:
  - "Recent" (last_interaction: 5 days ago)
  - "Stale" (last_interaction: 35 days ago, auto_archive_after_days: 30)
  - "Custom" (last_interaction: 20 days ago, auto_archive_after_days: 15)
WHEN:  CRON fires at 02:00 UTC
THEN:
  - "Recent" stays ACTIVE (5 < 30)
  - "Stale" → ARCHIVED (35 > 30)
  - "Custom" → ARCHIVED (20 > 15)
  - All data preserved (compressed_context, artifacts, etc.)
  - audit_log: 2 "project.archive" entries with metadata.trigger: "cron"
```

### TS-09: Zero Cross-Project Contamination

**Maps to**: US-4, FR-006, SC-003

```
GIVEN: Operator "12345" has:
  - Project "Alpha" with compressed_context: "Alpha is about cloud migration"
  - Project "Beta" with compressed_context: "Beta is about mobile app"
  - short_term_memory turns for both projects
WHEN:  Operator switches from Alpha to Beta
THEN:
  - Context assembler returns ONLY Beta's compressed_context
  - short_term_memory contains ONLY turns with project_id == beta.id
  - Zero Alpha content in assembled context
  - Repeat 100 times (SC-003): 0 contamination events
```

### TS-10: CRON Partial Failure (Edge Case)

**Maps to**: Edge case from spec

```
GIVEN: 3 projects qualifying for archival
  - Project A: archival succeeds
  - Project B: Firestore transaction fails (simulated)
  - Project C: archival succeeds
WHEN:  CRON fires
THEN:
  - A and C archived successfully
  - B remains ACTIVE
  - Error logged for B
  - CRON returns: { archived: 2, errors: 1 }
```

### TS-11: Concurrent Create (Edge Case)

**Maps to**: Edge case (write conflict)

```
GIVEN: Operator sends two rapid "create project" messages (debounce should catch, but testing the guard)
WHEN:  Both reach project-service simultaneously
THEN:
  - Firestore transaction ensures only one succeeds
  - Second attempt gets DUPLICATE_NAME or retries with version conflict
  - No orphaned state (active_context_id always consistent)
```

## Verification Checklist

After implementation, verify:

- [ ] All 11 test scenarios pass
- [ ] `npx vitest run --coverage` shows >=80% for project-state module
- [ ] 100% coverage for project-validators.ts (security-adjacent)
- [ ] Firestore emulator used for all integration tests (no mocks for DB per P-V)
- [ ] audit_log entries present for every lifecycle operation
- [ ] No cross-project data leakage in TS-09 (100 consecutive switches)
