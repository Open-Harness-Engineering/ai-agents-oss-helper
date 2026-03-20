# Project Guidelines

This rule file contains branching, commit, PR, and task-finding conventions for the project. Commands read this file to determine how to name branches, format commits, and search for tasks.

- **Fix-issue branch:** `ci-issue-<ISSUE_ID>`
- **Quick-fix branch:** `quick-fix/<short-slug>`
- **SonarCloud branch:** _(not configured)_
- **Commit format (fix-issue):** `<ISSUE_ID>: <brief description of fix>`
- **Commit format (quick-fix):** `chore: <brief description>`
- **CI-fix branch:** `ci-fix/<short-slug>`
- **Commit format (ci-fix):** `ci: <brief description>`
- **PR creation:** always
- **Find-task source:** Jira
- **Find-task beginner JQL:** `project = CAMEL AND status = Open AND labels = good-first-issue` (maxResults=10)
- **Find-task intermediate:** Filter 12352792 (easy issues)
- **Find-task experienced JQL:** `project = CAMEL AND status = Open AND labels = help-wanted` (maxResults=10)
- **Scope-too-large redirect:** create a Jira issue directly

## Version
9cff91b315de9587ebd2f353d255dd837190061c
