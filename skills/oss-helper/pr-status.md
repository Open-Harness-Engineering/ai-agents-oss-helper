### 1. Parse Input

Determine the pull request to inspect:

- If a number is provided: use as-is
- If a full URL (e.g., `https://github.com/org/repo/pull/42`): extract the number from the path
- If omitted: detect from the current branch

  ```bash
  gh pr view --repo <GITHUB_REPO> --json number --jq '.number'
  ```

  If no PR is associated with the current branch, **STOP** and inform the user:
  > No pull request found for the current branch. Please provide a PR number or URL.

### 2. Retrieve PR Details

Fetch the pull request metadata:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,state,isDraft,mergeable,baseRefName,headRefName,author,reviewDecision,reviewRequests,labels,milestone,createdAt,updatedAt
```

### 3. Retrieve CI Check Status

Fetch the status of all CI checks:

```bash
gh pr checks <PR_NUMBER> --repo <GITHUB_REPO>
```

### 4. Retrieve Reviews

Fetch review details:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json reviews --jq '.reviews[] | {author: .author.login, state: .state, submittedAt: .submittedAt}'
```

### 5. Retrieve Comments

Fetch recent comments for context on any open discussion:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --comments
```

### 6. Present Status Report

Provide a structured status report to the user:

```markdown
## PR Status: #<NUMBER> - <TITLE>

### Overview
- **State:** <open/closed/merged>
- **Draft:** <yes/no>
- **Author:** <author>
- **Branch:** <head> -> <base>
- **Created:** <date>
- **Updated:** <date>
- **Mergeable:** <yes/no/conflicting>

### CI Checks
| Check | Status | Details |
|-------|--------|---------|
| <name> | <pass/fail/pending> | <details if failed> |

**Overall:** <all passing / X of Y passing / X failing / pending>

### Reviews
- **Decision:** <approved/changes requested/review required/none>
- <reviewer>: <state> (<date>)

### Pending Actions
<List of things blocking merge, e.g.:>
- [ ] Failing CI checks
- [ ] Pending reviews
- [ ] Merge conflicts
- [ ] Draft status

### Recent Comments
<Summary of last 3-5 comments if relevant discussion exists, otherwise "No recent discussion.">
```

### 7. Suggest Next Steps

Based on the status, recommend actions:

- **Failing CI checks**: Suggest the Fix CI Errors guideline (`fix-ci-errors.md`) with the failed run ID
- **Changes requested**: Summarize what reviewers asked for
- **Merge conflicts**: Suggest rebasing onto the base branch
- **Draft PR**: Suggest marking as ready for review if appropriate
- **All clear**: Inform the user the PR is ready to merge

### 8. Constraints

You MUST:

- Present all information clearly and structured
- Include CI check details, especially for failures
- Summarize review feedback accurately
- Identify all blockers preventing merge

You MUST NOT:

- Merge or close the PR (status check only)
- Modify the PR in any way
- Dismiss reviews or re-request reviews
- Make changes to any code

### 9. Acceptance Criteria

- PR status is fully reported with CI, review, and merge readiness details
- All blocking items are clearly identified
- Actionable next steps are suggested
- Report is concise and easy to scan
