<!-- Sync Impact Report
Version: 1.0.0 (initial ratification)
Modified Principles: none (first version)
Added Sections: Core Principles (P-I through P-VII), Quality Governance, Governance
Removed Sections: none
Follow-up TODOs: none
-->

# Nexus Assistant OS Constitution

## Core Principles

### P-I. State Machine Determinism

**Rules**: Every user interaction transitions structured state
through a defined state machine. No free-form agent loops. All
state transitions must be auditable, reproducible, and
cost-bounded. Unbounded LLM reasoning chains are prohibited
at the message-handling level.

**Rationale**: Deterministic state transitions make the system
predictable, auditable, and cost-controlled — essential for
a productizable Work OS where each token has a measurable cost
per project.

**Enforcement**: Code review must verify that new message handlers
follow the state-transition pattern. Gate G5 (implementation
review) rejects free-form agent loops in the control plane.

### P-II. Human-in-the-Loop for External Actions

**Rules**: No external side effect (API call, file mutation,
message send, data deletion) may execute without explicit human
approval. Approval must be captured with timestamp, user identity,
and action description in an immutable audit trail. Internal
read-only operations (memory retrieval, intent classification)
are exempt.

**Rationale**: Reputational and data-integrity risk from
autonomous external execution is the primary blocker for B2B
adoption. Trust requires a verifiable approval chain.

**Enforcement**: All external action adapters must pass through
the HIL middleware. Gate G5 rejects any new integration that
bypasses the approval pipeline. Audit trail completeness is
a release gate criterion.

### P-III. Constitution-Governed Behavior

**Rules**: The system's 8 operational principles (defined in the
Nexus runtime constitution) govern all agent behavior. No agent,
skill, or workflow may violate a constitutional principle. When
principles conflict, explicit priority ordering resolves the
conflict — never silent overrides.

**Rationale**: A multi-agent system without governance drifts
toward unpredictable behavior. Constitutional constraints make
agent behavior verifiable and explainable to end users.

**Enforcement**: Each skill and workflow specification must
declare which constitutional principles it operates under.
Specification review validates alignment. Violations are
blocking defects.

### P-IV. Persistent Project Context

**Rules**: Every project interaction must persist context
sufficient to resume without user re-explanation. Context
includes: project identity, decision history, active tasks,
artifact versions, and relevant conversation summaries.
Context retrieval must complete within acceptable latency
for conversational UX.

**Rationale**: ~60 h/year lost to context repetition is the
primary user pain point. Persistent memory is the foundation
for all downstream features (proactive intelligence, artifact
versioning, cost tracking).

**Enforcement**: New features must declare their context
read/write contract in the specification. Gate G3 validates
that context persistence tests pass before implementation
proceeds.

### P-V. Specification-Driven Development

**Rules**: All production features must be specified before
implementation begins. Specifications define: intent (what and
why), acceptance criteria (measurable), edge cases, and
assertions. No code is written without a corresponding
specification. Specifications are living documents updated
when requirements change — never silently diverged from.

**Rationale**: The discovery identified 15 gaps between
aspirational documentation and actual implementation. SDD
prevents this drift by making specification the source of
truth that code must satisfy.

**Enforcement**: IIKit pipeline enforces spec-first workflow.
Pre-commit hooks validate assertion integrity. Implementation
PRs must reference their specification.

### P-VI. Traceability and Evidence

**Rules**: Every architectural claim, design decision, and
gap assessment must carry an evidence tag: [CODIGO] (verified
against source), [CONFIG] (verified against configuration),
[DOC] (verified against documentation), [INFERENCIA] (logically
derived from evidence), [SUPUESTO] (assumed without direct
evidence). Untagged claims are not actionable.

**Rationale**: The discovery produced 72 epistemologically
classified claims across 23 deliverables. Maintaining this
rigor prevents the documentation-reality drift that created
the original 15-gap problem.

**Enforcement**: Deliverable review gates reject untagged
claims. The quality guardian validates tag accuracy against
source material.

### P-VII. Incremental Extension Over Rewrite

**Rules**: New capabilities must extend the existing 4-plane
architecture (Ingesta, Control, Ejecucion, Persistencia)
rather than replacing it. Rewrites require an Architecture
Decision Record with cost-benefit analysis and explicit
approval. Breaking changes to existing interfaces require
a migration plan.

**Rationale**: 80% of the existing ~10,000 LOC base is solid.
The 3-horizon roadmap (16 weeks, ~6 FTE-months) assumes
extension, not rewrite. Unnecessary rewrites waste the
validated foundation.

**Enforcement**: ADRs are required for any change that modifies
an existing plane's interface contract. Gate G5 validates that
implementations conform to the extension pattern.

## Quality Governance

QA-PLAN.md is the authoritative quality artifact for this
project. It aggregates:
- Global Definition of Done and acceptance criteria (derived
  from this constitution)
- Per-feature qa/ subdirectories (created emergently by
  /sdd:spec and /sdd:test)
- Quality gate status (updated by /sdd:analyze)
- Feature quality registry (AC coverage, test coverage,
  checklist completion)

Run /sdd:qa to generate or refresh. Auto-invoked by
/sdd:analyze.

## Governance

This constitution supersedes all other process documents for
governance decisions. Principles are ordered by priority
(P-I highest) for conflict resolution.

**Amendments**: Any change to this constitution requires:
1. A written proposal identifying the principle affected
2. Impact analysis on existing specifications and plans
3. Version bump following semver (MAJOR: principle removal
   or redefinition, MINOR: new principle, PATCH: clarification)
4. Updated Sync Impact Report in the HTML comment header

**Compliance**: All specification reviews, plan reviews, and
implementation reviews must verify constitutional compliance.
Non-compliance is a blocking defect that cannot be deferred.

**Version**: 1.0.0 | **Ratified**: 2026-04-03 | **Last Amended**: 2026-04-03
