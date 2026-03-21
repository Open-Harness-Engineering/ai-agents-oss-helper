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

### 4. Review Scope

Review the pull request specifically against the loaded project rules:

- **Project guidelines** - Branch naming, commit conventions, PR expectations, contribution process
- **Project standards** - Build, test, format, and code-style expectations
- **Project information** - Related repositories or tracker conventions that affect the change

This command is a rules-and-conventions review. It is **not** a replacement for specialized review tools such as CodeRabbit or Sourcery, and it is **not** a replacement for static analyzers such as SonarCloud.

### 5. Evaluate the Pull Request

Check for issues such as:

- Missing or insufficient tests for the changed behavior
- Changes that appear inconsistent with the project's build, test, or formatting requirements
- Branch or commit conventions that do not follow `project-guidelines.md`
- Scope drift: unrelated changes mixed into the PR
- Missing issue linkage or context when the project conventions expect it
- Contribution-process problems (for example, PR body lacks required context)
- Behavioral regressions or obvious risks visible from the diff

### 6. Present Review Findings

Present findings in **code review format**:

1. List findings first, ordered by severity
2. Include file references whenever the diff makes that possible
3. Clearly separate:
   - **Confirmed issues** - Directly supported by the diff or rule files
   - **Questions / assumptions** - Areas where the PR may be correct but context is missing
4. If no significant issues are found, state that explicitly

Keep the review concise and actionable. Focus on concrete risks, regressions, rule violations, and missing validation.

### 7. Constraints

You MUST:

- Review the PR against the loaded project rule files
- Prioritize bugs, regressions, missing tests, and rule violations
- Cite the relevant rule file when a finding depends on project conventions
- State explicitly that this review does not replace specialized AI review tools or static analysis
- Distinguish clearly between findings and open questions

You MUST NOT:

- Re-implement the pull request instead of reviewing it
- Present the command as a substitute for CodeRabbit, Sourcery, SonarCloud, or similar tools
- Invent project conventions not present in the loaded rule files
- Ignore the diff and review only the PR title/body

### 8. Acceptance Criteria

- The PR was reviewed against the project's rule files
- Findings are concrete, prioritized, and actionable
- Missing tests, regressions, and convention violations are called out when present
- The review explicitly stays within OSS Helper's scope and does not claim to replace specialized tools
