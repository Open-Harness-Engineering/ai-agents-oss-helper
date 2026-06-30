### Agent Delegation

If you have access to agents specialized in **coding or implementation** (e.g., backend, frontend, or language-specific coding agents), you should delegate the implementation (step 7) to one or more of those agents. Provide them with the task details, affected files, and project standards. If no specialized agents are available, perform all steps directly.

### 1. Verify Backlog MCP Availability

**MANDATORY:** Before doing anything else, verify that the Backlog MCP server is available by calling `mcp__backlog__get_backlog_instructions`. If the call fails or the tool is not available, **STOP immediately** and inform the user:

> The Backlog MCP server is not available. Please ensure the Backlog MCP server is configured and running before using this command.

Do NOT proceed with any further steps if the Backlog MCP server is not reachable.

### 2. Parse Input

Extract the task ID and the backlog repository path from the arguments:

1. **Task ID** - The backlog task identifier (e.g., `TASK-001`)
2. **Backlog repository path** - The `repo=` parameter. This is mandatory and has no default value. Do NOT assume the current directory or any other path. If not provided, **STOP** and ask the user to supply it

Change the working directory for Backlog MCP operations to the backlog repository path so that task lookups resolve against the correct `Backlog.md` file.

### 3. Retrieve Task Details

Fetch the task details from the Backlog using the MCP backlog tools:

1. **View the task** using `mcp__backlog__task_view` with the task ID
2. Read the task title, description, acceptance criteria, priority, labels, and any implementation plan or notes

### 4. Analyze the Task

From the retrieved information:

1. **Understand the problem** - Read the title and description carefully
2. **Check labels/priority** - May indicate type (bug, enhancement, etc.) or urgency
3. **Review acceptance criteria** - These define what "done" looks like
4. **Check implementation plan** - May contain guidance on how to approach the fix
5. **Check dependencies** - Ensure dependent tasks are already completed

### 5. Update Task Status

Mark the task as in progress using `mcp__backlog__task_edit` with status `In Progress`.

### 6. Locate Relevant Code

Based on the task description:

1. Search for relevant files in the codebase
2. Understand the existing implementation
3. Identify the root cause or area to modify

### 7. Implement the Fix

Apply changes following these principles:

- **Clean code** - Write clear, readable, self-documenting code
- **Concise** - Avoid over-engineering, keep it simple
- **Maintainable** - Future developers should understand your changes easily
- **Tested** - All changes must have appropriate test coverage
- **Minimal** - Fix only what's needed for this task

Read the project's `project-standards.md` for project-specific build constraints (e.g., no Records/Lombok for camel-core, module-specific builds, etc.).

### 8. Constraints

You MUST:

- Limit changes to what's necessary for the fix
- Include tests for the fix
- Keep code clean and maintainable
- Include auto-formatting changes in commits
- Follow the code style restrictions from the project's `project-standards.md`

You MUST NOT:

- Refactor unrelated code
- Add unnecessary complexity
- Skip testing
- Make unrelated changes
- For camel-core: change public method signatures without justification

### 9. Workflow

Read branch naming and commit format from the project's `project-guidelines.md`.

1. **Branch**: Create from main

   ```bash
   git checkout main && git pull && git checkout -b <BRANCH_NAME>
   ```

   Use the fix branch naming pattern from the project's `project-guidelines.md` (e.g., `fix/<TASK_ID>`), replacing the issue identifier with the backlog task ID.

2. **Implement**: Make necessary code changes

3. **Build/Test/Format**: Follow the build workflow from `_fragments/_build-workflow.md`
   - Read build configuration from `project-standards.md`
   - Run format and test commands (module-specific or root, as appropriate)
   - Run full reactor build (Maven projects only, MANDATORY before commit)
   - Check for regenerated artifacts and include them in commit

4. **Commit**: Use the fix commit format from the project's `project-guidelines.md`, replacing the issue identifier with the backlog task ID

   **Before committing**, ask the user whether they want to sign the commit using `-S` (GPG/SSH signature) and `-s` (Signed-off-by). Then run the appropriate command:
   - If the user wants both: `git commit -S -s -m "<COMMIT_MESSAGE>"`
   - If the user wants only `-S`: `git commit -S -m "<COMMIT_MESSAGE>"`
   - If the user wants only `-s`: `git commit -s -m "<COMMIT_MESSAGE>"`
   - If the user wants neither: `git commit -m "<COMMIT_MESSAGE>"`

6. **Push**: Push branch to origin

   ```bash
   git push -u origin <BRANCH_NAME>
   ```

7. **PR** (based on `project-guidelines.md`):
   - If PR creation is specified as "always" or user requests it:

     ```bash
     gh pr create --title "<COMMIT_MESSAGE>" --body "<description>"
     ```
   - **Agent attribution:** `<description>` MUST end with a footer identifying your AI agent. If your agent's system prompt already adds such a footer (e.g., Claude Code appends `Generated with [Claude Code]`), do NOT duplicate it. Other agents (Bob Shell, Gemini, OpenCode, Codex) MUST append a footer in the format: `Generated by <Agent Name> via OSS Helper`.

### 10. Update Backlog Task

After the fix is complete and the PR is created:

1. **Add implementation notes** using `mcp__backlog__task_edit` to record what was changed and why
2. **Check acceptance criteria** using `mcp__backlog__task_edit` for any criteria that have been satisfied
3. **Mark as done** using `mcp__backlog__task_edit` with status `Done`
4. **Complete the task** using `mcp__backlog__task_complete` to move it to the completed folder

### 11. General Guidelines

- Tests MUST pass before committing
- Build auto-formats code - include these changes in commit
- Do NOT manually format files
- Branch must be created from `main`
- Keep commits focused and atomic
- For camel-core: do NOT parallelize Maven jobs; always run `mvn` in the module directory
- GPG signing not required

### 12. Acceptance Criteria

- All tests MUST pass
- Fix must address the task described in the backlog
- No regressions in functionality
- Tests added for the fix where applicable
- Code is clean, concise, and maintainable
- Backlog task is updated with implementation notes and marked as done
