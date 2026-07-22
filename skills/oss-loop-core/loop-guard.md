---
name: loop-guard
description: >
  Circuit breaker for ForgeBot loops. Before each fix/action attempt, check
  loop-ledger.json; if the same failure has been attempted too many times
  or token budget is exceeded, escalate to a human instead of retrying.
user-invocable: true
---

# Loop Guard (Circuit Breaker)

Prevents any ForgeBot loop from burning tokens on a problem it cannot solve.
Wraps every fix/action attempt with a deterministic circuit-breaker check.

## The Ledger

`loop-ledger.json` records the loop's goal and one entry per attempt:

```json
{
  "goal": "<goal from LOOP.md>",
  "pattern": "<ci-sweeper|review-loop>",
  "level": "L2",
  "attempts": [
    {
      "iteration": 1,
      "failure": "<identifier — test name, PR number, etc.>",
      "action": "<what was tried>",
      "outcome": "failure",
      "error": "AssertionError: expected 200 got 500",
      "tokensUsed": 180000,
      "timestamp": "2026-07-09T10:00:00Z"
    }
  ]
}
```

`outcome` is `success | failure | noop`. Always include `error` on failures.

## Before Each Action Attempt

1. Read `loop-ledger.json`.
2. Count attempts for the **same target** (match by identifier — job name + error signature for CI, PR number for reviews).
3. Check against thresholds (defaults — can be overridden in `loop-budget.md`):
   - **Stagnation:** same error message 3x in a row -> ESCALATE
   - **No progress:** 5 consecutive failures (any target) -> ESCALATE
   - **Iteration cap:** 10 total attempts across all targets -> ESCALATE
   - **Token budget:** sum of `tokensUsed` exceeds daily cap -> ESCALATE
4. Return the decision:

```
LOOP_GUARD: CONTINUE | ESCALATE

If ESCALATE:
  REASON: <stagnation | no-progress | iteration-cap | token-budget>
  DETAILS: <specific counts and thresholds>
  SUGGESTION: <what the human should look at>
```

## After Each Action Attempt

Append the attempt to `loop-ledger.json`:

```json
{
  "iteration": <N>,
  "failure": "<target identifier>",
  "action": "<what was tried>",
  "outcome": "<success|failure|noop>",
  "error": "<error message if failure>",
  "tokensUsed": <estimated tokens>,
  "timestamp": "<ISO8601>"
}
```

## On Escalate

1. Write the escalation into STATE.md "Escalated (human required)" section:
   ```
   - **<target>**: <N> attempts failed. Last error: <error>.
     Recommendation: <suggestion for human>.
   ```
2. Exit the action loop for this target. Do NOT retry.
3. Continue processing other targets if within limits.

## Rules

- Never widen thresholds just to keep looping — escalation is a feature.
- Never edit the ledger to hide a repeated error.
- A verifier rejection counts as a `failure` — log it.
- A flake classification counts as `noop` — log it but don't count toward failure caps.
- Defaults: 3x same error, 5 consecutive failures, 10 iterations total.
