# Review Question Templates

Use these templates during [step 5.1 (ASK)](review-pr.md#51-ask--form-review-questions) of the PR review workflow. Scan the diff for detection signals, then pick the matching review questions.

## Change-Type Templates

| Change Type | Detection Signal | Review Questions |
|---|---|---|
| **New public API** | `+ public` method or class added | Is the contract documented (Javadoc / docstring)? Is there a test? Is it thread-safe if accessed concurrently? |
| **Exception handling** | `catch` / `throws` / `raise` modified | Is the root cause preserved (chained exception)? Is the failure recoverable? Is the error message actionable? |
| **Dependency version bump** | `pom.xml` / `build.gradle` / `package.json` version changed | Does the new version have breaking API changes? Is CI coverage sufficient to catch regressions? Is the bump justified in the PR description? |
| **Concurrency** | `synchronized` / `Lock` / `Atomic` / `volatile` / `async` / threading primitives | Is the critical section minimal? Could this deadlock with existing locks? Is there a concurrency test? |
| **Config change** | Properties / YAML / `.env` / config files modified | Is there a migration path from the old config? Is the default value safe? Is the change documented (changelog, README)? |
| **Test-only** | Only test files changed | Does it reproduce a reported regression? Are assertions specific (not just `assertNotNull`)? Does it follow existing test conventions? |
| **Security-sensitive** | Auth / crypto / session / token / password files touched | Is user input validated and sanitized? Are secrets externalized (not hardcoded)? Is there an audit trail for the change? |

## How to Use

1. **Scan** the diff file list and hunks for detection signals in the middle column.
2. **Select** the matching change type(s) — most PRs match 1–2 types.
3. **Pick** 2–3 questions total from the matching rows. Prioritize questions where the diff gives you reason to doubt the answer.
4. **Skip** questions that are obviously satisfied by the diff (e.g., don't ask "Is there a test?" when the PR adds one).

## When No Template Matches

Form questions directly from the diff:

- _"Does the new behavior match the PR description / linked issue?"_
- _"Could this change regress existing behavior in [specific area]?"_
- _"Is the change tested for the edge case visible in [specific hunk]?"_

Keep to 2–3 questions maximum. More questions dilute review focus and increase noise.
