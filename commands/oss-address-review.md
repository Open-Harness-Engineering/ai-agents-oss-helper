# Address Review Feedback

Address review feedback on a pull request: read comments, categorize them, fix issues, reply to reviewers, and update the PR.

## Usage

```bash
/oss-address-review [pr]
```

**Arguments:**
- `[pr]` - Pull request number or full GitHub URL (optional). If omitted, detects the PR for the current branch.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (`project-info.md`, `project-standards.md`, `project-guidelines.md`) is loaded.

### 2. Identify the Pull Request

- If a PR number or URL is provided, use it.
- If omitted, detect from the current branch:
  ```bash
  gh pr view --repo <GITHUB_REPO> --json number --jq '.number'
  ```
- If no PR is found, abort: "No pull request found for the current branch."

### 3. Gather Review Feedback

Fetch all review activity:

```bash
# PR reviews (approve, request changes, comment)
gh api repos/{owner}/{repo}/pulls/<number>/reviews

# Inline review comments (file/line-specific)
gh api repos/{owner}/{repo}/pulls/<number>/comments

# General issue comments
gh api repos/{owner}/{repo}/issues/<number>/comments
```

Focus on comments from the **latest review round** (comments posted after the most recent push to the PR branch).

### 4. Understand Context via Git History

Before addressing feedback, understand why the code was written the way it is:

```bash
# Recent changes to the files mentioned in review comments
git log --oneline -15 -- <commented-files>

# Authorship and intent of the specific lines under discussion
git blame -L <start>,<end> -- <file>
```

This helps determine whether a reviewer's suggestion conflicts with a prior intentional decision, and provides context for drafting informed replies.

### 5. Categorize Comments

For each unresolved comment, classify as:

| Category | Description | Action |
|----------|-------------|--------|
| **Blocking** | Explicit change requests, correctness issues, missing tests | Must fix |
| **Suggestion** | Optional improvements, alternative approaches | Apply if beneficial, otherwise reply with reasoning |
| **Question** | Reviewer asking for clarification | Reply with explanation |
| **Resolved** | Already addressed or acknowledged | Skip |

### 6. Present Summary

Present all unresolved comments grouped by category (blocking first):

For each comment, show:
- Reviewer name
- File and line reference
- Comment text
- Proposed action (fix, reply, or decline with reason)
- Any git history context that informs the response

**Wait for user approval before making changes.**

### 7. Address Blocking Issues

- Check out the PR branch if not already on it.
- Address each blocking comment with a code change.
- For questions, draft a reply explaining the reasoning.

### 8. Consider Suggestions

- Apply suggestions that genuinely improve the code without over-engineering.
- For declined suggestions, draft a polite reply explaining why (cite git history, design decisions, or project conventions when relevant).

### 9. Build and Verify

Run the build and test commands from the project's `project-standards.md`:

- Build affected modules
- Run tests
- Run formatter
- Regenerate downstream artifacts if needed
- Check `git status` and commit all changes

### 10. Push and Reply

#### 10.1 Commit and Push

Commit with a message summarizing what was addressed:

```bash
git add <changed-files>
git commit -m "<issue-prefix>: Address review feedback"
git push
```

Use the commit format from the project's `project-guidelines.md`.

#### 10.2 Reply to Comments

For each addressed comment:
- Reply confirming the fix with a brief explanation.
- For questions, post the drafted reply.

#### 10.3 Update PR Description

Update the PR description to reflect any changes in approach or scope resulting from the review:

```bash
gh pr edit <number> --repo <GITHUB_REPO> --body "..."
```

### 11. Constraints

You MUST:
- Present all findings and proposed actions before making changes
- Wait for user approval before implementing fixes
- Reply to every unresolved comment (fix or explain why not)
- Use git history to inform responses when relevant
- Follow the build, format, and commit conventions from the project's rule files

You MUST NOT:
- Resolve review conversations — let the reviewer resolve them after checking
- Ignore blocking comments
- Make unrelated changes while addressing feedback
- Reply dismissively to suggestions — acknowledge the reviewer's perspective even when declining

### 12. Acceptance Criteria

- All blocking comments are addressed with code changes
- All unresolved comments have replies
- Build and tests pass after changes
- PR description is updated to reflect current state
- No review conversations were resolved by the author
