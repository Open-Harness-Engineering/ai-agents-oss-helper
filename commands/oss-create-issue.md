# Create Issue

Create a new issue in the current project's GitHub repository.

## Usage

```
/oss-create-issue <title>
```

**Arguments:**
- `<title>` - Brief title for the issue (optional - will prompt if not provided)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

If the project's **Create-issue supported** field is "no" (e.g., Jira projects like camel-core), stop and tell the user: "Issue creation is not supported for this project. Please create the issue directly in the project's issue tracker."

### 2. Gather Issue Information

If title not provided, ask the user for:
- **Title** - Brief, descriptive title for the issue

Then ask for:
- **Type** - Bug, enhancement, feature request, documentation, etc.
- **Description** - Detailed description of the issue
- **Reproduction steps** (for bugs) - Steps to reproduce the problem
- **Expected behavior** - What should happen
- **Actual behavior** (for bugs) - What currently happens
- **Additional context** - Any other relevant information

### 3. Determine Labels

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

### 4. Format Issue Body

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

### 5. Confirm with User

Before creating, show the user:
- Title
- Labels
- Full body content

Ask for confirmation to proceed.

### 6. Create the Issue

Use GitHub CLI to create the issue:

```bash
gh issue create --repo <GITHUB_REPO> --title "<TITLE>" --label "<LABELS>" --body "$(cat <<'EOF'
<BODY_CONTENT>
EOF
)"
```

### 7. Report Result

After creation, display:
- Issue number
- Issue URL
- Confirmation message

### 8. Constraints

You MUST:
- Confirm all details with the user before creating
- Use clear, descriptive titles
- Include relevant labels
- Format the body properly with Markdown

You MUST NOT:
- Create issues without user confirmation
- Use vague or unclear titles
- Skip gathering necessary information
- Create duplicate issues without checking

### 9. Acceptance Criteria

- Issue is created in the project's repository
- Issue has appropriate title and labels
- Issue body is well-formatted and informative
- User is provided with the issue URL
