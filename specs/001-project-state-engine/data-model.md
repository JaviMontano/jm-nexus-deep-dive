# Data Model: Project State Engine

**Feature**: 001-project-state-engine
**Date**: 2026-04-03
**Source**: Discovery canonical data model (A6), spec.md FR-001 through FR-012

## Entities

### Project

**Collection**: `projects`
**Purpose**: Core work context — named container for all project-scoped operations.

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| `id` | `string` | PK, UUID v4, auto-generated | Firestore document ID |
| `owner_id` | `string` | FK → operators.id, NOT NULL | Telegram user_id of creator |
| `name` | `string` | NOT NULL, 1-100 chars, trimmed, no whitespace-only | FR-011 validation |
| `status` | `string` | ENUM: `ACTIVE` \| `ARCHIVED`, NOT NULL, default `ACTIVE` | 2-state model per clarification |
| `compressed_context` | `string` | Max 500 tokens, default `""` | LLM summary, CRON-compressed |
| `knowledge_anchors` | `string[]` | Default `[]` | Reserved — no business logic in this feature (P-V) |
| `open_tasks` | `string[]` | Default `[]` | Reserved — no business logic in this feature (P-V) |
| `artifacts` | `string[]` | Default `[]` | Reserved — no business logic in this feature (P-V) |
| `compression_log` | `CompressionEntry[]` | Default `[]` | Append-only history of CRON compressions |
| `auto_archive_after_days` | `number` | Default `30`, min 1 | Configurable per-project archival threshold |
| `created_at` | `Timestamp` | NOT NULL, server-generated | Firestore server timestamp |
| `last_interaction` | `Timestamp` | NOT NULL, updated on every project-scoped operation | Used by archival CRON |
| `_version` | `number` | Default `1`, incremented on every write | Optimistic locking |

**Indexes**:
- `owner_id + status` (ASC, ASC) — dashboard: list active projects
- `owner_id + name` (ASC, ASC) — disambiguation queries

**Security Rules**:
- Read: `owner_id == request.auth.uid` OR system service account
- Write: `owner_id == request.auth.uid` OR system service account
- Delete: **NEVER** (FR-008 — projects are never deleted)

**Invariants**:
- I-1: `compressed_context` never exceeds 500 tokens (CRON enforces)
- I-2: `status` transitions: only `ACTIVE → ARCHIVED` and `ARCHIVED → ACTIVE`
- I-3: No hard delete — only status change to `ARCHIVED`
- I-4: `_version` incremented atomically on every write (optimistic locking)

#### CompressionEntry (embedded type)

| Field | Type | Constraints |
|-------|------|-------------|
| `date` | `Timestamp` | When compression ran |
| `before_tokens` | `number` | Token count before compression |
| `after_tokens` | `number` | Token count after compression |
| `dropped_topics` | `string[]` | Topics removed during compression |

---

### Operator (MODIFY — add field)

**Collection**: `operators`
**Purpose**: User profile. This feature adds/modifies `active_context_id`.

| Field | Type | Constraints | Change |
|-------|------|-------------|--------|
| `active_context_id` | `string \| null` | FK → projects.id, nullable | **ADD** — references the currently active project |

**Transition Logic**:
- On project create (FR-002): set `active_context_id = new_project.id`
- On project switch (FR-003): set `active_context_id = target_project.id`
- On project archive (FR-007): if `active_context_id == archived_project.id`, set to `null`
- On project reactivate (FR-009): set `active_context_id = reactivated_project.id`

All updates to `active_context_id` are transactional with the project operation (TD-04).

---

### Audit Log Entry (EXTEND — add action types)

**Collection**: `audit_log`
**Purpose**: Immutable trail. This feature adds project lifecycle action types.

