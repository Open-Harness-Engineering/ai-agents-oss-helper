---
name: babysit-pr
description: >
  Babysit a PR from creation to merge. Monitors CI, fixes failures,
  undrafts when CI is green, addresses review comments, and loops
  until the PR is merged. Uses blocking ETag polling for zero-cost idle.
user-invocable: true
---

# Babysit PR

Continuously monitor and shepherd a PR through its lifecycle until it is
merged. This skill is designed to be used with `/goal` (Claude Code native)
or as the second phase of an issue-fix workflow.

## Usage

```
/goal Babysit PR #1234 on apache/camel
```

Or from a ForgeBot task (after fixing an issue):

```
forge-task <repo> "Fix issue #567, then babysit the PR until merge"
```

## Inputs

The PR number and repo can come from:
- The goal/prompt text (e.g. "babysit PR #1234")
- The current branch (detect from `gh pr view --json number`)
- An argument passed by the calling skill

## Process

### 0. Detect PR

```bash
# From prompt or current branch
PR_NUMBER=<extracted from prompt or detected>
REPO=<from .oss-ai-helper-rules/project-info.md or git remote>

# Get initial PR state
gh pr view $PR_NUMBER --repo $REPO \
  --json number,title,state,isDraft,mergeable,headRefName,statusCheckRollup,reviewDecision,mergedAt
```

If the PR is already merged, report and stop (`[GOAL_COMPLETE]`).
If the PR is closed, report and stop (`[GOAL_BLOCKED]`).

### 1. Main Loop — Wait for Activity

Run the blocking poll script. It returns when something changes on the PR:

```bash
~/.claude/scripts/wait-for-pr-update.sh --pr $PR_NUMBER --repo $REPO
```

The script outputs one or more signals:
- `MERGED` — PR was merged → we're done
- `CLOSED` — PR was closed → we're blocked
- `CI_FAILED` — CI run failed → fix it
- `CI_GREEN` — CI passed → undraft + request reviewers
- `NEW_COMMENTS` — new comments/reviews → address them
- `PUSHED` — new commits → check CI status

### 2. Handle Signals

Based on the signal(s), take action:

#### MERGED

```
[GOAL_COMPLETE]
```

#### CLOSED

```
[GOAL_BLOCKED]
```

#### CI_FAILED

1. Fetch the failed CI run logs:
   ```bash
   gh run list --repo $REPO --branch $HEAD_BRANCH --status failure --limit 1 \
     --json databaseId --jq '.[0].databaseId'
   gh run view <RUN_ID> --repo $REPO --log-failed 2>/dev/null | tail -200
   ```

2. Diagnose the failure:
   - Read the error message
   - Check if it's a flaky test (compare with recent green runs on main)
   - Check if it's a code issue introduced by this PR

3. If fixable:
   - Fix the code
   - Run the relevant tests locally if possible
   - Commit and push:
     ```bash
     git add <files>
     git commit -m "fix: <description of CI fix>"
     git push
     ```

4. If not fixable (infrastructure, flake, unrelated):
   - Add a comment on the PR explaining the failure
   - Continue waiting (next loop iteration)

#### CI_GREEN

1. Check if the PR is still a draft:
   ```bash
   IS_DRAFT=$(gh pr view $PR_NUMBER --repo $REPO --json isDraft --jq '.isDraft')
   ```

2. If draft, undraft it:
   ```bash
   gh pr ready $PR_NUMBER --repo $REPO
   ```

3. Request reviewers (if not already requested):
   ```bash
   # Check if reviewers are already assigned
   REVIEWERS=$(gh pr view $PR_NUMBER --repo $REPO --json reviewRequests --jq '.reviewRequests | length')
   if [[ "$REVIEWERS" == "0" ]]; then
     # Let the project's CODEOWNERS or default reviewers handle it,
     # or request specific reviewers if known from project rules
     gh pr edit $PR_NUMBER --repo $REPO --add-reviewer <default-reviewers>
   fi
   ```

4. Continue waiting for reviews or merge.

#### NEW_COMMENTS

1. Fetch new comments and reviews:
   ```bash
   gh pr view $PR_NUMBER --repo $REPO --json comments,reviews,latestReviews
   ```

2. Categorize each comment:
   - **Review with changes requested** → address each finding
   - **Question** → answer it
   - **Suggestion (GitHub suggestion block)** → evaluate and apply if appropriate
   - **Approval** → note it, continue waiting for merge
   - **Nit / style feedback** → fix if trivial, otherwise note

3. For each actionable comment:
   - Read the relevant code
   - Make the requested change (or explain why not)
   - Push the fix
   - Reply to the comment confirming the change:
     ```bash
     gh api repos/$REPO/pulls/$PR_NUMBER/comments/<ID>/replies \
       --method POST -f body="Fixed in <commit-sha>."
     ```

4. After addressing all comments, push if changes were made.

#### PUSHED

New commits were pushed (possibly by us after a fix). Check the new CI
status — don't take action yet, wait for CI to complete. The next
`wait-for-pr-update.sh` call will return `CI_FAILED` or `CI_GREEN`.

### 3. Loop Back

After handling signals, go back to step 1. The script blocks again until
the next activity.

**Do NOT end with `[GOAL_COMPLETE]` unless the PR is merged.**
**Do NOT end with `[GOAL_BLOCKED]` unless the PR is closed or you cannot
proceed without human input.**

## Constraints

You MUST:
- Wait for the blocking script between actions (zero-cost idle)
- Fix CI failures before undrafting
- Address all review comments before pushing
- Include the issue reference in fix commits (e.g. "fix: address review feedback on #1234")
- Reply to review comments when addressing them
- Undraft only when CI is green

You MUST NOT:
- Merge the PR yourself (human or bot merges)
- Close the PR
- Force-push (use regular push)
- Ignore review comments (address or explain why not)
- Undraft while CI is failing
- Spam reviewers (request review only once after CI goes green, not on every push)
- End with `[GOAL_COMPLETE]` unless PR is merged
