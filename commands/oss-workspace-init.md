# Workspace Init

Initialize or rediscover a multi-repo OSS Helper workspace for a project family.

Use this command when a project spans several repositories and the operator wants the helper to treat them as one coordinated workspace for analysis, issue creation, fixes, validation, and PR tracking.

## Usage

```
/oss-workspace-init [name] [repo=<org/repo> ...] [root=<path>] [readonly]
```

**Arguments (all optional):**
- `name` - Workspace name. Defaults to the primary repository name with `-workspace` appended.
- `repo=<org/repo>` - Additional repository to include. May be repeated.
- `root=<path>` - Workspace root. Defaults to a sibling directory of the current checkout: `../<name>/`.
- `readonly` - Discover and record existing repositories only. Do not clone missing repositories.

## Workspace Model

A workspace is a lightweight grouping of independent git repositories. Each repository keeps its own remotes, branches, worktrees, issue tracker, rules, build commands, and PR policy. The workspace only records where the repositories are and how they relate to one primary issue workflow.

The default on-disk layout is:

```text
<workspace-root>/
  .oss-helper-workspace.json
  <primary-repo-name>/
  <related-repo-name>/
```

The metadata file is stored in the workspace root, outside the individual repositories. It is not committed to any project repository unless the user explicitly chooses a root inside a repository and confirms that choice.

Recommended metadata schema:

```json
{
  "version": 1,
  "name": "<workspace-name>",
  "root": "<absolute-workspace-root>",
  "primaryRepository": "<org/repo>",
  "createdFrom": "<absolute-path-to-initial-checkout>",
  "repositories": [
    {
      "name": "<repo-directory-name>",
      "repository": "<org/repo>",
      "path": "<absolute-path>",
      "role": "primary|related",
      "rulesSource": "project-local|installed|generated|unknown"
    }
  ]
}
```

Commands may add non-authoritative cache fields, but they must preserve the fields above and must not store credentials or tracker tokens in the metadata.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file from the current checkout to detect the primary project and load its rules. All subsequent steps assume the primary project context is loaded.

### 2. Parse Arguments

Parse:
- Workspace `name`, if present.
- Any repeated `repo=<org/repo>` values.
- Optional `root=<path>`.
- `readonly`, if present.

Use the current project's **GitHub repo** field as the primary repository.

If `name` is omitted, derive it from the primary repository basename:
- `apache/camel` -> `camel-workspace`
- `wanaku-ai/wanaku` -> `wanaku-workspace`

If `root` is omitted, use a deterministic sibling of the current repository:

```text
<parent-of-current-repo>/<workspace-name>/
```

Resolve the root to an absolute path before using it.

### 3. Discover Candidate Repositories

Build the candidate repository set in this order:

1. Primary repository from `project-info.md`.
2. Repositories listed in the primary project's **Related repositories** field.
3. Repositories supplied as `repo=<org/repo>` arguments.

Normalize repository names to `org/repo`, remove duplicates, and keep the primary repository first.

If the project has no related repositories and no `repo=` arguments were provided, present a one-repository workspace plan and ask whether the user wants to continue or provide additional repositories.

### 4. Confirm Workspace Plan

Before cloning or writing metadata, show:
- Workspace name.
- Workspace root.
- Primary repository.
- Candidate repositories.
- Which paths already exist.
- Which repositories would be cloned.
- Whether `readonly` is active.

Ask the user to confirm. Do not clone repositories or write metadata until they approve.

If `readonly` is active and any repository is missing, keep it in the report as `missing` but do not clone it.

### 5. Prepare Workspace Root

Create the workspace root if it does not exist:

```bash
mkdir -p <WORKSPACE_ROOT>
```

If the root is inside a git repository, warn that workspace metadata may be picked up by that repository. Prefer an external sibling directory unless the user explicitly confirms the in-repository root.

### 6. Clone or Register Repositories

For each repository:

1. Compute a deterministic directory name from the repository basename. If a name collides, prefix the organization, for example `org-repo`.
2. Target path: `<WORKSPACE_ROOT>/<directory-name>`.
3. If the current checkout already matches a candidate repository, reuse its path instead of cloning a duplicate.
4. If the target path exists and is a git repository, register it.
5. If the target path exists but is not a git repository, stop and ask for a different root or path.
6. If the target path is missing and `readonly` is not active, clone:

```bash
gh repo clone <ORG_REPO> <TARGET_PATH>
```

If `gh repo clone` is unavailable, use:

```bash
git clone https://github.com/<ORG_REPO>.git <TARGET_PATH>
```

Do not silently overwrite or remove existing directories.

### 7. Detect Rules for Each Repository

For each registered repository, load its rules independently using the same priority model as `.oss-init.md`:

1. Project-local `.oss-ai-helper-rules/`.
2. Installed rules matching the repository remote.
3. Auto-discovery and generated project-local rules, only after telling the user.

Record the rule source for status reporting. Do not assume all repositories share the same issue tracker, build tool, branch pattern, or PR policy.

### 8. Detect Checkout and Worktree State

For each registered repository, run:

```bash
git -C <PATH> rev-parse --show-toplevel
git -C <PATH> rev-parse --path-format=absolute --git-common-dir
git -C <PATH> rev-parse --path-format=absolute --git-dir
git -C <PATH> worktree list --porcelain
```

Classify the path as:
- `main checkout` - normal checkout whose git dir is the repository's main `.git` directory.
- `worktree` - linked worktree whose git dir is under the common git directory's `worktrees/` area or whose `.git` file points elsewhere.
- `unknown` - command output is incomplete; report the raw paths.

Record the common git directory and the current worktree path for status.

### 9. Write Workspace Metadata

Write or update:

```text
<WORKSPACE_ROOT>/.oss-helper-workspace.json
```

Use stable absolute paths in the metadata. Preserve repositories that are still present unless the user confirms removal.

If a metadata file already exists:
- Read it first.
- Merge newly discovered repositories.
- Ask before changing the primary repository or root.
- Never discard unknown fields unless they are invalid JSON and the user approves recreating the file.

### 10. Report Result

Print a concise summary:

```markdown
## Workspace Initialized

**Name:** <workspace-name>
**Root:** <absolute-root>
**Metadata:** <metadata-path>

| Repository | Path | Checkout | Rules | State |
|------------|------|----------|-------|-------|
| <org/repo> | <path> | main checkout/worktree | project-local/installed/generated | ready/missing |

Next:
- `/oss-workspace-status`
- `/oss-create-multi-repo-issue`
- `/oss-fix-multi-repo-issue <issue>`
```

### 11. Constraints

You MUST:
- Initialize project context before discovering related repositories.
- Ask before cloning repositories or writing workspace metadata.
- Store metadata outside the individual repositories by default.
- Load rules independently for every registered repository.
- Detect worktrees with `git worktree list --porcelain`.
- Preserve dirty or existing repositories; never reset, delete, or overwrite them.

You MUST NOT:
- Assume all repositories share one build tool, tracker, branch naming scheme, or PR policy.
- Clone repositories into arbitrary locations without showing the plan first.
- Create branches or commits; this command only initializes workspace metadata.
- Store credentials, tokens, or secrets in workspace metadata.

### 12. Acceptance Criteria

- A workspace root and metadata file are created or rediscovered.
- The primary repository and selected related repositories are recorded.
- Missing repositories are cloned only after confirmation.
- Each registered repository has an independent rules source recorded.
- Each registered repository is classified as a main checkout, worktree, or unknown.
- The user gets a clear next-step summary.
