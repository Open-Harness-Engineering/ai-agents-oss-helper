# AI Agents OSS Helper

Generic commands for AI coding agents (Claude, Bob, Gemini, Codex) to help contribute to open source projects. Commands auto-detect the current project via `git remote get-url origin` and load project-specific configuration from rule files.

## Getting Started

Any project can use the helper by adding an `.oss-ai-helper-rules/` directory to its repository root with three rule files:

```
my-project/
├── .oss-ai-helper-rules/
│   ├── project-info.md          # Repository URLs, issue trackers, related repos
│   ├── project-standards.md     # Build tools, commands, code style restrictions
│   └── project-guidelines.md    # Branch naming, commit formats, PR policies
└── ...
```

Use `/oss-add-project` to generate initial rule files for any project. Once committed, every contributor gets the right configuration automatically — no per-user installation of project-specific rules required.

## Installation

### Quick Install (All Agents)

```bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
```

### Selective Install

```bash
# Clone the repository
git clone https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git
cd ai-agents-oss-helper

# Install for specific agent
./install.sh claude    # Claude only
./install.sh bob       # Bob only
./install.sh gemini    # Gemini CLI only
./install.sh opencode  # OpenCode only
./install.sh codex     # Codex only
./install.sh           # All agents
```

## How It Works

Commands are generic and project-agnostic. Project-specific configuration is stored in rule files with three files per project:
- **`project-info.md`** - Repository URLs, issue trackers, SonarCloud keys, related repos
- **`project-standards.md`** - Build tools, commands, code style restrictions
- **`project-guidelines.md`** - Branch naming, commit formats, PR policies, task labels

### Rule loading priority

Every command starts by processing `.oss-init.md`, which loads project rules in this priority order:

1. **Project-local rules** - `.oss-ai-helper-rules/` directory in the repository root. Highest priority, versioned with the project.
2. **Installed fallback rules** - Matching `rules/<project>/` from the globally installed helper. Used when the project does not yet ship its own rules.
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files in `.oss-ai-helper-rules/` so they can be committed and shared.

Projects should adopt project-local rules so that configuration travels with the repository and stays in sync across all contributors and agents.

## Available Commands

| Command                                   | Description                                                             |
|-------------------------------------------|-------------------------------------------------------------------------|
| `/oss-fix-issue <issue>`                  | Fix an issue from the project's tracker (GitHub or Jira)                |
| `/oss-review-pr <pr>`                     | Review a pull request against project rules and contribution standards   |
| `/oss-find-task`                          | Find an issue to contribute based on experience level                   |
| `/oss-create-issue <title>`               | Create a new issue in the project's GitHub repository                   |
| `/oss-quick-fix <description>`            | Apply a quick fix without a tracked issue (CI, docs, deps, etc.)        |
| `/oss-analyze-issue <issue>`              | Analyze an issue to understand the problem and investigate the codebase |
| `/oss-fix-sonarcloud <rule>`              | Fix SonarCloud issues for a given rule                                  |
| `/oss-fix-github-alert <type>`            | Assign and fix a GitHub Code Scanning, Dependabot, or Secret Scanning alert |
| `/oss-add-project <name> <description>`  | Add a new project with the helper                                       |
| `/oss-update-knowledge <source>`          | Update a project's rule files from a description or URL                 |
| `/oss-fix-ci-errors [run-id]`             | Download CI build reports, identify errors, and fix them                |
| `/oss-fix-backlog-task <task> repo=<path>` | Fix a task from a Backlog.md file (requires Backlog MCP server)        |
| `/oss-pr-status [pr]`                     | Check CI checks, review state, and merge readiness of a pull request   |
| `/oss-list-pr-status`                     | List all your open PRs with CI, review, and merge readiness summary    |
| `/oss-list-prs [filters]`                 | List all open PRs in the repo, then pick one to review with `/oss-review-pr` |
| `/oss-backport-pr <pr> branch=<branch>`  | Cherry-pick a merged PR onto a maintenance/release branch               |
| `/oss-triage-security-report [source]`    | Triage an inbound security report: verify claims, check prior fixes, recommend disclosure path |
| `/oss-draft-cve <cve_id> template=<url_or_path> [triage_ref=<path>] [fix_pr=<pr>]` | Draft a project-specific CVE advisory page and matching PGP-signable plaintext body from a reserved CVE ID and a reference advisory |

All commands auto-detect the project from the current directory's git remote.

## Usage Examples

### Fix an Issue

```bash
# Navigate to any project with .oss-ai-helper-rules/, then:

# GitHub project - using issue number
/oss-fix-issue 42

# GitHub project - using full URL
/oss-fix-issue https://github.com/wanaku-ai/wanaku/issues/42

# Jira project (camel-core) - using issue ID
/oss-fix-issue CAMEL-20410

# Jira project - using full URL
/oss-fix-issue https://issues.apache.org/jira/browse/CAMEL-22326
```

