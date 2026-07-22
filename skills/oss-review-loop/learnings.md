# Review Learnings System

Persistent learnings from PR review feedback. The learnings file accumulates
patterns that were confirmed (accepted) or dismissed (rejected) by humans,
allowing the review loop to improve over time.

## Data Model

Learnings are stored in `learnings.json` on the state branch alongside STATE.md.
See `learnings-schema.json` for the full JSON Schema.

### Learning Types

| Type | Created When | Initial Confidence | Decay |
|------|-------------|-------------------|-------|
| `accepted` | Reviewer flagged X → human agreed (applied suggestion, resolved comment) | 0.5 | Normal |
| `rejected` | Reviewer flagged X → human dismissed (dismissed review, merged without resolving) | 0.5 | Normal |
| `instruction` | Explicit human directive via PR comment or config | 1.0 | Never |

### Confidence Rules

Confidence tracks how reliable a learning is across multiple observations:

- **Initial score**: 0.5 for organic learnings, 1.0 for instructions
- **On acceptance**: `confidence = min(1.0, confidence + 0.15)`
- **On rejection**: `confidence = max(0.0, confidence - 0.25)` (faster decay — false positives are costly)
- **Auto-suppress**: When `confidence < 0.1` AND `occurrences >= 3`, set `suppressed = true`
- **Instructions**: Never decay, never auto-suppress

### File Pattern Scoping

Each learning has an optional `file_pattern` glob (e.g. `src/main/**/*.java`,
`**/pom.xml`). When loading learnings for a PR, filter to learnings whose
`file_pattern` matches at least one file in the PR diff. Learnings without a
`file_pattern` apply to all files.

## Loading Learnings

During the review loop (step 1, Read State), load `learnings.json` from the
state branch:

```bash
# Read learnings from state branch via API
LEARNINGS=$(gh api repos/$FORK_REPO/contents/learnings.json?ref=$STATE_BRANCH \
  --jq '.content' 2>/dev/null | base64 -d)
```

If the file doesn't exist, start with an empty learnings set.

### Filtering for a PR

Before injecting into the reviewer prompt, filter learnings:

1. Remove `suppressed == true` entries
2. Remove entries where `file_pattern` doesn't match any file in the PR diff
3. Sort by confidence (highest first)
4. Limit to top 20 to avoid prompt bloat

## Injecting into Reviews

Split filtered learnings into two categories for the reviewer prompt:

### BOOST (high-confidence accepted patterns)

Learnings with `type == "accepted"` AND `confidence >= 0.5`:

```
## Review Learnings — BOOST
These patterns were confirmed as real issues in past reviews on this project.
Pay extra attention when you see them:

- [confidence: 0.85, seen 6x] Empty catch blocks in camel-core components
  should always log at DEBUG level (project convention)
- [confidence: 0.65, seen 3x] New public API methods in SPI packages require
  @since javadoc tag
```

### SUPPRESS (low-confidence rejected patterns)

Learnings with `type == "rejected"` AND `confidence < 0.3`:

```
## Review Learnings — SUPPRESS
These patterns were previously flagged but dismissed by maintainers.
Do NOT flag them unless you have strong new evidence:

- [confidence: 0.15, dismissed 4x] Unused imports in test files — project
  uses star imports intentionally
- [confidence: 0.10, dismissed 3x] Missing null checks on CamelContext
  parameters — guaranteed non-null by framework
```

### Instructions

Learnings with `type == "instruction"` are always included:

```
## Review Instructions (from project maintainers)
- Always check for SQL injection in controller files
- Camel endpoint URIs must use constants, not string concatenation
```

## Detecting Feedback

After posting reviews (review-loop step 7), scan for feedback on past reviews
to update learnings. Check reviews posted in the last 7 days:

### Signal: Suggestion Applied

```bash
# Get commits after our review
REVIEW_DATE="<date of our review>"
gh api repos/$UPSTREAM_REPO/pulls/<NUMBER>/commits \
  --jq "[.[] | select(.commit.committer.date > \"$REVIEW_DATE\")] | length"
```

If there are commits after our review AND they touch the same file/line we
commented on → likely **accepted**. Verify by checking if the commit diff
matches our suggestion.

### Signal: Review Dismissed

```bash
gh api repos/$UPSTREAM_REPO/pulls/<NUMBER>/reviews \
  --jq '.[] | select(.body | contains("AI agent")) | select(.state == "DISMISSED")'
```

If our review was dismissed → **rejected**.

### Signal: PR Merged Without Resolution

```bash
gh pr view <NUMBER> --repo $UPSTREAM_REPO --json state,mergedAt
```

If the PR was merged and our review comments were not resolved → likely
**rejected** (maintainer chose to ignore the finding).

### Signal: Explicit Feedback

If a maintainer replies to our review comment with keywords:
- "good catch", "fixed", "thanks" → **accepted**
- "false positive", "intentional", "by design", "not an issue" → **rejected**
- "always check for...", "rule: ..." → create **instruction**

## Updating Learnings

For each feedback signal detected:

1. **Find existing learning** matching the same `finding_rule` + `file_pattern`
2. If found:
   - Update `confidence` using the growth/decay rules
   - Increment `occurrences`
   - Update `last_seen`
   - Check auto-suppress condition
3. If not found:
   - Create a new learning entry with a UUID, initial confidence 0.5
   - Extract `finding_rule` from the review comment (ast-grep rule ID or general pattern)
   - Extract `file_pattern` from the reviewed file path
4. Push updated `learnings.json` alongside other state files

## Constraints

- Learnings are **per-project** — each project's state branch has its own `learnings.json`
- Maximum 100 learnings per project (oldest low-confidence entries pruned first)
- Instructions are never auto-pruned
- Suppressed learnings are still stored (for audit) but excluded from prompts
- Never leak learnings from one project into another project's reviews
