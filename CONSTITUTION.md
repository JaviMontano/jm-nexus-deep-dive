<!-- Sync Impact Report
Version: 1.1.0
Modified Principles: none (existing P-I through P-VII unchanged)
Added Sections: Runtime Principles (RP-1 through RP-8), Definition of Ready,
  Definition of Done, Quality Gates, Security Checkpoints, Best Practices,
  Risk Guard Rails
Removed Sections: none
Follow-up TODOs:
  - Cascade check: verify spec.md, plan.md, tasks.md alignment with new sections
  - Update feature checklists to reference DoD/DoR
  - Re-run /iikit-06-analyze after cascade
-->

# Nexus Assistant OS Constitution

## Core Principles (Governance)

These principles govern all project decisions. Ordered by priority
for conflict resolution (P-I highest).

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

---

## Runtime Principles (Architecture)

These 8 principles govern Nexus runtime behavior. Extracted
from the discovery TO-BE architecture (A4) and validated by
the Feasibility Think Tank (05b). Each maps to specific code
files and has a completeness target.

### RP-1. Async-First Processing

**Rule**: All operations >5 seconds MUST use Pub/Sub async
dispatch. Webhook ACK MUST return <2 seconds. No synchronous
LLM call in the webhook handler path.

**Guard**: Webhook timeout (R-10, risk score 9) is mitigated
by this rule. Violation triggers 504 cascade.

**Enforcement**: Pre-deployment latency test; monitoring alert
on any webhook response >2s.

### RP-2. State Machine Enforcement

**Rule**: Each message transitions state through a defined
machine. Maximum 5 transitions per message. Loop detection
MUST kill the chain and revert state. No free-form agent
reasoning loops in the control plane.

**Guard**: Aligns with P-I. Prevents unbounded token spend
and unpredictable behavior.

### RP-3. Context Compression

**Rule**: compressed_context MUST NOT exceed 500 tokens.
short_term_memory limited to last 15 turns per project.
CRON compression runs daily. Alert threshold at 800 tokens;
force compression at 900 tokens.

**Guard**: Context bloat (R-13, risk score 9) causes cost
explosion and prompt truncation. Token cap is non-negotiable.

### RP-4. Execution Isolation

**Rule**: Each agent operates with minimal IAM. Researcher
role is read-only. No agent may escalate privileges. Agent
pool limited to 6 concurrent agents.

**Guard**: Prevents credential abuse and lateral movement.
Cross-instance memory isolation mandatory.

### RP-5. Declarative Agents

**Rule**: Agent behavior defined by agent.md + skill.yaml.
No hardcoded agent logic. Zod schema validation on load;
invalid skills disable gracefully (no crash).

**Guard**: Enables hot-reload and configuration-driven
behavior without redeployment.

### RP-6. Idempotent Handlers

**Rule**: All webhook handlers MUST deduplicate by
update_id with 24-hour TTL. Duplicate Telegram updates
(retransmission) MUST NOT cause duplicate actions.

**Guard**: Telegram may retransmit webhooks on timeout.
Without dedup, duplicate actions violate P-II audit trail.

### RP-7. Fail-Open Reads / Fail-Closed Writes

**Rule**: Read operations degrade gracefully (return partial
data, notify quality loss). Write operations block on failure
(fail-closed with retry max 3, then surface error).

**Guard**: Maintains data integrity for writes while
preserving availability for reads. Circuit breaker: 3
failures / 60 seconds triggers provider fallback.

### RP-8. Token Budget Enforcement

**Rule**: Per-request token budgets: Single=4K, Terna=12K,
Committee=20K. Pre-flight estimation MUST occur before LLM
call. If estimate exceeds budget, downgrade delegation mode
(Committee→Terna→Single) and notify operator.

**Guard**: Cost control. H1 target: <$50/month operational.
Alert if >10% of requests are truncated.

---

## Definition of Ready (DoR)

A feature/story is ready for implementation when ALL of the
following are true:

