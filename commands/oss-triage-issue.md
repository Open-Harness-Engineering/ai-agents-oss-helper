# Triage Issue

Triage a freshly-filed issue from the project's tracker: understand what is being reported, reproduce it where feasible, search for duplicates and prior fixes, classify it (type, priority, affected component), and recommend a disposition. After triage, guide the maintainer to the right follow-up — request more information, hand off to a fix, refine the issue, or close it as duplicate / invalid / wontfix.

This command is **maintainer-side** triage. It is distinct from:
- `/oss-analyze-issue`, which is **contributor-side** — it helps someone who has already decided to fix an issue understand the code involved.
- `/oss-triage-security-report`, which stays **security-specific** and keeps all findings confidential. `/oss-triage-issue` is the general-purpose analog for ordinary bug reports, feature requests, and questions.

This command is read-only with respect to the tracker: it does NOT post comments, apply labels, change state, or assign anyone unless you explicitly confirm a handoff. The triage itself is a local investigative workflow.

## Usage

```
/oss-triage-issue <issue>
```

**Arguments:**
- `<issue>` - Issue identifier: numeric ID (e.g. `42`), alphanumeric ID (e.g. `CAMEL-20410`), or a full URL.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

Extract the issue ID from the argument based on the project's **Issue tracker** type (from `project-info.md`):

**GitHub projects:**
- Full URL (e.g. `https://github.com/org/repo/issues/42`): extract the number from the path.
- Number only: use as-is.

**Jira projects:**
- Full URL (e.g. `https://issues.apache.org/jira/browse/CAMEL-20410`): extract the ID from the path.
- ID only (e.g. `CAMEL-20410`): use as-is.

### 3. Retrieve Issue Details

**GitHub projects** — fetch the issue and its comments:

```bash
gh issue view <ISSUE_NUMBER> --repo <GITHUB_REPO> --json number,title,body,state,labels,assignees,milestone,comments,createdAt
```

**Jira projects** — fetch via the Jira REST API. Make **one** request only; do NOT poll.

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/issue/<ISSUE_ID>?fields=summary,description,status,priority,issuetype,components,labels,fixVersions,created,updated,comment" | jq '{
  key: .key, summary: .fields.summary, description: .fields.description,
  status: .fields.status.name, priority: .fields.priority.name, type: .fields.issuetype.name,
  components: [.fields.components[].name], labels: .fields.labels,
  fixVersions: [.fields.fixVersions[].name], created: .fields.created
}'
```

If the issue is already **closed**, note its resolution and ask the user whether they still want to triage it (e.g. to reopen or to confirm a close was correct).

### 4. Understand the Report

Read the title/summary, body/description, and comments. Extract a structured understanding:

- **Reported type** — bug, feature request, enhancement, question, documentation, support request.
- **Claimed behavior** — for a bug: expected vs. actual; for a request: the desired capability and motivation.
- **Reproduction inputs** — version/commit, environment (OS, runtime, build tool versions), configuration, and the steps the reporter gave.
- **Cited code / artifacts** — files, classes, stack traces, logs, error messages.
- **Reporter's proposed change** (if any).

Present this back to the user as a short structured summary and confirm nothing was misread. If the report is **missing information** required to proceed (no version, no steps, no error text), note exactly what is missing — this drives the "needs more info" disposition in step 9.

### 5. Reproduce the Report (where feasible)

Do not take the report at face value. Attempt to confirm it against the **current** code on `main`.

**For a bug:**
- Locate the implicated code with `Grep` / `Glob` and read it.
- Trace the path from the reporter's entry point to the symptom.
- Where the project has a build/test tool (read **Build/Test command** from `project-standards.md`), attempt a **minimal reproduction** — ideally a small failing test or a short standalone snippet that exercises the reported path. Keep it minimal and non-destructive; do not run anything that mutates external systems.
- If you cannot reproduce, record **why**: already fixed, missing information, environment-specific, reporter error, or works-as-designed.

**For a feature request / enhancement:**
- Confirm the capability does not already exist (search the codebase and docs).
- Note where it would fit and any obvious design constraints, without committing to a design.

Record a reproduction verdict: `reproduced`, `not reproduced`, `cannot reproduce (missing info)`, or `not applicable`.

### 6. Search for Duplicates and Related Work

**GitHub projects:**

```bash
# Open and closed issues with similar keywords
gh issue list --repo <GITHUB_REPO> --state all --search "<keywords>" --limit 20
# Linked or referencing PRs
gh pr list --repo <GITHUB_REPO> --state all --search "<keywords>" --limit 20
```

**Jira projects:**

```bash
curl -s "<ISSUE_TRACKER_URL>rest/api/2/search?jql=project=<JIRA_PROJECT_KEY>+AND+text+~+\"<keywords>\"&maxResults=10" | jq '.issues[] | {key, summary: .fields.summary, status: .fields.status.name}'
```

Identify exact duplicates, near-duplicates, and related issues (same component, prior discussion, rejected approaches).

### 7. Check Whether It Is Already Fixed

```bash
# Commits referencing the issue or the symptom
git log --all --oneline --grep="<ISSUE_ID>"
git log --all --oneline -i --grep="<distinctive keyword from the report>"
# History around the implicated code
git log --oneline -15 -- <affected-files>
git blame -L <start>,<end> -- <file>
```

Determine whether the reported defect was already addressed in `main` (and, if the project tracks releases, whether the fix has shipped). A bug that is fixed on `main` but reported against an older release changes the disposition (point to the fixing commit / release).

### 8. Classify

Assign:
- **Type** — bug / enhancement / documentation / question / duplicate / invalid.
- **Severity / priority** — based on impact and reach (data loss / crash / regression vs. cosmetic / edge-case). For Jira, map to the project's priority scheme (Blocker/Critical/Major/Minor/Trivial); for GitHub, to the project's conventions.
- **Affected component / module** — derived from the implicated path. For Jira, match against the project's component list.
- **Suggested labels** — propose labels and **validate them against the tracker's actual set** before suggesting:
  - GitHub: `gh label list --repo <GITHUB_REPO> --limit 100` — only propose labels that exist (or flag a new label explicitly).
  - Jira: labels are free-form, but components and priorities are constrained — use real component names.

### 9. Build the Triage Summary

Produce a structured summary. State confidence honestly; do not overstate certainty.

```markdown
> :robot: **Note:** This triage was generated by a coding agent and should be reviewed by a human maintainer before acting on it.

