---
name: consolidate-learnings
description: >
  Graduate high-confidence review learnings into ast-grep rules or
  suppress patterns.
user-invocable: true
---

# Learnings Consolidation

Periodically extract high-confidence learnings into ast-grep rules or skill
improvements. This is the mechanism by which the review loop becomes
self-improving — validated patterns graduate from soft LLM guidance into
deterministic structural checks.

## Triggers

Run consolidation when any of these conditions are met:

1. A learning reaches `confidence >= 0.9` AND `occurrences >= 5`
2. The `learnings.json` file exceeds 50 entries
3. Monthly maintenance (at the start of each month's first loop run)

Consolidation can be triggered manually via `/consolidate-learnings`
or runs automatically within the review loop when triggers are met.

## Process

### 1. Load and Classify Learnings

Load `learnings.json` from the state branch. Classify learnings into
consolidation candidates:

| Category | Criteria | Action |
|----------|----------|--------|
| **Graduate to rule** | `type == "accepted"`, `confidence >= 0.9`, `occurrences >= 5`, describes a structural code pattern | Generate ast-grep YAML rule |
| **Graduate to suppress** | `type == "rejected"`, `suppressed == true`, `occurrences >= 3` | Add to suppress-patterns.yaml |
| **Prune** | `type == "rejected"`, `confidence == 0.0`, `occurrences >= 5` | Remove from learnings.json |
| **Keep** | All others | No action |

### 2. Generate ast-grep Rules

For each "graduate to rule" candidate, generate a YAML rule file:

```yaml
# Auto-generated from learning <id>
# Source: PR #<pr>, confidence <confidence>, occurrences <occurrences>
# Pattern: <learning.pattern>
id: learning-<short-id>
language: java
rule:
  # Extract the structural pattern from the learning description
  # This requires LLM interpretation of the natural-language pattern
  <ast-grep rule body>
message: "<learning.action>"
severity: warning
note: "Auto-generated from review learning. Original pattern: <learning.pattern>"
```

**Important**: Not all learnings can be expressed as ast-grep rules. Only
learnings that describe **structural code patterns** (e.g. "empty catch blocks
in camel-core should log at DEBUG") can be converted. Process/convention
learnings (e.g. "PRs touching SPI must update the compatibility matrix") should
be proposed as skill patches instead.

### 3. Generate Suppress Patterns

For each "graduate to suppress" candidate, add to `suppress-patterns.yaml`:

```yaml
# Auto-generated suppressions from review learnings
suppressions:
  - id: suppress-<short-id>
    rule: <finding_rule that was suppressed>
    file_pattern: <file_pattern from learning>
    reason: "<learning.pattern> — dismissed <occurrences>x, confidence <confidence>"
```

The reviewer prompt should load `suppress-patterns.yaml` and skip findings
that match a suppression entry.

### 4. Propose Changes

Consolidation outputs should be proposed as changes, not applied directly:

**For ast-grep rules (go to oss-helper):**

```bash
# Create a branch on the oss-helper repo
cd ~/.oss-helper  # or wherever oss-helper is cloned
git checkout -b learnings/consolidate-$(date +%Y%m%d)

# Copy generated rule files
cp /tmp/generated-rules/*.yml rules/java/quality/

# Commit and push
git add rules/
git commit -m "feat(rules): auto-generated rules from review learnings

Generated from $PROJECT learnings consolidation.
Rules: <list of new rule IDs>
Source learnings: <list of learning IDs>"
git push origin learnings/consolidate-$(date +%Y%m%d)

# Open PR
gh pr create --title "feat(rules): auto-generated rules from review learnings" \
  --body "These rules were automatically generated from high-confidence review
learnings on $PROJECT. Each rule has been validated through at least 5 reviews
with >= 90% confidence.

## New Rules
<table of new rules with pattern, confidence, occurrences>"
```

**For skill patches (go to oss-helper):**

Propose a patch to the relevant skill file. Include the learning source
and confidence data in the commit message.

**For suppress patterns (stay in oss-helper):**

Add to the state branch alongside other state files.

### 5. Update Learnings

After consolidation:

1. For graduated learnings: set a `graduated_to` field with the rule ID or
   skill patch reference. Keep the learning in the file for audit trail.
2. For pruned learnings: remove from `learnings.json`.
3. Push updated `learnings.json` to the state branch.

### 6. Report

```
## Learnings Consolidation Complete

- Learnings analyzed: <N>
- Graduated to ast-grep rules: <R> (proposed as PR to oss-helper)
- Added to suppress patterns: <S>
- Pruned (zero confidence): <P>
- Remaining active learnings: <K>
```

## Constraints

- Never auto-merge generated rules — always propose as PR for human review
- Include learning provenance (PR numbers, confidence, occurrences) in all generated artifacts
- Only generate ast-grep rules from structural code patterns, not process/convention learnings
- Suppress patterns are project-scoped — never leak between projects
- Keep graduated learnings in `learnings.json` with `graduated_to` for audit trail
