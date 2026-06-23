# Workspace Status

Report the current state of every repository in an OSS Helper multi-repo workspace.

This command is read-only. It helps the operator understand branches, worktrees, dirty state, tracking status, loaded rules, open PRs, and validation commands across the workspace before starting or continuing cross-repo work.

## Usage

```
/oss-workspace-status [root=<path>] [name=<workspace-name>]
```

**Arguments (all optional):**
- `root=<path>` - Workspace root containing `.oss-helper-workspace.json`.
- `name=<workspace-name>` - Workspace name to find in the global registry, if a registry exists.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file from the current checkout. This identifies the current repository, but each workspace repository must still load its own rules independently.

### 2. Locate Workspace Metadata

Locate `.oss-helper-workspace.json` using this order:

1. Explicit `root=<path>`.
2. Current directory and its parents.
3. Parent directories of the current repository root.
4. A known workspace registry if one exists, such as `$XDG_STATE_HOME/oss-helper/workspaces/` or `$HOME/.local/state/oss-helper/workspaces/`.

If no metadata is found, stop and tell the user to run `/oss-workspace-init` first.

Read the metadata as JSON. If the file is invalid JSON, stop and report the path and parse error. Do not rewrite it from status.

### 3. Validate Registered Repositories

For each repository entry:

1. Confirm the path exists.
2. Confirm the path is a git repository:

```bash
git -C <PATH> rev-parse --show-toplevel
```

3. Confirm the current remote still matches the recorded `org/repo` where possible:

```bash
git -C <PATH> remote get-url origin
```

Mark missing or mismatched paths clearly but keep reporting the rest of the workspace.

### 4. Load Repository Rules

For each valid repository path, load its rules independently using `.oss-init.md` priority:

1. Project-local `.oss-ai-helper-rules/`.
2. Installed rules matching the repository remote.
3. Auto-discovered generated rules only if needed and only after telling the user.

Record:
- Rules source.
- Build command.
- Test command.
- Format command.
- PR creation policy.

Do not assume the primary repository's rules apply to related repositories.

### 5. Detect Checkout and Worktree Type

For each valid repository path, run:

```bash
git -C <PATH> rev-parse --abbrev-ref HEAD
git -C <PATH> rev-parse --path-format=absolute --git-common-dir
git -C <PATH> rev-parse --path-format=absolute --git-dir
git -C <PATH> worktree list --porcelain
```

Classify the path as:
- `main checkout`
- `worktree`
- `unknown`

When the path is a worktree, report:
- Worktree path.
- Common git directory.
- Source repository path if it can be inferred from `git worktree list --porcelain`.

### 6. Detect Dirty State

For each valid repository:

```bash
git -C <PATH> status --short
```

Classify:
- `clean` - no output.
- `dirty` - tracked modifications, staged changes, or untracked files.

Show a compact count by category when possible:
- staged
- modified
- deleted
- untracked

Do not clean, stash, reset, or delete anything.

### 7. Detect Remote Tracking State

For each valid repository:

```bash
git -C <PATH> status --short --branch
git -C <PATH> rev-parse --abbrev-ref --symbolic-full-name @{u}
```

Report:
- Current branch.
- Upstream branch, if configured.
- Ahead/behind counts from `git status --short --branch`.
- `no upstream` when no tracking branch exists.

Do not fetch by default. If the user asks for fresh remote data, ask before running fetches across repositories.

### 8. Detect Open PR for Current Branch

For each GitHub-backed repository with a current branch:

```bash
gh pr list --repo <ORG_REPO> --head <BRANCH> --state open --json number,title,url,isDraft,reviewDecision
```

If the repository does not use GitHub or `gh` is unavailable, mark PR status as `not checked`.

Use one PR-list request per repository. Do not poll check status from `/oss-workspace-status`; use `/oss-pr-status` or repository-specific commands for detailed CI.

### 9. Present Status

Produce a table:

```markdown
## Workspace Status: <workspace-name>

**Root:** <workspace-root>
**Metadata:** <metadata-path>

| Repository | Branch | Checkout | Dirty | Tracking | Rules | PR | Build/Test |
|------------|--------|----------|-------|----------|-------|----|------------|
| <org/repo> | <branch> | main checkout/worktree | clean/dirty | ahead/behind/no upstream | project-local | #123/draft/none | <command summary> |
```

After the table, include:
- Missing or mismatched paths.
- Worktree details for any worktree rows.
- Repositories with dirty state.
- Repositories with no loaded rules.
- Suggested next command, such as `/oss-fix-multi-repo-issue <issue>`.

### 10. Constraints

You MUST:
- Treat status as read-only.
- Load rules per repository.
- Detect worktree state with `git worktree list --porcelain`.
- Report dirty state without changing it.
- Report open PRs for current branches when GitHub metadata is available.

You MUST NOT:
- Fetch, pull, checkout, stash, reset, clean, commit, push, or create PRs.
- Assume all repositories have the same tracker or build tool.
- Hide missing repositories or invalid metadata.

### 11. Acceptance Criteria

- Status covers every repository recorded in workspace metadata.
- Each repository shows branch, checkout/worktree type, dirty state, tracking state, rules source, PR status, and build/test command summary.
- Missing, invalid, or dirty repositories are clearly called out.
- No repository state is modified.
