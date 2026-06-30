### 1. Parse Arguments

Parse the optional arguments into local variables. Use these defaults when an argument is not provided:

| Argument | Default |
|----------|---------|
| `author` | _(none — list all authors)_ |
| `label` | _(none — no label filter)_ |
| `limit` | `20` |
| `include-drafts` | false (drafts are excluded) |
| `exclude-mine` | false (your own PRs are included) |

### 2. Determine Current User

If the `exclude-mine` flag is set, fetch the authenticated GitHub user so that PRs by this user can be filtered out:

```bash
gh api user --jq '.login'
```

### 3. List Open Pull Requests

Build a `gh pr list` invocation using the `--search` flag so multiple criteria can be combined. Always include `is:pr is:open` in the search.

| Condition | Search fragment to add |
|-----------|------------------------|
| Drafts excluded (default) | `-is:draft` |
| `author=<user>` provided | `author:<user>` |
| `exclude-mine` set | `-author:@me` |
| `label=<label>` provided | `label:"<label>"` |

Run:

```bash
gh pr list \
  --repo <GITHUB_REPO> \
  --search "<SEARCH_QUERY>" \
  --limit <LIMIT> \
  --json number,title,author,headRefName,baseRefName,isDraft,createdAt,updatedAt,reviewDecision,labels
```

**Rate limiting:** Make ONE call only. Do NOT poll, refresh, or fetch per-PR CI status — the goal is a fast list. If the user wants deeper detail on a specific PR, they can use the PR Status guideline (`pr-status.md`) after picking.

If no PRs are returned, inform the user:

> No open pull requests matched the requested filters in `<GITHUB_REPO>`.

Suggest dropping a filter (e.g., `include-drafts`, removing `author=`) and stop.

### 4. Present a Numbered Table

Render a numbered list (numbering starts at 1) so the user can pick by index. Include the PR number, title (truncate at ~70 chars), author, branch, current review decision, draft flag, and the updated date.

```markdown
## Open PRs in <GITHUB_REPO>

Filters: <human-readable summary of active filters, e.g. "open, non-draft, label=\"needs review\"">

| # | PR | Title | Author | Branch | Reviews | Draft | Updated |
|---|----|-------|--------|--------|---------|-------|---------|
| 1 | #<number> | <title> | <login> | <head> -> <base> | <approved/changes requested/review required/none> | <yes/no> | <YYYY-MM-DD> |
| 2 | ... | ... | ... | ... | ... | ... | ... |

**Total:** <N> PR(s)
```

Map `reviewDecision` values to readable text:

- `APPROVED` -> `approved`
- `CHANGES_REQUESTED` -> `changes requested`
- `REVIEW_REQUIRED` -> `review required`
- `null` / empty -> `none`

### 5. Highlight Notable PRs (optional)

If any PRs in the list look especially relevant for review, briefly call them out **after** the table — keep this short and only when it adds value:

- PRs with `review required` and no recent activity from a reviewer — likely waiting for someone to pick them up
- PRs with `changes requested` — author may be waiting on clarification
- PRs older than 30 days — possible stale review backlog

If nothing stands out, skip this section.

### 6. Ask the User to Select a PR

Ask the user which PR they want to review. They can answer by:

- The list index (e.g., `2`)
- The PR number (e.g., `#42` or `42`)
- A full GitHub PR URL

If the user does not want to review any of them, stop without further action.

### 7. Hand Off to the Review PR Guideline

Once the user picks a PR, **do not** start the review yourself. Hand off to the Review PR guideline (`review-pr.md`) with the selected PR number.

This keeps the review flow inside the Review PR guideline (`review-pr.md`) (which performs the rules-based review) and avoids embedding two distinct guideline behaviors into one. Mirror the Find Task guideline (`find-task.md`) -> Fix Issue guideline (`fix-issue.md`) handoff pattern.

### 8. Constraints

You MUST:

- Make exactly ONE `gh pr list` call (no per-PR fetches, no polling)
- Apply the documented defaults (open, exclude drafts, include the user's own PRs, limit 20)
- Present results as a numbered table so the user can select by index
- Hand off the review to the Review PR guideline (`review-pr.md`) rather than performing it inline
- Stop gracefully if no PRs match

You MUST NOT:

- Merge, close, comment on, label, or otherwise modify any PR
- Fetch CI checks or detailed reviews for every PR (defer to the PR Status guideline (`pr-status.md`))
- Submit a review on behalf of the user
- List closed or merged PRs
- Repeat the API call to refresh the list within the same invocation

### 9. Acceptance Criteria

- A single `gh pr list` call is made with the requested filters
- All matching open PRs are presented in a numbered table with the documented columns
- The user is prompted to pick a PR and pointed to the Review PR guideline (`review-pr.md`) to perform the review
- No PR is modified or commented on by this command
- The output is concise and easy to scan
