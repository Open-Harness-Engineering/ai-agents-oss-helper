# Fix SonarCloud Issues

Fix SonarCloud issues in the current project's codebase.

## Usage

```
/oss-fix-sonarcloud <rule> [options]
```

**Arguments:**
- `<rule>` - SonarCloud rule ID (e.g., `S3776`, `S6126`, `java:S1192`)

**Options (optional, space-separated after rule):**
- `branch=<name>` - Custom branch name (default from the project's `project-guidelines.md`)
- `module=<path>` - Limit to specific module (e.g., `components/camel-jms`)
- `limit=<n>` - Max issues to process (default: all)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

Check the **SonarCloud component key** field in the project's `project-info.md`. If the project has no SonarCloud component key configured (shows `_(none)_`), stop and tell the user: "SonarCloud is not configured for this project."

### 2. Gather Context

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

### 3. Apply Fixes

For each issue:

1. **Read the affected file** at the reported line(s)
2. **Understand the violation** from the issue `message` and rule description
3. **Apply the fix** following the compliant pattern from the rule
4. **Preserve behavior** - fixes must be semantically equivalent

Read the project's `project-standards.md` for project-specific code style restrictions.

### 4. Constraints

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

### 5. Workflow

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

3. **Push**: After all modules processed
   ```bash
   git push -u origin <branch-name>
   ```

### 6. General Guidelines

- Tests MUST pass before committing
- Do NOT reformat files manually - use the format command from the project's `project-standards.md`
- Include auto-formatting changes in commit
- GPG signing not required
- For camel-core: do NOT parallelize Maven jobs; always run `mvn` in the module directory
- One commit per module

### 7. Acceptance Criteria

- Every affected module MUST pass integration tests
- Fixes must address the specific SonarCloud rule violation
- No regressions in functionality
