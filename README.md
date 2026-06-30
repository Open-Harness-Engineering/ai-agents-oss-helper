# AI Agents OSS Helper

A skill for AI coding agents (Claude, Bob, Gemini, OpenCode, Codex) that provides guidelines for contributing to open source projects. The skill auto-detects the current project via `git remote get-url origin` and loads project-specific configuration from rule files.

For agents that support skills natively (Claude, Bob, Codex), the helper is installed as background knowledge — just describe what you want to do and the agent follows the appropriate guidelines automatically. For other agents (Gemini, OpenCode), individual commands are generated from the same guidelines.

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

### Rule loading priority

The skill initializes by loading project rules in this priority order:

1. **Project-local rules** - `.oss-ai-helper-rules/` directory in the repository root. Highest priority, versioned with the project.
2. **Installed fallback rules** - A subdirectory under the agent's local rules directory (for example `~/.claude/rules/<project>/`) whose `project-info.md` declares a matching `Remote pattern`. Install these on demand with the Install Info guideline.
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files in `.oss-ai-helper-rules/` so they can be committed and shared.

Projects should adopt project-local rules so that configuration travels with the repository and stays in sync across all contributors and agents.

### Where the rules come from

Project rules are not bundled with the installer. They live in a separate repository, [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects), and are installed on demand via the Install Info guideline. This keeps the helper focused on guidelines and lets projects that prefer not to host AI-agent metadata in their source tree have rules hosted centrally instead.

## Capabilities

The OSS Helper provides guidelines for the following tasks. For agents with skill support (Claude, Bob, Codex), just describe what you want in natural language or use the `/oss-*` command directly. For other agents, use the corresponding command.

| Capability | Gemini/OpenCode command | Description |
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
| Draft CVE advisory | `/oss-draft-cve` | Draft a project-specific CVE advisory page |
| Analyze third-party CVE | `/oss-analyze-third-party-cve` | Analyze exposure to a CVE in a third-party dependency |
| Create security advisory | `/oss-create-security-advisory` | Privately report a security vulnerability via GitHub |
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

## Usage Examples

### Fix an Issue

```
# With Claude, Bob, or Codex — just ask naturally:
fix issue 42
fix issue CAMEL-20410
fix https://github.com/wanaku-ai/wanaku/issues/42

# With Gemini or OpenCode — use the command:
/oss-fix-issue 42
/oss-fix-issue CAMEL-20410
```

### Find a Task

```
# Natural language:
find me a task to contribute to

# Command:
/oss-find-task
```

### Review a Pull Request

```
# Natural language:
review PR 42
review https://github.com/wanaku-ai/wanaku/pull/42

# Command:
/oss-review-pr 42
```

### Quick Fix

```
# Natural language:
upgrade Quarkus BOM to 3.18.0
fix broken link in CONTRIBUTING.md

# Command:
/oss-quick-fix upgrade Quarkus BOM to 3.18.0
```

### Backport a Merged PR

```
# Natural language:
backport PR 42 to the release/1.x branch

# Command:
/oss-backport-pr 42 branch=release/1.x
```

### Install Project Rules

```
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

Installed as a background skill at `~/.{agent}/skills/oss-helper/` plus individual `/oss-*` commands in `~/.{agent}/commands/`. You can either describe what you want in natural language (the agent matches it to the skill automatically) or invoke a specific command directly (e.g. `/oss-fix-issue 42`).

### Gemini CLI

Individual TOML commands are generated from each guideline file and installed to `~/.gemini/commands/`. Each command includes a preamble instructing Gemini to read project rules from `~/.gemini/rules/<project-directory>/`.

### OpenCode

Individual markdown commands with frontmatter are generated and installed to `~/.config/opencode/commands/`. Each command includes a preamble for project rule loading from `~/.config/opencode/rules/<project-directory>/`.

### Codex

Installed as a single skill directory at `~/.agents/skills/oss-helper/` with all guideline files as supporting files. Project rule files are installed to `~/.codex/oss-helper/rules/`.

## Project Structure

```text
ai-agents-oss-helper/
├── install.sh                              # Installation script
├── README.md
└── skills/
    └── oss-helper/                         # Single skill with all guidelines
        ├── SKILL.md                        # Main skill: init logic + capability catalog
        ├── fix-issue.md                    # Fix an issue
        ├── review-pr.md                    # Review a PR
        ├── quick-fix.md                    # Apply a quick fix
        ├── analyze-issue.md               # Analyze an issue
        ├── find-task.md                    # Find a task to contribute
        ├── create-issue.md                # Create a new issue
        ├── fix-sonarcloud.md              # Fix SonarCloud issues
        ├── fix-github-alert.md            # Fix a GitHub alert
        ├── fix-ci-errors.md               # Fix CI errors
        ├── pr-status.md                   # Check PR status
        ├── list-pr-status.md              # List your PR statuses
        ├── list-prs.md                    # List open PRs
        ├── list-issues.md                 # List assigned issues
        ├── backport-pr.md                 # Backport a merged PR
        ├── address-review.md              # Address review feedback
        ├── merge-pr.md                    # Merge a PR
        ├── add-project.md                 # Add a new project
        ├── update-knowledge.md            # Update project rules
        ├── install-info.md                # Install project rules
        ├── fix-backlog-task.md            # Fix a backlog task
        ├── triage-security-report.md      # Triage security report
        ├── analyze-third-party-cve.md     # Analyze third-party CVE
        ├── draft-cve.md                   # Draft CVE advisory
        ├── create-security-advisory.md    # Create security advisory
        ├── oss-create-multi-repo-issue.md # Create cross-repo issue
        ├── oss-create-rules.md            # Generate project rules
        ├── oss-fix-multi-repo-issue.md    # Fix cross-repo issue
        ├── oss-qe-create-test-plan.md     # Create test plan
        ├── oss-qe-verify.md               # Execute test plan
        ├── oss-review-prs.md              # Review a batch of open PRs
        ├── oss-security-scan.md           # Scan codebase for vulnerabilities
        ├── oss-triage-issue.md            # Triage a filed issue
        ├── oss-workspace-init.md          # Initialize multi-repo workspace
        └── oss-workspace-status.md        # Report workspace status
```

Project rule files are no longer bundled with this repository. They live in
[`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects)
and are installed on demand via the Install Info guideline.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify guideline files in `skills/oss-helper/`
4. Update `install.sh` if adding new files
5. Submit a pull request

## License

Apache License 2.0

---

[GitHub Repository](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper)
