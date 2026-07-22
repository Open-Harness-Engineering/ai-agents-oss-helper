---
name: ci-triage
description: >
  Classify a CI failure as flake, regression, or infrastructure issue.
  Parse CI logs, identify the failing job/step, correlate with recent commits,
  and recommend an action (fix, skip, escalate).
user-invocable: true
---

# CI Triage Skill

Classify a single CI failure and recommend an action.

## Inputs

- CI run ID or URL
- Branch name
- Failing job name (if known)
- Error log excerpt (if available)
- **UPSTREAM_REPO** (from init)

## Process

### 1. Fetch Failure Details

```bash
# Get failed jobs from the run
gh run view <RUN_ID> --repo $UPSTREAM_REPO \
  --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion}'

# Get the log for failed jobs
gh run view <RUN_ID> --repo $UPSTREAM_REPO --log-failed 2>/dev/null | tail -500
```

### 2. Parse the Error

Extract:
- **Test class and method** (if test failure): from `Tests run:` / `Failed:` lines
- **Error type**: `AssertionError`, `TimeoutException`, `CompilationError`, etc.
- **Stack trace**: first 10 lines of the relevant stack trace
- **Module**: which build module failed

### 3. Classify

**Flake indicators** (classify as `flake`):
- Test has `@Flaky` or `@DisabledOnCI` annotation
- Error is timing-related: `TimeoutException`, `ConnectException`, `BindException`
- Same test alternates pass/fail across recent runs
- Error mentions port conflicts, connection refused, socket timeout
- Test is in an integration test module with external service dependency

**Infrastructure indicators** (classify as `infra`):
- `OutOfMemoryError` in the runner (not in the test)
- Docker/container registry errors: `rate limit`, `manifest unknown`, `toomanyrequests`
- Dependency download failures: `Could not transfer artifact`, `Could not resolve`
- CI service errors: `RUNNER_FAILED`, `TIMEOUT`
- Disk full: `No space left on device`

**Regression indicators** (classify as `regression`):
- Compilation error in recently changed code
- New test failure not seen in prior 10 runs
- `AssertionError` with clear logic bug (not timing)
- Failure correlates with a commit that touched the failing module

### 4. Find Culprit (for regressions)

```bash
# Last green SHA
LAST_GREEN=$(gh run list --repo $UPSTREAM_REPO --branch <branch> \
  --workflow "$CI_WORKFLOW" --limit 20 \
  --json headSha,conclusion \
  --jq '[.[] | select(.conclusion == "success")][0].headSha')

# Commits between last green and failing SHA
git log --oneline $LAST_GREEN..<FAILING_SHA> -- <module-path>
```

For each candidate commit, check if it touched files related to the failure:
```bash
git show --stat <commit-sha> | grep -i <failing-class-or-module>
```

### 5. Recommend Action

| Classification | Action | Details |
|---------------|--------|---------|
| `flake` | `skip` | Log in STATE.md, do not attempt fix |
| `infra` | `escalate` | Log in STATE.md Escalated section |
| `regression` (< 5 files scope) | `fix` | Spawn implementer sub-agent |
| `regression` (> 5 files scope) | `escalate` | Too large for automated fix |
| `regression` (3+ prior attempts) | `escalate` | Circuit breaker tripped |

## Output

```markdown
## CI Triage: <job-name>

- **Branch:** <branch>
- **Run:** <run-id>
- **SHA:** <sha>
- **Classification:** flake | regression | infra
- **Confidence:** high | medium | low
- **Error:** <one-line summary>
- **Module:** <build-module>
- **Failing test:** <class#method> (if applicable)
- **Culprit commit:** <sha> "<message>" (if regression)
- **Action:** fix | skip | escalate
- **Reason:** <why this classification and action>
```

## Rules

- Default to `escalate` when uncertain -- false negatives (missing a real issue)
  are worse than false positives (escalating a flake).
- Never classify a compilation error as a flake.
- Never classify a new test failure (not seen in last 10 runs) as a flake
  without strong evidence.
- If the same failure appears on multiple branches, classify once and apply
  the classification to all affected branches.
