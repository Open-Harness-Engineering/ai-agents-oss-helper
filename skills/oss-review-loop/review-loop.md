---
name: review-loop
description: >
  PR review loop. Lists open PRs, filters already-reviewed
  ones, triages new/updated PRs, and reviews them using sub-agents with
  a maker/checker pattern. Tracks state in STATE.md.
user-invocable: true
---

# PR Review Loop

Automated loop that discovers, triages, and reviews open PRs.
Uses sub-agents for parallel review and verification, and the oss-helper
`review-pr.md` guideline for the actual review logic.

## Architecture

```
Main loop (orchestrator)
  +-- Step 1-4: Triage (inline -- fast, low cost)
  |
  +-- Step 5: Review (sub-agents, parallel)
  |     +-- Reviewer agent PR #1234  <- gets learnings, runs review-pr.md (incl. SA)
  |     +-- Reviewer agent PR #5678
  |     +-- Reviewer agent PR #9012
  |
  +-- Step 6: Verify (sub-agents, one per review)
  |     +-- Verifier agent PR #1234  <- checks reviewer's findings
  |     +-- Verifier agent PR #5678
  |     +-- Verifier agent PR #9012
  |
  +-- Step 7-8: Post & update state (inline)
```

- **Reviewer agents** do the deep review work (read diff, git history, project rules).
  Each runs in parallel to avoid serializing expensive diff analysis.
- **Verifier agents** independently check each reviewer's findings for false positives
  before anything is posted to GitHub. This is the maker/checker split.
- **No worktrees needed** -- reviews are read-only (diffs come from `gh pr diff`).

## Execution Steps

### 0. MANDATORY — Block Until Activity Detected

> **🛑 STOP. Do NOT skip this step. Do NOT proceed to step 1.**
>
> You MUST run the blocking precondition script FIRST, BEFORE doing anything
> else. This script polls GitHub using zero-cost ETag requests and BLOCKS
> until there is actual PR activity. Without it, you burn tokens checking
> for work that doesn't exist.
>
> **If you skip this step and go straight to `gh pr list`, you are doing it
> wrong.** The whole point of this loop is to sleep cheaply and only wake up
> when there's work.

Run these commands NOW, before reading any further:

```bash
# 1. Detect fork repo and state branch from local config
#    (loop-config.json exists in the worktree from previous runs or setup)
FORK_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
STATE_BRANCH=$(python3 -c "import json; print(json.load(open('loop-config.json'))['state_branch'])" 2>/dev/null || echo "")

# 2. Pull latest state from the fork (skip if no config yet — first run)
if [[ -n "$STATE_BRANCH" ]]; then
  ~/.claude/scripts/pull-state.sh "$FORK_REPO" "$STATE_BRANCH" .
fi

# 3. BLOCK here until GitHub activity is detected
#    This command will NOT return for minutes or hours. That is correct.
#    Do NOT interrupt it. Do NOT set a short timeout. Let it block.
~/.claude/scripts/wait-for-pr-work.sh state.json
```

**This command blocks.** It sits in a `while true` loop, polling the GitHub
Events API with ETag conditional requests (304 = free, no rate limit hit).
It will return ONLY when:
- New PR activity is detected (exit 0 → proceed to step 1)
- The kill switch is set in state.json (exit 1 → stop, do nothing)

**Expected behavior:** After you run this command, nothing happens for a long
time. That is correct. The script is sleeping and polling. You are saving
tokens by not doing anything until there's actual work.

**With ForgeBot `/loop`:** Use `--timeout` matching the loop interval:
```bash
~/.claude/scripts/wait-for-pr-work.sh --timeout 900 state.json
```
Exit 1 on timeout = skip this tick, report nothing, exit immediately.

**Do NOT proceed past this point until `wait-for-pr-work.sh` returns exit 0.**

If it exits with code 1 (timeout, no work, or kill switch):
- **Output nothing.** Do not say "no PRs found" or "queue empty."
- **Do not run `gh pr list`.** The script already checked.
- **Exit immediately.** The loop will fire again later.

If it exits with code 0, proceed:

1. Run the ForgeBot init steps (read `init.md`) to detect the project and load config.
2. Read `loop-config.json` -- load constraints, budget, cadence (all in one file).
3. Check `state.json` `paused` flag -- if true, exit immediately.

From initialization, you now have:
- **UPSTREAM_REPO**: the upstream org/repo (from `project-info.md`)
- **FORK_REPO**: the operator's fork org/repo
- **OPERATOR_NAME**: for attribution
- **MAX_PRS_PER_RUN**: from `loop-config.json`
- **STATE_BRANCH**: from `loop-config.json`

