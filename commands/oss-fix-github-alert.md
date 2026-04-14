# Fix GitHub Security or Quality Alert

Assign and fix a GitHub security or quality alert (Code Scanning, Dependabot, or Secret Scanning) for the current project. Unlike `/oss-fix-issue`, this command works directly with the alerts in the repository's "Security" tab — it does **not** create a tracking issue.

## Usage

```
/oss-fix-github-alert <type> [options]
```

**Arguments:**
- `<type>` - Alert source: `code-scanning`, `dependabot`, or `secret-scanning`

**Options (space-separated after `<type>`):**
- `alert=<number>` - Specific alert number to work on. If omitted, the command lists open alerts and stops so the user can pick one.
- `severity=<level>` - Filter by severity (e.g., `critical`, `high`, `medium`, `low`, `error`, `warning`, `note`)
- `rule=<rule-id>` - Filter by rule ID (code-scanning only, e.g., `js/sql-injection`)
- `state=<state>` - Filter by alert state (default: `open`)
- `limit=<n>` - Max alerts to display when listing (default: 10)
- `assignee=<user>` - GitHub user to assign the alert to (default: current authenticated user)
- `branch=<name>` - Custom branch name (default: `ci-alert-<type>-<NUMBER>`)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

Read the **Issue tracker** field from the project's `project-info.md`. If the issue tracker is not `GitHub`, stop and tell the user: "GitHub security alerts are only available for GitHub-hosted projects."

Read the **GitHub repo** field — this is `<OWNER>/<REPO>` for the API calls below.

### 2. Parse Arguments

Validate `<type>` is one of: `code-scanning`, `dependabot`, `secret-scanning`. If missing or invalid, stop and tell the user the accepted values.

Parse the optional `key=value` arguments. Defaults:
- `state=open`
- `limit=10`
- `assignee` = the current GitHub user (`gh api user --jq .login`)

### 3. Determine the API Endpoint

Each alert type uses a different REST API endpoint. References:
- <https://docs.github.com/en/rest/code-scanning>
- <https://docs.github.com/en/rest/dependabot/alerts>
- <https://docs.github.com/en/rest/secret-scanning>

| Type             | List endpoint                                  | Update endpoint                                              |
|------------------|------------------------------------------------|--------------------------------------------------------------|
| code-scanning    | `repos/<OWNER>/<REPO>/code-scanning/alerts`    | `PATCH repos/<OWNER>/<REPO>/code-scanning/alerts/<NUMBER>`   |
| dependabot       | `repos/<OWNER>/<REPO>/dependabot/alerts`       | `PATCH repos/<OWNER>/<REPO>/dependabot/alerts/<NUMBER>`      |
| secret-scanning  | `repos/<OWNER>/<REPO>/secret-scanning/alerts`  | `PATCH repos/<OWNER>/<REPO>/secret-scanning/alerts/<NUMBER>` |

### 4. List Open Alerts (when `alert=` is not provided)

Fetch alerts from the list endpoint, applying filters:

```bash
gh api "repos/<OWNER>/<REPO>/<TYPE>/alerts?state=<state>&per_page=<limit>" --paginate
```

Apply additional client-side filtering for `severity=` and `rule=` (code-scanning only).

**Handle errors:**
- HTTP 404 → tell the user: "`<type>` alerts are not enabled for this project."
- HTTP 403 → tell the user: "Access denied. GitHub Advanced Security may be required, or your token lacks the `security_events` / `dependabot_alerts` scope."

Display the results as a concise table: number, severity, rule (or package), affected file, and short description. Then **stop** and instruct the user to re-run with `alert=<number>` to work on a specific one.

### 5. Fetch Alert Details

When `alert=<number>` is provided, fetch the alert:

```bash
gh api "repos/<OWNER>/<REPO>/<TYPE>/alerts/<NUMBER>"
```