| Field | Type | Constraints |
|-------|------|-------------|
| `id` | `string` | PK, UUID v4 |
| `timestamp` | `Timestamp` | Server-generated, NOT NULL |
| `operator_id` | `string` | FK → operators.id |
| `action_type` | `string` | **NEW values**: `project.create`, `project.retrieve`, `project.archive`, `project.reactivate` |
| `resource` | `object` | `{ type: 'project', id: string, before?: string, after: string }` |
| `status` | `string` | `success` \| `failure` |
| `reason` | `string?` | Error description on failure |
| `metadata` | `object` | Additional context (e.g., `{ trigger: 'cron' \| 'operator' }`) |

**Rules**: Append-only (no update/delete). Retention 90+ days.

---

## State Transitions

### Project Status State Machine

```
     ┌─────────────────────────────────────────┐
     │                                         │
     │  CREATE (FR-001)                        │
     │  ∅ ──────────────▶ ACTIVE               │
     │                      │                  │
     │  ARCHIVE (FR-007)    │                  │
     │  CRON or manual      ▼                  │
     │                   ARCHIVED              │
     │                      │                  │
     │  REACTIVATE (FR-009) │                  │
     │  Explicit reference  ▼                  │
     │                   ACTIVE ◀──────────────┘
     │
     │  DELETE: PROHIBITED (FR-008)
     └─────────────────────────────────────────┘
```

### Valid Transitions

| From | To | Trigger | Guard | Side Effects |
|------|----|---------|-------|-------------|
| ∅ | ACTIVE | Operator creates project | Name valid (FR-011), no exact duplicate without confirmation (FR-012) | Set operator.active_context_id, audit log |
| ACTIVE | ARCHIVED | CRON (FR-007) or manual | `last_interaction + auto_archive_after_days < now` (CRON), or operator request (manual) | Clear operator.active_context_id if matches, audit log |
| ARCHIVED | ACTIVE | Operator explicit reference (FR-009) | Project exists with matching owner_id | Set operator.active_context_id, update last_interaction, audit log |

### Invalid Transitions (Rejected)

| Attempt | Rejection Reason |
|---------|-----------------|
| ACTIVE → DELETED | FR-008: projects are never deleted |
| ARCHIVED → DELETED | FR-008: projects are never deleted |
| Any → SUSPENDED/COMPLETED | Only 2 states in H1 per clarification |

---

## Validation Schemas (Zod)

```typescript
// Project creation input
const CreateProjectInput = z.object({
  name: z.string()
    .trim()
    .min(1, 'Project name cannot be empty')
    .max(100, 'Project name cannot exceed 100 characters')
    .refine(s => s.trim().length > 0, 'Project name cannot be whitespace-only'),
  owner_id: z.string().min(1),
  auto_archive_after_days: z.number().int().min(1).default(30),
});

// Project status enum
const ProjectStatus = z.enum(['ACTIVE', 'ARCHIVED']);

// Full project document
const ProjectDocument = z.object({
  id: z.string().uuid(),
  owner_id: z.string().min(1),
  name: z.string().min(1).max(100),
  status: ProjectStatus,
  compressed_context: z.string().max(2000), // ~500 tokens ≈ ~2000 chars
  knowledge_anchors: z.array(z.string()).default([]),
  open_tasks: z.array(z.string()).default([]),
  artifacts: z.array(z.string()).default([]),
  compression_log: z.array(z.object({
    date: z.any(), // Firestore Timestamp
    before_tokens: z.number().int().min(0),
    after_tokens: z.number().int().min(0),
    dropped_topics: z.array(z.string()),
  })).default([]),
  auto_archive_after_days: z.number().int().min(1).default(30),
  created_at: z.any(), // Firestore Timestamp
  last_interaction: z.any(), // Firestore Timestamp
  _version: z.number().int().min(1).default(1),
});
```

---

## Relationships

```
operators (1) ──── active_context_id ────▶ (0..1) projects
operators (1) ──── owner_id ─────────────▶ (0..N) projects
projects  (1) ──── lifecycle events ─────▶ (0..N) audit_log
```

- One operator has zero or one active project at a time
- One operator owns zero or many projects
- One project generates zero or many audit log entries
- Projects reference artifacts, tasks, and memory (reserved fields — no business logic in this feature)
