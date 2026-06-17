# Review PRs (Batch)

Review a batch of open pull requests on the current project's repository in one pass: select the PRs (by default, the ones you have not already reviewed), review each against the project's rules using the same evaluation as `/oss-review-pr`, present one consolidated report, and — after a single approval — submit all the reviews.

This is the "actually review them" sibling of `/oss-list-prs`. Where `/oss-list-prs` makes one listing call and hands a single PR off to `/oss-review-pr`, this command fans out across many PRs and gates once. It does **not** replace `/oss-review-pr` for deep single-PR review, and like `/oss-review-pr` it is **not** a substitute for specialized review tools (CodeRabbit, Sourcery) or static analyzers (SonarCloud).

Nothing is posted to GitHub until you explicitly approve. By default the command never formally **approves** a PR in your name — clean PRs are reported (or commented), not auto-approved — unless you pass `auto-approve`.

## Usage

```
/oss-review-prs [author=<user>] [label=<label>] [limit=<N>]
                [include-reviewed] [include-drafts]
                [post=ask|actionable|all|none] [auto-approve]
```

**Arguments (all optional):**
- `author=<user>` — Only review PRs authored by `<user>`.
- `label=<label>` — Only review PRs with the given label (quote multi-word labels, e.g. `label="needs review"`).
- `limit=<N>` — Maximum number of candidate PRs to fetch (default: `20`).
- `include-reviewed` — Also review PRs you have already reviewed (default: skip them). Use this to re-review after authors have pushed new commits.
- `include-drafts` — Include draft PRs (excluded by default).
- `post=<mode>` — What to do after the consolidated report (default `ask`):
  - `ask` — present the report and ask how to post (interactive).
  - `actionable` — post only the `COMMENT` / `REQUEST_CHANGES` reviews; leave clean PRs unposted.
  - `all` — post every review (respecting `auto-approve` for the clean ones).
  - `none` — dry run: produce the report, post nothing.
- `auto-approve` — Allow the command to submit a formal `APPROVE` review on clean PRs in your name. Off by default — without it, clean PRs are reported (and, under `post=all`, posted as `COMMENT` rather than `APPROVE`).

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Arguments

Parse the optional arguments into local variables. Use these defaults when an argument is not provided:

| Argument | Default |
|----------|---------|
| `author` | _(none — all authors)_ |
| `label` | _(none — no label filter)_ |
| `limit` | `20` |
| `include-reviewed` | false (PRs you already reviewed are skipped) |
| `include-drafts` | false (drafts are excluded) |
| `post` | `ask` |
| `auto-approve` | false (clean PRs are never auto-approved) |

### 3. Determine the Current User

```bash
gh api user --jq '.login'
```

This login drives both the "authored by me" and "reviewed by me" exclusions below.

### 4. Select Candidate PRs

Select with the GitHub search qualifiers so the whole selection is a small number of **aggregate** `gh pr list` calls — never a per-PR review-history fetch. Start from `is:pr is:open` and add:

| Condition | Search fragment |
|-----------|-----------------|
| Drafts excluded (default) | `-is:draft` |
| Exclude your own PRs (always — you cannot review them) | `-author:@me` |
| Exclude PRs you already reviewed (default; unless `include-reviewed`) | `-reviewed-by:@me` |
| `author=<user>` provided | `author:<user>` |
| `label=<label>` provided | `label:"<label>"` |

```bash
gh pr list --repo <GITHUB_REPO> --search "<SEARCH_QUERY>" --limit <LIMIT> \
  --json number,title,author,headRefName,baseRefName,isDraft,updatedAt,reviewDecision,labels
```

From the result, drop PRs whose title marks them not-for-review (`[DO NOT MERGE]`, `[WIP]`, `WIP:`, `DRAFT:`) and record them as skipped.

If no PRs match, tell the user (suggest dropping a filter or `include-reviewed`) and stop.

If the candidate count is large (> 15), **state the count and confirm before continuing** — a batch review posts many public reviews under the operator's name.

### 5. Review Each Candidate (in parallel, read-only)

Review the candidates concurrently — this keeps the run fast and keeps each PR's diff out of the main context. For each PR, perform the **same evaluation `/oss-review-pr` does** (retrieve metadata + diff, investigate the git history of the modified files, evaluate against the project rule files) and return a structured verdict instead of posting anything:

