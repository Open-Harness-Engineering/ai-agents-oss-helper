# Create Issue

Create a new issue in the current project's issue tracker (GitHub or Jira).

## Usage

```
/oss-create-issue <title>
```

**Arguments:**
- `<title>` - Brief title for the issue (optional - will prompt if not provided)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

If the project's **Create-issue supported** field is "no", stop and tell the user: "Issue creation is not supported for this project. Please create the issue directly in the project's issue tracker."

### 2. Detect Issue Tracker Type

Read the **Issue tracker** field from the project's `project-info.md`:
- If `GitHub` -> follow the **GitHub path** (steps 3-7)
- If `Jira` -> follow the **Jira path** (steps 8-13)

---

## GitHub Path

### 3. Gather Issue Information (GitHub)

If title not provided, ask the user for:
- **Title** - Brief, descriptive title for the issue

Then ask for:
- **Type** - Bug, enhancement, feature request, documentation, etc.
- **Description** - Detailed description of the issue
- **Reproduction steps** (for bugs) - Steps to reproduce the problem
- **Expected behavior** - What should happen
- **Actual behavior** (for bugs) - What currently happens
- **Additional context** - Any other relevant information

### 4. Determine Labels (GitHub)

Based on the issue type, suggest appropriate labels:

| Type | Suggested Labels |
|------|-----------------|
| Bug | `bug` |
| Enhancement | `enhancement` |
| Feature request | `enhancement` |
| Documentation | `documentation` |
| Good first issue | `good first issue` |
| Help wanted | `help wanted` |

Ask the user to confirm or modify labels.

### 5. Format Issue Body (GitHub)

Structure the issue body using this template:

```markdown
## Description

<description>

## Steps to Reproduce (if bug)

1. <step 1>
2. <step 2>
3. <step 3>

## Expected Behavior

<expected>

## Actual Behavior (if bug)

<actual>

## Additional Context

<context>
```

### 6. Confirm with User (GitHub)

Before creating, show the user:
- Title
- Labels
- Full body content

Ask for confirmation to proceed.

### 7. Create the Issue (GitHub)

Use GitHub CLI to create the issue:

```bash
gh issue create --repo <GITHUB_REPO> --title "<TITLE>" --label "<LABELS>" --body "$(cat <<'EOF'
<BODY_CONTENT>
EOF
)"
```

After creation, display:
- Issue number
- Issue URL
- Confirmation message

---

## Jira Path

### 8. Gather Issue Information (Jira)

If title not provided, ask the user for:
- **Summary** - Concise one-line title (under 80 chars)

Then ask for:
- **Issue type** - Bug, Improvement, Task, or Wish
- **Description** - Detailed description of the issue with:
  - What the problem is
  - How to reproduce (if applicable)
  - Expected vs actual behavior (if applicable)
  - Any relevant code references (file paths, test class names)
- **Component(s)** - Identify the affected component(s) from the module path (e.g., `camel-kafka` -> `camel-kafka`)
- **Priority** - Major (default), Critical (if blocking), Minor (if cosmetic/nit)

### 9. Check for Duplicates (Jira)

Search Jira for existing issues with similar keywords:

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "<ISSUE_TRACKER_URL>rest/api/2/search?jql=project=<JIRA_PROJECT_KEY>+AND+text+~+\"<keywords>\"+AND+status+not+in+(Closed,Resolved)&maxResults=5"
```

Read the **Issue tracker URL** and **Jira project key** from the project's `project-info.md`.

If potential duplicates are found, show them to the user and ask whether to proceed or link to an existing issue.

If no duplicates are found, continue.

### 10. Confirm with User (Jira)

Before creating, present the issue details:
- Summary
- Issue type
- Component(s)
- Priority
- Full description

Ask for confirmation to proceed.

### 11. Create the Issue (Jira)

**Authentication:** Use the `$JIRA_TOKEN` environment variable. If not set, stop and tell the user: "The `JIRA_TOKEN` environment variable is not set. Please set it with your Jira personal access token to create issues."

Create the issue via the Jira REST API:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "project": {"key": "<JIRA_PROJECT_KEY>"},
      "summary": "<summary>",
      "issuetype": {"name": "<type>"},
      "components": [{"name": "<component>"}],
      "priority": {"name": "<priority>"},
      "description": "<description>"
    }
  }' \
  "<ISSUE_TRACKER_URL>rest/api/2/issue"
```

Read the **Issue tracker URL** and **Jira project key** from the project's `project-info.md`.

Do NOT assign the issue (leave it unassigned for anyone to pick up, unless the user says they want to work on it).

### 12. Report Result (Jira)

After creation, display:
- Issue key (e.g., `CAMEL-XXXXX`)
- Issue URL: `<ISSUE_TRACKER_URL><ISSUE_KEY>`
- Confirmation message

If the user is currently working on a PR, mention: "Created `<ISSUE_KEY>` - not linked to current work."

---

## General

### 13. Constraints

You MUST:
- Confirm all details with the user before creating
- Use clear, descriptive titles/summaries
- For GitHub: include relevant labels
- For Jira: check for duplicates before creating
- Format the body/description properly

You MUST NOT:
- Create issues without user confirmation
- Use vague or unclear titles
- Skip gathering necessary information
- Create duplicate issues without checking
- For Jira: assign the issue unless the user requests it

### 14. Acceptance Criteria

- Issue is created in the project's issue tracker (GitHub or Jira)
- Issue has appropriate title/summary and metadata (labels/components)
- Issue body/description is well-formatted and informative
- User is provided with the issue URL
