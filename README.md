# AI Agents OSS Helper

A collection of skills for AI coding agents (Claude, Bob, Gemini, OpenCode, Codex) that provides guidelines for contributing to open source projects. The skills auto-detect the current project via `git remote get-url origin` and load project-specific configuration from rule files.

For agents that support skills natively (Claude, Bob, Codex), the helper is installed as 6 focused, user-invocable skills — just describe what you want to do (or invoke `/oss-*` directly) and the agent follows the appropriate guidelines automatically. For other agents (Gemini, OpenCode), individual commands are generated from the same guidelines.

## Getting Started

Any project can use the helper by adding an `.oss-ai-helper-rules/` directory to its repository root with three rule files:

```text
my-project/
├── .oss-ai-helper-rules/
│   ├── project-info.md          # Repository URLs, issue trackers, related repos
│   ├── project-standards.md     # Build tools, commands, code style restrictions
│   └── project-guidelines.md    # Branch naming, commit formats, PR policies
└── ...
```

Use the Add Project guideline to generate initial rule files for any project. Once committed, every contributor gets the right configuration automatically — no per-user installation of project-specific rules required.

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

The helper provides guidelines that are project-agnostic. Project-specific configuration is stored in rule files with three files per project:

- **`project-info.md`** - Repository URLs, issue trackers, SonarCloud keys, related repos
- **`project-standards.md`** - Build tools, commands, code style restrictions
- **`project-guidelines.md`** - Branch naming, commit formats, PR policies, task labels

### Skill groups

The 37 guidelines are organized into 6 focused skills:

- **`/oss-issues`** — Issue lifecycle: fix, analyze, create, list, find tasks, triage, cross-repo issues
- **`/oss-review`** — PR lifecycle: review, address feedback, batch review, status, merge, backport
- **`/oss-ci`** — CI/CD and code quality: fix CI errors, SonarCloud, GitHub alerts, quick fixes
- **`/oss-security`** — Security: triage reports, drive a report end to end, analyze CVEs, draft advisories, sync the GitHub Advisory Database, scan code
- **`/oss-project`** — Project setup: add projects, install/generate/update rules, workspaces
- **`/oss-qe`** — Quality engineering: create and execute test plans, deep module audits

Each skill is user-invocable — you can invoke it directly via `/oss-issues`, `/oss-review`, etc. or the agent can auto-invoke it when your request matches. Individual `/oss-*` commands (e.g. `/oss-fix-issue`) are also available as thin wrappers that delegate to the appropriate skill.

### Rule loading priority

Each skill initializes by loading project rules in this priority order:

1. **Project-local rules** - `.oss-ai-helper-rules/` directory in the repository root. Highest priority, versioned with the project.
2. **Installed fallback rules** - A subdirectory under the agent's local rules directory (for example `~/.claude/oss-helper/rules/<project>/`) whose `project-info.md` declares a matching `Remote pattern`. Install these on demand with the Install Info guideline. Claude and Bob keep them under `oss-helper/rules/`, not `~/.claude/rules/`, because Claude Code loads every file under `~/.claude/rules/` into every session in every repository. `install.sh` moves rule sets left in the old location.
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files in `.oss-ai-helper-rules/` so they can be committed and shared.

Projects should adopt project-local rules so that configuration travels with the repository and stays in sync across all contributors and agents.

### Where the rules come from

Project rules are not bundled with the installer. They live in a separate repository, [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects), and are installed on demand via the Install Info guideline. This keeps the helper focused on guidelines and lets projects that prefer not to host AI-agent metadata in their source tree have rules hosted centrally instead.

## Capabilities

The OSS Helper provides guidelines for the following tasks. For agents with skill support (Claude, Bob, Codex), just describe what you want in natural language or use the `/oss-*` command directly. For other agents, use the corresponding command.

