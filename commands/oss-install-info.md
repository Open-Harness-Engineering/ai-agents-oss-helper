# Install Project Rules

Install project rules from the `ai-agents-oss-known-projects` repository into the local agent rules directory. Use this when the current project does not ship its own `.oss-ai-helper-rules/` directory and the helper has no installed rules that match the current git remote.

## Usage

```
/oss-install-info [project]
```

**Arguments:**
- `<project>` (optional) - Project slug to install (e.g., `camel-core`, `wanaku`). Use `auto` to detect the slug from the current git remote, or `all` to install every project in the known-projects repository. If omitted, the command lists the projects available in the known-projects repository.

**Examples:**
```
/oss-install-info                # list available projects
/oss-install-info wanaku         # install rules for wanaku
/oss-install-info camel-core     # install rules for Apache Camel core
/oss-install-info auto           # detect current git remote and install the matching project
/oss-install-info all            # install every project in the known-projects repository
```

## Instructions

### 1. Resolve Known-Projects Repository

Use the following values (override via environment if set):

| Variable | Default |
|----------|---------|
| `OSS_KNOWN_PROJECTS_REPO` | `Open-Harness-Engineering/ai-agents-oss-known-projects` |
| `OSS_KNOWN_PROJECTS_BRANCH` | `main` |

These determine the GitHub repo and branch that the command reads project rule files from.

### 2. Resolve Target Rules Directory

Determine the rules directory based on the agent that invoked this command:

| Agent      | Rules directory                       |
|------------|---------------------------------------|
| Claude     | `~/.claude/rules/`                    |
| Bob        | `~/.bob/rules/`                       |
| Gemini CLI | `~/.gemini/rules/`                    |
| OpenCode   | `~/.config/opencode/rules/`           |
| Codex      | `~/.codex/oss-helper/rules/`          |

Project rule files will be written to `<RULES_DIR>/<project>/`.

### 3. List Mode (no `<project>` argument)

If no argument is provided, list the projects available in the known-projects repository:

```bash
gh api "repos/<OSS_KNOWN_PROJECTS_REPO>/contents?ref=<OSS_KNOWN_PROJECTS_BRANCH>" --jq '.[] | select(.type == "dir") | .name'
```

For each listed project, indicate whether it is already installed locally (i.e., whether `<RULES_DIR>/<project>/project-info.md` exists).

Render a numbered table:

```markdown
## Available projects in <OSS_KNOWN_PROJECTS_REPO>

| # | Project | Installed locally |
|---|---------|-------------------|
| 1 | camel-core | yes |
| 2 | wanaku | no |
| ... | ... | ... |

Run `/oss-install-info <project>` to install one.
```

Stop after rendering.

### 4. Auto Mode (`<project>` is `auto`)

Detect the slug from the current git remote:

```bash
git remote get-url origin
```

Extract the GitHub `org/repo` from the URL (handle both `https://github.com/org/repo.git` and `git@github.com:org/repo.git`).

Find the project in the known-projects repository whose `project-info.md` has a `Remote pattern:` matching `org/repo`. List the candidate projects with `gh api .../contents`, then fetch each `project-info.md` only as needed until a match is found. Stop fetching as soon as a match is found.

If no match is found, report:
> No project in `<OSS_KNOWN_PROJECTS_REPO>` matches the current git remote (`<org/repo>`). Run `/oss-install-info` to list available projects, or run `/oss-add-project` to create new rules.

Stop.

If a match is found, use that slug and continue with the install steps below.

### 5. All Mode (`<project>` is `all`)

Install every project listed in the known-projects repository.

#### 5.1 Enumerate projects

```bash
gh api "repos/<OSS_KNOWN_PROJECTS_REPO>/contents?ref=<OSS_KNOWN_PROJECTS_BRANCH>" --jq '.[] | select(.type == "dir") | .name'
```

#### 5.2 Install each project

For each project slug returned, run the install steps in section 6 (Install Mode) — including the validation in 6.1, the version check in 6.2, and the fetch in 6.3.

When the version check in 6.2 reports a SHA mismatch, ask the user once whether to overwrite, and reuse that answer for the rest of the run. Do not prompt per project.

Do not emit the per-project confirmation block (section 6.4) for each project — aggregate the outcomes instead.

#### 5.3 Aggregate summary

