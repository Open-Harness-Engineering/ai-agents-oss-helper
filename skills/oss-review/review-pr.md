### Agent Delegation

If you have access to agents specialized in **code review** or **software architecture** (e.g., code review or architecture agents), you should delegate the evaluation (steps 4–5) to one or more of those agents. Provide them with the PR diff, project rules, and git history context. If no specialized agents are available, perform all steps directly.

### 1. Parse Input

Extract the pull request number:

- If the input is a full GitHub pull request URL (for example, `https://github.com/org/repo/pull/42`), extract the number from the path
- If the input is a number only, use it as-is

### 2. Retrieve Pull Request Details

Fetch the pull request metadata:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,body,baseRefName,headRefName,author,changedFiles,additions,deletions
```

Fetch the diff for detailed review:

```bash
gh pr diff <PR_NUMBER> --repo <GITHUB_REPO>
```

If the PR references an issue or ticket, review that context as needed to validate scope and intent.

### 3. Investigate Git History

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

### 4. Review Scope

Review the pull request specifically against the loaded project rules:

- **Project guidelines** - Commit conventions, PR expectations, contribution process
- **Project standards** - Build, test, format, and code-style expectations
- **Project information** - Related repositories or tracker conventions that affect the change

This command is a rules-and-conventions review. It is **not** a replacement for specialized review tools such as CodeRabbit or Sourcery, and it is **not** a replacement for static analyzers such as SonarCloud.

### 5. Review the Changes (Ask → Narrow → Read → Decide)

Use a question-driven review workflow. Do **not** attempt to "review everything" — form specific questions, gather minimal context, then judge.

#### 5.1 ASK — Form Review Questions

Read the diff summary (changed files, additions, deletions) and form **2–3 specific review questions** about the changes. Use the change-type templates in [review-questions.md](review-questions.md) to select questions that match the diff signals:

- Scan the diff for detection signals (new public API, exception handling changes, dependency bumps, concurrency primitives, config changes, test-only changes, security-sensitive files).
- For each signal detected, pick the corresponding review questions from the template.
- If no template matches, form questions from the diff itself: _"Does this change handle X correctly?"_, _"Is the new behavior tested?"_, _"Could this regress Y?"_

Limit yourself to 2–3 high-value questions. More questions dilute focus.

#### 5.2 NARROW — Identify Target Regions

For each review question, identify the **smallest code region** in the diff that answers it:

- A single hunk, a method signature, a test assertion, a config block.
- Note the file and line range. Do not expand beyond what the question requires.

#### 5.3 READ — Gather Targeted Context

Read **only** the targeted regions identified above. If a region is ambiguous, use `git blame` or `git log` on that specific region — not the entire file.

**Anti-patterns — do NOT:**

- Read entire files when only a few lines changed
- Browse related files without a specific question demanding it
- Repeat static-analysis findings without adding new insight
- Flag style issues covered by the project's configured formatter or linter
- Expand context "just in case" — every extra file read must be justified by a question

#### 5.4 DECIDE — Judge Each Question

For each review question, reach exactly one verdict:

| Verdict | Meaning | Action |
|---------|---------|--------|
| **Non-issue** | The code handles it correctly | No finding — do not mention it |
| **Real issue** | The code has a concrete bug, gap, or rule violation | Record as a finding with file + line reference |
| **Uncertain** | One more targeted check could resolve it | Perform that one check, then decide non-issue or real issue — do not leave it uncertain |

### 6. Present Review Findings

Present findings locally in **structured review format**, tracing each finding back to the review question that produced it:

For each finding, include:

1. **Review question** — The specific question from step 5.1 that led to this finding
2. **Code region** — File, line range, and the relevant code snippet
3. **Verdict** — What was found (bug, missing test, rule violation, risk)
4. **Severity** — Blocking / non-blocking / suggestion
5. **Evidence** — Why this is an issue (diff excerpt, rule reference, git history)

Order findings by severity (blocking first).

Clearly separate:
- **Confirmed issues** — Directly supported by the diff, rule files, or git history
- **Questions / assumptions** — Areas where the PR may be correct but context is missing

If all review questions resolved as non-issues, state that explicitly: _"All review questions resolved — no issues found."_

Keep the review concise and actionable. Do not pad findings with restated diff content.

**Wait for user approval before submitting the review to GitHub.**

### 7. Submit Review to GitHub

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

````text
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

### 8. Constraints

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

### 9. Acceptance Criteria

- The PR was reviewed against the project's rule files
- Findings are concrete, prioritized, and actionable
- Missing tests, regressions, and convention violations are called out when present
- The review explicitly stays within OSS Helper's scope and does not claim to replace specialized tools
- Review is submitted to GitHub with inline comments on specific lines where possible
- Suggestion blocks are used for clear, concrete fixes
- The review includes the AI-generated disclaimer
