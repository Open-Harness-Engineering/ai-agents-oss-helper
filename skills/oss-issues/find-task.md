### 1. Understand the User's Experience

Ask the user about their experience level:

**Questions to ask:**

- Is this your first time contributing to this project?
- Are you familiar with the codebase?
- Are you looking for something quick or a larger task?

Based on responses, categorize as:

- **Beginner** - First-time contributor, wants something approachable
- **Intermediate** - Some experience (only applicable for Jira projects with intermediate tier)
- **Experienced** - Familiar with the project, ready for more complex work

### 2. Search for Issues

Read the project's `project-guidelines.md` to determine the find-task source and labels/JQL for the current project.

#### GitHub Projects

Use the appropriate search based on experience level:

**Beginner:**

```bash
gh issue list --repo <GITHUB_REPO> --label "<BEGINNER_LABEL>" --state open --limit 10 --json number,title,labels
```

**Experienced:**

```bash
gh issue list --repo <GITHUB_REPO> --label "<EXPERIENCED_LABEL>" --state open --limit 10 --json number,title,labels
```

#### Jira Projects

Read the **Issue tracker URL** from the project's `project-info.md` and use it as `<ISSUE_TRACKER_URL>` below.
Read the **Find-task beginner JQL**, **Find-task intermediate**, and **Find-task experienced JQL** from the project's `project-guidelines.md`.

**Beginner** (uses `Find-task beginner JQL`):

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/search?jql=<BEGINNER_JQL_URL_ENCODED>&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

**Intermediate** (uses `Find-task intermediate` — skip if not configured):

If `Find-task intermediate` specifies a Jira filter ID (e.g., `Filter 12352792`):

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/filter/<FILTER_ID>" | jq -r '.searchUrl' | xargs -I {} curl -s "{}&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

**Experienced** (uses `Find-task experienced JQL`):

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/search?jql=<EXPERIENCED_JQL_URL_ENCODED>&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

### 3. Rate Limiting

**Be a good net citizen:**

- Make only ONE search request per interaction
- Do NOT poll or refresh repeatedly
- Respect API rate limits

### 4. Present Results

For each issue found, present:

**GitHub projects:**

- **Issue Number** (e.g., #42)
- **Title** - Brief description
- **Labels** - Additional context

**Jira projects:**

- **Issue ID** (e.g., CAMEL-20410)
- **Summary** - Brief description
- **Priority** - Helps gauge urgency
- **Components** - Affected areas of the codebase

Format as a numbered list for easy selection.

### 5. Help User Choose

After presenting options:

- Ask which issue interests them
- Provide a brief explanation of what the issue involves
- Mention any prerequisites or context needed

### 6. Next Steps

Once the user selects an issue, instruct them:

```text
To work on this issue, use:

the Fix Issue guideline (`fix-issue.md`)
```

### 7. Constraints

You MUST:

- Ask about experience before searching
- Make only ONE API request to find issues
- Present results clearly with issue IDs
- Direct users to the Fix Issue guideline (`fix-issue.md`) for implementation

You MUST NOT:

- Make multiple API requests
- Modify any issues
- Start implementing without user confirmation
- Overwhelm users with too many options (limit to 10)

### 8. Quick Reference

Read the project's `project-guidelines.md` for the full label/JQL reference for the current project.
