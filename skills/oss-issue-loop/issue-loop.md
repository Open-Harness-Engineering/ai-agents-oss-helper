---
name: issue-loop
description: >
  Issue triage loop. Monitors for open issues, triages deterministically,
  spawns ForgeBot tasks to fix selected issues and babysit the resulting PRs.
user-invocable: true
---

# Issue Loop

Automated loop that discovers open issues, triages them, and dispatches
ForgeBot tasks to fix the most actionable ones. Each spawned task fixes the
issue AND babysits the resulting PR until merge.

## Usage

```
/goal Monitor and fix issues on this project
```

Or with ForgeBot (persistent):

```
/loop 5m --session-ttl 1h issue-loop
```

## Architecture

```
Issue Loop (orchestrator)
  +-- Step 0: Wait for issue activity (ETag blocking)
  +-- Step 1: Init (detect project, load config)
  +-- Step 2: Triage issues (deterministic script)
  +-- Step 3: For each actionable issue:
  |     +-- forge-task <repo> "Fix issue #N, then babysit the PR"
  +-- Step 4: Update state (mark issues as handled)
  +-- Step 5: Push state
  +-- Loop back to step 0
```

The orchestrator does NOT fix issues itself — it triages and dispatches.
Each ForgeBot task runs independently with its own Claude Code session
and worktree.

## Execution Steps

### 0. MANDATORY — Wait for Issue Activity

> **🛑 STOP. Do NOT skip this step. Do NOT proceed to step 1.**
>
> You MUST run the blocking precondition script FIRST. It polls GitHub using
> zero-cost ETag requests and BLOCKS until repo activity is detected.

Run these commands NOW, before reading any further:

```bash
# 1. Detect fork repo and state branch from local config
FORK_REPO=$(git remote get-url fork 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
if [[ -z "$FORK_REPO" ]]; then
  for remote in gnodet origin; do
    FORK_REPO=$(git remote get-url "$remote" 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
    [[ -n "$FORK_REPO" ]] && break
  done
fi
STATE_BRANCH=$(python3 -c "import json; print(json.load(open('loop-config.json'))['state_branch'])" 2>/dev/null || echo "")

# 2. Pull latest state from the fork
if [[ -n "$STATE_BRANCH" ]]; then
  ~/.claude/scripts/pull-state.sh "$FORK_REPO" "$STATE_BRANCH" .
fi

# 3. BLOCK here until repo activity is detected
~/.claude/scripts/wait-for-pr-work.sh --timeout 3600 state.json
```

**Do NOT proceed past this point until the script returns exit 0.**

If it exits with code 1:
- **Output nothing.** Exit immediately.

### 1. Initialize

Run the ForgeBot init steps (read `init.md`):
- Detect project from git remote
- Load project rules from `.oss-ai-helper-rules/`
- Pull latest oss-helper (`git pull`)
- Load state from the state branch

From initialization, you have:
- **UPSTREAM_REPO**: the upstream org/repo
- **FORK_REPO**: the operator's fork
- **MAX_ISSUES_PER_RUN**: from `loop-config.json` (default: 2)

### 2. Triage Issues (Deterministic)

Run the triage script — no LLM needed:

```bash
python3 ~/.claude/scripts/triage-issues.py $UPSTREAM_REPO state.json \
  --max $MAX_ISSUES_PER_RUN \
  --labels bug,help-wanted \
  --format json
```

The script:
- Fetches open issues from GitHub
- Filters out: bots, already-handled, already-skipped, assigned issues
- Prioritizes: bugs > help-wanted > old issues
- Returns JSON array of actionable issues

If exit 1 (no actionable issues), go back to step 0.

### 3. Dispatch Tasks

For each actionable issue, spawn a ForgeBot task:

```bash
forge-task $UPSTREAM_REPO "Fix issue #<NUMBER>: <TITLE>

Read the issue description and comments:
  gh issue view <NUMBER> --repo $UPSTREAM_REPO

Then:
1. Follow /oss-fix-issue to implement the fix
2. Create a PR with the fix
3. Follow /babysit-pr to monitor CI, address reviews, until the PR is merged

Do NOT end until the PR is merged or you are blocked."
```

**Important:**
- Spawn at most `MAX_ISSUES_PER_RUN` tasks per iteration (default: 2)
- Each task gets its own worktree and session — fully isolated
- The babysit phase handles CI fixes, undraft, review addressing
- Do NOT wait for tasks to complete — dispatch and move on

### 4. Update State

Mark dispatched issues as handled:

```bash
for issue_number in <dispatched issues>; do
  python3 ~/.claude/scripts/update-state.py state.json handled-issue \
    --issue $issue_number \
    --notes "Dispatched to ForgeBot task"
done
```

### 5. Push State

```bash
~/.claude/scripts/push-state.sh $FORK_REPO $STATE_BRANCH .
```

### 6. Loop Back

Go back to step 0. The blocking script waits for the next batch of issues.

**Do NOT end with `[GOAL_COMPLETE]` — this loop runs indefinitely.**
Use `[GOAL_BLOCKED]` only if there's an unrecoverable error.

## Configuration

In `loop-config.json`:

```json
{
  "max_issues_per_run": 2,
  "issue_labels": ["bug", "help-wanted"],
  "skip_labels": ["dependencies", "documentation", "wontfix"],
  "issue_tracker": "github"
}
```

## Constraints

You MUST:
- Use the deterministic triage script (no LLM for issue selection)
- Dispatch tasks via `forge-task` (parallel, isolated worktrees)
- Include both `/oss-fix-issue` and `/babysit-pr` in the task prompt
- Update state after dispatching to avoid re-dispatching
- Respect the per-run issue limit

You MUST NOT:
- Fix issues directly in the orchestrator (dispatch only)
- Dispatch issues that are already assigned to someone
- Dispatch more than `max_issues_per_run` per iteration
- Wait for dispatched tasks to complete (fire and forget)
- Close or modify issues from the orchestrator
