# Quick Fix

Apply a quick fix to the current project's codebase without requiring a tracked issue. Intended for small changes such as CI fixes, documentation fixes, dependency upgrades, and other minor improvements.

## Usage

```
/oss-quick-fix <description>
```

**Arguments:**
- `<description>` - A brief description of the quick fix to apply

**Examples:**
```
/oss-quick-fix upgrade dependency version in pom.xml
/oss-quick-fix fix broken link in README
/oss-quick-fix update GitHub Actions workflow to latest version
```

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

Extract the description from the argument. This describes the quick fix to apply.

### 3. Validate Scope

Before proceeding, verify the change qualifies as a quick fix. Acceptable changes include:

- **CI/CD fixes** - GitHub Actions workflows, build scripts
- **Documentation fixes** - Typos, broken links, outdated instructions
- **Dependency upgrades** - Version bumps in `pom.xml` or other build files
- **Minor code fixes** - Trivial corrections that don't alter behavior
- **Configuration changes** - Small updates to project configuration

If the change is too large or complex (e.g., new features, architectural changes, refactoring), stop and suggest the appropriate action from the project's `project-guidelines.md` (e.g., `/oss-create-issue` for GitHub projects, or creating a Jira issue for Jira projects).

### 4. Locate Relevant Files

Based on the description:

1. Search for relevant files in the codebase
2. Understand what needs to change
3. Confirm the change is minimal and low-risk

### 5. Implement the Fix

Apply changes following these principles:

- **Minimal** - Change only what is strictly necessary
- **Safe** - Do not alter existing behavior or APIs
- **Clean** - Keep code readable and consistent with surrounding style
- **Tested** - If the change touches code (not docs/CI), verify tests still pass

Read the project's `project-standards.md` for project-specific build constraints (e.g., no Records/Lombok for camel-core, module-specific builds, etc.).

### 6. Workflow

Read branch naming and commit format from the project's `project-guidelines.md`.

1. **Branch**: Create from main with a descriptive name
   ```bash
   git checkout main && git pull && git checkout -b quick-fix/<short-slug>
   ```
   Use a short slug derived from the description (e.g., `quick-fix/upgrade-quarkus-bom`, `quick-fix/fix-readme-typo`).

2. **Implement**: Make the necessary changes

3. **Format & Build**: Run the build commands from the project's `project-standards.md`
   - For projects with module-specific builds (camel-core): run formatting in the module directory first, then test
   - For documentation-only changes, the build step may be skipped if no code was modified
   - For projects with no build tool (ai-agents-oss-helper): skip build

4. **Commit**: Use the quick-fix commit format from the project's `project-guidelines.md`

   **Before committing**, ask the user whether they want to sign the commit using `-S` (GPG/SSH signature) and `-s` (Signed-off-by). Then run the appropriate command:
   - If the user wants both: `git commit -S -s -m "chore: <brief description>"`
   - If the user wants only `-S`: `git commit -S -m "chore: <brief description>"`
   - If the user wants only `-s`: `git commit -s -m "chore: <brief description>"`
   - If the user wants neither: `git commit -m "chore: <brief description>"`

5. **Push**: Push the branch to origin
   ```bash
   git push -u origin quick-fix/<short-slug>
   ```

6. **Pull Request**: Create a pull request
   ```bash
   gh pr create --title "chore: <brief description>" --body "<short explanation of what was changed and why>"
   ```

### 7. Constraints

You MUST:
- Work on a dedicated branch (never commit to `main`)
- Create a pull request after pushing
- Keep changes small and focused
- Include formatting changes from the build in your commit
- For camel-core: always run `mvn` in the module directory; do NOT parallelize Maven jobs

You MUST NOT:
- Make large or behavioral changes without an issue
- Refactor unrelated code
- Skip the build for code changes
- Combine multiple unrelated fixes in a single quick fix
- Push directly to `main`
- For camel-core: change public method signatures

### 8. Acceptance Criteria

- All tests pass for code changes (using the test command from the project's `project-standards.md`)
- Changes are minimal and match the described fix
- A pull request has been created with a clear title and description
- Work is done on a branch, not on `main`