## Issue Triage — <issue id>

### Metadata
- **Title:** <title>
- **Reported type:** <type>  | **State:** <open/closed>
- **Affected component / module:** <component>
- **Reported against:** <version / commit, or "unspecified">

### Understanding
<2-4 sentences: what is actually being reported, in maintainer terms.>

### Reproduction
- **Verdict:** reproduced / not reproduced / cannot reproduce (missing info) / not applicable
- **Evidence:** <failing test, snippet, or the data-flow reasoning; or what is missing>

### Duplicates & Related
- **Duplicate of:** <id or "none found">
- **Related:** <ids / PRs>

### Already Fixed?
- <fixing commit / release, or "no prior fix found">

### Classification
- **Type:** <bug/enhancement/...>
- **Suggested priority/severity:** <level> — <rationale>
- **Suggested labels:** <validated labels>

### Recommended Disposition
- :large_blue_diamond: **Accept & fix** — valid and reproducible → hand off to `/oss-fix-issue`.
- :large_blue_diamond: **Needs more info** — cannot proceed without <missing items> → draft a reply.
- :large_blue_diamond: **Refine & keep** — valid but poorly specified → propose rewritten title/body via `/oss-create-issue` (or an edit).
- :large_blue_diamond: **Duplicate** — of <id> → draft a close-as-duplicate note.
- :large_blue_diamond: **Already fixed** — in <commit/release> → draft a note pointing there.
- :large_blue_diamond: **Invalid / wontfix / works-as-designed** — draft a factual, non-dismissive explanation.

### Open Questions
- <question 1>
```

### 10. Propose a Follow-up Path

Based on the disposition, offer one or more actions. Do **NOT** execute any of them without explicit confirmation, and do not touch the tracker until the user approves a specific handoff.

- **Accept & fix** — hand off to `/oss-fix-issue <issue>`.
- **Needs more info** — draft a concise, friendly comment listing exactly what is required (version, steps, logs, minimal repro). Present it for confirmation; only then offer to post it (`gh issue comment` / Jira) or let the user post it.
- **Refine & keep** — propose a rewritten title and body (clear repro, expected/actual, scope). Hand off to `/oss-create-issue` for a fresh well-formed issue, or present an edit for the existing one.
- **Duplicate / already fixed / invalid / wontfix** — draft the closing comment (referencing the duplicate id, fixing commit, or rationale). Apply the close + label only after the user confirms.
- **Label / prioritize only** — if the user just wants metadata applied, present the validated label/priority set and apply it on confirmation.

For GitHub, applying a confirmed action uses `gh issue comment`, `gh issue edit --add-label`, or `gh issue close --reason`. For Jira, present the exact transition/field change and let the user apply it (respect one-request rate limiting and do not loop).

### 11. Constraints

You MUST:
- Read and process `.oss-init.md` first.
- Include the :robot: disclaimer at the top of the triage summary.
- Verify the report against the **current** code before classifying it (read the implicated code; attempt reproduction where the project's tooling allows).
- Check the tracker for duplicates and git history for prior fixes.
- Validate any suggested labels/components against the tracker's real set before proposing them.
- Present any tracker-facing text (comment, edited body, close note) for explicit confirmation before it is posted.
- For Jira: make a single read request for the issue and do not poll.

You MUST NOT:
- Post a comment, apply a label, change state, or assign the issue without explicit user confirmation.
- Mark a report as invalid, duplicate, or wontfix without completing reproduction and duplicate/history checks.
- Overstate reproduction confidence — distinguish "reproduced" from "matched by static reading only".
- Modify the codebase as part of triage — fixing is the job of `/oss-fix-issue` after a confirmed handoff.
- Be dismissive in a drafted reply; a report may reflect a real problem in an older version.

### 12. Acceptance Criteria

- The issue is fetched and its report understood, with any missing information identified.
- A reproduction attempt is made (or its impossibility justified), with an explicit verdict.
- Duplicates and prior fixes are searched in both the tracker and git history.
- The issue is classified (type, priority, component) with labels validated against the tracker.
- A structured triage summary with the :robot: disclaimer and a clear recommended disposition is produced.
- A concrete follow-up path is proposed, with the appropriate downstream command named, and nothing is posted to the tracker without explicit confirmation.
