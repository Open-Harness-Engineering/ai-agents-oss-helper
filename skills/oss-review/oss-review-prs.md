### Agent Delegation

If you have access to agents specialized in **code review** (e.g., code review agents), you should use them for the per-PR evaluations in step 4. Each agent should receive the PR diff, project rules, and git history context, and return a structured verdict. If no specialized agents are available, perform all evaluations directly.

### 1. Parse Arguments

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

### 2. Determine the Current User

```bash
gh api user --jq '.login'
```

This login drives both the "authored by me" and "reviewed by me" exclusions below.

### 3. Select Candidate PRs

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

### 4. Review Each Candidate (in parallel, read-only)

Review the candidates concurrently — this keeps the run fast and keeps each PR's diff out of the main context. For each PR, perform the **same evaluation the Review PR guideline (`review-pr.md`) does** (retrieve metadata + diff, investigate the git history of the modified files, evaluate against the project rule files) and return a structured verdict instead of posting anything:

- Recommended event: `APPROVE` / `COMMENT` / `REQUEST_CHANGES` (per the Review PR guideline mapping).
- Findings, severity-ordered, with file references.
- A short checklist: tests, docs/upgrade-guide, commit convention, generated files, public-API / backward-compat, security, CI status.
- Any claim that could not be verified.

Group trivially similar PRs (for example automated dependency or container-image bumps) so they share one reviewer rather than one each.

Each review MUST be strictly **read-only**: no `gh pr review`, no comments, no labels, no checkout of PR branches, no working-tree changes.

### 5. Verify Load-Bearing Claims

Before presenting, re-check the claims a posted review would stand on — current CI state (`gh pr checks <PR>`), and any factual correction about existing code (confirm by reading the file / `grep`). Parallel sub-reviews can be wrong, and these reviews go out under the operator's name. Correct or downgrade anything that does not hold up.

### 6. Present the Consolidated Report

Present all reviews locally, grouped by recommended event (`REQUEST_CHANGES`, then `COMMENT`, then `APPROVE`), each with a one-line verdict and its key findings. Note the skipped PRs (already-reviewed, drafts, DO-NOT-MERGE) and any batch-threshold confirmation.

**Wait for approval before submitting anything to GitHub**, unless `post` was given a non-`ask` value (which pre-answers this). When asking, offer clear choices (e.g. post all / actionable only / pick / none, and whether to allow approvals).

### 7. Submit the Reviews

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

### 8. Constraints

You MUST:

- Select candidates with aggregate `gh pr list --search` calls only — never poll per-PR review history.
- Always exclude PRs authored by the current user, and (by default) PRs they have already reviewed.
- Review each PR against the project rule files, with the same rigor as the Review PR guideline (`review-pr.md`).
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

### 9. Acceptance Criteria

- Candidates are selected with aggregate search calls, excluding the operator's own PRs and (by default) ones they already reviewed.
- Each candidate is reviewed against the project rule files with a recommended event and concrete, prioritized findings.
- Load-bearing claims (CI state, factual corrections) are verified before presenting.
- A single consolidated report is presented, and nothing is posted without approval (or an explicit `post=` value).
- Posted reviews use the correct event, carry the attribution + AI disclaimer, and clean PRs are not auto-approved unless `auto-approve` was passed.
- Skipped PRs and any batch-threshold confirmation are surfaced to the user.
