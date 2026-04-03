# Testify Clarifications: Project State Engine

## Session 2026-04-03

- Q: How should the CRON notify the operator when their active project is archived (TS-022)? -> A: No notification. Operator hasn't interacted in 30+ days; FR-009 reactivates instantly on next reference. Proactive messaging requires infrastructure that violates P-VII for a zero-consequence event. Removed notification step from TS-022. [TS-022, FR-007, FR-002, FR-009, SC-004, P-VII]

- Q: Which component owns re-compression when compressed_context exceeds 500 tokens at retrieval time (TS-028)? -> A: context-assembler.ts. It is the last component before prompt injection (plan.md architecture). Guard clause: if token count > 500 after load, re-compress synchronously before injection. Not CRON (async), not project-service (CRUD only). Updated TS-028 steps to name context-assembler explicitly. [TS-028, FR-004, plan.md: context-assembler.ts]

- Q: Should a BDD scenario test _version optimistic locking conflicts? -> A: No. H1 is single-operator — concurrent writes to the same project cannot occur. The _version field exists as a schema safety net (data-model.md) but testing it belongs to feature 008 (Multi-Tenant Isolation). Adding a scenario violates P-VII (no overengineering). [data-model.md: _version, P-VII, Constraints: "H1 targets assume single-operator"]
