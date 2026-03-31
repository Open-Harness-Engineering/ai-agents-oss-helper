# PR Status

Check the status of a pull request in the current project's repository, including CI checks, review state, and merge readiness.

## Usage

```
/oss-pr-status [pr]
```

**Arguments:**
- `[pr]` - Pull request identifier: number (e.g., `42`), full URL, or omitted to auto-detect from the current branch

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

Determine the pull request to inspect:

- If a number is provided: use as-is
- If a full URL (e.g., `https://github.com/org/repo/pull/42`): extract the number from the path
- If omitted: detect from the current branch

  ```bash
  gh pr view --repo <GITHUB_REPO> --json number --jq '.number'
  ```

  If no PR is associated with the current branch, **STOP** and inform the user:
  > No pull request found for the current branch. Please provide a PR number or URL.

### 3. Retrieve PR Details

Fetch the pull request metadata:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,state,isDraft,mergeable,baseRefName,headRefName,author,reviewDecision,reviewRequests,labels,milestone,createdAt,updatedAt
```

### 4. Retrieve CI Check Status

Fetch the status of all CI checks:

```bash
gh pr checks <PR_NUMBER> --repo <GITHUB_REPO>
```

### 5. Retrieve Reviews

Fetch review details:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json reviews --jq '.reviews[] | {author: .author.login, state: .state, submittedAt: .submittedAt}'
```

### 6. Retrieve Comments

Fetch recent comments for context on any open discussion:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --comments
```

### 7. Present Status Report

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

### 8. Suggest Next Steps

Based on the status, recommend actions:

- **Failing CI checks**: Suggest `/oss-fix-ci-errors <run-id>` with the failed run ID
- **Changes requested**: Summarize what reviewers asked for
- **Merge conflicts**: Suggest rebasing onto the base branch
- **Draft PR**: Suggest marking as ready for review if appropriate
- **All clear**: Inform the user the PR is ready to merge

### 9. Constraints

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

### 10. Acceptance Criteria

- PR status is fully reported with CI, review, and merge readiness details
- All blocking items are clearly identified
- Actionable next steps are suggested
- Report is concise and easy to scan
