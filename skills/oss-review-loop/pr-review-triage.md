---
name: pr-review-triage
description: >
  Quick triage per PR: CI status, review comments, merge readiness.
  Outputs green/red CI, approval counts, blocking comments, and suggested action.
user-invocable: true
---

# PR Review Triage

Quick triage of a single PR to determine review priority and readiness.

## Inputs

- PR number
- **UPSTREAM_REPO** (from init)

## Process

### 1. Fetch PR Status

```bash
# CI checks
gh pr checks <NUMBER> --repo $UPSTREAM_REPO

# Review status
gh pr view <NUMBER> --repo $UPSTREAM_REPO \
  --json reviewDecision,reviews,labels,mergeable,mergeStateStatus

# Recent activity
gh api repos/$UPSTREAM_REPO/pulls/<NUMBER>/comments --jq 'length'
```

### 2. Assess

- **CI status**: green / red / pending
- **Review state**: approved / changes requested / review required / no reviews
- **Blocking comments**: count of unresolved review threads
- **Merge readiness**: all checks green + approved + no blocking comments
- **Age**: days since creation
- **Size**: additions + deletions

### 3. Suggest Action

| State | Action |
|-------|--------|
| No reviews, CI green | Review (high priority) |
| No reviews, CI red | Skip until CI green |
| Changes requested, updated since | Re-review |
| Already approved by human | Review anyway (verify) |
| Draft | Skip |
| Bot PR | Skip |
| PR idle > 4 days | Suggest human handoff |
| High-risk labels (security, breaking) | Escalate to human |

## Output

```markdown
## Triage: PR #<NUMBER>

- **CI:** green | red | pending
- **Reviews:** <N> approvals, <M> changes requested
- **Blocking:** <K> unresolved threads
- **Merge-ready:** yes | no (<reason>)
- **Priority:** high | medium | low
- **Action:** review | skip | re-review | wait-for-ci | escalate-human
```

## Rules

- "Ready to merge" requires all required checks + approvals per project policy.
- Non-actionable nits: note but do not spawn fix.
- If PR idle > 4 days: suggest human handoff.
- High-risk labels (security, breaking): escalate-human always.
