### 1. Identify the Pull Request

- If a PR number or URL is provided, use it.
- If omitted, detect from the current branch:

  ```bash
  gh pr view --repo <GITHUB_REPO> --json number,url --jq '.number'
  ```

- If no PR is found, abort: "No pull request found for the current branch."

### 2. Pre-merge Checks

Run ALL of the following checks. If ANY check fails, abort and report which checks failed.

#### 3.1 CI Status

```bash
gh pr checks <number> --repo <GITHUB_REPO>
```

Verify all checks have passed (no failures or pending checks). If any check is failing or still pending, abort: "CI is not green. Failing/pending checks: ..."

#### 3.2 Unresolved Discussions

```bash
gh api repos/{owner}/{repo}/pulls/<number>/reviews
```

Check for:

- Reviews with state `CHANGES_REQUESTED` that haven't been followed by an `APPROVED` from the same reviewer.
- Unresolved review threads.

If there are unresolved conversations or outstanding change requests, abort: "Unresolved discussions found: ..."

#### 3.3 Approvals

```bash
gh pr view <number> --repo <GITHUB_REPO> --json reviews --jq '[.reviews[] | select(.state=="APPROVED")] | map(.author.login) | unique'
```

Verify the PR has the required number of approvals. Check the project's `project-guidelines.md` for the approval policy. If not specified, require at least **1 approval**.

If insufficient approvals, abort: "Only N approval(s) found. Need at least M."

### 3. Understand the Full Changeset

#### 4.1 Read PR Context

- Read the PR description and all commit messages:

  ```bash
  gh pr view <number> --repo <GITHUB_REPO> --json title,body,commits,headRefName
  ```

- Read the full diff:

  ```bash
  gh pr diff <number> --repo <GITHUB_REPO>
  ```

#### 4.2 Check Git History

Understand what the branch contributes in context of the project history:

```bash
# Full commit log on the branch
git log --oneline main..HEAD

# Summary of changes by file
git diff --stat main...HEAD
```

#### 4.3 Identify Linked Issue

- Extract the issue/ticket reference from the branch name, PR title, or PR body.
- For GitHub projects: look for `#<number>`, `Fix #<number>`, `Closes #<number>`.
- For Jira projects: look for `<PROJECT>-<NUMBER>` patterns.

If a linked issue is found, fetch its details for context.

### 4. Write the Merge Commit Message

Compose a squash-merge commit message following the commit format from the project's `project-guidelines.md`.

General structure:

```text
<prefix>: Short title (under 70 chars)

<Description of the changes in 200 words max. Explain WHAT changed and WHY.
Focus on the purpose and impact, not a file-by-file listing.>

Closes #<PR number>
```

The `<prefix>` depends on the project conventions (e.g., issue ID for Jira projects, `Fix #N` for GitHub projects, or a conventional commit prefix).

### 5. Confirm with User

Present the following for approval before proceeding:

- Pre-merge check results (all passed)
- The composed commit message
- Merge strategy (squash)

**Wait for explicit user approval.**

### 6. Merge

Execute the squash merge:

```bash
gh pr merge <number> --repo <GITHUB_REPO> --squash --subject "<title>" --body "<body>" --delete-branch
```

Verify the merge succeeded:

```bash
gh pr view <number> --repo <GITHUB_REPO> --json state --jq '.state'
```

### 7. Cleanup

- Confirm the remote branch was deleted.
- If the local branch matches the PR branch, switch to `main` and pull:

  ```bash
  git checkout main && git pull
  ```

### 8. Constraints

You MUST:

- Run all pre-merge checks before proceeding
- Abort immediately if any check fails
- Present the commit message for user approval before merging
- Use squash merge (unless the project's `project-guidelines.md` specifies otherwise)
- Delete the remote branch after merge

You MUST NOT:

- Merge with failing CI
- Merge with unresolved review discussions
- Merge without sufficient approvals
- Merge without user confirmation
- Force-merge or bypass branch protections

### 9. Acceptance Criteria

- All pre-merge checks passed
- User approved the commit message
- PR is merged with a clean squash commit
- Remote branch is deleted
- Local branch is switched to `main` (if applicable)
