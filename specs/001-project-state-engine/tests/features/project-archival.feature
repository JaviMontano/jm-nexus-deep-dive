# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-003
Feature: Archive Inactive Projects
  As the system (CRON job), I want to automatically archive projects
  with no interaction for a configurable number of days (default 30)
  so that active context retrieval stays fast and the operator's
  project list remains manageable.

  Rule: CRON archival runs daily and archives inactive projects

    @TS-012 @FR-007 @SC-004 @P2 @acceptance
    Scenario: CRON archives project exceeding inactivity threshold
      Given a project "Stale Project" with last_interaction exceeding auto_archive_after_days of 30
      When the daily archival CRON job executes
      Then "Stale Project" status changes to "ARCHIVED"
      And "Stale Project" is excluded from default context retrieval

    @TS-018 @FR-007 @P2 @acceptance
    Scenario: CRON respects custom auto_archive_after_days per project
      Given a project "Custom Threshold" with auto_archive_after_days set to 7
      And last_interaction was 8 days ago
      When the daily archival CRON job executes
      Then "Custom Threshold" status changes to "ARCHIVED"

    @TS-019 @FR-007 @P2 @acceptance
    Scenario: CRON does not archive projects within threshold
      Given a project "Recent Project" with last_interaction 5 days ago
      And auto_archive_after_days is 30
      When the daily archival CRON job executes
      Then "Recent Project" remains with status "ACTIVE"

  Rule: Archival preserves all project data

    @TS-035 @FR-008 @SC-004 @P1 @acceptance
    Scenario: Archived project retains all data
      Given an active project "Data Rich" with compressed_context, knowledge_anchors, open_tasks, and artifacts
      When the project is archived
      Then status changes to "ARCHIVED"
      And compressed_context is preserved unchanged
      And knowledge_anchors are preserved unchanged
      And open_tasks are preserved unchanged
      And artifacts are preserved unchanged
      And no data is deleted

  Rule: Archived projects remain searchable

    @TS-020 @FR-009 @SC-005 @P2 @acceptance
    Scenario: Archived project appears in explicit search
      Given an archived project "Old Research"
      When the operator explicitly searches for "Old Research"
      Then "Old Research" appears in search results
      And the operator can reactivate it

  Rule: CRON failures are isolated per project

    @TS-021 @FR-007 @P2 @acceptance
    Scenario: CRON partial failure does not affect other projects
      Given three projects qualifying for archival
      And archival of the second project encounters a transient Firestore error
      When the daily archival CRON job executes
      Then the first project is successfully archived
      And the third project is successfully archived
      And the second project remains ACTIVE for retry in the next CRON cycle

  Rule: Archival clears active_context_id when applicable

    @TS-022 @FR-007 @FR-002 @P1 @acceptance
    Scenario: Archiving the active project clears active_context_id
      Given the operator's active project is "Sunset Project"
      When "Sunset Project" is archived by the CRON job
      Then the operator's active_context_id is set to null
