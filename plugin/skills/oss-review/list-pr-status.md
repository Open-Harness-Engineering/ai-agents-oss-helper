### Fast path: the script

`pr-report.sh`, installed next to this guideline, does steps 1-5 in one `gh` call: it lists your open PRs with their check runs and mergeability, classifies the CI state and the review decision, and prints the summary table and the "Needs Attention" groups:

```bash
bash <directory of this guideline>/pr-report.sh mine --repo <GITHUB_REPO>
```

Present its output as it is and continue with step 6. When the script is missing or prints `ERROR`, follow steps 1-5 by hand.

**Repeated runs.** When this guideline runs on a loop or a schedule, add `--state ~/.local/state/oss-helper/pr-report/<org>__<repo>-mine.txt`. When the script prints `UNCHANGED since <time>`, reply with that one line and stop. To wait for a change without running the guideline at all, start `pr-report.sh watch mine --repo <GITHUB_REPO>` with the same `--state` file in the background (in Claude Code, a background Bash command): it polls every 5 minutes and exits, printing the new report, only when something changed.

### 1. Determine Current User

Get the authenticated GitHub user:

```bash
gh api user --jq '.login'
```

### 2. List Open Pull Requests

Fetch all open PRs authored by the current user in the project's repository:

```bash
gh pr list --repo <GITHUB_REPO> --author @me --state open --json number,title,headRefName,baseRefName,isDraft,createdAt,updatedAt,reviewDecision,mergeable,statusCheckRollup
```

`statusCheckRollup` holds every PR's check runs and `mergeable` its conflict state (`CONFLICTING` means merge conflicts), so step 3 needs no further calls.

If no open PRs are found, inform the user:
> No open pull requests found for your account in this repository.

### 3. Classify CI Status for Each PR

From each PR's `statusCheckRollup` (when a check was re-run, use its latest run), classify the overall CI status as:

- **passing** - All checks passed
- **failing** - One or more checks failed
- **pending** - One or more checks still running, none failed
- **none** - No CI checks configured

### 4. Present Summary Table

Provide a summary table of all open PRs:

```markdown
## Your Open PRs in <GITHUB_REPO>

| # | Title | Branch | CI | Reviews | Draft | Updated |
|---|-------|--------|----|---------|-------|---------|
| <number> | <title> | <head> -> <base> | <passing/failing/pending/none> | <approved/changes requested/pending/none> | <yes/no> | <date> |

**Total:** <N> open PR(s)
```

### 5. Highlight PRs Needing Attention

After the table, list PRs that need action, grouped by reason:

```markdown
### Needs Attention

**Failing CI:**
- #<number> - <title> — use the PR Status guideline (`pr-status.md`) for details

**Changes Requested:**
- #<number> - <title> — use the PR Status guideline (`pr-status.md`) for details

**Merge Conflicts:**
- #<number> - <title> — rebase onto <base> branch
```

If all PRs are in good shape, report:
> All your PRs are in good shape. No action needed.

### 6. Suggest Next Steps

- For any PR needing attention, suggest using the PR Status guideline (`pr-status.md`) to get the full status report
- For PRs with failing CI, suggest the Fix CI Errors guideline (`fix-ci-errors.md`) as a follow-up
- For PRs with changes requested, suggest reviewing the feedback via the PR Status guideline (`pr-status.md`)

### 7. Constraints

You MUST:

- Only list PRs authored by the current user
- Present all PRs in a single summary table
- Clearly highlight PRs that need attention
- Reference the PR Status guideline (`pr-status.md`) for detailed inspection of individual PRs

You MUST NOT:

- Merge, close, or modify any PR
- Dismiss reviews or re-request reviews
- Make changes to any code
- List PRs from other authors

### 8. Acceptance Criteria

- All open PRs by the current user are listed with CI and review status
- PRs needing attention are clearly highlighted with reasons
- Next steps reference the PR Status guideline (`pr-status.md`) for detailed follow-up
- Report is concise and easy to scan
