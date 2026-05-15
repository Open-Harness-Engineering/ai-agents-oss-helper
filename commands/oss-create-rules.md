# Create Rules

Generate project rule files for a repository by auto-inspecting it and optionally using an existing project's rules as a structural template.

## Usage

```
/oss-create-rules [repo] [--template <project>]
```

**Arguments:**
- `<repo>` (optional) - Target GitHub repo URL or `org/repo` slug. If omitted, uses the current git remote.
- `--template <project>` (optional) - Slug of an existing project whose installed rules will be used as a structural starting point (e.g., `camel-core`, `wanaku`). If omitted, the command lists installed projects and lets you pick one, or you can proceed without a template.

**Examples:**
```
/oss-create-rules                                          # current repo, no template
/oss-create-rules --template wanaku                        # current repo, use wanaku rules as template
/oss-create-rules apache/camel-k --template camel-core     # remote repo, use camel-core as template
/oss-create-rules https://github.com/org/repo              # remote repo from URL, no template
```

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context is available.

### 2. Resolve Target Repository

Determine the target repository from the arguments:

**If a `<repo>` argument is provided:**
- If it is a full URL (e.g., `https://github.com/org/repo`): extract `org/repo`
- If it is already in `org/repo` format: use as-is

**If no `<repo>` argument is provided:**
- Use the current git remote:
  ```bash
  git remote get-url origin
  ```
- Extract `org/repo` from the URL (handle both `https://` and `git@` formats)

Verify the repository exists:

```bash
gh repo view <org/repo> --json name --jq '.name' 2>/dev/null
```

If the repository does not exist or is not accessible, report the error and stop.

### 3. Check for Existing Rules

Check if the target repository already has rules:

**A. Project-local rules in the target repo:**

```bash
gh api repos/<org/repo>/contents/.oss-ai-helper-rules --jq '.[].name' 2>/dev/null
```

**B. Installed rules matching the remote pattern:**

Check the agent's rules directory for a project whose `project-info.md` has a `Remote pattern:` matching `org/repo`.

If rules already exist (either project-local or installed), inform the user:

> Rules already exist for `<org/repo>`. Do you want to overwrite them?

Stop if the user declines. Continue if they confirm.

### 4. Resolve Template Project

**If `--template <project>` is provided:**

Locate the template project's rule files. Check, in order:
1. Agent's installed rules directory (e.g., `~/.claude/rules/<project>/`)
2. The `ai-agents-oss-known-projects` repository:
   ```bash
   gh api "repos/Open-Harness-Engineering/ai-agents-oss-known-projects/contents/<project>/project-info.md" --jq '.name' 2>/dev/null
   ```

If the template project is not found, report:
> Template project `<project>` not found. Run `/oss-install-info` to see available projects.

Stop.

If found, read all three rule files (`project-info.md`, `project-standards.md`, `project-guidelines.md`) from the template project. These will be used as the structural starting point.

**If `--template` is NOT provided:**

List installed projects from the agent's rules directory:

```bash
ls -d ~/.claude/rules/*/project-info.md 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {}
```

(Adjust the path for the current agent: `~/.bob/rules/`, `~/.gemini/rules/`, `~/.config/opencode/rules/`, `~/.codex/oss-helper/rules/`)

Present the list to the user:

> Available template projects:
> 1. camel-core
> 2. wanaku
> 3. ...
>
> Pick a template project (number or name), or type "none" to generate rules from scratch.

If the user picks a template, load its rule files. If "none", proceed without a template.

### 5. Inspect Target Repository

Auto-detect the target repository's characteristics. If the target is the current working directory, inspect the local filesystem. Otherwise, use the GitHub API.

#### 5.1 Detect Build Tool

**Local filesystem (current repo):**

Check for build files at the repository root:

| File found | Build tool | Build command | Test command | Format command |
|------------|-----------|---------------|-------------|----------------|
| `pom.xml` | Maven | `mvn verify` | `mvn verify` | `cd <module> && mvn -DskipTests install` |
| `build.gradle` or `build.gradle.kts` | Gradle | `./gradlew build` | `./gradlew test` | `./gradlew spotlessApply` |
| `package.json` | npm/yarn | `npm run build` / `yarn build` | `npm test` / `yarn test` | `npm run format` / `yarn format` |
| `Makefile` | Make | `make` | `make test` | _(none)_ |
| `go.mod` | Go | `go build ./...` | `go test ./...` | `gofmt -w .` |
| `Cargo.toml` | Cargo | `cargo build` | `cargo test` | `cargo fmt` |

If `package.json` exists, check for `yarn.lock` (use yarn) vs `package-lock.json` (use npm).

For Maven projects, check if a Maven wrapper (`mvnw`) exists — if so, use `./mvnw` instead of `mvn`.

**Remote repo (GitHub API):**

```bash
gh api repos/<org/repo>/contents --jq '.[].name' 2>/dev/null
```

Match the returned filenames against the table above.

#### 5.2 Detect Issue Tracker

- Default to GitHub
- If the repo belongs to `apache/` or the description mentions Jira, set issue tracker to Jira with URL `https://issues.apache.org/jira/browse/`
- If a Jira project key is detectable from the repo name or description, record it

#### 5.3 Detect Project Conventions

**Local filesystem:**

```bash
ls <repo-root>/CONTRIBUTING.md <repo-root>/.github/CONTRIBUTING.md <repo-root>/docs/CONTRIBUTING.md 2>/dev/null
```

If found, read it and extract any branch naming, commit format, or PR policies.

**Remote repo:**

```bash
gh api repos/<org/repo>/contents/CONTRIBUTING.md --jq '.content' 2>/dev/null | base64 -d
```

#### 5.4 Detect Related Repositories