| Capability | Command | Description |
|---|---|---|
| Fix an issue | `/oss-fix-issue` | Fix an issue from the project's tracker (GitHub or Jira) |
| Review a PR | `/oss-review-pr` | Review a pull request against project rules and contribution standards |
| Find a task | `/oss-find-task` | Find an issue to contribute based on experience level |
| Create an issue | `/oss-create-issue` | Create a new issue in the project's issue tracker |
| Quick fix | `/oss-quick-fix` | Apply a quick fix without a tracked issue (CI, docs, deps, etc.) |
| Analyze an issue | `/oss-analyze-issue` | Analyze an issue to understand the problem and investigate the codebase |
| Fix SonarCloud issues | `/oss-fix-sonarcloud` | Fix SonarCloud issues for a given rule |
| Fix GitHub alert | `/oss-fix-github-alert` | Fix a GitHub Code Scanning, Dependabot, or Secret Scanning alert |
| Add a project | `/oss-add-project` | Add a new project with the helper |
| Update knowledge | `/oss-update-knowledge` | Update a project's rule files from a description or URL |
| Fix CI errors | `/oss-fix-ci-errors` | Download CI build reports, identify errors, and fix them |
| Fix backlog task | `/oss-fix-backlog-task` | Fix a task from a Backlog.md file (requires Backlog MCP server) |
| PR status | `/oss-pr-status` | Check CI checks, review state, and merge readiness of a PR |
| List PR status | `/oss-list-pr-status` | List all your open PRs with CI, review, and merge readiness summary |
| List PRs | `/oss-list-prs` | List all open PRs in the repo for browsing and review selection |
| List issues | `/oss-list-issues` | List issues assigned to you in the project's tracker |
| Backport a PR | `/oss-backport-pr` | Cherry-pick a merged PR onto a maintenance/release branch |
| Address review | `/oss-address-review` | Address review feedback on a PR |
| Merge a PR | `/oss-merge-pr` | Merge a PR after verifying all requirements are met |
| Triage security report | `/oss-triage-security-report` | Triage an inbound security vulnerability report |
| Drive a security case | `/oss-security-case` | Drive one security report through triage, reporter reply, CVE, sanitized issue, fix, backports and CVE draft, stopping at every maintainer gate (a Claude Code workflow; other agents follow the same graph by hand) |
| Draft CVE advisory | `/oss-draft-cve` | Draft a project-specific CVE advisory page plus the CVE Record Format JSON |
| Analyze third-party CVE | `/oss-analyze-third-party-cve` | Analyze exposure to a CVE in a third-party dependency |
| Create security advisory | `/oss-create-security-advisory` | Privately report a security vulnerability via GitHub |
| Update GH Advisory Database | `/oss-update-gh-advisory-db` | Populate GitHub Advisory Database entries for the project's published CVEs |
| Triage an issue | `/oss-triage-issue` | Triage a filed issue: reproduce, dedupe, classify, recommend disposition |
| Review batch of PRs | `/oss-review-prs` | Review a batch of open PRs you haven't reviewed yet |
| Security scan | `/oss-security-scan` | Scan first-party code for security vulnerabilities |
| Generate project rules | `/oss-create-rules` | Generate project rule files for a new or existing repository |
| Install project rules | `/oss-install-info` | Install project rules from the known-projects repository |
| Initialize workspace | `/oss-workspace-init` | Initialize or rediscover a multi-repo workspace |
| Workspace status | `/oss-workspace-status` | Report status of all repos in a workspace |
| Create multi-repo issue | `/oss-create-multi-repo-issue` | Create and link issues across multiple repositories |
| Fix multi-repo issue | `/oss-fix-multi-repo-issue` | Fix an issue spanning multiple repositories |
| Create test plan | `/oss-qe-create-test-plan` | Create a test plan for a project feature or component |
| Execute test plan | `/oss-qe-verify` | Execute an existing test plan and track results |
| Audit a module family | `/oss-qe-module-audit` | Deep-audit a module family for bugs, antipatterns, inconsistencies, missing features, and ideas |

## Usage Examples

### Fix an Issue

```text
# With Claude, Bob, or Codex — just ask naturally:
fix issue 42
fix issue CAMEL-20410
fix https://github.com/wanaku-ai/wanaku/issues/42

# With Gemini or OpenCode — use the command:
/oss-fix-issue 42
/oss-fix-issue CAMEL-20410
```

### Find a Task

```text
# Natural language:
find me a task to contribute to

# Command:
/oss-find-task
```

### Review a Pull Request

