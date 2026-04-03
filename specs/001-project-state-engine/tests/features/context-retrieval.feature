# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-002
Feature: Retrieve Project Context
  As the operator, I want to resume a conversation about a previous
  project and have the bot recall its full context so that I do not
  lose ~60 hours/year repeating context to prompts.

  Background:
    Given an authenticated operator

  Rule: Context retrieval loads compressed context and short-term memory

    @TS-004 @FR-003 @FR-004 @SC-002 @P1 @acceptance
    Scenario: Retrieve context for project with prior interactions
      Given an existing project "Acme Proposal" with compressed_context and prior interactions
      When the operator mentions "Acme Proposal"
      Then the system loads compressed_context of 500 tokens or fewer
      And the system loads short_term_memory of the last 15 turns filtered by project_id
      And the context is assembled within 3 seconds p95 processing time

    @TS-005 @FR-003 @P1 @acceptance
    Scenario: Explicit command retrieves project deterministically
      Given an existing project "Acme Proposal"
      When the operator sends "/project Acme Proposal"
      Then the system switches to "Acme Proposal" without confirmation
      And "Acme Proposal" becomes the operator's active_context_id

    @TS-006 @FR-003 @P1 @acceptance
    Scenario: Implicit mention requires operator confirmation before switching
      Given an existing project "Acme Proposal"
      And the operator's active project is "Other Project"
      When the intent router detects "Acme Proposal" in the operator's message
      Then the system presents "Acme Proposal" as a suggestion
      And waits for operator confirmation before switching active_context_id

  Rule: Ambiguous project names must be disambiguated

    @TS-007 @FR-005 @SC-007 @P1 @acceptance
    Scenario: Partial match triggers disambiguation
      Given existing projects "Acme Proposal" and "Acme Research"
      When the operator references "Acme"
      Then the system lists all matching projects
      And asks the operator to disambiguate
      And never auto-selects a project

    @TS-008 @FR-005 @SC-007 @P1 @acceptance
    Scenario: Ambiguous abbreviation always disambiguates
      Given existing projects "Alpha" and "Alpha v2"
      When the operator references "Alpha"
      Then the system lists both projects
      And asks the operator to choose
      And never auto-selects

  Rule: Missing context degrades gracefully

    @TS-009 @FR-004 @P1 @acceptance
    Scenario: New project with empty compressed_context degrades gracefully
      Given a project "Fresh Start" with empty compressed_context and zero prior turns
      When context is retrieved for "Fresh Start"
      Then the system returns available short_term_memory only
      And no error is raised
      And the operator can begin working immediately

  Rule: Archived projects can be retrieved and reactivated

    @TS-010 @FR-009 @SC-005 @P1 @acceptance
    Scenario: Reactivate archived project via explicit reference
      Given a project "Old Project" with status "ARCHIVED" inactive for 30+ days
      When the operator explicitly references "Old Project"
      Then the system retrieves and reactivates "Old Project" to status "ACTIVE"
      And "Old Project" becomes the operator's active_context_id
      And the reactivation completes within 3 seconds p95 processing time

  Rule: Pagination handles large project lists

    @TS-011 @FR-005 @P2 @acceptance
    Scenario: Operator with 100+ projects gets paginated results
      Given an operator with 150 projects
      When the operator searches for projects
      Then results are paginated with most-recent-first ordering
      And the operator can navigate through pages
