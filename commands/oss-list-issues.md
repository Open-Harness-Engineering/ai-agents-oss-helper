# List Issues

List all issues assigned to you in the current project's issue tracker (GitHub or Jira).

## Usage

```
/oss-list-issues [state=<open|closed|all>] [label=<label>] [limit=<N>]
```

**Arguments (all optional):**
- `state=<open|closed|all>` - Filter by issue state (default: `open`)
- `label=<label>` - Filter to issues with the given label (quote multi-word labels, e.g. `label="bug"`)
- `limit=<N>` - Maximum number of issues to fetch (default: `20`)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Arguments

Parse the optional arguments into local variables. Use these defaults when an argument is not provided:

| Argument | Default |
|----------|---------|
| `state` | `open` |
| `label` | _(none -- no label filter)_ |
| `limit` | `20` |

### 3. Detect Issue Tracker Type

Read the **Issue tracker** field from the project's `project-info.md`:
- If `GitHub` -> follow the **GitHub path** (step 4)
- If `Jira` -> follow the **Jira path** (step 5)

### 4. GitHub Path

#### 4.1 Determine Current User

```bash
gh api user --jq '.login'
```

#### 4.2 Fetch Assigned Issues

Build a `gh issue list` invocation using the parsed arguments:

```bash
gh issue list \
  --repo <GITHUB_REPO> \
  --assignee @me \
  --state <STATE> \
  --limit <LIMIT> \
  --json number,title,labels,state,createdAt,updatedAt
```

If the `label` argument is provided, add `--label "<LABEL>"` to the command.

If no issues are returned, inform the user:
> No issues assigned to you matched the requested filters in `<GITHUB_REPO>`.

Suggest dropping a filter and stop.

#### 4.3 Present Results

Render a numbered table:

```markdown
## Your Assigned Issues in <GITHUB_REPO>

Filters: <human-readable summary of active filters, e.g. "open, label='bug'">

| # | Issue | Title | Labels | State | Updated |
|---|-------|-------|--------|-------|---------|
| 1 | #<number> | <title> | <labels> | <state> | <YYYY-MM-DD> |
| 2 | ... | ... | ... | ... | ... |

**Total:** <N> issue(s)
```

Skip to step 6.

### 5. Jira Path

#### 5.1 Build JQL Query

Read the **Jira project key** from the project's `project-info.md` (e.g., `CAMEL`).

Build a JQL query that searches for issues assigned to the current user:

```
project = <PROJECT_KEY> AND assignee = currentUser()
```

Add filters based on the parsed arguments:
- If `state=open` (default): append `AND status != Closed AND status != Resolved`
- If `state=closed`: append `AND (status = Closed OR status = Resolved)`
- If `state=all`: do not add a status filter
- If `label` is provided: append `AND labels = "<LABEL>"`

URL-encode the full JQL string.

#### 5.2 Fetch Assigned Issues

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "<ISSUE_TRACKER_URL>rest/api/2/search?jql=<ENCODED_JQL>&maxResults=<LIMIT>&fields=key,summary,status,priority,labels,components,updated" \
  | jq '.issues[] | {key: .key, summary: .fields.summary, status: .fields.status.name, priority: .fields.priority.name, labels: .fields.labels, components: [.fields.components[].name], updated: .fields.updated}'
```

If `$JIRA_TOKEN` is not set, try the request without authentication (works for public Jira instances like Apache's):

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/search?jql=<ENCODED_JQL>&maxResults=<LIMIT>&fields=key,summary,status,priority,labels,components,updated" \
  | jq '.issues[] | {key: .key, summary: .fields.summary, status: .fields.status.name, priority: .fields.priority.name, labels: .fields.labels, components: [.fields.components[].name], updated: .fields.updated}'
```

**Important:** For unauthenticated Jira requests, `currentUser()` will not work. In that case, ask the user for their Jira username and use `assignee = "<username>"` instead. If a `JIRA_TOKEN` is available, `currentUser()` will resolve correctly.

If no issues are returned, inform the user:
> No issues assigned to you matched the requested filters in the project's Jira tracker.

Suggest dropping a filter and stop.

#### 5.3 Present Results

Render a numbered table:

```markdown
## Your Assigned Issues in <PROJECT_KEY>

Filters: <human-readable summary of active filters, e.g. "open, label='bug'">

| # | Issue | Summary | Status | Priority | Components | Labels | Updated |
|---|-------|---------|--------|----------|------------|--------|---------|
| 1 | <KEY> | <summary> | <status> | <priority> | <components> | <labels> | <YYYY-MM-DD> |
| 2 | ... | ... | ... | ... | ... | ... | ... |

**Total:** <N> issue(s)
```

### 6. Ask the User to Select an Issue

Ask the user which issue they want to work on. They can answer by:
- The list index (e.g., `2`)
- The issue number or key (e.g., `#42` or `CAMEL-20410`)
- A full issue URL

If the user does not want to work on any of them, stop without further action.

### 7. Hand Off to Next Command

Once the user picks an issue, suggest the appropriate follow-up:

```
To fix this issue, use:
/oss-fix-issue <ISSUE_ID>

To analyze this issue first, use:
/oss-analyze-issue <ISSUE_ID>
```

### 8. Constraints

You MUST:
- Make exactly ONE API call to list issues (no polling, no per-issue fetches)
- Only list issues assigned to the current user
- Present results as a numbered table so the user can select by index
- Hand off to `/oss-fix-issue` or `/oss-analyze-issue` rather than starting work inline
- Stop gracefully if no issues match

You MUST NOT:
- Close, modify, comment on, or reassign any issue
- Fetch detailed information for every issue (defer that to `/oss-analyze-issue`)
- List issues assigned to other users
- Repeat the API call to refresh the list within the same invocation

### 9. Acceptance Criteria

- A single API call is made with the requested filters
- All matching assigned issues are presented in a numbered table with the documented columns
- The user is prompted to pick an issue and pointed to `/oss-fix-issue` or `/oss-analyze-issue`
- No issue is modified by this command
- The output is concise and easy to scan
