---
name: loop-budget
description: >
  Check token budget and run-log spend before and after a loop run.
  Enforces early exit when over budget or when there is no work to do.
user-invocable: true
---

# Loop Budget Guard

Run at the **start** and **end** of every loop iteration.

## Start of Run

1. Read `loop-config.json` for daily caps (`budget.max_tokens_per_day`, `budget.max_runs_per_day`).
2. Read `loop-run-log.json` — sum `tokens_estimate` for entries in the last 24h.
3. If spend >= 80% of daily cap -> **report-only mode** (triage but no action agents).
4. If spend >= 100% or `state.json` has `paused: true` -> **exit immediately**.
5. If there is no work to do (CI green, no PRs to review) -> **exit in < 5k tokens**
   (do not spawn sub-agents when there is nothing actionable).

## End of Run

Record the run via script:

```bash
python3 ~/.claude/scripts/update-state.py state.json run \
  --prs-checked <N> --reviews-posted <M> --tokens <T>
```

## Rules

- Never exceed `budget.max_subagents_per_run` from `loop-config.json`.
- Early-exit when there is no actionable work — do not run the full pipeline.
- All budget/limit values come from `loop-config.json` (JSON, not markdown).
