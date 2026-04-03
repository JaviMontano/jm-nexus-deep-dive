# API Contract: Context Assembly

**Feature**: 001-project-state-engine
**Type**: Internal service contract (consumed by prompt-composer.ts)
**FR**: FR-004, FR-006

## Overview

The Context Assembler loads project context for the Prompt Composer.
It is called on every project-scoped message after the router identifies
a PROJECT_QUERY or after active_context_id is resolved.

## assembleContext

### Input

```typescript
interface AssembleContextRequest {
  operator_id: string;
  project_id: string;       // From operator.active_context_id
}
```

### Output

```typescript
interface AssembledContext {
  project: {
    id: string;
    name: string;
    compressed_context: string;   // <=500 tokens
  };
  short_term_memory: MemoryTurn[];  // Last 15 turns, ordered by turn_number ASC
  token_count: number;              // Total tokens in assembled context
  assembled_at: Timestamp;
}

interface MemoryTurn {
  turn_number: number;
  role: 'user' | 'assistant';
  content: string;
  metadata: {
    tokens: number;
    intent?: string;
    agent_id?: string;
  };
}
```

### Processing

1. **Batch read** (single Firestore call):
   - `projects/{project_id}` — get compressed_context
   - `short_term_memory` WHERE `operator_id == req.operator_id` AND `project_id == req.project_id` ORDER BY `created_at DESC` LIMIT 15

2. **Contamination guard** (FR-006):
   - Assert `project.owner_id == operator_id` — reject if mismatch
   - Assert all memory turns have matching `project_id` — filter any that don't (defensive)

3. **Token counting**:
   - Count tokens in compressed_context + all memory turn contents
   - If total > token budget for current delegation mode: truncate short_term_memory first (oldest turns removed), then compressed_context

4. **Return** assembled context object

### Error Cases

| Code | Condition | Response |
|------|-----------|----------|
| `PROJECT_NOT_FOUND` | project_id doesn't exist | `{ error: 'PROJECT_NOT_FOUND' }` — upstream handles |
| `OWNER_MISMATCH` | project.owner_id != operator_id | `{ error: 'OWNER_MISMATCH' }` — security violation, audit log |
| `CONTEXT_OVERFLOW` | compressed_context > 500 tokens | Log warning, proceed with truncated context |

### Latency Target

< 200ms (context assembly only, per FR-006 from discovery spec)

### Zero-Contamination Guarantee (FR-006)

The assembler enforces isolation at three levels:
1. **Query level**: All Firestore queries include `owner_id` and `project_id` filters
2. **Assertion level**: Post-query validation confirms ownership match
3. **Defensive level**: Any memory turn with mismatched `project_id` is silently filtered (log warning)

This triple-filter ensures SC-003 (zero contamination across 100 consecutive switches).
