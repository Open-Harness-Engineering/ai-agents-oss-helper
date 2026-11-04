---
title: "Find sources and helper scripts"
description: "Locate editable guidelines, agent definitions, workflow tests and generated bundles, and understand the scripts that support maintenance tasks."
---

# Find sources and helper scripts

Locate editable guidelines, agent definitions, workflow tests and generated bundles, and understand the scripts that support maintenance tasks.

## Before you begin

Use [Edit skill sources and regenerate bundles](skill-sources.md) for source and output ownership rules.

## Repository layout

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

## Helper scripts

Deterministic steps ship as read-only scripts installed next to the guidelines, so a guideline runs them in one call instead of a series of tool calls. Each guideline keeps its manual steps as the fallback, for agents that cannot run them.

- `oss-init.sh` (in every skill) detects the project, prints its rule files and checks their version: initialization steps 1-3.
- `pr-report.sh` (`oss-review`) prints the tables of the List PRs, List PR Status and PR Status guidelines, each from one `gh` call. With `--state <file>` it prints `UNCHANGED` when nothing changed since the previous run. `watch` waits in the background and exits only when something changed, so a loop does not wake the agent for nothing.
- `skip-list.sh` (`oss-security`) filters CVE candidates against the unmappable skip list and adds entries to it.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Build bundles locally](build-locally.md) after changing source files.
- [Follow the contribution workflow](contribute.md) to submit source and generated updates.
