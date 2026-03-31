# List PR Status

List all your open pull requests in the current project's repository with a summary of their CI, review, and merge readiness status.

## Usage

```
/oss-list-pr-status
```

**Arguments:**
- None

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Determine Current User

Get the authenticated GitHub user:

```bash
gh api user --jq '.login'
```

### 3. List Open Pull Requests

Fetch all open PRs authored by the current user in the project's repository:

```bash
gh pr list --repo <GITHUB_REPO> --author @me --state open --json number,title,headRefName,baseRefName,isDraft,createdAt,updatedAt,reviewDecision
```

If no open PRs are found, inform the user:
> No open pull requests found for your account in this repository.

### 4. Retrieve CI Status for Each PR

For each open PR, fetch the CI check summary:

```bash
gh pr checks <PR_NUMBER> --repo <GITHUB_REPO>
```

Classify the overall CI status as:
- **passing** - All checks passed
- **failing** - One or more checks failed
- **pending** - One or more checks still running, none failed
- **none** - No CI checks configured

### 5. Present Summary Table

Provide a summary table of all open PRs:

```markdown
## Your Open PRs in <GITHUB_REPO>

| # | Title | Branch | CI | Reviews | Draft | Updated |
|---|-------|--------|----|---------|-------|---------|
| <number> | <title> | <head> -> <base> | <passing/failing/pending/none> | <approved/changes requested/pending/none> | <yes/no> | <date> |

**Total:** <N> open PR(s)
```

### 6. Highlight PRs Needing Attention

After the table, list PRs that need action, grouped by reason:

```markdown
### Needs Attention

**Failing CI:**
- #<number> - <title> — use `/oss-pr-status <number>` for details

**Changes Requested:**
- #<number> - <title> — use `/oss-pr-status <number>` for details

**Merge Conflicts:**
- #<number> - <title> — rebase onto <base> branch
```

If all PRs are in good shape, report:
> All your PRs are in good shape. No action needed.

### 7. Suggest Next Steps

- For any PR needing attention, suggest using `/oss-pr-status <number>` to get the full status report
- For PRs with failing CI, suggest `/oss-fix-ci-errors` as a follow-up
- For PRs with changes requested, suggest reviewing the feedback via `/oss-pr-status <number>`

### 8. Constraints

You MUST:
- Only list PRs authored by the current user
- Present all PRs in a single summary table
- Clearly highlight PRs that need attention
- Reference `/oss-pr-status` for detailed inspection of individual PRs

You MUST NOT:
- Merge, close, or modify any PR
- Dismiss reviews or re-request reviews
- Make changes to any code
- List PRs from other authors

### 9. Acceptance Criteria

- All open PRs by the current user are listed with CI and review status
- PRs needing attention are clearly highlighted with reasons
- Next steps reference `/oss-pr-status` for detailed follow-up
- Report is concise and easy to scan