### Find a Task

```bash
# Interactive - asks about your experience level
/oss-find-task
```

The command will:
1. Detect the current project
2. Ask about your experience level
3. Search for appropriate issues (good first issue, help wanted, etc.)
4. Present a list of options
5. Guide you to use `/oss-fix-issue` to implement

### Review a Pull Request

```bash
# Review by pull request number
/oss-review-pr 42

# Review by full URL
/oss-review-pr https://github.com/wanaku-ai/wanaku/pull/42
```

The command will:
1. Detect the current project
2. Load the project's rule files
3. Fetch the PR metadata and diff
4. Review the PR against project guidelines, standards, and contribution expectations
5. Report actionable findings without replacing specialized review tools or static analyzers

### Analyze an Issue

```bash
# Using issue number
/oss-analyze-issue 42

# Using full URL
/oss-analyze-issue https://github.com/wanaku-ai/wanaku/issues/42
```

The command will:
1. Fetch the issue details and comments
2. Investigate the codebase for relevant code
3. Check related repos if configured
4. Provide a structured analysis report
5. Suggest next steps (fix, ask for more info, etc.)

### Create an Issue

```bash
# Interactive - will prompt for details
/oss-create-issue

# With title provided
/oss-create-issue "Add support for custom headers in HTTP requests"
```

### Quick Fix

```bash
# Upgrade a dependency
/oss-quick-fix upgrade Quarkus BOM to 3.18.0

# Fix documentation
/oss-quick-fix fix broken link in CONTRIBUTING.md

# Update CI
/oss-quick-fix update GitHub Actions checkout to v4
```

### Fix SonarCloud Issues

```bash
# Fix cognitive complexity issues
/oss-fix-sonarcloud S3776

# Fix pattern matching for instanceof
/oss-fix-sonarcloud S6201

# Fix issues in a specific module only
/oss-fix-sonarcloud S3457 module=components/camel-jms

# Limit number of issues to process
/oss-fix-sonarcloud S6126 limit=10
```

### Fix a GitHub Security or Quality Alert

```bash
# List open Code Scanning alerts in the current project
/oss-fix-github-alert code-scanning

# Work on a specific Code Scanning alert (assigns it to you, walks the fix)
/oss-fix-github-alert code-scanning alert=42

# Filter Dependabot alerts by severity
/oss-fix-github-alert dependabot severity=high

# Work on a Secret Scanning alert (warns about provider-side rotation)
/oss-fix-github-alert secret-scanning alert=7
```

The command will:
1. Detect the current project and validate the alert type
2. List open alerts (when no `alert=` is provided) with severity, rule, and location
3. For a specific alert: fetch its details and assign it to you via the GitHub API
4. Walk through analyzing and fixing the alert (root-cause fix, dependency bump, or secret removal)
5. Create a branch, commit, push, and open a PR linking back to the alert

### Fix a Backlog Task

```bash
# Fix a backlog task, pointing to the backlog repository
/oss-fix-backlog-task TASK-001 repo=/home/user/projects/my-backlog

# Another example
/oss-fix-backlog-task TASK-042 repo=/home/user/work/team-backlog
```

The command will:
1. Verify the Backlog MCP server is available
2. Detect the current project
3. Fetch the task details from the backlog repository
4. Implement the fix following project standards
5. Create a branch, commit, push, and open a PR
6. Update the backlog task with implementation notes and mark it as done

**Note:** Requires the Backlog MCP server to be configured and running.

### Check PR Status

```bash
# Auto-detect PR from current branch
/oss-pr-status

# By PR number
/oss-pr-status 42

# By full URL
/oss-pr-status https://github.com/org/repo/pull/42
```

The command will:
1. Detect the current project
2. Fetch PR metadata, CI check results, and reviews
3. Present a structured status report
4. Identify blockers (failing checks, pending reviews, conflicts)
5. Suggest next steps (e.g., `/oss-fix-ci-errors` for failing CI)

### List All Your PR Statuses

```bash
# List all your open PRs in the current project
/oss-list-pr-status
```

The command will:
1. Detect the current project
2. List all your open PRs with CI, review, and merge readiness status
3. Highlight PRs needing attention (failing CI, changes requested, conflicts)
4. Suggest using `/oss-pr-status <number>` for detailed inspection of individual PRs

### Browse Open PRs to Review