```text
# Natural language:
review PR 42
review https://github.com/wanaku-ai/wanaku/pull/42

# Command:
/oss-review-pr 42
```

### Quick Fix

```text
# Natural language:
upgrade Quarkus BOM to 3.18.0
fix broken link in CONTRIBUTING.md

# Command:
/oss-quick-fix upgrade Quarkus BOM to 3.18.0
```

### Backport a Merged PR

```text
# Natural language:
backport PR 42 to the release/1.x branch

# Command:
/oss-backport-pr 42 branch=release/1.x
```

### Drive a Security Report End to End

```text
# Start a case from a report file; it stops at the verdict gate:
/oss-security-case xml-entities report=/path/to/report.txt

# Each later run records your decisions and approvals, and advances to the next gate:
/oss-security-case xml-entities verdict=VALID approve=issue
/oss-security-case xml-entities cve=CVE-2026-12345 approve=pr
/oss-security-case xml-entities done=reply approve=backports

# Once every fixed version is released, the next run drafts the advisory and the CVE record,
# kept in the case directory and archived only to your private draft repository, if you set one:
/oss-security-case xml-entities
```

Every run leaves a `STATUS.md` in the private case directory listing what is done, what waits on you, and the next command. Nothing is sent, reserved, merged, signed or published by the agent: those stay maintainer actions. The project's `project-security.md` supplies the CNA, the advisory template and the supported lines; see `skills/oss-security/security-case.md` for the other settings.

Each node is a separate subagent. The mechanical ones (the loader, the persistence step, the issue creation, the final reply and the PR publishing) run on cheaper models; pass `economy=off` to run everything on the session model. The loader starts from `security-case-probe.sh`, a read-only script installed with the skill that prints the clone facts, the rule files, the environment, the operator preferences and the case files; run it by hand to see what the workflow will read.

### Install Project Rules

```text
# Natural language:
install project rules for camel-core

# Command:
/oss-install-info camel-core
/oss-install-info auto           # detect from git remote
/oss-install-info all            # install all known projects
```

#### Pointing at a different rules repository

The default source is [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects) on the `main` branch. You can override either part with environment variables — useful for teams that maintain a private fork of the rules repo:

| Variable | Default | Purpose |
|----------|---------|---------|
| `OSS_KNOWN_PROJECTS_REPO` | `Open-Harness-Engineering/ai-agents-oss-known-projects` | GitHub `org/repo` to read rules from |
| `OSS_KNOWN_PROJECTS_BRANCH` | `main` | Branch within that repository |

## Agent-Specific Notes

### Claude, Bob

Installed as 6 user-invocable skills at `~/.{agent}/skills/oss-{issues,review,ci,security,project,qe}/` plus individual `/oss-*` commands in `~/.{agent}/commands/`. You can either describe what you want in natural language (the agent matches it to a skill automatically), invoke a skill group (e.g. `/oss-issues`), or invoke a specific command directly (e.g. `/oss-fix-issue 42`).

In Claude Code the individual commands are installed with `disable-model-invocation: true`: you type them, but their descriptions stay out of the model's context in every session. Requests in natural language reach the same guidelines through the skill groups. The sub-agent descriptions are kept to a sentence or two for the same reason, since Claude Code lists them in every session too.

For Claude only, the installer also copies the workflows in `workflows/` to `~/.claude/workflows/`. These are scripts for Claude Code's Workflow tool, which runs the subagents of a multi-step guideline in the background. `/oss-security-case` uses one. Claude Code reads the directory when a session starts, so start a new session after installing. Bob installs the same guideline and follows it by hand.

### Gemini CLI

Individual TOML commands are generated from each guideline file and installed to `~/.gemini/commands/`. Each command includes a preamble instructing Gemini to read project rules from `~/.gemini/rules/<project-directory>/`.

### OpenCode

Individual markdown commands with frontmatter are generated and installed to `~/.config/opencode/commands/`. Each command includes a preamble for project rule loading from `~/.config/opencode/rules/<project-directory>/`.

### Codex

Installed as 6 skill directories at `~/.agents/skills/oss-{issues,review,ci,security,project,qe}/` with all guideline files as supporting files. Project rule files are installed to `~/.codex/oss-helper/rules/`.

