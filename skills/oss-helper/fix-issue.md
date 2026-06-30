### Agent Delegation

If you have access to agents specialized in **coding or implementation** (e.g., backend, frontend, or language-specific coding agents), you should delegate the implementation (step 6) to one or more of those agents. Provide them with the issue analysis, affected files, and project standards. If no specialized agents are available, perform all steps directly.

### 1. Parse Input

Extract the issue ID from the argument based on the project's issue tracker type (from the project's `project-info.md`):

**GitHub projects:**

- If full URL (e.g., `https://github.com/wanaku-ai/wanaku/issues/42`): extract the number from the path
- If number only: use as-is

**Jira projects:**

- If full URL (e.g., `https://issues.apache.org/jira/browse/CAMEL-20410`): extract the ID from the path
- If ID only (e.g., `CAMEL-20410`): use as-is

### 2. Retrieve Issue Details

**GitHub projects** - Fetch via GitHub CLI:

```bash
gh issue view <ISSUE_NUMBER> --repo <GITHUB_REPO> --json number,title,body,state,labels,assignees,milestone
```

**Jira projects** - Fetch via Jira REST API:

```bash
curl -s "https://issues.apache.org/jira/rest/api/2/issue/<ISSUE_ID>" | jq '{
  key: .key,
  summary: .fields.summary,
  description: .fields.description,
  status: .fields.status.name,
  priority: .fields.priority.name,
  type: .fields.issuetype.name,
  components: [.fields.components[].name],
  labels: .fields.labels,
  fixVersions: [.fields.fixVersions[].name],
  created: .fields.created,
  updated: .fields.updated
}'
```

**Rate Limiting:** For Jira, make ONE request only. Do NOT poll or make repeated requests.

### 3. Analyze the Issue

From the retrieved information:

1. **Understand the problem** - Read the title/summary and body/description carefully
2. **Check labels/components** - May indicate type (bug, enhancement, etc.) or affected areas
3. **Review comments** - May contain additional context or discussion
4. **Check for linked PRs** - Avoid duplicating work

### 4. Locate Relevant Code

Based on the issue description:

1. Search for relevant files in the codebase
2. Understand the existing implementation
3. Identify the root cause or area to modify

### 5. Investigate Git History

Before changing anything, understand **why** the code is written the way it is:

```bash
# Recent changes to affected files
git log --oneline -20 -- <affected-files>

# Authorship and intent of key areas
git blame -L <start>,<end> -- <file>
```

- Read commit messages and any linked issue references for prior changes.
- Check if a recent commit might have introduced the bug.
- If the proposed fix would effectively revert a prior intentional commit, flag this to the user before proceeding.
- Search for related issues in the project tracker (same component, similar keywords) to find prior discussions or rejected approaches.

### 6. Implement the Fix

Apply changes following these principles:

- **Clean code** - Write clear, readable, self-documenting code
- **Concise** - Avoid over-engineering, keep it simple
- **Maintainable** - Future developers should understand your changes easily
- **Tested** - All changes must have appropriate test coverage
- **Minimal** - Fix only what's needed for this issue

Read the project's `project-standards.md` for project-specific build constraints (e.g., no Records/Lombok for camel-core, module-specific builds, etc.).

### 7. Constraints

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
- For Jira projects: modify the Jira issue or make multiple API requests
- For camel-core: change public method signatures without justification

### 8. Workflow

Read branch naming and commit format from the project's `project-guidelines.md`.

1. **Branch**: Create from main

   ```bash
   git checkout main && git pull && git checkout -b <BRANCH_NAME>
   ```

   Use the branch naming pattern from the project's `project-guidelines.md` (e.g., `fix/<ISSUE_ID>`).

2. **Implement**: Make necessary code changes

3. **Build/Test/Format**: Follow the build workflow from `_fragments/_build-workflow.md`
   - Read build configuration from `project-standards.md`
   - Run format and test commands (module-specific or root, as appropriate)
   - Run full reactor build (Maven projects only, MANDATORY before commit)
   - Check for regenerated artifacts and include them in commit

5. **Commit**: Use the commit format from the project's `project-guidelines.md`
   - GitHub projects: `Fix #<ISSUE_NUMBER>: <brief description>`
   - Jira projects: `<ISSUE_ID>: <brief description of fix>`

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

### 9. General Guidelines

- Tests MUST pass before committing
- Build auto-formats code - include these changes in commit
- Do NOT manually format files
- Branch must be created from `main`
- Keep commits focused and atomic
- For camel-core: do NOT parallelize Maven jobs; always run `mvn` in the module directory
- GPG signing not required

### 10. Acceptance Criteria

- All tests MUST pass
- Fix must address the issue described in the tracker
- No regressions in functionality
- Tests added for the fix where applicable
- Code is clean, concise, and maintainable
