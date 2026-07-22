---
name: loop-init
description: >
  Initialize ForgeBot loop configuration for a project. Uses
  init-state-branch.sh to create JSON state files on a dedicated branch.
user-invocable: true
---

# Loop Initialization

Sets up the loop configuration for a ForgeBot loop on the current project.

## Prerequisites

- Project must have `.oss-ai-helper-rules/` with project-info, project-standards, and project-guidelines.
- If not present, suggest running `/oss-create-rules` first.

## Process

### 1. Run ForgeBot Init

Follow the initialization steps in `init.md` to detect the project and load rules.

### 2. Ask Which Loop(s)

Ask the user which loop(s) to set up:

1. **CI Sweeper** — monitors CI, classifies failures, proposes fixes as draft PRs
2. **PR Review Loop** — reviews open PRs, posts verified findings
3. **Both**

### 3. Ask for Configuration

For each selected loop, ask:

**CI Sweeper:**
- Watched branches (default: `main` + latest release branch if detectable)
- Cadence (default: 15 minutes)
- Max fix attempts per failure (default: 3)
- Max failures per run (default: 2)
- Max files per fix (default: 5)
- CI workflow name(s) to monitor (detect from `.github/workflows/`)

**PR Review Loop:**
- Cadence (default: 1 hour)
- Max PRs per run (default: 3)
- Review level: L1 (comment only) or L2 (approve/request changes)
- Human gates (e.g. PRs > N lines, security-sensitive paths)

**Shared:**
- Daily token budget (default: 10M)
- State branch name (default: `ci-sweeper-state` or `pr-review-loop-state`)

### 4. Detect CI Workflows

For CI Sweeper, auto-detect available CI workflows:

```bash
ls <repo-root>/.github/workflows/ 2>/dev/null
grep -l 'push:' <repo-root>/.github/workflows/*.yml | head -5
```

### 5. Create State Branch (Deterministic — No LLM)

Run the initialization script:

```bash
~/.claude/scripts/init-state-branch.sh <fork-repo> <state-branch> "<project-name>" <loop-type>
```

This script:
1. Creates the state branch on the fork via GitHub API
2. Pushes initial JSON files: `state.json`, `loop-config.json`, `loop-run-log.json`, `learnings.json`
3. No git checkout needed — uses API exclusively

The generated `loop-config.json` contains all configuration in one file:
cadence, budget, constraints, watched branches (for ci-sweeper), and operator identity.

To customize the generated config after initialization:

```bash
# Pull, edit, push
~/.claude/scripts/pull-state.sh <fork-repo> <state-branch> .
# Edit loop-config.json as needed
~/.claude/scripts/push-state.sh <fork-repo> <state-branch> loop-config.json
```

### 6. Summary

Tell the user:

```
ForgeBot <loop-type> initialized for <project>.

State branch: <state-branch> on <fork-repo>

Files created:
  - state.json         — reviewed PRs, failures, queue (JSON)
  - loop-config.json   — cadence, budget, constraints (JSON)
  - loop-run-log.json  — run history (JSON)
  - learnings.json     — review learnings for self-improvement (JSON)

To start the loop:
  /loop <cadence> /oss-<loop-type>

To pause:
  python3 ~/.claude/scripts/update-state.py state.json pause

To resume:
  python3 ~/.claude/scripts/update-state.py state.json unpause
```