After processing every project, render a single summary table:

```markdown
## Installed rules for all projects in <OSS_KNOWN_PROJECTS_REPO>

| # | Project | Status |
|---|---------|--------|
| 1 | camel-core | installed |
| 2 | wanaku | already up to date |
| 3 | hawtio | skipped (user declined overwrite) |
| ... | ... | ... |

Total: <N> project(s) — <installed> installed, <unchanged> already up to date, <skipped> skipped.
```

The next OSS Helper command run from any project that matches one of these remote patterns will load the matching rules through `.oss-init.md` step 2B without any further configuration.

Stop after rendering the summary.

### 6. Install Mode (project slug provided)

#### 6.1 Validate the project exists

Check that `<project>/project-info.md` exists in the known-projects repo:

```bash
gh api "repos/<OSS_KNOWN_PROJECTS_REPO>/contents/<project>/project-info.md?ref=<OSS_KNOWN_PROJECTS_BRANCH>" --jq '.name' 2>/dev/null
```

If the project is not found, report:
> Project `<project>` not found in `<OSS_KNOWN_PROJECTS_REPO>`. Run `/oss-install-info` to list available projects.

Stop.

#### 6.2 Check existing local copy

If `<RULES_DIR>/<project>/project-info.md` exists locally, read its `## Version` SHA. Fetch the remote version:

```bash
gh api "repos/<OSS_KNOWN_PROJECTS_REPO>/contents/<project>/project-info.md?ref=<OSS_KNOWN_PROJECTS_BRANCH>" --jq '.content' 2>/dev/null | base64 -d | grep -A1 '## Version'
```

- If the SHAs match: inform the user the rules are already up to date and stop.
- If they differ (or the local file has no `## Version`): ask the user whether to overwrite.

Stop if the user declines.

#### 6.3 Fetch and write rule files

For each of the three files (`project-info.md`, `project-standards.md`, `project-guidelines.md`):

```bash
mkdir -p <RULES_DIR>/<project>
gh api "repos/<OSS_KNOWN_PROJECTS_REPO>/contents/<project>/<file>?ref=<OSS_KNOWN_PROJECTS_BRANCH>" --jq '.content' | base64 -d > <RULES_DIR>/<project>/<file>
```

If `gh` is not available, fall back to `curl`:

```bash
curl -fsSL "https://raw.githubusercontent.com/<OSS_KNOWN_PROJECTS_REPO>/<OSS_KNOWN_PROJECTS_BRANCH>/<project>/<file>" -o <RULES_DIR>/<project>/<file>
```

#### 6.4 Confirm the install

Report to the user:

```
Installed rules for <project> to <RULES_DIR>/<project>/:
- project-info.md
- project-standards.md
- project-guidelines.md
```

Suggest the next step:
> The next time you run an OSS Helper command from a project whose git remote matches `<remote-pattern>`, these rules will be loaded automatically.

### 7. Constraints

You MUST:
- Make minimal API calls — per project: one to validate, three to fetch the rule files, plus one extra to compare versions if a local copy already exists
- Install only the three rule files (`project-info.md`, `project-standards.md`, `project-guidelines.md`)
- Ask the user before overwriting a local copy that has a different `## Version` SHA; in `all` mode, reuse the first answer for the rest of the run
- Create each target rules directory if it does not exist

You MUST NOT:
- Modify the known-projects repository itself (this command is read-only against it)
- Install commands or other helper files (use `install.sh` for that)
- Install rules for projects other than those covered by the current invocation (single slug, `auto` match, or every project under `all`)
- Overwrite local rules without performing the version check first
- Touch project-local `.oss-ai-helper-rules/` directories (those take precedence over installed rules)
- Prompt the user once per project in `all` mode — collect overwrite consent at most once

### 8. Acceptance Criteria

- The three rule files for each requested `<project>` are present in `<RULES_DIR>/<project>/` after the command completes successfully
- The local `## Version` SHA matches the remote SHA for each installed project
- Subsequent OSS Helper commands load the newly installed rules through `.oss-init.md` step 2B
- Existing project-local `.oss-ai-helper-rules/` directories continue to take precedence
- No commands or helper files outside `<RULES_DIR>/<project>/` are modified
- In `all` mode, a single aggregated summary table is produced instead of per-project confirmation messages
