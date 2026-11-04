---
title: "Find commands and skill groups"
description: "Look up OSS Helper capabilities, choose among the six skill groups and open the generated command and workflow catalog for summaries and usage examples."
---

# Find commands and skill groups

Look up OSS Helper capabilities, choose among the six skill groups and open the generated command and workflow catalog for summaries and usage examples.

## Before you begin

Check [agent support and paths](agent-support.md) for differences between native plugins and compatibility installations.

## Skill groups

The 37 guidelines are organized into 6 focused skills:

- **`/oss-issues`** — Issue lifecycle: fix, analyze, create, list, find tasks, triage, cross-repo issues
- **`/oss-review`** — PR lifecycle: review, address feedback, batch review, status, merge, backport
- **`/oss-ci`** — CI/CD and code quality: fix CI errors, SonarCloud, GitHub alerts, quick fixes
- **`/oss-security`** — Security: triage reports, drive a report end to end, analyze CVEs, draft advisories, sync the GitHub Advisory Database, scan code
- **`/oss-project`** — Project setup: add projects, install/generate/update rules, workspaces
- **`/oss-qe`** — Quality engineering: create and execute test plans, deep module audits

Each skill is user-invocable — you can invoke it directly via `/oss-issues`, `/oss-review`, etc. or the agent can auto-invoke it when your request matches. Individual `/oss-*` commands (e.g. `/oss-fix-issue`) are also available as thin wrappers that delegate to the appropriate skill.

## Commands

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

## Generated catalog

Browse the [generated command and workflow reference](https://open-harness-engineering.github.io/ai-agents-oss-helper/) for fuller summaries and usage examples. Its sources are the [command registry](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/build.sh), [reference data](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/docs/reference.json), [skill descriptions](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/tree/main/skills) and [workflow metadata](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/tree/main/workflows).

## Next steps

- [Reference guides](index.md) for the section map.
- [Run maintenance tasks](../use/run-tasks.md) for issue, review and backport examples.
- [Drive a security case](../use/security-case.md) for the maintainer-gated workflow.