### 0.5 Check for Unanswered Replies (Deterministic — No LLM for detection)

Before triaging new PRs, check if anyone replied to our past review comments:

```bash
python3 ~/.claude/scripts/check-review-replies.py $UPSTREAM_REPO state.json --days 14 \
  > /tmp/unanswered-replies.json 2>/dev/null
```

If the script exits with code 0, there are unanswered replies. These take
priority over new reviews — someone is waiting for our response.

For each unanswered reply (this part needs the LLM):
- **Questions**: read the thread context and respond with a helpful answer
- **Disagreements**: re-examine our original finding, concede if wrong, clarify if right
- **Acknowledgments**: no response needed (but note the positive signal for learnings)

Post replies via the GitHub API:

```bash
gh api repos/$UPSTREAM_REPO/pulls/<PR>/comments --method POST \
  -f body="<response>" \
  -F in_reply_to=<thread_id>
```

After responding, record the interaction:

```bash
python3 ~/.claude/scripts/update-state.py state.json reviewed \
  --pr <NUMBER> --verdict COMMENT --notes "Responded to <author>'s reply"
```

### 1. Read Current State

State is already pulled in step 0. Read `state.json` (JSON, no parsing needed):

- `reviewed_prs[]` — already reviewed, with timestamps and verdicts
- `skipped_prs[]` — permanently skipped, with reasons
- `last_run` — timestamp, counts from the previous run
- `paused` — kill switch flag

Also load `learnings.json` (already pulled in step 0).

If either file is missing, start with empty defaults.

### 2. Triage PRs (Deterministic — No LLM)

Run the deterministic triage script to get actionable PRs:

```bash
python3 ~/.claude/scripts/triage-prs.py $UPSTREAM_REPO state.json \
  --max $MAX_PRS_PER_RUN --format json > /tmp/actionable-prs.json
```

This script handles all filtering (bots, drafts, already-reviewed, skipped,
drift detection) and prioritization (review-required, age, recency)
**without any LLM calls**. The output is a JSON array of actionable PRs
with number, title, author, priority, and whether it's a re-review.

Select the top N PRs by priority (N = `MAX_PRS_PER_RUN` from loop-budget.md).

### 5. Review PRs (Parallel Sub-agents)

For each selected PR, spawn a **reviewer sub-agent** using the Agent tool.
Launch all reviewer agents in a single message so they run concurrently.

Each reviewer agent prompt must include:

```
You are reviewing PR #<NUMBER> on $UPSTREAM_REPO.

## Review Learnings (from past reviews)

<Include filtered learnings from learnings.json here. See learnings.md for
filtering and formatting rules. Split into BOOST (accepted, confidence >= 0.5),
SUPPRESS (rejected, confidence < 0.3), and INSTRUCTIONS sections.
Filter by file_pattern relevance to this PR's changed files.
Limit to top 20 learnings. Omit this section entirely if no learnings exist.>

IMPORTANT: Before doing anything else, read and follow the oss-helper review-pr
guideline. This is the canonical review process for this project:

1. Read the oss-helper skill and review guideline:
   - Read the oss-review skill files (if installed)
   - Read review-pr.md (the review process)

2. Run the oss-helper initialization:
   - Detect project from git remote
   - Load project rules from .oss-ai-helper-rules/
     (project-info.md, project-standards.md, project-guidelines.md)

3. Follow review-pr.md steps 1-6 exactly:
   - Parse the PR number
   - Fetch PR metadata and diff via gh
   - Investigate git history of modified files (git log, git blame)
   - Review against the loaded project rules
   - Evaluate for issues (missing tests, regressions, convention violations, etc.)

4. Return your findings as structured output (do NOT post to GitHub -- the main
   loop handles that):

   VERDICT: <APPROVE|COMMENT|REQUEST_CHANGES>
   SUMMARY: <1-2 sentence overall assessment>
   FINDINGS:
   - [SEVERITY: high|medium|low] [FILE: path/to/file] [LINE: N] <description>
   SUGGESTION_BLOCKS:
   - [FILE: path/to/file] [START_LINE: N] [END_LINE: M]
     ```suggestion
     <corrected code>
     ```
   GENERAL_COMMENTS:
   - <comment not tied to a specific line>

Return ONLY the structured output above -- no preamble, no markdown headers.
```

### 6. Verify Findings (Parallel Sub-agents)

After all reviewer agents complete, spawn a **verifier sub-agent** for each review
that returned findings (verdict != APPROVE). Launch all verifiers in parallel.

Each verifier agent prompt must include:

