# API Contract: Archival CRON

**Feature**: 001-project-state-engine
**Type**: Cloud Scheduler → Cloud Function trigger
**FR**: FR-007, FR-008, FR-010

## Trigger

**Schedule**: Daily at 02:00 UTC (configurable)
**Mechanism**: Cloud Scheduler HTTP POST to Cloud Function endpoint
**Auth**: Service account with Firestore read/write permissions

## Endpoint

```
POST /cron/archive-projects
Authorization: Bearer <service-account-token>
Content-Type: application/json
Body: {} (empty — timestamp derived from server)
```

## Processing Flow

```
Cloud Scheduler
  → POST /cron/archive-projects
  → Query: projects WHERE status == 'ACTIVE'
  → For each project:
      calculate days_inactive = (now - last_interaction) / 86400000
      IF days_inactive > auto_archive_after_days:
        BEGIN TRANSACTION
          SET project.status = 'ARCHIVED'
          SET project._version++
          IF operator.active_context_id == project.id:
            SET operator.active_context_id = null
          APPEND audit_log { action: 'project.archive', trigger: 'cron' }
        COMMIT
  → Return summary
```

## Response

```typescript
// HTTP 200
{
  processed: number;      // Total ACTIVE projects evaluated
  archived: number;       // Projects archived this run
  errors: number;         // Projects that failed (logged, not retried)
  duration_ms: number;
}
```

## Error Handling

- Per-project transactions: failure on one project does not block others
- Failed projects logged to Cloud Logging (structured JSON)
- Cloud Scheduler retry: 1 retry after 5 minutes on HTTP 5xx
- No retry on HTTP 200 (even if `errors > 0` — those are per-project)

## Idempotency

Safe to re-run: archiving an already-ARCHIVED project is a no-op.
The `status == 'ACTIVE'` query naturally filters already-archived projects.

## Monitoring

- Alert if `errors / processed > 10%`
- Alert if CRON does not fire within expected window (Cloud Scheduler monitoring)
- Metric: `archived_count` per run (track archival trend)
