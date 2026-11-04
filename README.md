# AI Agents OSS Helper

A collection of skills for AI coding agents (Claude, Bob, Gemini, OpenCode, Codex, agy) that provides guidelines for contributing to open source projects. The skills auto-detect the current project via `git remote get-url origin` and load project-specific configuration from rule files.

For agents that support skills natively (Claude, Bob, Codex, agy), the helper is installed as 6 focused, user-invocable skills — just describe what you want to do (or invoke `/oss-*` directly) and the agent follows the appropriate guidelines automatically. For other agents (Gemini, OpenCode), individual commands are generated from the same guidelines.

## Documentation

Browse the full command and workflow reference at
[open-harness-engineering.github.io/ai-agents-oss-helper](https://open-harness-engineering.github.io/ai-agents-oss-helper/),
generated from the guidelines and published via GitHub Pages.

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

### Claude Code marketplace

```bash
claude plugin marketplace add Open-Harness-Engineering/ai-agents-oss-helper
claude plugin install oss-helper@ai-agents-oss-helper
```

The Claude marketplace installs the committed `plugin/` bundle; users do not run a build.
Plugin skills and commands are namespaced, for example `/oss-helper:oss-issues`
and `/oss-helper:oss-fix-issue 42`.

### Codex marketplace

```bash
codex plugin marketplace add Open-Harness-Engineering/ai-agents-oss-helper
codex plugin add oss-helper@ai-agents-oss-helper
```

Start a new session, open `/skills`, and try `$oss-helper:oss-review` to list this
repository's pull requests. The Codex plugin exposes the six skill groups;
Claude-specific command wrappers and workflows remain Claude-only. Native
marketplace support requires a current Codex client.

### Gemini CLI native installation

Install the assembled skills directly from Git:

```bash
gemini skills install https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git --path plugin/skills
```

Run `gemini skills list` to check discovery. For local development, build the Gemini extension with its native command and
agent formats:

```bash
./build.sh gemini
gemini extensions install ./build/gemini
```

Gemini's Git extension installer cannot select a repository subdirectory. Use
the native skills command above for remote installation; the repository root
contains editable sources, while `plugin/skills/` contains assembled skills.
See the [Gemini skill installer](https://geminicli.com/docs/cli/skills/).

### Bob Shell extension adapter

For Bob Shell clients that support extensions:

```bash
bob extensions install https://github.com/Open-Harness-Engineering/ai-agents-oss-helper
```

The adapter follows the [Keycloak skills pattern](https://github.com/lhanusov/keycloak-ai-skills):
`bob-extension.json` loads `BOB.md`, which routes requests to the assembled
`plugin/skills/` directories. The shared `plugin/` bundle can also be passed to a
local extension installer. This adapter is structurally checked; the Bob Shell
client available for testing here does not expose `extensions`, so live Bob
extension installation remains unverified. Use `./install.sh bob` with older
clients. This does not install a Bob IDE plugin.

### Compatibility installer

Existing automation can continue using `install.sh`. From a checkout:

```bash
./install.sh codex    # Install one agent
./install.sh          # Install all six agents
```

The existing remote installation path also remains available:

```bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash -s -- --version v1.0.0 codex
```

`--version <tag>`, `--version=<tag>` and `OSS_HELPER_VERSION` select a remote
version; the flag takes precedence over the environment variable. Without a
version selection, a checkout uses its local sources and a standalone or piped
script downloads `main`. Remote installation requires `curl` or `wget` and `tar`.
The wrapper builds in a temporary directory and copies the selected assets to
user directories. It preserves unrelated files and project rules; use
`uninstall.sh` separately to remove obsolete assets.

Direct Claude installations retain `/oss-*` commands and files under
`~/.claude/`. Choose either that installation or the marketplace plugin to avoid
duplicate skills and commands. The marketplace remains the recommended Claude
installation path.

### Build locally

```bash
git clone https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git
cd ai-agents-oss-helper
./build.sh          # All six targets
./build.sh claude   # plugin/ (committed)
./build.sh codex    # build/codex/ (ignored)
```

The build uses the current checkout, works offline, and writes only generated
output inside the project. It requires `sha256sum` or `shasum` for native package
versions. Check out a release tag before building to select a
specific version. Rebuild `plugin/` whenever its inputs change; CI checks it for
drift. For isolated builds, use `./build.sh --output-dir /tmp/oss-plugin claude`.

Test the Claude bundle locally with `claude --plugin-dir ./plugin`.

### Other agents

Use `./install.sh <agent>` for automatic installation, or build the target and
copy its output to the corresponding directories. The build itself never copies
files into your home directory.

| Target | Built directory | Copy destination |
| --- | --- | --- |
| Bob | `build/bob/{skills,commands,agents}/` | `~/.bob/{skills,commands,agents}/` |
| agy | `build/agy/{skills,commands,agents}/` | `~/.agy/{skills,commands,agents}/` |
| Gemini | `build/gemini/{skills,commands,agents}/` | `~/.gemini/{skills,commands,agents}/` |
| OpenCode | `build/opencode/{commands,agents}/` | `~/.config/opencode/{commands,agents}/` |
| Codex | `build/codex/skills/` | `~/.agents/skills/` |
| Codex | `build/codex/agents/` | `~/.codex/agents/` |

For example:

```bash
./build.sh codex
mkdir -p ~/.agents/skills ~/.codex/agents
cp -R build/codex/skills/. ~/.agents/skills/
cp -R build/codex/agents/. ~/.codex/agents/
```

### Remove older installations

Before switching from the old installer, preview the legacy files to remove:

```bash
./uninstall.sh claude          # Preview only
./uninstall.sh --yes claude    # Remove legacy Claude assets
./uninstall.sh --yes           # All six agents
```

The uninstaller preserves project rules, security case data and unrelated user
assets. It does not remove marketplace-managed plugins. To remove the Claude
plugin, run `claude plugin uninstall oss-helper@ai-agents-oss-helper`. After
removing legacy Claude assets, install the marketplace plugin and start a fresh
session.

The uninstaller's filename lists cover recent OSS Helper versions. Much older
installers may have left additional files or directories behind. The uninstaller
reports possible leftovers by filename and leaves them untouched, even with
`--yes`; these candidates may belong to other projects. This scan is a heuristic
and may miss files with other names. Inspect your
agent's skill, command, agent and workflow directories after uninstalling. For
Claude these are `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/agents/`
and `~/.claude/workflows/`; the copy destinations above list the other agents.
You may need to forcefully remove remaining OSS Helper files and directories
manually. Verify that each item belongs to OSS Helper before deleting it; an
`oss-*` wildcard can also match unrelated skills or commands.

## Upgrading

Plugins currently follow the latest committed packages on `main`; these steps
update that source rather than select a numbered plugin release. Git-hosted
marketplace users do not need to clone the repository or run the builder.

### Claude Code

Refresh the marketplace, then update the installed plugin:

```bash
claude plugin marketplace update ai-agents-oss-helper
claude plugin update oss-helper@ai-agents-oss-helper
```

Start a new Claude session to load the updated plugin.

### Codex

Refresh the marketplace snapshot, then install the updated package:

```bash
codex plugin marketplace upgrade ai-agents-oss-helper
codex plugin add oss-helper@ai-agents-oss-helper
```

Start a new Codex session to load the updated skills.

### Gemini CLI

For skills installed from Git, repeat the native installation command:

```bash
gemini skills install https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git --path plugin/skills
```

For an extension installed from a local build, update its source checkout and
rebuild before refreshing the installed copy:

```bash
git pull --ff-only
./build.sh gemini
gemini extensions update oss-helper
```

Confirm replacement or update prompts, then restart Gemini.

### Compatibility and local installations

From your source checkout, update and rerun the installer for the agent you use:

```bash
git pull --ff-only
./install.sh codex
```

Replace `codex` with `claude`, `bob`, `gemini`, `opencode` or `agy`, or omit it to
update all six. No uninstall step is required. For remote-script installations,
rerun the unpinned installation command above. Omit `--version` and unset
`OSS_HELPER_VERSION` when you want to follow `main`.

If you registered a local checkout as a marketplace during testing, run
`git pull --ff-only` and `./build.sh claude` there. Restart Claude to reload its
local bundle; for Codex, rerun `codex plugin add oss-helper@ai-agents-oss-helper`
and start a new session. The Git marketplace refresh steps above are not needed
for local sources. For Bob Shell extension installations, use your client's
extension updater; that update path remains unverified here. Older Bob clients
can use `./install.sh bob`.

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
2. **Installed fallback rules** - A subdirectory under the agent's local rules directory (for example `~/.claude/oss-helper/rules/<project>/`) whose `project-info.md` declares a matching `Remote pattern`. Install these on demand with the Install Info guideline. Claude and Bob keep them under `oss-helper/rules/`, not `~/.claude/rules/`, because Claude Code loads every file under `~/.claude/rules/` into every session in every repository. Legacy rule sets remain readable in the old location; move them to `oss-helper/rules/` manually to stop Claude from preloading them.
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files in `.oss-ai-helper-rules/` so they can be committed and shared.

Projects should adopt project-local rules so that configuration travels with the repository and stays in sync across all contributors and agents.

### Where the rules come from

Project rules are not bundled with the plugin. They live in a separate repository, [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects), and are installed on demand via the Install Info guideline. This keeps the helper focused on guidelines and lets projects that prefer not to host AI-agent metadata in their source tree have rules hosted centrally instead.

### Helper scripts

Deterministic steps ship as read-only scripts installed next to the guidelines, so a guideline runs them in one call instead of a series of tool calls. Each guideline keeps its manual steps as the fallback, for agents that cannot run them.

- `oss-init.sh` (in every skill) detects the project, prints its rule files and checks their version: initialization steps 1-3.
- `pr-report.sh` (`oss-review`) prints the tables of the List PRs, List PR Status and PR Status guidelines, each from one `gh` call. With `--state <file>` it prints `UNCHANGED` when nothing changed since the previous run. `watch` waits in the background and exits only when something changed, so a loop does not wake the agent for nothing.
- `skip-list.sh` (`oss-security`) filters CVE candidates against the unmappable skip list and adds entries to it.

## Capabilities

The OSS Helper provides guidelines for the following tasks. For agents with skill support (Claude, Bob, Codex, agy), just describe what you want in natural language or use the `/oss-*` command directly. For other agents, use the corresponding command.

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
# With Claude, Bob, Codex, or agy — just ask naturally:
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

Each node is a separate subagent. The mechanical ones (the loader, the persistence step, the issue creation, the final reply and the PR publishing) run on cheaper models; pass `economy=off` to run everything on the session model. The loader starts from `security-case-probe.sh`, a read-only script installed with the skill that prints the clone facts, the rule files, the environment, the operator preferences and the case files, with the node files reduced to the fields the workflow routes on; run it by hand to see what the workflow will read.

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

## Fewer Questions, Smaller Sessions

An agent re-reads its whole conversation on every turn, and an answer that comes back more than an hour later also makes it re-cache all of it. Three things keep a run from dragging a long conversation along:

- **Report commands run in a fork (Claude Code).** `/oss-list-prs`, `/oss-list-pr-status`, `/oss-pr-status`, `/oss-list-issues`, `/oss-analyze-issue` and `/oss-workspace-status` run in a forked sub-agent (`context: fork`). It starts from the guideline alone, its tool calls stay out of your session, and only the report comes back.
- **Preferences answer the recurring questions.** Put your defaults in `~/.config/oss-helper/preferences.md` (or `$OSS_HELPER_PREFS`), and the guidelines stop asking:

  ```markdown
  - **Commit signing:** -S -s
  - **Reactor build:** skip-tests
  ```

  `sign=` and `build=` override them for one run, for example `/oss-fix-issue 42 sign=none build=full`. A project rule that requires signed commits still wins.
- **Gates can be answered later.** Before asking to post a review, merge a PR, create an issue or apply an address-review plan, the guideline saves a checkpoint under `~/.local/state/oss-helper/checkpoints/`. Answer from a fresh session with `resume`, for example `/oss-review-pr 42 resume` or `/oss-merge-pr 42 resume`. The guideline checks the PR again first, and starts over if it changed.

## Agent-Specific Notes

### Claude, Bob, agy

Claude uses the marketplace plugin and its namespaced commands. Bob and agy use
6 user-invocable skills copied to `~/.{agent}/skills/oss-{issues,review,ci,security,project,qe}/` plus individual `/oss-*` commands in `~/.{agent}/commands/`. You can either describe what you want in natural language (the agent matches it to a skill automatically), invoke a skill group (e.g. `/oss-issues`), or invoke a specific command directly (e.g. `/oss-fix-issue 42`).

In Claude Code the individual commands are installed with `disable-model-invocation: true`: you type them, but their descriptions stay out of the model's context in every session. Requests in natural language reach the same guidelines through the skill groups. The sub-agent descriptions are kept to a sentence or two for the same reason, since Claude Code lists them in every session too.

The Claude plugin also bundles the workflows in `workflows/` for Claude Code's
Workflow tool. `/oss-helper:oss-security-case` uses one. Bob and agy follow the
same guideline by hand.

### Gemini CLI

The Gemini target includes six skill groups, native TOML commands, converted
agents and extension metadata. Commands activate their matching bundled skill
and resolve supporting files from that skill directory; inline guidelines
remain available for older clients. The compatibility installer copies these
components under `~/.gemini/`. Project rules remain under
`~/.gemini/rules/<project-directory>/`.

### OpenCode

Individual markdown commands with frontmatter are generated and installed to `~/.config/opencode/commands/`. Each command includes a preamble for project rule loading from `~/.config/opencode/rules/<project-directory>/`.

### Codex

Marketplace installs use Codex's managed plugin cache. Compatibility installs
and manual copies use 6 skill directories at `~/.agents/skills/oss-{issues,review,ci,security,project,qe}/` with all guideline files as supporting files. Project rule files are installed to `~/.codex/oss-helper/rules/`.

If Codex reports a missing `~/.codex/oss-helper/.oss-init.md`, remove the legacy installation with `./uninstall.sh --yes codex`, build and copy the current Codex bundle, then start a new session. Current skills use their bundled `init.md`.

## Project Structure

```text
ai-agents-oss-helper/
├── install.sh                              # Compatibility installation wrapper
├── build.sh                                # Local asset builder
├── uninstall.sh                            # Legacy installation cleanup
├── .claude-plugin/                         # Claude marketplace catalog
├── .agents/plugins/                        # Codex marketplace catalog
├── bob-extension.json                      # Generated Bob Shell adapter manifest
├── BOB.md                                  # Generated Bob Shell skill routing
├── packaging/                              # Plugin metadata template
├── plugin/                                 # Shared native plugin bundle (committed)
├── build/                                  # Other generated targets (ignored)
├── README.md
├── workflows/                              # Claude Code workflows (installed for Claude only)
│   └── oss-security-case.js               # Security report lifecycle graph
├── tests/
│   └── workflows/
│       └── oss-security-case.test.mjs     # Routing test with mocked agents
└── skills/
    ├── _shared/
    │   ├── init.md                         # Shared initialization logic
    │   └── oss-init.sh                     # Initialization steps 1-3 in one read-only call
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
    │   ├── backport-pr.md                 # Backport a merged PR
    │   └── pr-report.sh                   # One-call PR tables for list-prs, list-pr-status, pr-status
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
    │   ├── skip-list.sh                   # Filter and extend the unmappable-CVE skip list
    │   ├── skip_cves_apache_unmappable.txt # CVEs proven unmappable to a package
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

## Releases and versioning

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Notable changes are recorded in [`CHANGELOG.md`](CHANGELOG.md).

The marketplaces track `main`. The Claude manifest and Claude marketplace entry
intentionally omit `version`, so Claude uses the installed directory's commit SHA
to detect updates between releases. Do not add a fixed version to those files.
The portable plugin and Gemini/Bob extension manifests use a deterministic
prerelease version derived from the assembled package content and templates, so
changes produce a new version without a fixed release number.
See [Claude plugin version resolution](https://code.claude.com/docs/en/plugins/loading#how-claude-code-computes-the-version).
Claude validation reports an advisory about the omitted version; this is
intentional, so `--strict` treats that advisory as a failure.
Before tagging a release, run `./build.sh claude` and commit any regenerated
`plugin/` output and root `bob-extension.json` / `BOB.md`. Do not edit generated versions
manually.

Releases are cut by pushing a `vMAJOR.MINOR.PATCH` tag (for example `v1.0.0`). A
GitHub Actions workflow (`.github/workflows/release.yml`) then publishes the
matching [GitHub Release](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/releases)
with generated notes. The marketplace reads the committed Claude bundle; local
builds use the checked-out source version.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify guideline files in the appropriate `skills/oss-*/` directory
4. Update `build.sh` if adding new files
5. For a Claude Code workflow, add the script to `workflows/` (its `meta.name` must match the file name), list it in `WORKFLOW_FILES` in `build.sh`, give it a guideline that also works by hand for the other agents, and add a test under `tests/workflows/`
6. Run `./build.sh claude` and include updated `plugin/`, `bob-extension.json` and `BOB.md`
7. Submit a pull request

## License

Apache License 2.0

---

[GitHub Repository](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper)