```
You are a verification agent. A reviewer found the following issues in PR #<NUMBER>
on $UPSTREAM_REPO. Your job is to independently check each finding and determine
whether it is a TRUE issue or a FALSE POSITIVE.

Be skeptical. Default to marking findings as false positives unless you can
independently confirm the issue by reading the diff and git history yourself.

PR DIFF (fetch fresh):
  gh pr diff <NUMBER> --repo $UPSTREAM_REPO

REVIEWER'S FINDINGS:
<paste the reviewer's structured output here>

For EACH finding, independently verify:
1. Does the file and line reference exist in the diff?
2. Is the finding actually a problem, or is it correct code?
3. Does git history show this was intentional? (git log, git blame)
4. Does it actually violate the cited rule?

Return your verification as:

VERIFIED_FINDINGS:
- [FINDING: <original finding summary>] [VERDICT: confirmed|false_positive] [REASON: <why>]
FINAL_VERDICT: <APPROVE|COMMENT|REQUEST_CHANGES>
FINAL_SUMMARY: <updated summary after removing false positives>

Return ONLY the structured output above.
```

### 7. Post Reviews to GitHub

For each PR where the verifier confirmed at least one finding, post the review
to GitHub. Only include **verified findings** (not false positives).

Build the review using the GitHub API:

```bash
gh api repos/$UPSTREAM_REPO/pulls/<NUMBER>/reviews --input - <<'EOF'
{
  "event": "<COMMENT|REQUEST_CHANGES|APPROVE>",
  "body": "<FINAL_SUMMARY>\n\n_This review was generated by an AI agent and may contain inaccuracies. Please verify all suggestions before applying._\n\n_Claude Code on behalf of $OPERATOR_NAME_",
  "comments": [
    {
      "path": "<file>",
      "line": <line>,
      "side": "RIGHT",
      "body": "<finding description or suggestion block>"
    }
  ]
}
EOF
```

For PRs where all findings were marked as false positives, do NOT post a review.

For PRs where the reviewer returned APPROVE (no findings), always post an
approving review.

### 7.5 Detect Feedback on Past Reviews (Deterministic — No LLM)

Run the feedback detection script:

```bash
python3 ~/.claude/scripts/detect-feedback.py $UPSTREAM_REPO state.json learnings.json --days 7
```

This script deterministically scans past reviews for signals (dismissed,
merged, new commits) and updates `learnings.json` confidence scores.
No LLM calls. See `learnings.md` for the data model.

### 8. Update State (Deterministic — No LLM)

After posting reviews, update state using the script:

```bash
# Record each reviewed PR
python3 ~/.claude/scripts/update-state.py state.json reviewed \
  --pr <NUMBER> --title "<title>" --author "<author>" \
  --verdict <APPROVE|COMMENT|REQUEST_CHANGES> \
  --notes "<one-line summary>"

# Record skipped PRs
python3 ~/.claude/scripts/update-state.py state.json skip \
  --pr <NUMBER> --reason "<reason>"

# Record this run
python3 ~/.claude/scripts/update-state.py state.json run \
  --prs-checked <N> --reviews-posted <M> --tokens <T>
```

### 9. Push State to Fork (Deterministic — No LLM)

```bash
~/.claude/scripts/push-state.sh $FORK_REPO $STATE_BRANCH \
  state.json loop-run-log.json learnings.json
```

This script pushes via the GitHub Contents API — no git checkout needed,
safe in worktrees. Never force-pushes. If the push fails, logs the error
and continues.

### 10. Summary

```
## Loop Complete

- Reviewed: <N> PRs (<M> reviews posted, <K> suppressed by verifier)
- Skipped: <P> PRs
- False positive rate: <X>%
- Remaining in queue: <R> PRs
- Learnings updated: <L> entries (<A> accepted, <J> rejected, <I> instructions)
```

## Constraints

You MUST:
- Read STATE.md before fetching PRs to avoid re-reviewing
- Spawn reviewer agents in parallel (all in one message)
- Spawn verifier agents in parallel after reviewers complete
- Only post verified findings -- never post unverified reviewer output directly
- Post reviews with the AI-generated disclaimer and operator attribution
- Update STATE.md after every run
- Respect the per-run PR limit from loop-budget.md
- Use project rules from .oss-ai-helper-rules/ for review standards
- Load and inject learnings into reviewer prompts (see learnings.md)
- Detect feedback on past reviews and update learnings.json
- Push learnings.json alongside other state files

You MUST NOT:
- Merge, close, or label any PR
- Review draft PRs
- Post a review without running the verifier first
- Post reviews where all findings were false positives
- Skip the git history investigation step in reviewer agents
- Hardcode any project-specific values (repo names, commands, etc.)
