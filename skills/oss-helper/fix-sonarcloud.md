### Agent Delegation

If you have access to agents specialized in **coding or implementation** (e.g., backend, frontend, or language-specific coding agents), you should delegate the fix application (step 2) to one or more of those agents. Provide them with the SonarCloud rule details, affected files, and project standards. If no specialized agents are available, perform all steps directly.

### 1. Gather Context

#### A. Fetch Open Issues

Retrieve issues from SonarCloud API using the component key from the project's `project-info.md`:

```bash
curl "https://sonarcloud.io/api/issues/search?componentKeys=<COMPONENT_KEY>&rules=java%3A<rule>&issueStatuses=OPEN%2CCONFIRMED&ps=100"
```

The response `issues` array contains:

- `component` - Full file path
- `line` / `textRange` - Affected location
- `message` - Description of what's wrong
- `effort` - Estimated fix effort
- `type` - BUG, VULNERABILITY, CODE_SMELL

#### B. Fetch Rule Details

Get the rule description and remediation guidance:

```bash
curl "https://sonarcloud.io/api/rules/show?key=java:<rule>"
```

The response contains:

- `rule.name` - Human-readable rule name
- `rule.htmlDesc` - Full description with examples
- `rule.type` - Issue category

**Use the rule description to understand the expected fix pattern.** The `htmlDesc` typically includes "Noncompliant" and "Compliant" code examples.

### 2. Apply Fixes

For each issue:

1. **Read the affected file** at the reported line(s)
2. **Understand the violation** from the issue `message` and rule description
3. **Apply the fix** following the compliant pattern from the rule
4. **Preserve behavior** - fixes must be semantically equivalent

Read the project's `project-standards.md` for project-specific code style restrictions.

### 3. Constraints

When fixing issues, you MUST:

- **Limit changes to reported issues** - Do not refactor unrelated code
- **Maintain backwards compatibility** - Do not change public API signatures
- **Preserve existing behavior** - Fixes must be functionally equivalent
- **Respect code style** - Match surrounding code conventions
- Follow the code style restrictions from the project's `project-standards.md`

You MUST NOT:

- Use Records or Lombok (unless already present)
- Add new dependencies
- Modify code outside the flagged lines unless necessary for the fix
- Change method visibility or signatures of public/protected members

### 4. Workflow

Read branch naming from the project's `project-guidelines.md`.

1. **Branch**: Create from main

   ```bash
   git checkout main && git checkout -b <branch-name>
   ```

   Use the SonarCloud branch pattern from the project's `project-guidelines.md` (e.g., `ci-camel-4-sonarcloud-<rule>`), or the custom `branch=<name>` if provided.

2. **For each affected module**:
   - Apply fixes to all issues in that module
   - Run formatting using the format command from the project's `project-standards.md`
   - Run tests using the test command from the project's `project-standards.md`
   - **If tests pass**: Commit with the sonarcloud commit format from the project's `project-guidelines.md`
   - **If tests fail**: Skip commit, continue to next module

3. **Final Sanity Build (MANDATORY before push)** (Maven projects only): After all per-module commits are in place and before pushing, run a full-reactor build from the **repository root**.

   **Before running, ask the user** which build to run (use `AskUserQuestion`):
   - **(a) Skip tests** (faster, step 2 already ran tests per module): `mvn clean install -DskipTests`
   - **(b) Run full tests** (slower, catches cross-module integration regressions): `mvn clean install`

   Do NOT pick a default silently — wait for the user's choice. Both options run the **full reactor build** — do NOT add `-pl` or `-am` flags. A scoped build only covers the changed module and its upstream dependencies, leaving downstream generators (project-wide catalogs, DSL builder factories, metadata mirrors) stale. CI runs the full reactor build and then fails on any uncommitted regen artifacts, so the local check must match.

   This catches cross-module breakage that per-module builds in step 2 would miss (e.g., a SonarCloud fix in module A breaks a caller in module B). Run this once, not per module. Skip entirely for non-Maven projects. If the build fails, investigate and fix with an additional per-module commit before pushing — do NOT push on a failing root build.

4. **Push**: After all modules processed and the sanity build passes

   ```bash
   git push -u origin <branch-name>
   ```

5. **Agent attribution (if you open the PR)**: This command does not create a PR — the user typically opens it separately. If you (the agent) are asked to open a PR for this branch afterwards, the PR body MUST end with a footer identifying your AI agent. If your agent's system prompt already adds such a footer (e.g., Claude Code appends `Generated with [Claude Code]`), do NOT duplicate it. Other agents (Bob Shell, Gemini, OpenCode, Codex) MUST append a footer in the format: `Generated by <Agent Name> via OSS Helper`.

### 5. General Guidelines

- Tests MUST pass before committing
- Do NOT reformat files manually - use the format command from the project's `project-standards.md`
- Include auto-formatting changes in commit
- GPG signing not required
- For camel-core: do NOT parallelize Maven jobs; always run `mvn` in the module directory
- One commit per module

### 6. Acceptance Criteria

- Every affected module MUST pass integration tests
- Fixes must address the specific SonarCloud rule violation
- No regressions in functionality