```bash
# List all open PRs in the current repo (non-draft, limit 20)
/oss-list-prs

# Filter by author
/oss-list-prs author=octocat

# Filter by label (quote multi-word labels)
/oss-list-prs label="needs review"

# Raise the limit
/oss-list-prs limit=50

# Include draft PRs
/oss-list-prs include-drafts

# Hide PRs you authored
/oss-list-prs exclude-mine
```

The command will:
1. Detect the current project
2. List all open PRs in the repository (one `gh pr list` call, no per-PR CI fetch)
3. Present them in a numbered table with author, branch, review state, draft flag, and last update
4. Ask which PR you want to review
5. Hand off to `/oss-review-pr <number>` for the actual review

This is the counterpart to `/oss-list-pr-status`: that command lists *your own* PRs for tracking your work, while `/oss-list-prs` lists *all* open PRs in the repo for browsing and review selection.

### Backport a Merged PR

```bash
# Backport PR #42 to a release branch
/oss-backport-pr 42 branch=release/1.x

# Backport by URL
/oss-backport-pr https://github.com/org/repo/pull/42 branch=camel-4.8.x
```

The command will:
1. Validate the source PR is merged and the target branch exists
2. Cherry-pick the PR commits onto a new backport branch
3. Attempt to resolve conflicts automatically, or report them clearly
4. Open a backport PR with `[backport <branch>]` title prefix, linking back to the original PR

### Triage a Security Report

```bash
# Paste the report inline (agent will ask)
/oss-triage-security-report

# Read the report from a local file
/oss-triage-security-report ~/reports/incoming-report.txt

# Fetch from a URL (the agent will ask for confirmation first)
/oss-triage-security-report https://example.com/report.txt
```

The command will:
1. Detect the current project and load its rules
2. Acquire the report (paste / file / URL) and confirm confidentiality
3. Extract each technical claim from the report as a discrete bullet
4. Verify each claim against the current codebase (file reads, grep, git history)
5. Check git history for prior fixes, related CVEs, and parent tickets
6. Produce a structured triage summary with a confirmed/refuted verdict per claim
7. Recommend a follow-up path (private advisory, sanitized tracking issue, reporter reply, or duplicate pointer)
8. When a public tracking issue is the right path, propose sanitized issue text with all exploit specifics removed, then hand off to `/oss-create-issue` only after your confirmation

No content is published anywhere until you explicitly confirm a handoff.

### Add a New Project

```bash
/oss-add-project my-project "Java project at https://github.com/org/my-project, uses Maven, GitHub issues"
```

## OpenCode Notes

OpenCode uses markdown command files. The installer adds frontmatter descriptions and installs commands to:

- `~/.config/opencode/commands/`
- `~/.config/opencode/rules/` (project rule files)

## Codex Notes

Codex uses skills. The installer generates skills from each command and installs them to:

- `~/.agents/skills/`

The shared OSS Helper init file is installed to:

- `~/.codex/oss-helper/.oss-init.md`

Project rule files are installed to:

- `~/.codex/oss-helper/rules/`

Invoke any command in Codex by typing `$<skill-name>` (for example, `$oss-fix-issue`).

## Gemini CLI Notes

Gemini CLI uses TOML command files instead of Markdown. The installer automatically converts `.md` commands to `.toml` format at install time, wrapping the prompt content and extracting the description.

Since Gemini CLI has no auto-loading `rules/` directory, each generated TOML command includes a preamble instructing Gemini to read project rule files from `~/.gemini/rules/<project-directory>/`.

## Project Structure

```
ai-agents-oss-helper/
├── install.sh                        # Installation script
├── README.md
├── commands/                         # Generic commands (installed to ~/.{agent}/commands/)
│   ├── oss-add-project.md
│   ├── oss-fix-issue.md
│   ├── oss-review-pr.md
│   ├── oss-find-task.md
│   ├── oss-create-issue.md
│   ├── oss-quick-fix.md
│   ├── oss-analyze-issue.md
│   ├── oss-fix-sonarcloud.md
│   ├── oss-fix-github-alert.md
│   ├── oss-update-knowledge.md
│   ├── oss-fix-ci-errors.md
│   ├── oss-fix-backlog-task.md
│   ├── oss-pr-status.md
│   ├── oss-list-pr-status.md
│   ├── oss-list-prs.md
│   ├── oss-backport-pr.md
│   ├── oss-triage-security-report.md
│   └── .oss-init.md                  # Shared preamble: project detection & rule loading
└── rules/                            # Fallback rules for projects without .oss-ai-helper-rules/
    ├── <project>/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    └── generic-github/               # Catch-all fallback for any GitHub project
        ├── project-info.md
        ├── project-standards.md
        └── project-guidelines.md
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify commands/rules
4. Update `install.sh` if adding new files
5. Submit a pull request

## License

Apache License 2.0

---

[GitHub Repository](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper)
