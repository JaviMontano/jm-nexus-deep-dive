# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-001 @US-002 @US-003
Feature: Project Lifecycle Audit Logging
  All project lifecycle events must be logged to audit_log with
  operator_id, action type, and ISO timestamp per FR-010.

  Background:
    Given an authenticated operator with operator_id "op-123"

  Rule: Every lifecycle event produces an audit log entry

    @TS-029 @FR-010 @SC-006 @P1 @contract
    Scenario: Project creation is logged
      When the operator creates a project "Audit Test"
      Then an audit_log entry is created with action_type "project.create"
      And the entry contains operator_id "op-123"
      And the entry contains a server-generated ISO timestamp
      And the entry contains resource type "project" with the new project id
      And the entry status is "success"

    @TS-030 @FR-010 @SC-006 @P1 @contract
    Scenario: Project retrieval is logged
      Given an existing project "Tracked Project"
      When the operator retrieves "Tracked Project"
      Then an audit_log entry is created with action_type "project.retrieve"
      And the entry contains operator_id "op-123"
      And the entry contains a server-generated ISO timestamp

    @TS-031 @FR-010 @SC-006 @P1 @contract
    Scenario: Project archival is logged
      Given an active project "Archive Target"
      When "Archive Target" is archived
      Then an audit_log entry is created with action_type "project.archive"
      And the entry contains operator_id "op-123"
      And the entry contains a server-generated ISO timestamp
      And the entry resource shows before status "ACTIVE" and after status "ARCHIVED"

    @TS-032 @FR-010 @SC-006 @P1 @contract
    Scenario: Project reactivation is logged
      Given an archived project "Reactivate Target"
      When the operator reactivates "Reactivate Target"
      Then an audit_log entry is created with action_type "project.reactivate"
      And the entry contains operator_id "op-123"
      And the entry contains a server-generated ISO timestamp
      And the entry resource shows before status "ARCHIVED" and after status "ACTIVE"

  Rule: CRON-triggered events include trigger metadata

    @TS-033 @FR-010 @FR-007 @SC-006 @P2 @contract
    Scenario: CRON archival includes trigger metadata
      Given a project qualifying for CRON archival
      When the daily CRON job archives the project
      Then the audit_log entry metadata contains trigger "cron"

  Rule: Failed operations are also logged

    @TS-034 @FR-010 @P2 @contract
    Scenario: Failed project creation is logged with error reason
      Given an operator attempts to create a project with invalid name ""
      When the creation fails validation
      Then an audit_log entry is created with action_type "project.create"
      And the entry status is "failure"
      And the entry reason describes the validation error
