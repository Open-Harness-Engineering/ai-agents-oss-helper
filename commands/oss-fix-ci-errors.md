# Fix CI Errors

Download CI build reports, identify errors, and fix them properly.

## Usage

```
/oss-fix-ci-errors [run-id]
```

**Arguments:**
- `[run-id]` - GitHub Actions run ID (optional). If omitted, auto-detects the latest failed run on the default branch.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

- If a run ID is provided, use it directly.
- If omitted, find the latest failed runs:

```bash
gh run list --repo <REPO> --status failure --branch main --limit 5 --json databaseId,name,conclusion,headBranch,event,createdAt
```

Present the failed runs to the user and ask which to investigate, or use the most recent one.

### 3. Download CI Logs

Fetch the failed job logs:

```bash
gh run view <RUN_ID> --repo <REPO> --log-failed
```

If the log output is too large, first identify the failed jobs:

```bash
gh run view <RUN_ID> --repo <REPO> --json jobs
```

Then download logs for specific failed jobs individually.

### 4. Analyze Errors

Parse the logs to identify error categories:

- **Compilation errors** - Missing imports, type mismatches, syntax errors
- **Test failures** - Assertion failures, unexpected exceptions, timeouts
- **Lint/style violations** - Checkstyle, spotless, formatting errors
- **Dependency resolution failures** - Missing or conflicting dependencies
- **Configuration errors** - Invalid build configuration, missing properties

Group errors by type and affected files.

### 5. Triage Errors

Classify each error into one of two categories:

**A. Directly fixable** - Clear root cause, straightforward fix:
- Compilation errors with obvious cause
- Simple test fixes (e.g., updated API, renamed method)
- Dependency version issues
- Style/formatting violations

**B. Needs investigation** - Root cause unclear or fix is non-trivial:
- Intermittent test failures
- Complex logic bugs
- Design-level issues
- Problems requiring upstream changes

For category B errors: create a GitHub issue (using the same approach as `/oss-create-issue`) describing the error, its context, and the CI run link.

Present the triage summary to the user for confirmation before proceeding with any fixes.

### 6. Implement Fixes

For category A errors:

1. Fix the root cause of each error
2. Follow the project's `project-standards.md` for code style and build constraints
3. For category B errors that can be partially addressed without shallow workarounds, fix what is genuinely possible

### 7. Constraints

You MUST:
- Fix root causes, not symptoms
- Create tickets for problems too large to fix inline
- Reference created tickets in the PR description
- Verify fixes locally with build/test commands from the project's `project-standards.md`
- Present the full analysis to the user before making any changes

You MUST NOT:
- Disable, skip, or delete failing tests (`@Ignore`, `@Disabled`, `skipTests`, `-DskipTests`, etc.)
- Weaken assertions (e.g., removing asserts, loosening expected values, widening tolerances)
- Suppress warnings or errors without addressing the root cause
- Add `@SuppressWarnings` without genuine justification
- Catch and swallow exceptions to hide failures
- Reduce test coverage
- Apply any workaround whose sole purpose is making CI green
- Mark tests as flaky without proper investigation
- Comment out failing code

### 8. Workflow

Read branch naming and commit format from the project's `project-guidelines.md`.

1. **Branch**: Create from main
   ```bash
   git checkout main && git pull && git checkout -b ci-fix/<short-slug>
   ```
   Use the CI-fix branch pattern from the project's `project-guidelines.md`.

2. **Implement**: Apply the fixes for category A errors

3. **Format & Build**: Run the build commands from the project's `project-standards.md`
   - For projects with module-specific builds: run in the affected module directory
   - For other projects: run from root

4. **Commit**: Use the CI-fix commit format from the project's `project-guidelines.md`

   **Before committing**, ask the user whether they want to sign the commit using `-S` (GPG/SSH signature) and `-s` (Signed-off-by). Then run the appropriate command:
   - If the user wants both: `git commit -S -s -m "ci: <brief description>"`
   - If the user wants only `-S`: `git commit -S -m "ci: <brief description>"`
   - If the user wants only `-s`: `git commit -s -m "ci: <brief description>"`
   - If the user wants neither: `git commit -m "ci: <brief description>"`

5. **Push**: Push branch to origin
   ```bash
   git push -u origin ci-fix/<short-slug>
   ```

6. **PR**: Create a pull request with a description listing:
   - Link to the failed CI run
   - Errors found and fixes applied
   - Tickets created for deferred issues (if any)

   ```bash
   gh pr create --title "ci: <brief description>" --body "$(cat <<'EOF'
   ## CI Fix

   **Failed run:** <link to CI run>

   ### Errors Fixed
   - <error 1>: <fix applied>
   - <error 2>: <fix applied>

   ### Deferred Issues
   - <ticket link>: <brief description> (if any)
   EOF
   )"
   ```

### 9. Acceptance Criteria

- Local build and tests pass (using commands from the project's `project-standards.md`)
- Fixes address genuine root causes
- No test suppression, coverage reduction, or assertion weakening
- PR links to the failed CI run
- Tickets created for any deferred problems
- User approved the triage before fixes were applied
