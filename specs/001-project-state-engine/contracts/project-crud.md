# API Contract: Project CRUD

**Feature**: 001-project-state-engine
**Type**: Internal service contract (not HTTP — invoked by orchestrator)

## Overview

The Project Service exposes four operations consumed by the P2 Control
plane (router/orchestrator). These are TypeScript function calls, not
REST endpoints — Nexus processes messages via Pub/Sub workers, not HTTP
request/response.

---

## createProject

**Trigger**: Router classifies `PROJECT_QUERY` with create intent
**FR**: FR-001, FR-002, FR-011, FR-012

### Input

```typescript
interface CreateProjectRequest {
  operator_id: string;   // Telegram user_id
  name: string;          // 1-100 chars, trimmed, non-whitespace
}
```

### Output

```typescript
interface CreateProjectResponse {
  success: true;
  project: {
    id: string;          // UUID v4
    name: string;
    status: 'ACTIVE';
    created_at: Timestamp;
  };
  message: string;       // Confirmation text for Telegram
}
```

### Error Cases

| Code | Condition | Response |
|------|-----------|----------|
| `INVALID_NAME` | Empty, >100 chars, or whitespace-only (FR-011) | `{ success: false, error: 'INVALID_NAME', message: '...' }` |
| `DUPLICATE_NAME` | Exact name match exists for this operator (FR-012) | `{ success: false, error: 'DUPLICATE_NAME', matches: Project[], message: 'Project "X" already exists. Switch to it or create with a different name?' }` |
| `TRANSACTION_FAILED` | Firestore transaction failed after 3 retries | `{ success: false, error: 'TRANSACTION_FAILED', message: '...' }` |

### Side Effects

1. Creates document in `projects` collection
2. Updates `operators.active_context_id` to new project ID (transactional)
3. Writes `project.create` entry to `audit_log`
4. Updates `projects.last_interaction` to now

### Latency Target

< 3s p95 (webhook received → Telegram response sent)

---

## retrieveProject

**Trigger**: Router classifies `PROJECT_QUERY` with retrieve intent, or implicit project name detected
**FR**: FR-003, FR-004, FR-005, FR-006

### Input

```typescript
interface RetrieveProjectRequest {
  operator_id: string;
  query: string;           // Project name or partial match
  mode: 'explicit' | 'implicit';  // /project cmd vs NLP detection
}
```

### Output (single match)

```typescript
interface RetrieveProjectResponse {
  success: true;
  project: {
    id: string;
    name: string;
    status: 'ACTIVE' | 'ARCHIVED';
    compressed_context: string;    // <=500 tokens
  };
  short_term_memory: MemoryTurn[];  // Last 15 turns for this project
  context_token_count: number;
  message: string;
}
```

### Output (multiple matches — disambiguation)

```typescript
interface DisambiguationResponse {
  success: true;
  disambiguation: true;
  matches: Array<{
    id: string;
    name: string;
    status: 'ACTIVE' | 'ARCHIVED';
    last_interaction: Timestamp;
  }>;
  message: string;    // "Multiple projects match. Please select:"
  telegram_buttons: InlineKeyboardButton[];  // One per match
}
```

### Output (no match)

```typescript
interface NoMatchResponse {
  success: true;
  no_match: true;
  message: string;    // "No project found matching 'X'. Create it?"
  telegram_buttons: InlineKeyboardButton[];  // [Create] button
}
```

### Error Cases

| Code | Condition | Response |
|------|-----------|----------|
| `CONTEXT_OVERFLOW` | compressed_context > 500 tokens after load | Trigger immediate re-compression, then return |

### Side Effects

1. Updates `operators.active_context_id` if mode is `explicit` (transactional)
2. If mode is `implicit`: returns suggestion, does NOT auto-switch (FR-003)
3. Writes `project.retrieve` entry to `audit_log`
4. Updates `projects.last_interaction` to now
5. If project was ARCHIVED: reactivates first (chains to reactivateProject)

### Latency Target

< 3s p95 (webhook received → Telegram response sent)

---

## archiveProject

**Trigger**: CRON daily job (FR-007) or manual operator request
**FR**: FR-007, FR-008, FR-009, FR-010

### Input (CRON)

```typescript
interface ArchiveCronRequest {
  trigger: 'cron';
  current_time: Timestamp;
}
```

### Input (Manual)

```typescript
interface ArchiveManualRequest {
  trigger: 'operator';
  operator_id: string;
  project_id: string;
}
```

### Output (CRON)

```typescript
interface ArchiveCronResponse {
  success: true;
  archived_count: number;
  archived_projects: Array<{ id: string; name: string; days_inactive: number }>;
  errors: Array<{ project_id: string; error: string }>;
}
```

### Processing (CRON)

1. Query all projects where `status == 'ACTIVE'`
2. For each: calculate `days_since = (now - last_interaction) / 86400000`
3. If `days_since > auto_archive_after_days`: archive (transactional per project)
4. Per-project transaction: set `status = 'ARCHIVED'`, if `operator.active_context_id == project.id` then clear it
5. Write `project.archive` to `audit_log` with `metadata: { trigger: 'cron' }`
6. Partial failures do not affect other projects (edge case from spec)

### Side Effects

1. Sets `project.status = 'ARCHIVED'` (data preserved — FR-008)
2. Clears `operator.active_context_id` if it pointed to archived project
3. Writes `project.archive` entry to `audit_log`

---

## reactivateProject

**Trigger**: Operator explicitly references an ARCHIVED project (FR-009)
**FR**: FR-009, FR-010

### Input

```typescript
interface ReactivateProjectRequest {
  operator_id: string;
  project_id: string;
}
```

### Output

```typescript
interface ReactivateProjectResponse {
  success: true;
  project: {
    id: string;
    name: string;
    status: 'ACTIVE';
    compressed_context: string;
  };
  message: string;    // "Project 'X' reactivated and set as active context."
}
```

### Side Effects

1. Sets `project.status = 'ACTIVE'`
2. Updates `project.last_interaction` to now
3. Sets `operator.active_context_id = project.id` (transactional)
4. Writes `project.reactivate` entry to `audit_log`

### Latency Target

< 3s p95 (webhook received → Telegram response sent)
