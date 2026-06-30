### 1. Parse Input

Extract the PR identifier, the target branch, and the remote from the arguments:

- If a number is provided: use as-is
- If a full URL (e.g., `https://github.com/org/repo/pull/42`): extract the number from the path
- If `branch=` is missing: **STOP** and ask the user:
  > Please specify the target branch. Usage: backport PR `<pr>` branch=`<target-branch>` [remote=`<remote-name>`]
- If `remote=` is provided: use that value as `<REMOTE>`. Otherwise default `<REMOTE>` to `origin`.

Validate that `<REMOTE>` exists in the local clone:

```bash
git remote get-url <REMOTE>
```

If the command fails (remote not found), **STOP** and inform the user:
> Remote `<REMOTE>` is not configured in this clone. Available remotes can be listed with `git remote -v`.

### 2. Validate the Source PR

Fetch the source PR metadata:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,state,mergeCommit,headRefName,baseRefName,body,labels,author
```

Validate:

- The PR **must be merged**. If not, **STOP** and inform the user:
  > PR #<NUMBER> is not merged (state: <state>). Only merged PRs can be backported.
- Extract the merge commit SHA from `mergeCommit.oid`

### 3. Validate the Target Branch

Verify the target branch exists on the remote:

```bash
git ls-remote --heads <REMOTE> <TARGET_BRANCH>
```

If the branch does not exist, **STOP** and inform the user:
> Target branch `<TARGET_BRANCH>` does not exist on remote `<REMOTE>`. Available branches can be listed with `git branch -r`.

### 4. Fetch and Identify Commits to Cherry-Pick

Fetch the latest remote state:

```bash
git fetch <REMOTE> <TARGET_BRANCH>
```

Get the list of commits from the source PR:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json commits --jq '.commits[].oid'
```

This returns the individual commits that were part of the PR (in order). These are the commits to cherry-pick, preserving the original commit history rather than using the squashed merge commit.

If the PR was squash-merged (only one commit returned, or the merge commit differs from the PR commits), use the merge commit SHA instead:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json mergeCommit --jq '.mergeCommit.oid'
```

### 5. Create the Backport Branch

Create a new branch from the target branch:

```bash
git checkout -b backport/<PR_NUMBER>-to-<TARGET_BRANCH_SLUG> <REMOTE>/<TARGET_BRANCH>
```

Where `<TARGET_BRANCH_SLUG>` is the target branch name with `/` replaced by `-` (e.g., `release/1.x` becomes `release-1.x`).

### 6. Cherry-Pick the Commits

Cherry-pick the commits onto the backport branch:

```bash
git cherry-pick <COMMIT_SHA_1> <COMMIT_SHA_2> ...
```

If cherry-pick **succeeds**: proceed to step 8.

If cherry-pick **fails with conflicts**:

1. List the conflicted files:

   ```bash
   git diff --name-only --diff-filter=U
   ```

2. Attempt to resolve the conflicts by reading the conflicted files, understanding the context of both sides, and applying the changes from the source PR in a way that makes sense for the target branch.

3. After resolving each file, stage it:

   ```bash
   git add <file>
   ```

4. Continue the cherry-pick:

   ```bash
   git cherry-pick --continue
   ```

5. If conflicts are **too complex to resolve automatically** (e.g., the target branch has diverged significantly and the changes cannot be applied cleanly), abort the cherry-pick and **STOP**:

   ```bash
   git cherry-pick --abort
   git checkout -
   git branch -D backport/<PR_NUMBER>-to-<TARGET_BRANCH_SLUG>
   ```

   Inform the user:
   > Cherry-pick failed due to conflicts that require manual resolution. Conflicted files:
   > - `<file1>`
   > - `<file2>`
   >
   > You may want to manually cherry-pick and resolve the conflicts.

### 7. Sanity Build (MANDATORY before push)

Follow the build workflow from `_fragments/_build-workflow.md`:

- Read build configuration from `project-standards.md`
- Run full reactor build (Maven projects only, MANDATORY before push)
- Ask user for build mode: (a) skip tests (default for backports) or (b) full tests
- This catches API drift between source and target branches
- Skip for non-Maven projects

If the build fails:

1. Inspect the failure — it usually indicates a missing dependency commit or a signature change on the target branch.
2. Either cherry-pick the missing prerequisite commits, resolve manually, or abort:

   ```bash
   git checkout -
   git branch -D backport/<PR_NUMBER>-to-<TARGET_BRANCH_SLUG>
   ```

   and inform the user which prerequisite is missing.
3. Do NOT push on a failing root build.

### 8. Push the Backport Branch

```bash
git push -u <REMOTE> backport/<PR_NUMBER>-to-<TARGET_BRANCH_SLUG>
```

### 9. Create the Backport PR

Open a pull request from the backport branch to the target branch:

```bash
gh pr create --repo <GITHUB_REPO> \
  --base <TARGET_BRANCH> \
  --head backport/<PR_NUMBER>-to-<TARGET_BRANCH_SLUG> \
  --title "[backport <TARGET_BRANCH>] <ORIGINAL_PR_TITLE>" \
  --label "backport" \
  --body "$(cat <<'PREOF'
## Backport of #<PR_NUMBER>

Cherry-pick of #<PR_NUMBER> onto `<TARGET_BRANCH>`.

**Original PR:** #<PR_NUMBER> - <ORIGINAL_PR_TITLE>
**Original author:** @<ORIGINAL_AUTHOR>
**Target branch:** `<TARGET_BRANCH>`

### Original description

<ORIGINAL_PR_BODY or "See original PR for details.">
PREOF
)"
```

If the `backport` label does not exist, create the PR without it rather than failing.

**Agent attribution:** The PR body MUST end with a footer identifying your AI agent. If your agent's system prompt already adds such a footer (e.g., Claude Code appends `Generated with [Claude Code]`), do NOT duplicate it. Other agents (Bob Shell, Gemini, OpenCode, Codex) MUST append a footer in the format: `Generated by <Agent Name> via OSS Helper`.

### 10. Report Result

Provide the user with:

```markdown
## Backport Complete

- **Source PR:** #<PR_NUMBER> - <TITLE>
- **Backport PR:** #<NEW_PR_NUMBER> - <NEW_PR_URL>
- **Target branch:** `<TARGET_BRANCH>`
- **Commits cherry-picked:** <N>
- **Conflicts resolved:** <yes/no>

Use the PR Status guideline (`pr-status.md`) to monitor the backport PR.
```

### 11. Constraints

You MUST:

- Verify the source PR is merged before attempting the backport
- Verify the target branch exists
- Preserve the original commit messages during cherry-pick
- Link the backport PR back to the original PR
- Clean up the local backport branch if the process fails
- Report conflicts clearly if they cannot be resolved

You MUST NOT:

- Backport PRs that are not merged
- Modify the original PR in any way
- Force-push to the target branch directly
- Skip conflict resolution without informing the user
- Create the backport PR if cherry-pick failed

### 12. Acceptance Criteria

- Source PR is validated as merged
- Target branch is validated as existing
- Commits are cherry-picked onto a new backport branch
- Backport PR is opened with proper title, body, and label
- Original PR is referenced in the backport PR body
- Conflicts are either resolved or clearly reported
- User receives the backport PR URL
