# Fix Multi-Repo Issue

Fix an existing issue that requires coordinated changes across multiple repositories in an OSS Helper workspace.

This command extends `/oss-fix-issue` to workspace-aware work. It must produce a cross-repo impact plan before editing, then apply changes repository-by-repository while respecting each repository's own rules, worktree state, validation commands, commit conventions, and PR policy.

## Usage

```
/oss-fix-multi-repo-issue <issue> [root=<path>] [repo=<org/repo> ...] [readonly]
```

**Arguments:**
- `<issue>` - Issue identifier or full issue URL for the canonical issue.

**Options:**
- `root=<path>` - Workspace root containing `.oss-helper-workspace.json`.
- `repo=<org/repo>` - Limit or extend the affected repository set. May be repeated.
- `readonly` - Analyze and plan only. Do not create branches, edit files, commit, push, or open PRs.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file from the current checkout. Then locate and load workspace metadata using the same discovery rules as `/oss-workspace-status`.

If no workspace exists, stop and tell the user to run `/oss-workspace-init` first.

### 2. Parse the Issue

Extract the canonical issue ID from the argument:

**GitHub:**
- Full URL: extract `<org>/<repo>` and issue number from the path.
- Number only: use the primary workspace repository from metadata.

**Jira:**
- Full URL: extract the issue key from the path.
- Issue key only: use the current project's Jira tracker.

If a full URL points to a repository that is not in the workspace metadata, ask whether to add that repository to the workspace before continuing.

### 3. Load Repository Rules

For every workspace repository and every explicit `repo=` repository:

1. Verify the path exists and is a git repository.
2. Load that repository's own rules using `.oss-init.md` priority.
3. Read branch naming, commit format, build/test/format commands, PR policy, issue tracker, and create-issue support.

Keep repository contexts separate. Never apply one repository's rules to another repository.

### 4. Fetch and Analyze the Canonical Issue

Fetch the issue and comments.

**GitHub:**

```bash
gh issue view <ISSUE_NUMBER> --repo <ORG_REPO> --json number,title,body,state,labels,assignees,milestone,comments,url
```

**Jira:**

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/issue/<ISSUE_ID>?fields=summary,description,status,priority,issuetype,components,labels,fixVersions,comment"
```

Read the issue thoroughly and identify:
- Affected repositories named in the body.
- Checklist items per repository.
- Linked child issues.
- Expected validation commands.
- Required merge order.
- Open questions.

Search for linked PRs or sibling issues to avoid duplicating work:

```bash
gh pr list --repo <ORG_REPO> --state all --search "<ISSUE_NUMBER> <title keywords>" --limit 20
```

### 5. Inspect Repositories

For each candidate affected repository:

1. Search for relevant files and terms from the issue.
2. Check current branch, dirty state, and worktree classification:

```bash
git -C <PATH> status --short --branch
git -C <PATH> worktree list --porcelain
```

3. Inspect git history for affected files:

```bash
git -C <PATH> log --oneline -20 -- <affected-files>
git -C <PATH> blame -L <start>,<end> -- <affected-file>
```

4. Determine whether the repository needs changes, only validation, or no action.

If a repository has dirty state, report it in the plan. Do not overwrite or stash it without user confirmation.

### 6. Produce Cross-Repo Impact Plan

Before editing anything, present a plan:

```markdown
## Cross-Repo Impact Plan

**Canonical issue:** <issue-url>
**Workspace:** <workspace-name>

| Repository | Action | Expected files/modules | Checkout strategy | Validation | PR strategy |
|------------|--------|------------------------|-------------------|------------|-------------|
| <org/repo> | change/validate/no action | <paths> | reuse checkout/new worktree/reuse worktree | <commands> | primary/sibling/none |

### Branches and Worktrees

- <org/repo>: <branch>, <checkout/worktree path>, <reason>

### Merge Order

<none or required order>

### Open Questions

