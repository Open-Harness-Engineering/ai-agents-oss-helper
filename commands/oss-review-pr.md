# Review Pull Request

Review a pull request against the project's rules, standards, and contribution expectations.

## Usage

```bash
/oss-review-pr <pr>
```

**Arguments:**
- `<pr>` - Pull request number (e.g., `42`) or full GitHub pull request URL

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (`project-info.md`, `project-standards.md`, `project-guidelines.md`) is loaded.

### 2. Parse Input

Extract the pull request number:

- If the input is a full GitHub pull request URL (for example, `https://github.com/org/repo/pull/42`), extract the number from the path
- If the input is a number only, use it as-is

### 3. Retrieve Pull Request Details

Fetch the pull request metadata:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,body,baseRefName,headRefName,author,changedFiles,additions,deletions
```

Fetch the diff for detailed review:

```bash
gh pr diff <PR_NUMBER> --repo <GITHUB_REPO>
```

If the PR references an issue or ticket, review that context as needed to validate scope and intent.

### 4. Investigate Git History

Before reviewing the changes, understand the history of the modified files:

```bash
# Recent changes to files modified by the PR
git log --oneline -15 -- <modified-files>

# Authorship and intent of specific changed areas
git blame -L <start>,<end> -- <file>
```

- Read commit messages and any linked issue references for prior changes to understand **why** the existing code was written the way it is.
- Check if the PR conflicts with or effectively reverts a prior intentional commit. If so, flag this as a finding.
- Look for related issues or discussions in the project tracker that provide context on design decisions in the affected area.

### 5. Review Scope

Review the pull request specifically against the loaded project rules:

- **Project guidelines** - Branch naming, commit conventions, PR expectations, contribution process
- **Project standards** - Build, test, format, and code-style expectations
- **Project information** - Related repositories or tracker conventions that affect the change

This command is a rules-and-conventions review. It is **not** a replacement for specialized review tools such as CodeRabbit or Sourcery, and it is **not** a replacement for static analyzers such as SonarCloud.

### 6. Evaluate the Pull Request

Check for issues such as:

- Missing or insufficient tests for the changed behavior
- Changes that appear inconsistent with the project's build, test, or formatting requirements
- Branch or commit conventions that do not follow `project-guidelines.md`
- Scope drift: unrelated changes mixed into the PR
- Missing issue linkage or context when the project conventions expect it
- Contribution-process problems (for example, PR body lacks required context)
- Behavioral regressions or obvious risks visible from the diff

### 7. Present Review Findings

Present findings locally in **code review format**:

1. List findings first, ordered by severity
2. Include file references whenever the diff makes that possible
3. Clearly separate:
   - **Confirmed issues** - Directly supported by the diff or rule files
   - **Questions / assumptions** - Areas where the PR may be correct but context is missing
4. If no significant issues are found, state that explicitly

Keep the review concise and actionable. Focus on concrete risks, regressions, rule violations, and missing validation.

**Wait for user approval before submitting the review to GitHub.**

### 8. Submit Review to GitHub

After user approval, submit the review using the GitHub CLI with inline comments.

#### 8.1 Determine the Review Event

Based on the findings:

| Findings | Event |
|----------|-------|
| No significant issues | `APPROVE` |
| Only questions or suggestions | `COMMENT` |
| Blocking issues found | `REQUEST_CHANGES` |

#### 8.2 Build Inline Comments

For each finding that references a specific file and line in the diff, create an inline comment. Use the GitHub review comments API to attach comments to the exact file and line:

```bash
gh api repos/{owner}/{repo}/pulls/<number>/reviews \
  -f event="<EVENT>" \
  -f body="<overall summary>" \
  -f 'comments[][path]=<file>' \
  -f 'comments[][position]=<diff-position>' \
  -f 'comments[][body]=<comment>'
```

Alternatively, for multiple comments, build a JSON payload:

```bash
gh api repos/{owner}/{repo}/pulls/<number>/reviews --input - <<EOF
{
  "event": "<EVENT>",
  "body": "<overall summary>",
  "comments": [
    {
      "path": "<file>",
      "line": <line-in-new-file>,
      "side": "RIGHT",
      "body": "<comment>"
    }
  ]
}
EOF
```

**Important:** The `line` field refers to the line number in the **new version** of the file (RIGHT side of the diff). For multi-line comments, use `start_line` and `line` together.

#### 8.3 Use Suggestion Blocks

When the fix is clear and concrete, use GitHub suggestion blocks so the author can apply the change with one click:

````
```suggestion
<corrected code>
```
````

Use suggestions for:
- Simple code fixes (typos, naming, missing annotations)
- Style or formatting corrections
- Small logic adjustments where the intent is unambiguous

Do **not** use suggestions for:
- Large refactors or multi-file changes
- Changes where multiple valid approaches exist
- Deletions of entire blocks (use a descriptive comment instead)

For multi-line suggestions, use `start_line` and `line` to span the range, and include the full replacement in the suggestion block.

#### 8.4 General Comments

Findings that are not tied to a specific line (e.g., missing tests, scope drift, convention violations) go in the review body as the overall summary.

#### 8.5 Attribution

The review body must end with: "_This review was generated by an AI agent and may contain inaccuracies. Please verify all suggestions before applying._"

### 9. Constraints

You MUST:

- Review the PR against the loaded project rule files
- Prioritize bugs, regressions, missing tests, and rule violations
- Check git history of modified files to understand prior intent before flagging issues
- Cite the relevant rule file when a finding depends on project conventions
- State explicitly that this review does not replace specialized AI review tools or static analysis
- Distinguish clearly between findings and open questions
- Demonstrate empathy towards the contributor when requesting changes — acknowledge their effort, frame feedback constructively, and avoid dismissive or discouraging language

You MUST NOT:

- Re-implement the pull request instead of reviewing it
- Present the command as a substitute for CodeRabbit, Sourcery, SonarCloud, or similar tools
- Invent project conventions not present in the loaded rule files
- Ignore the diff and review only the PR title/body
- Submit the review to GitHub without user approval
- Use suggestion blocks for large or ambiguous changes

### 10. Acceptance Criteria

- The PR was reviewed against the project's rule files
- Findings are concrete, prioritized, and actionable
- Missing tests, regressions, and convention violations are called out when present
- The review explicitly stays within OSS Helper's scope and does not claim to replace specialized tools
- Review is submitted to GitHub with inline comments on specific lines where possible
- Suggestion blocks are used for clear, concrete fixes
- The review includes the AI-generated disclaimer