Extract the relevant fields:
- **code-scanning:** `rule.id`, `rule.description`, `rule.help`, `most_recent_instance.location.path`, `most_recent_instance.location.start_line`, `html_url`
- **dependabot:** `security_advisory.summary`, `security_advisory.severity`, `security_advisory.cve_id`, `dependency.package.name`, `dependency.package.ecosystem`, `dependency.manifest_path`, `security_vulnerability.first_patched_version.identifier`, `html_url`
- **secret-scanning:** `secret_type_display_name`, `html_url`. Also fetch alert locations:
  ```bash
  gh api "repos/<OWNER>/<REPO>/secret-scanning/alerts/<NUMBER>/locations"
  ```

### 6. Assign the Alert

Attempt to assign the alert to the contributor (default: current user):

```bash
gh api --method PATCH "repos/<OWNER>/<REPO>/<TYPE>/alerts/<NUMBER>" \
  -f "assignees[]=<ASSIGNEE>"
```

GitHub's REST API support for the `assignees` field on security alerts is evolving and may require GitHub Advanced Security on private repositories. If the API rejects the field (HTTP 422 or "field not found"):

1. Inform the user that native API assignment is not supported on this repository tier or alert type.
2. Print the alert URL (`html_url`) so the user can assign it manually in the GitHub web UI.
3. **Continue with the fix workflow** — assignment is best-effort metadata, not a blocker.

### 7. Analyze the Alert

Investigate based on the alert type:

**code-scanning:**
- Read the `rule.help` and `rule.description` fields — they typically include "Recommendation" and example code.
- Read the affected file at the reported `start_line` to understand the violation in context.

**dependabot:**
- Identify the vulnerable package, manifest path, and the `first_patched_version`.
- Check whether Dependabot has already opened a PR for this alert:
  ```bash
  gh pr list --search "in:title <package>" --state open --author "app/dependabot"
  ```
  If a PR already exists, point the user to it and ask whether to continue manually or close.

**secret-scanning:**
- Identify the secret type and the file/commit where it appeared.
- **WARN the user explicitly:** Removing the secret from the source tree is NOT enough. The secret must be **rotated/revoked at the provider** (e.g., regenerate the API key, invalidate the token). Removing it from git history is also recommended but is a separate, non-trivial operation.
- **Ask the user to confirm they have rotated the secret** before proceeding with code changes.

### 8. Locate Relevant Code

Read the affected file(s) and the surrounding context. For `dependabot`, read the dependency manifest (`pom.xml`, `package.json`, `go.mod`, `Cargo.toml`, etc.) referenced by `dependency.manifest_path`.

### 9. Investigate Git History

Before changing anything, understand **why** the affected code is the way it is:

```bash
# Recent changes to affected files
git log --oneline -20 -- <affected-files>

# Authorship and intent of key areas
git blame -L <start>,<end> -- <file>
```

- Read commit messages and any linked issue references for prior changes.
- For secret-scanning, identify when the secret was first committed.
- If the proposed fix would effectively revert a prior intentional commit, flag this to the user before proceeding.

### 10. Implement the Fix

Apply the fix following these principles:

- **code-scanning:** Address the root cause as recommended in the rule help. Avoid inline suppression unless the alert is a confirmed false positive — in that case, prefer dismissing the alert via the API with a clear `dismissed_reason` (e.g., `false_positive`) rather than adding suppression comments.
- **dependabot:** Bump the affected dependency to `first_patched_version` (or later) in the manifest. Run the build to update lockfiles. If the patched version introduces breaking changes, document them in the PR description.
- **secret-scanning:** Remove the secret from the source code. If the value must remain referenced, replace it with an environment variable, secret reference, or configuration placeholder. Confirm with the user that the secret has been rotated at the provider.

Read the project's `project-standards.md` for any code style restrictions.

### 11. Build & Test

Run the build/test commands from the project's `project-standards.md`. Tests MUST pass before committing.

### 12. Constraints

You MUST:
- Process **one alert per invocation** — do not bulk-fix
- Limit changes to what is necessary for the alert
- Preserve existing behavior outside the fix
- Follow the code style restrictions from the project's `project-standards.md`
- For **secret-scanning**: warn about provider-side rotation explicitly and require user confirmation before committing
- For **dependabot**: prefer dependency upgrades over suppressions