1. **Specification exists**: spec.md with FR-xxx, SC-xxx,
   acceptance scenarios (Given/When/Then), and edge cases
2. **Plan exists**: plan.md with architecture, file paths,
   dependencies, and constitution check
3. **Acceptance criteria measurable**: Every SC-xxx has a
   numeric threshold or binary pass/fail condition
4. **Edge cases documented**: Relevant cases from the 16
   discovery edge cases (CB-01 through CB-16) identified
5. **Security checkpoint mapping**: CP1/CP2/CP3 impact
   assessed; if feature handles user input, CP1 test required
6. **Token budget impact**: Delegation mode and estimated
   token cost per request documented
7. **Risk registry check**: Applicable risks (R-xxx) from
   the risk register identified; mitigation referenced
8. **Feasibility constraints verified**: C1 (founder focus)
   and C2 (no H3 before H1) checked if scope-relevant
9. **Feature files exist**: .feature BDD scenarios generated
   and hash-locked via /iikit-04-testify
10. **Tasks generated**: tasks.md with dependency graph and
    TDD ordering via /iikit-05-tasks

---

## Definition of Done (DoD)

A feature is done when ALL of the following are verified:

### Code Quality
1. TypeScript strict mode; no `any` types in new code
2. Zod validation on all external inputs and document loads
3. Test coverage ≥80% global; 100% for routing and security
4. All .feature BDD scenarios pass green
5. No lint errors; no TypeScript compilation warnings

### Integration
6. Async patterns verified (RP-1): no sync LLM in webhook path
7. State machine constraints verified (RP-2): transitions ≤5
8. Idempotency verified (RP-6): update_id dedup in handlers
9. Context isolation verified: zero cross-project contamination

### Security
10. CP1 (Input Sanitization): regex + deny-list + 4096 char cap
    tested for feature's input paths
11. CP2 (Prompt Hardening): security instructions in prompt
    composition verified
12. CP3 (Output Scan): PII detection active (soft-pass until
    H2 hardening)
13. IAM: no privilege escalation possible from new code paths

### Performance
14. Webhook ACK <2 seconds (RP-1)
15. Context retrieval <3 seconds p95 (P-IV)
16. Firestore queries <200ms (H1 baseline)
17. Token budget compliance: no request exceeds mode budget (RP-8)

### Operational Readiness
18. Audit logging: all lifecycle events in audit_log with
    operator_id, action_type, timestamp
19. Monitoring: alerts configured for threshold breaches
20. CRON jobs: scheduled and verified in staging
21. Rollback: procedure documented; agent configs disable
    without code redeploy

### Documentation
22. Constitution mapping: affected principles declared
23. Evidence tags on all architectural claims in plan.md
24. Edge case handling documented in spec clarifications

---

## Quality Gates

### Gate G1: Specification Review
- spec.md complete with FR-xxx, SC-xxx, user stories
- Constitution alignment declared
- Edge cases from discovery CB-01–CB-16 assessed

### Gate G2: Plan Review
- plan.md with architecture, file paths, dependencies
- Technology decisions in research.md with evidence tags
- Data model validated against canonical model (A6)

### Gate G3: Test Readiness
- .feature files generated and hash-locked
- tasks.md with TDD ordering (red→green)
- DoR criteria met

### Gate G4: Implementation Review
- All tasks complete; DoD criteria met
- /iikit-06-analyze health score ≥90/100
- No CRITICAL or HIGH findings

### Gate G5: Release Gate (per Horizon)

**H1 Gate** (4 weeks):
- G-05 (HIL) and G-06 (Project State) production-ready
- 0 critical risks (R-04, R-10, R-13 mitigated)
- 80% test coverage (constitutional)
- HIL enforcing L2+ approvals with audit trail
- Context retrieval <3s verified
- Feasibility constraint C1 enforced (Nexus priority)

**H2 Gate** (8 weeks):
- All H1 gaps closed; H1 gate criteria maintained
- Google Workspace integrations with HIL
- CP3 hardened (no longer soft-pass)
- Memory semantic relevance >80% on test set

