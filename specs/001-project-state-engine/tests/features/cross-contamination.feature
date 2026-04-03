# DO NOT MODIFY SCENARIOS
# These .feature files define expected behavior derived from requirements.
# During implementation:
#   - Write step definitions to match these scenarios
#   - Fix code to pass tests, don't modify .feature files
#   - If requirements change, re-run /iikit-04-testify

@US-004
Feature: Zero Cross-Project Contamination
  As the operator working across multiple projects, I want absolute
  guarantee that context from Project A never leaks into Project B
  so that proposals, research, and decisions are never contaminated
  with wrong-project data.

  Rule: Context switch loads only the target project's data

    @TS-023 @FR-006 @SC-003 @P1 @acceptance
    Scenario: Switching projects loads only target context
      Given two active projects "Project Alpha" with context "Alpha decisions" and "Project Beta" with context "Beta research"
      When the operator switches from "Project Alpha" to "Project Beta"
      Then only "Project Beta" compressed_context is loaded
      And only "Project Beta" short_term_memory turns are loaded
      And zero data from "Project Alpha" is present in the assembled context

    @TS-024 @FR-006 @SC-003 @P1 @acceptance
    Scenario: Orchestrator filters strictly by active_context_id
      Given a multi-project environment with projects "A", "B", and "C"
      And the operator's active_context_id points to project "B"
      When the orchestrator assembles context for a response
      Then all queries filter by active_context_id and owner_id
      And no data from projects "A" or "C" is included

    @TS-025 @FR-006 @SC-003 @P1 @acceptance
    Scenario: Zero contamination across 100 consecutive switches
      Given an operator with projects "P1" through "P10" each with distinct contexts
      When the operator switches between projects 100 times in sequence
      Then every context assembly contains only the active project's data
      And the audit log confirms zero cross-project references

  Rule: Short-term memory is strictly per-project

    @TS-026 @FR-004 @FR-006 @SC-003 @P1 @acceptance
    Scenario: Short-term memory filtered by project_id on switch
      Given project "Alpha" with 10 conversation turns
      And project "Beta" with 5 conversation turns
      When the operator switches from "Alpha" to "Beta"
      Then short_term_memory contains only "Beta" turns
      And zero turns from "Alpha" appear in the context

    @TS-027 @FR-004 @FR-006 @P1 @acceptance
    Scenario: New project has zero short-term memory from other projects
      Given project "Existing" with 15 conversation turns
      When the operator creates a new project "Brand New"
      Then short_term_memory for "Brand New" contains zero turns
      And no turns from "Existing" leak into "Brand New"

  Rule: Compressed context exceeding limit triggers re-compression

    @TS-028 @FR-004 @P2 @acceptance
    Scenario: Context exceeding 500 tokens triggers immediate re-compression
      Given a project with compressed_context at 520 tokens after retrieval
      When context-assembler loads the context for prompt assembly
      Then context-assembler triggers immediate re-compression before injection
      And the resulting compressed_context is 500 tokens or fewer