Check if the GitHub org has other repositories with similar names or that are mentioned in the README:

```bash
gh api repos/<org/repo> --jq '.description' 2>/dev/null
```

Read the repo description for clues about related projects.

### 6. Generate Rule Files

Build the three rule files by merging template values (if available) with auto-detected values. Auto-detected values take precedence where they differ from the template.

#### 6.1 `project-info.md`

| Field | Source |
|-------|--------|
| Remote pattern | Auto-detected from `org/repo` |
| GitHub repo | Auto-detected from `org/repo` |
| Issue tracker | Auto-detected (step 5.2) |
| Issue tracker URL | Auto-detected or from template |
| Issue ID format | `numeric` (GitHub) or `alphanumeric` (Jira) |
| SonarCloud component key | From template or _(none)_ |
| Documentation URL | From template or _(none)_ |
| Related repositories | Auto-detected (step 5.4) or from template |
| Create-issue supported | `yes` |
| Jira project key | Auto-detected if Jira |
| Version | Current HEAD SHA of the target repo |

#### 6.2 `project-standards.md`

| Field | Source |
|-------|--------|
| Build tool | Auto-detected (step 5.1) |
| Build command | Auto-detected (step 5.1) |
| Test command | Auto-detected (step 5.1) |
| Format command | Auto-detected (step 5.1) |
| Module-specific build | From template or `no` |
| Parallelized Maven | From template or `n/a` |
| Code style restrictions | From template or `none` |

#### 6.3 `project-guidelines.md`

| Field | Source |
|-------|--------|
| Branch naming patterns | From template or defaults |
| Commit formats | From template or defaults |
| PR creation | From template or `always` |
| Find-task source | From template or `GitHub labels` |
| Find-task labels | From template or defaults (`good first issue`, `help wanted`) |
| Scope-too-large redirect | From template or `/oss-create-issue` |

**Defaults** (used when no template and no CONTRIBUTING.md conventions found):
- Fix branch: `fix/<ISSUE_NUMBER>`
- Feature branch: `feature/<ISSUE_NUMBER>-<short-slug>`
- Bugfix branch: `bugfix/<ISSUE_NUMBER>`
- Quick-fix branch: `quick-fix/<short-slug>`
- CI-issue branch: `ci-issue/<short-slug>`
- Commit format (fix): `Fix #<ISSUE_NUMBER>: <brief description>`
- Commit format (quick-fix): `chore: <brief description>`
- Commit format (ci-issue): `ci: <brief description>`
- PR creation: `always`
- Find-task source: `GitHub labels`
- Find-task beginner label: `good first issue`
- Find-task experienced label: `help wanted`
- Scope-too-large redirect: `/oss-create-issue`

### 7. Confirm with User

Present the generated rule files to the user for review. Show each file's content and ask for confirmation:

> Here are the generated rules for `<org/repo>`:
>
> **project-info.md:**
> (content)
>
> **project-standards.md:**
> (content)
>
> **project-guidelines.md:**
> (content)
>
> Do you want to write these files?

Allow the user to request changes before writing. Apply any requested modifications and re-confirm.

### 8. Write Rule Files

Determine where to write the rule files:

**If the target repo is the current working directory:**
Create the rules in `<repo-root>/.oss-ai-helper-rules/`:

```bash
mkdir -p <repo-root>/.oss-ai-helper-rules
```

Write the three files to this directory.

**If the target repo is remote (not the current working directory):**
Create the rules in the agent's installed rules directory under a project slug derived from the repo name:

```bash
mkdir -p <RULES_DIR>/<project-slug>
```

Where `<RULES_DIR>` is the agent's rules directory:

| Agent | Rules directory |
|-------|----------------|
| Claude | `~/.claude/rules/` |
| Bob | `~/.bob/rules/` |
| Gemini CLI | `~/.gemini/rules/` |
| OpenCode | `~/.config/opencode/rules/` |
| Codex | `~/.codex/oss-helper/rules/` |

And `<project-slug>` is derived from the repo name (e.g., `apache/camel-k` -> `camel-k`).

Write the three files to this directory.

### 9. Report Result

After writing, inform the user:

**If rules were written to `.oss-ai-helper-rules/` (project-local):**
> Rules created in `.oss-ai-helper-rules/`. Review and commit them to share with other contributors.
> The next OSS Helper command run from this project will load these rules automatically.

**If rules were written to the agent's rules directory (remote target):**
> Rules installed to `<RULES_DIR>/<project-slug>/`.
> The next time you run an OSS Helper command from a project whose git remote matches `<org/repo>`, these rules will be loaded automatically.

If a template was used, mention it:
> Based on template: `<template-project>`

### 10. Constraints

You MUST:
- Confirm all generated rules with the user before writing
- Auto-detect values from the target repository where possible
- Let auto-detected values override template values for repo-specific fields (remote pattern, GitHub repo, build tool)
- Preserve template values for convention fields (branch naming, commit formats) unless the user requests changes
- Create all three rule files
- Use the exact format from existing rule files in `ai-agents-oss-known-projects`

You MUST NOT:
- Write rule files without user confirmation
- Skip auto-detection and blindly copy template values for repo-specific fields
- Modify existing rule files in other projects
- Modify `install.sh`, `.oss-init.md`, or `README.md`
- Create per-project command files
- Make excessive GitHub API calls — inspect only what is needed

### 11. Acceptance Criteria

- Three rule files are generated with correct format matching existing projects
- Auto-detected values (build tool, issue tracker, remote pattern) are accurate
- Template values are properly inherited for convention fields when a template is used
- User has reviewed and approved the generated rules before they are written
- Rules are written to the correct location (`.oss-ai-helper-rules/` for local, agent rules dir for remote)
- Generated rules are loadable by `.oss-init.md` without errors