**H3 Gate** (16 weeks):
- Multi-tenant architecture validated
- Firestore performance at scale (R-01 mitigated)
- Cross-tenant isolation verified
- No H3 work starts before H1 gate complete (C2)

---

## Security Checkpoints

### CP1: Input Sanitization (HARD — enforced always)
- Regex pattern matching for injection attempts
- Deny-list for known attack patterns
- 4,096 character cap on all user inputs
- Suspicious inputs flagged `needs_review` in audit_log
- **No override**: CP1 blocks invalid input unconditionally

### CP2: Prompt Hardening (HARD — enforced always)
- Security instructions injected into all prompt compositions
- Agent delegation integrity checks
- System prompt immutability (no user-controlled system prompt)
- **No override**: CP2 hardens every LLM call

### CP3: Output Scanning (SOFT until H2)
- PII detection: email, phone, card numbers
- Auto-redaction of detected PII before Telegram response
- **Known limitation**: Currently soft-pass; mischaracterizes
  role in some edge cases. Hard enforcement deferred to H2.
- **H2 requirement**: Fix CP3 mischaracterization; convert to
  hard enforcement before Google Workspace integrations

---

## Best Practices

### Development
1. **TDD mandatory**: Write tests (red) → implement (green) →
   refactor. Never skip the red phase.
2. **Atomic commits**: One logical change per commit. Reference
   spec FR-xxx or task T-xxx in commit message.
3. **Assertion integrity**: .feature file hashes are immutable.
   Fix code to pass tests, never modify test assertions.
4. **Evidence-first claims**: No architectural statement without
   evidence tag. research.md is the evidence repository.

### Architecture
5. **4-plane extension**: New features extend P1-P4 planes.
   Never create a 5th plane or bypass the pipeline.
6. **Firestore-only persistence (H1)**: No Redis, no PostgreSQL,
   no secondary stores until H3 evaluation gate.
7. **Managed services**: Cloud Scheduler for CRON, Pub/Sub for
   async, Secret Manager for keys. No self-managed infra.
8. **2-state simplicity**: ACTIVE/ARCHIVED only for H1. No
   SUSPENDED, COMPLETED, or DELETED states without ADR.

### Operations
9. **Circuit breaker cascade**: Groq → OpenRouter → Gemini.
   3 failures / 60s triggers fallback. Log all transitions.
10. **Context hygiene**: CRON daily compression. Alert at 800
    tokens. Force compress at 900. Never exceed 500 in prompt.
11. **Cost tracking**: Per-request token usage logged. Monthly
    budget dashboard. Escalate if approaching $50/month H1 cap.

---

## Risk Guard Rails

Constitutional protections against the top discovery risks:

| Risk | Score | Guard Rail | Enforcement |
|------|-------|-----------|-------------|
| R-04: L0-L4 not implemented | 9 | HIL mandatory for L2+; no release without full enforcement | Gate G5 H1: blocks release |
| R-10: Webhook timeout cascade | 9 | RP-1 async-first; ACK <2s; Pub/Sub mandatory | Monitoring alert; SLA in CI |
| R-13: Context bloat | 9 | RP-3 500-token cap; CRON daily; alert at 800 | Automated compression; metric dashboard |
| R-01: Firestore bottleneck (H3) | 6 | Deferred to H3 spike; H1 single-tenant only | Gate G5 H3: evaluate before start |
| R-08: CRON information loss | 6 | compression_log mandatory; dropped_topics tracked | Audit trail; recovery possible |
| R-11: Prompt injection | 6 | CP1 hard + CP2 hard + CP3 soft (fix H2) | Security gate; penetration test H2 |
| R-14: Overengineering multi-tenant | 6 | C2: no H3 before H1 gate | Sprint planning constraint |

---

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

---

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

**Version**: 1.1.0 | **Ratified**: 2026-04-03 | **Last Amended**: 2026-04-03