You MUST NOT:
- Suppress code-scanning alerts inline unless the user has explicitly classified them as false positives
- Skip rotation guidance for secret-scanning alerts
- Modify code unrelated to the alert
- Open multiple PRs from a single invocation
- Use the `Fix #<number>` form in commit messages (it would auto-close an unrelated issue if a number collides — see step 13)

### 13. Workflow

Read branch naming and PR policy from the project's `project-guidelines.md`.

1. **Branch:** Create from main.
   ```bash
   git checkout main && git pull && git checkout -b <BRANCH_NAME>
   ```
   Default branch name: `ci-alert-<type>-<NUMBER>` (e.g., `ci-alert-code-scanning-42`), or use the custom `branch=<name>` if provided.

2. **Implement:** Apply the fix from step 10.

3. **Format & Build:** Run the build command from `project-standards.md`. Include any auto-formatting changes.

4. **Final Sanity Build** (Maven projects only): As the last step before committing, run a full-reactor compile check from the **repository root**:
   ```bash
   mvn clean install -DskipTests
   ```
   This catches cross-module breakage that a module-only build in step 3 would miss. Tests are skipped because step 3 already ran them. Skip this step entirely for non-Maven projects (Go via `make`, yarn, docs-only). If the build fails, fix the issue and re-run — do NOT commit on a failing root build.

5. **Commit:** Use the format:
   ```
   Fix <type> alert <NUMBER>: <brief description>
   ```
   **Important:** do **not** include `#` before `<NUMBER>` — that would create a GitHub issue cross-reference (and a `Fix #<N>` form would auto-close issue `#N`). Examples:
   - `Fix code-scanning alert 42: escape user input in SQL query`
   - `Fix dependabot alert 18: bump jackson-databind to 2.15.4`
   - `Fix secret-scanning alert 7: remove leaked AWS access key`

   **Before committing**, ask the user whether they want to sign the commit using `-S` (GPG/SSH signature) and `-s` (Signed-off-by). Then run the appropriate command:
   - Both: `git commit -S -s -m "<COMMIT_MESSAGE>"`
   - `-S` only: `git commit -S -m "<COMMIT_MESSAGE>"`
   - `-s` only: `git commit -s -m "<COMMIT_MESSAGE>"`
   - Neither: `git commit -m "<COMMIT_MESSAGE>"`

6. **Push:**
   ```bash
   git push -u origin <BRANCH_NAME>
   ```

7. **PR:** If PR creation is `always` in `project-guidelines.md`, create the PR:
   ```bash
   gh pr create --title "<COMMIT_MESSAGE>" --body "<description>"
   ```
   Include the alert `html_url` in the PR body so reviewers can cross-reference. Do **not** include `Fixes #<number>` style references — security alerts are not GitHub issues.

### 14. Post-Merge: Update Alert State

After the PR is merged:

- **code-scanning** alerts close automatically when the next CodeQL (or third-party) scan confirms the fix.
- **dependabot** alerts close automatically when the upgraded dependency is detected.
- **secret-scanning** alerts can be marked as resolved via the API after rotation:
  ```bash
  gh api --method PATCH "repos/<OWNER>/<REPO>/secret-scanning/alerts/<NUMBER>" \
    -f state=resolved -f resolution=revoked \
    -f resolution_comment="Secret rotated at provider and removed from source"
  ```

### 15. General Guidelines

- Tests MUST pass before committing
- Branch must be created from `main`
- Keep commits focused and atomic — one alert per commit
- For camel-core: do NOT parallelize Maven jobs; always run `mvn` in the module directory
- GPG signing not required

### 16. Acceptance Criteria

- The alert is fetched and (best-effort) assigned to the contributor
- A targeted fix is applied — type-appropriate (code change, dependency bump, or secret removal + rotation)
- All tests pass before committing
- Branch, commit, and PR follow the project's conventions
- The PR body links back to the original alert via its `html_url`
- For secret-scanning: the user has confirmed the secret was rotated at the provider