If Codex reports a missing `~/.codex/oss-helper/.oss-init.md`, rerun `./install.sh codex` from an updated checkout, then start a new Codex session. The installer removes stale standalone OSS Helper skills; current skills use their bundled `init.md`.

## Project Structure

```text
ai-agents-oss-helper/
├── install.sh                              # Installation script
├── README.md
├── workflows/                              # Claude Code workflows (installed for Claude only)
│   └── oss-security-case.js               # Security report lifecycle graph
├── tests/
│   └── workflows/
│       └── oss-security-case.test.mjs     # Routing test with mocked agents
└── skills/
    ├── _shared/
    │   └── init.md                         # Shared initialization logic
    ├── oss-issues/                          # Issue management skill
    │   ├── SKILL.md                        # Skill entry point
    │   ├── fix-issue.md                    # Fix an issue
    │   ├── analyze-issue.md               # Analyze an issue
    │   ├── create-issue.md                # Create a new issue
    │   ├── list-issues.md                 # List assigned issues
    │   ├── find-task.md                    # Find a task to contribute
    │   ├── fix-backlog-task.md            # Fix a backlog task
    │   ├── oss-triage-issue.md            # Triage a filed issue
    │   ├── oss-create-multi-repo-issue.md # Create cross-repo issue
    │   └── oss-fix-multi-repo-issue.md    # Fix cross-repo issue
    ├── oss-review/                          # PR management skill
    │   ├── SKILL.md
    │   ├── review-pr.md                    # Review a PR
    │   ├── address-review.md              # Address review feedback
    │   ├── oss-review-prs.md              # Review batch of PRs
    │   ├── pr-status.md                   # Check PR status
    │   ├── list-pr-status.md              # List your PR statuses
    │   ├── list-prs.md                    # List open PRs
    │   ├── merge-pr.md                    # Merge a PR
    │   └── backport-pr.md                 # Backport a merged PR
    ├── oss-ci/                              # CI/CD & quality skill
    │   ├── SKILL.md
    │   ├── fix-ci-errors.md               # Fix CI errors
    │   ├── fix-sonarcloud.md              # Fix SonarCloud issues
    │   ├── fix-github-alert.md            # Fix a GitHub alert
    │   └── quick-fix.md                    # Apply a quick fix
    ├── oss-security/                        # Security skill
    │   ├── SKILL.md
    │   ├── triage-security-report.md      # Triage security report
    │   ├── security-case.md               # Drive a security report end to end
    │   ├── security-case-probe.sh         # Read-only probe run by the workflow's loader
    │   ├── analyze-third-party-cve.md     # Analyze third-party CVE
    │   ├── draft-cve.md                   # Draft CVE advisory
    │   ├── create-security-advisory.md    # Create security advisory
    │   ├── update-gh-advisory-db.md       # Sync GitHub Advisory Database
    │   └── oss-security-scan.md           # Scan codebase
    ├── oss-project/                         # Project setup skill
    │   ├── SKILL.md
    │   ├── add-project.md                 # Add a new project
    │   ├── install-info.md                # Install project rules
    │   ├── oss-create-rules.md            # Generate project rules
    │   ├── update-knowledge.md            # Update project rules
    │   ├── oss-workspace-init.md          # Initialize workspace
    │   └── oss-workspace-status.md        # Workspace status
    └── oss-qe/                              # Quality engineering skill
        ├── SKILL.md
        ├── oss-qe-create-test-plan.md     # Create test plan
        ├── oss-qe-verify.md               # Execute test plan
        └── oss-qe-module-audit.md         # Deep module-family audit
```

Project rule files are no longer bundled with this repository. They live in
[`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects)
and are installed on demand via the Install Info guideline.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify guideline files in the appropriate `skills/oss-*/` directory
4. Update `install.sh` if adding new files
5. For a Claude Code workflow, add the script to `workflows/` (its `meta.name` must match the file name), list it in `WORKFLOW_FILES` in `install.sh`, give it a guideline that also works by hand for the other agents, and add a test under `tests/workflows/`
6. Submit a pull request

## License

Apache License 2.0

---

[GitHub Repository](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper)
