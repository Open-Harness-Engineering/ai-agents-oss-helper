---
name: ci-sweeper
description: >
  CI sweeper loop. Monitors CI on watched branches, classifies
  failures (flake, regression, infra), and proposes minimal fixes as draft PRs.
  Uses sub-agents for parallel fix and verification with a maker/checker pattern.
  Tracks state in state.json.
user-invocable: true
---

# CI Sweeper Loop

Automated loop that discovers CI failures on watched branches, classifies them,
and proposes minimal fixes. Uses worktree-isolated sub-agents for fixes and
independent verifiers before opening draft PRs.

## Architecture

```
Main loop (orchestrator)
  +-- Step 0: Pre-flight (ETag check + deterministic state load)
  |
  +-- Step 1-3: Discover & classify (inline -- fast, low cost)
  |
  +-- Step 4: Fix (sub-agents, parallel, worktree-isolated)
  |     +-- Implementer agent failure #1 (worktree)
  |     +-- Implementer agent failure #2 (worktree)
  |
  +-- Step 5: Verify (sub-agents, one per fix)
  |     +-- Verifier agent fix #1  <- checks implementer's work
  |     +-- Verifier agent fix #2
  |
  +-- Step 6-8: Open draft PRs, update state, push (deterministic scripts)
```

## Execution Steps

### 0. Pre-flight — Wait for CI Failure

Run the blocking precondition script. It polls the GitHub Events API using
ETag-based conditional requests (free on 304 Not Modified) and only returns
when a CI failure is detected on a watched branch — or when the timeout expires.

This means **zero LLM tokens are consumed while waiting**. The script blocks
the session, not the model.

**With `/goal` (recommended for Claude Code — immediate reactivity):**

```bash
~/.claude/scripts/pull-state.sh $FORK_REPO $STATE_BRANCH .
~/.claude/scripts/wait-for-ci-failure.sh
```

No timeout — blocks indefinitely until a CI failure is detected.

**With `/loop` (recommended for ForgeBot — persistence across restarts):**

```bash
~/.claude/scripts/pull-state.sh $FORK_REPO $STATE_BRANCH .
~/.claude/scripts/wait-for-ci-failure.sh --timeout 900
```

Timeout matches the `/loop` interval. Exit 1 on timeout = skip this tick.

> See the `/goal` vs `/loop` comparison in `review-loop.md` step 0.

If the script exits with code 1 (timeout, all green, or kill switch), all
watched branches are green — **skip this iteration entirely**.

If it exits with code 0, proceed:

1. Run the ForgeBot init steps (read `init.md`) to detect the project and load config.
2. Read `loop-config.json` -- load constraints, budget, cadence, watched branches.
3. Check `state.json` `paused` flag -- if true, exit immediately.

From initialization, you now have:
- **UPSTREAM_REPO**: the upstream org/repo (from `project-info.md`)
- **FORK_REPO**: the operator's fork org/repo
- **OPERATOR_NAME**: for attribution
- **BUILD_CMD**, **TEST_CMD**, **FORMAT_CMD**: from `project-standards.md`
- **WATCHED_BRANCHES**, **CI_WORKFLOW**: from `loop-config.json`

### 1. Discover CI Failures

For each watched branch (from `loop-config.json`), get the latest CI run:

```bash
gh run list --repo $UPSTREAM_REPO --branch $BRANCH \
  --workflow "$CI_WORKFLOW" --limit 1 \
  --json databaseId,status,conclusion,headSha,createdAt \
  --jq '.[0]'
```

If the latest run is `completed` with `conclusion: success` -> CI is green.
Log it and move on to the next branch.

If the latest run is `completed` with `conclusion: failure`:

```bash
# Get failed jobs
gh run view <RUN_ID> --repo $UPSTREAM_REPO \
  --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
```

```bash
# Download the log for the failed run
gh run view <RUN_ID> --repo $UPSTREAM_REPO --log-failed 2>/dev/null | tail -500
```

If the run is still `in_progress` or `queued`, skip this branch.

### 2. Check Against State (Deterministic — No LLM)

Read `state.json` and compare each failure against:

- `active_failures[]` -- same failure (same job name + similar error)?
  If yes, check attempt count. If attempts >= max (from `loop-config.json`),
  escalate instead of retrying.
- `resolved[]` -- was this failure recently resolved but came back? Flag as
  regression of a regression.
- `proposed_fixes[]` -- is there already a draft PR for this failure?
  Check PR status instead of re-attempting.

### 3. Classify Failures

For each new or updated failure, use the `ci-triage.md` skill to classify it as
flake, regression, or infrastructure issue. The triage skill reads the CI logs,
checks recent run history, and correlates with commits.

### 4. Fix Regressions (Parallel Sub-agents)

For each actionable regression (max per run from `loop-config.json`), spawn an
**implementer sub-agent** using the Agent tool with `isolation: "worktree"`.

Each implementer agent prompt must include:

```
You are fixing a CI failure on $UPSTREAM_REPO.

## Failure Details
- Branch: <branch>
- Job: <job-name>
- Error: <error message, truncated to relevant lines>
- Likely culprit commit: <sha> "<message>"
- CI run log (relevant excerpt): <paste relevant log lines>

## Instructions

1. Read the project rules:
   - Read .oss-ai-helper-rules/project-standards.md (build/test commands)
   - Read .oss-ai-helper-rules/project-guidelines.md (conventions)

2. Investigate the failure:
   - Read the culprit commit: git show <sha>
   - Understand what it changed and why
   - Read the failing test(s) and the code they exercise
   - Check git history for context (git log, git blame)

3. Produce the minimal fix:
   - Change only what is necessary to fix the failure
   - Do NOT refactor unrelated code
   - Do NOT disable tests or weaken assertions
   - Max 5 files changed -- if more are needed, STOP and report

4. Run tests:
   - Build the affected module: $BUILD_CMD (scoped to module)
   - Run the specific failing test if identifiable
   - Report the test result

5. Format the code:
   - Run: $FORMAT_CMD (scoped to module)

6. Return your findings:

   STATUS: <fixed|needs-escalation|cannot-fix>
   FIX_SUMMARY: <1-3 sentence description of what you changed and why>
   FILES_CHANGED:
   - <path/to/file> -- <what changed>
   TEST_RESULT: <pass|fail -- command + output snippet>
   RISK: <low|medium|high>

   If STATUS is needs-escalation or cannot-fix, explain why.
```

### 5. Verify Fixes (Parallel Sub-agents)

After all implementer agents complete, spawn a **verifier sub-agent** for each
fix that returned `STATUS: fixed`. Use the `loop-verifier` agent definition.

Each verifier prompt must include:

```
You are verifying a proposed CI fix for $UPSTREAM_REPO.

## Original Failure
- Branch: <branch>
- Job: <job-name>
- Error: <error summary>

## Proposed Fix
- Files changed: <list>
- Summary: <implementer's FIX_SUMMARY>

## Your Job

1. Review the diff in the worktree -- does it address the root cause?
2. Check git history -- does this fix revert prior intentional work?
3. Run the tests: $TEST_CMD (scoped to module)
4. Verify scope -- are only relevant files changed? No drive-by edits?
5. Check for cheating -- no disabled tests, skipped assertions, commented checks?

Return your verdict:

VERDICT: <APPROVE|REJECT|ESCALATE_HUMAN>
EVIDENCE:
- Tests: <command + result>
- Scope check: <pass/fail + notes>
- Root cause addressed: <yes/no + reasoning>

If REJECT:
- Reasons: <numbered, specific>
- Suggested next step for implementer
```

### 6. Open Draft PRs

For each fix where the verifier returned `APPROVE`:

1. Create a branch on the operator's fork:
   ```bash
   git checkout -b ci-fix/<failure-slug> origin/<branch>
   git push fork ci-fix/<failure-slug>
   ```

2. Open a draft PR:
   ```bash
   gh pr create --repo $UPSTREAM_REPO \
     --head $FORK_ORG:ci-fix/<failure-slug> \
     --base <branch> \
     --draft \
     --title "ci: fix <failure-description>" \
     --body "<summary + CI details + verification + attribution>"
   ```

### 7. Update State (Deterministic — No LLM)

```bash
# Record each failure and its outcome
python3 ~/.claude/scripts/update-state.py state.json reviewed \
  --pr <DRAFT_PR_NUMBER> --title "<title>" --author "$(git config user.name)" \
  --verdict COMMENT --notes "CI fix proposed: <summary>"

# Record this run
python3 ~/.claude/scripts/update-state.py state.json run \
  --prs-checked <BRANCHES_CHECKED> --reviews-posted <FIXES_PROPOSED> --tokens <T>
```

### 8. Push State (Deterministic — No LLM)

```bash
~/.claude/scripts/push-state.sh $FORK_REPO $STATE_BRANCH \
  state.json loop-run-log.json learnings.json
```

### 9. Summary

Output a brief summary:

```
## CI Sweeper Complete

- Branches checked: <list>
- Failures found: <N> (<M> regressions, <F> flakes, <I> infra)
- Fixes proposed: <P> draft PRs
- Escalated: <E> failures
- Verifier rejection rate: <X>%
- Next check in: <cadence>
```

## Constraints

You MUST:
- Read state.json before checking CI to track across runs
- Early-exit in < 5k tokens if all branches are green
- Run loop-guard before each fix attempt
- Spawn implementer agents with worktree isolation
- Run verifier agent before opening any PR
- Open all PRs as draft on the operator's fork
- Include AI attribution in all PRs
- Update state.json after every run (via update-state.py)
- Respect the per-run failure limit from loop-config.json
- Use build/test commands from project-standards.md, never hardcode

You MUST NOT:
- Merge, close, or label any PR
- Push to the upstream repo directly
- Fix flaky tests (log and skip)
- Act on infrastructure failures (escalate)
- Disable tests or weaken assertions to go green
- Change more than 5 files per fix (or custom limit from loop-config.json)
- Attempt more than the max fix attempts for the same failure
