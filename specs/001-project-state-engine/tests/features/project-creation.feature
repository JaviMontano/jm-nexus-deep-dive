# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-001
Feature: Create and Activate a Project
  As the operator, I want to create a named project via Telegram
  so that all subsequent interactions are associated with a persistent
  context and I never have to re-explain my project from scratch.

  Rule: Project creation initializes a complete project document

    @TS-001 @FR-001 @FR-002 @SC-001 @P1 @acceptance
    Scenario: Create project with no active project
      Given an authenticated operator with no active project
      When the operator sends "create project Acme Proposal"
      Then a project is created with name "Acme Proposal"
      And the project status is "ACTIVE"
      And the project compressed_context is empty
      And the project knowledge_anchors is an empty array
      And the project open_tasks is an empty array
      And the project artifacts is an empty array
      And the project compression_log is an empty array
      And the project auto_archive_after_days is 30
      And the project has a server-generated created_at timestamp
      And the project has a server-generated last_interaction timestamp
      And the project _version is 1
      And the project becomes the operator's active_context_id

    @TS-002 @FR-001 @FR-002 @P1 @acceptance
    Scenario: Create project when another project is already active
      Given an authenticated operator with an existing active project "Old Project"
      When the operator creates a new project "New Project"
      Then the project "New Project" is created with status "ACTIVE"
      And "New Project" becomes the operator's active_context_id
      And the project "Old Project" remains accessible with status "ACTIVE"

    @TS-003 @SC-001 @P1 @acceptance
    Scenario: Project creation completes within performance SLA
      Given an authenticated operator
      When the operator sends "create project Performance Test"
      Then the response is received within 3 seconds p95 processing time
      And the operator receives confirmation with the project name "Performance Test"

  Rule: Project names must be validated before creation

    @TS-013 @FR-011 @P1 @validation
    Scenario: Reject empty project name
      Given an authenticated operator
      When the operator sends "create project" with an empty name
      Then the system rejects the request with a validation error
      And no project is created

    @TS-014 @FR-011 @P1 @validation
    Scenario: Reject project name exceeding 100 characters
      Given an authenticated operator
      When the operator creates a project with a name of 101 characters
      Then the system rejects the request with a validation error
      And no project is created

    @TS-015 @FR-011 @P1 @validation
    Scenario: Reject whitespace-only project name
      Given an authenticated operator
      When the operator sends "create project" with name "   "
      Then the system rejects the request with a validation error
      And no project is created

  Rule: Duplicate project names require operator confirmation

    @TS-016 @FR-012 @P2 @acceptance
    Scenario: Duplicate project name presents existing match
      Given an authenticated operator with an existing project named "Acme Proposal"
      When the operator sends "create project Acme Proposal"
      Then the system presents the existing project "Acme Proposal"
      And asks the operator to confirm new creation or switch to existing

  Rule: Concurrent writes are handled safely

    @TS-017 @FR-001 @P2 @acceptance
    Scenario: Concurrent project creation uses atomic transactions
      Given an authenticated operator
      When two simultaneous project creation requests are received
      Then Firestore transactions ensure at most one succeeds
      And the operator receives a clear result for each request