- Recommended event: `APPROVE` / `COMMENT` / `REQUEST_CHANGES` (per the `/oss-review-pr` mapping).
- Findings, severity-ordered, with file references.
- A short checklist: tests, docs/upgrade-guide, commit convention, generated files, public-API / backward-compat, security, CI status.
- Any claim that could not be verified.

Group trivially similar PRs (for example automated dependency or container-image bumps) so they share one reviewer rather than one each.

Each review MUST be strictly **read-only**: no `gh pr review`, no comments, no labels, no checkout of PR branches, no working-tree changes.

### 6. Verify Load-Bearing Claims

Before presenting, re-check the claims a posted review would stand on — current CI state (`gh pr checks <PR>`), and any factual correction about existing code (confirm by reading the file / `grep`). Parallel sub-reviews can be wrong, and these reviews go out under the operator's name. Correct or downgrade anything that does not hold up.

### 7. Present the Consolidated Report

Present all reviews locally, grouped by recommended event (`REQUEST_CHANGES`, then `COMMENT`, then `APPROVE`), each with a one-line verdict and its key findings. Note the skipped PRs (already-reviewed, drafts, DO-NOT-MERGE) and any batch-threshold confirmation.

**Wait for approval before submitting anything to GitHub**, unless `post` was given a non-`ask` value (which pre-answers this). When asking, offer clear choices (e.g. post all / actionable only / pick / none, and whether to allow approvals).

### 8. Submit the Reviews

After approval (or per `post=`), submit each review with `gh pr review`:

```bash
gh pr review <PR> --repo <GITHUB_REPO> --request-changes --body-file <file>
gh pr review <PR> --repo <GITHUB_REPO> --comment         --body-file <file>
gh pr review <PR> --repo <GITHUB_REPO> --approve         --body-file <file>
```

- Use **review-body** comments, with `file:line` references in prose. Inline-position comments are fragile in a batch; only use them when highly confident of the diff position (and never duplicate an existing reviewer's inline note).
- Map events: clean → `APPROVE` **only if `auto-approve`**, otherwise `COMMENT`; questions / suggestions → `COMMENT`; blocking issues → `REQUEST_CHANGES`.
- Submit **sequentially** (not in parallel) to space the calls and avoid GitHub secondary rate limits.
- Every review body MUST end with an attribution + AI-disclaimer footer identifying the agent and the operator, e.g.:
  > _Reviewed with <agent> on behalf of <operator>. This review was generated by an AI agent and may contain inaccuracies; please verify all suggestions before applying._
- After posting, report a short summary (PR → event) and verify a sample landed with the expected state.

### 9. Constraints

You MUST:
- Initialize project context via `.oss-init.md` first.
- Select candidates with aggregate `gh pr list --search` calls only — never poll per-PR review history.
- Always exclude PRs authored by the current user, and (by default) PRs they have already reviewed.
- Review each PR against the project rule files, with the same rigor as `/oss-review-pr`.
- Verify CI state and factual corrections before presenting.
- Present one consolidated report and obtain a single approval before posting (unless `post=` pre-answers it).
- Include the attribution + AI-disclaimer footer on every posted review.
- Be constructive and empathetic when requesting changes — acknowledge the contributor's effort.

You MUST NOT:
- Post any review, comment, label, or state change before approval.
- Formally `APPROVE` a PR in the operator's name unless `auto-approve` is set.
- Review or approve a PR authored by the operator.
- Merge any PR, or push to any contributor's branch.
- Re-implement the PRs instead of reviewing them.
- Present this command as a substitute for CodeRabbit, Sourcery, SonarCloud, or similar tools.

### 10. Acceptance Criteria

- Candidates are selected with aggregate search calls, excluding the operator's own PRs and (by default) ones they already reviewed.
- Each candidate is reviewed against the project rule files with a recommended event and concrete, prioritized findings.
- Load-bearing claims (CI state, factual corrections) are verified before presenting.
- A single consolidated report is presented, and nothing is posted without approval (or an explicit `post=` value).
- Posted reviews use the correct event, carry the attribution + AI disclaimer, and clean PRs are not auto-approved unless `auto-approve` was passed.
- Skipped PRs and any batch-threshold confirmation are surfaced to the user.