- <question>
```

The plan must state:
- Repositories to change.
- Repositories inspected but not changed.
- Expected files/modules.
- Validation command per repository.
- Whether each repository uses the existing checkout, reuses an existing worktree, or creates a new worktree.
- Branch names derived from each repository's guidelines.
- PR relationship strategy and merge order.

Ask the user to approve the plan before editing. If `readonly` is active, stop after the plan.

### 7. Prepare Branches and Worktrees

For each repository to change:

1. If the current path is dirty, ask whether to stop, use another worktree, or continue with the dirty checkout.
2. Derive a branch name from that repository's guidelines. If no multi-repo pattern exists, use the fix-issue pattern and include the canonical issue ID.
3. Avoid duplicate worktrees:

```bash
git -C <PATH> worktree list --porcelain
git -C <PATH> branch --list <BRANCH>
```

4. If a worktree already exists for the branch, reuse it.
5. If a branch exists in another worktree, use that worktree.
6. If creating a new worktree, choose a safe deterministic path under the workspace root:

```text
<workspace-root>/worktrees/<repo-name>/<branch-name>
```

7. Create branches/worktrees only after the user approves the plan.

Example commands:

```bash
git -C <PATH> checkout -b <BRANCH>
git -C <PATH> worktree add -b <BRANCH> <WORKTREE_PATH> <BASE_BRANCH>
```

Do not create a second worktree for a branch that already has one.

### 8. Implement Repository Changes

Work one repository at a time. For each repository:

1. Re-read the repository's rules before editing.
2. Make the minimal changes needed for that repository's part of the issue.
3. Add or update tests/docs appropriate for that repository.
4. Keep unrelated refactors out of scope.
5. Preserve generated files and formatting expectations described by that repository's standards.

After each repository's changes, summarize what changed before moving to the next repository.

### 9. Validate Each Repository

Run the validation commands from each affected repository's `project-standards.md` in the correct checkout or worktree path.

If no build/test command exists, run the smallest meaningful static validation available for the changed files, for example:

```bash
bash -n <script>
```

or explain why no validation command exists.

Do not run a validation command from the main checkout when the changes were made in a worktree.

### 10. Commit Per Repository

For each changed repository:

1. Inspect `git status`.
2. Include only files related to that repository's part of the fix.
3. Use that repository's commit message format, referencing the canonical issue.
4. Ask whether to sign the commit with `-S`, use `-s`, both, or neither.
5. Commit from the correct checkout or worktree path.

Do not combine changes from different repositories into one commit.

### 11. Push and Open PRs

For each changed repository whose rules say to open a PR:

1. Push the branch to that repository's fork or configured remote.
2. Create one PR per changed repository.
3. PR bodies must link:
   - Canonical issue.
   - Child issue for that repository, if any.
   - Sibling PRs in other repositories.
   - Required merge order, if any.
   - Validation commands and outcomes.
4. PR bodies must end with an agent attribution footer:

```text
Generated by Codex via /oss-fix-multi-repo-issue.
```

If sibling PR URLs are not all known when the first PR is created, update PR bodies or add comments after all PRs are open, but only after confirming the final link text.

### 12. Final Report

Report:
- Repositories changed.
- Branches and worktree paths used.
- Commits created.
- Validation commands and outcomes.
- PR URLs.
- Sibling PR link status.
- Any repositories inspected but left unchanged.
- Any follow-up the user must do manually.

### 13. Constraints

You MUST:
- Initialize project context and workspace metadata first.
- Load and respect each repository's own rules.
- Produce and get approval for a cross-repo impact plan before editing.
- Detect and safely handle git worktrees.
- Avoid creating duplicate worktrees for the same branch.
- Run validation from the actual checkout or worktree where changes were made.
- Create one commit and one PR per changed repository, unless repository rules say otherwise.
- Link canonical issue, child issues, sibling PRs, and merge order in PR bodies.

You MUST NOT:
- Treat all repositories as if they share one build tool, tracker, branch pattern, or PR policy.
- Modify a dirty checkout without surfacing the dirty state and receiving confirmation.
- Reset, clean, remove, or overwrite user changes.
- Push or open PRs before validation and commit.
- Create tracker comments, child issues, or PR-body updates without showing final text when confirmation is required.

### 14. Acceptance Criteria

- The canonical issue is fetched and analyzed.
- Workspace repositories are inspected with independent rules loaded.
- A cross-repo impact plan is approved before edits.
- Branch/worktree handling avoids duplicate worktrees and respects dirty state.
- Each changed repository is validated from the correct path.
- Each changed repository gets its own commit and PR, with cross-links to the issue and sibling PRs.
- The final report gives the user a coherent cross-repo status.
