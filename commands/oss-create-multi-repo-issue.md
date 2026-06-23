# Create Multi-Repo Issue

Create and link tracking issues for work that spans multiple repositories in an OSS Helper workspace.

This command decides how cross-repo work is represented in the issue tracker. It is separate from `/oss-fix-multi-repo-issue`, which executes an existing tracked issue.

## Usage

```
/oss-create-multi-repo-issue [title] [root=<path>] [repo=<org/repo> ...]
```

**Arguments (all optional):**
- `title` - Proposed issue title.
- `root=<path>` - Workspace root containing `.oss-helper-workspace.json`.
- `repo=<org/repo>` - Limit or extend the affected repository set. May be repeated.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file from the current checkout. Then locate and load workspace metadata using the same discovery rules as `/oss-workspace-status`.

If no workspace exists, ask the user whether to run `/oss-workspace-init` first. Do not create a multi-repo issue without an explicit repository set.

### 2. Load Workspace Repositories and Rules

For each workspace repository:

1. Verify the path exists and is a git repository.
2. Load that repository's own rules using `.oss-init.md` priority.
3. Read:
   - GitHub repo or Jira tracker information.
   - Create-issue supported.
   - Related repositories.
   - Branch and PR policies.
   - Build/test commands.

Do not assume secondary repositories use the same tracker as the primary repository.

### 3. Gather Issue Information

If `title` was not provided, ask for a concise title.

Ask for:
- Problem or feature description.
- Expected change areas per repository.
- Validation expectations per repository.
- Whether one canonical issue is enough or child issues are desired.
- Any known branch/worktree strategy.
- Labels or components, if known.

Keep the gathered information local until the final confirmation step.

### 4. Select Affected Repositories

Start with:
- Repositories explicitly provided via `repo=`.
- Repositories the user names while describing the work.
- Repositories inferred from the workspace metadata and related repository fields.

Show the candidate set and ask the user to confirm which repositories are affected.

For each affected repository, record:
- Expected change area.
- Validation command from that repository's `project-standards.md`.
- Whether issue creation is supported.
- Tracker type and tracker URL.

### 5. Search for Duplicates Across Repositories

Search before creating anything.

**GitHub repositories:**

```bash
gh issue list --repo <ORG_REPO> --state all --search "<keywords>" --limit 20
gh pr list --repo <ORG_REPO> --state all --search "<keywords>" --limit 20
```

**Jira repositories:**

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/search?jql=project=<JIRA_PROJECT_KEY>+AND+text+~+\"<keywords>\"&maxResults=10"
```

For Jira, respect project-specific rate-limiting instructions and avoid repeated polling.

Present possible duplicates grouped by repository and ask whether to continue, link to an existing issue, or stop.

### 6. Choose Canonical Tracker

Ask which repository or tracker should own the canonical issue.

Default recommendation:
- Use the primary workspace repository when it supports issue creation.
- Otherwise use the first affected repository that supports issue creation.

If no affected repository supports issue creation, stop and tell the user to create the canonical issue manually in the appropriate tracker.

### 7. Build Primary Issue Body

Use this structure:

```markdown
## Summary

<description>

## Affected Repositories

| Repository | Expected change area | Validation |
|------------|----------------------|------------|
| <org/repo> | <area> | <command> |

## Workspace Strategy

- Workspace: <workspace-name>
- Branch/worktree strategy: <strategy>
- Primary issue owner: <repo or tracker>

## Required Work

- [ ] <org/repo>: <expected work>
- [ ] <org/repo>: <expected work>

## PR Coordination

- Primary PR: TBD
- Sibling PRs: TBD
- Required merge order: <none/describe>

## Notes

<additional context>
```

Include links to duplicate or related issues if the user chose to proceed despite them.

### 8. Optional Child Issues

Ask whether to create child issues in secondary repositories.

Only create child issues after explicit confirmation. For each child issue:
- Confirm that the repository's **Create-issue supported** field is not `no`.
- Use the repository's own tracker and issue format.
- Link back to the canonical issue.
- Include the repository-specific expected change area and validation command.

If child issue creation is not supported for a repository, include that repository as a checklist item in the canonical issue instead.

### 9. Confirm Before Creating

Show:
- Canonical repository/tracker.
- Title.
- Labels/components.
- Full primary issue body.
- Child issues to create, if any.

Ask for explicit confirmation before running any creation command.

### 10. Create Issues

**GitHub canonical issue:**

```bash
gh issue create --repo <ORG_REPO> --title "<TITLE>" --body-file <BODY_FILE>
```

Add labels only after validating they exist with:

```bash
gh label list --repo <ORG_REPO> --limit 100
```

**Jira canonical issue:**

Use the repository's Jira REST configuration from `project-info.md`. Present the exact fields first and create only after confirmation.

For each created child issue, update or comment on the canonical issue with links after confirming the final link text.

### 11. Report Result

Print:
- Canonical issue URL.
- Child issue URLs, if any.
- Affected repositories.
- Suggested next command:

```text
/oss-fix-multi-repo-issue <canonical-issue-url>
```

### 12. Constraints

You MUST:
- Initialize project context and workspace metadata before creating anything.
- Search for duplicates across affected repositories.
- Ask which tracker owns the canonical issue.
- Confirm the final issue text before creation.
- Respect each repository's `Create-issue supported`, tracker type, labels/components, and rules.
- Create child issues only after explicit confirmation.

You MUST NOT:
- Create issues in repositories that declare issue creation unsupported.
- Assume GitHub and Jira issue fields are interchangeable.
- Create duplicate issues without showing the duplicate search results.
- Create branches, commits, or PRs; fixing is handled by `/oss-fix-multi-repo-issue`.

### 13. Acceptance Criteria

- A canonical cross-repo issue is created or the command stops with a clear reason.
- Duplicate searches are performed across affected repositories.
- The canonical issue lists affected repositories, change areas, validation expectations, branch/worktree strategy, and PR checklist.
- Optional child issues are linked to the canonical issue and created only after confirmation.
- The user receives the issue URL(s) and the fix handoff command.
