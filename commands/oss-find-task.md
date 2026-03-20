# Find a Task to Contribute

Help users find an issue to contribute to the current project.

## Usage

```
/oss-find-task
```

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Understand the User's Experience

Ask the user about their experience level:

**Questions to ask:**
- Is this your first time contributing to this project?
- Are you familiar with the codebase?
- Are you looking for something quick or a larger task?

Based on responses, categorize as:
- **Beginner** - First-time contributor, wants something approachable
- **Intermediate** - Some experience (only applicable for Jira projects with intermediate tier)
- **Experienced** - Familiar with the project, ready for more complex work

### 3. Search for Issues

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

#### Jira Projects (camel-core)

**Beginner:**
```bash
curl -s "https://issues.apache.org/jira/rest/api/2/search?jql=project%20%3D%20CAMEL%20AND%20status%20%3D%20Open%20AND%20labels%20%3D%20good-first-issue&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

**Intermediate:**
```bash
curl -s "https://issues.apache.org/jira/rest/api/2/filter/12352792" | jq -r '.searchUrl' | xargs -I {} curl -s "{}&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

**Experienced:**
```bash
curl -s "https://issues.apache.org/jira/rest/api/2/search?jql=project%20%3D%20CAMEL%20AND%20status%20%3D%20Open%20AND%20labels%20%3D%20help-wanted&maxResults=10" | jq '.issues[] | {key: .key, summary: .fields.summary, priority: .fields.priority.name, components: [.fields.components[].name]}'
```

### 4. Rate Limiting

**Be a good net citizen:**
- Make only ONE search request per interaction
- Do NOT poll or refresh repeatedly
- Respect API rate limits

### 5. Present Results

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

### 6. Help User Choose

After presenting options:
- Ask which issue interests them
- Provide a brief explanation of what the issue involves
- Mention any prerequisites or context needed

### 7. Next Steps

Once the user selects an issue, instruct them:

```
To work on this issue, use:

/oss-fix-issue <ISSUE_ID>
```

### 8. Constraints

You MUST:
- Ask about experience before searching
- Make only ONE API request to find issues
- Present results clearly with issue IDs
- Direct users to `/oss-fix-issue` for implementation

You MUST NOT:
- Make multiple API requests
- Modify any issues
- Start implementing without user confirmation
- Overwhelm users with too many options (limit to 10)

### 9. Quick Reference

Read the project's `project-guidelines.md` for the full label/JQL reference for the current project.
