---
name: oss-review-loop
description: >
  PR review loop. Lists open PRs, filters already-reviewed ones,
  triages new/updated PRs, and reviews them using sub-agents with
  a maker/checker pattern. Reads project config from .oss-ai-helper-rules/.
guidelines:
  - review-loop.md: Main PR review orchestrator loop
  - pr-review-triage.md: Quick triage per PR (CI status, review state)
  - learnings.md: Review learnings system — persistent feedback loop for self-improvement
  - consolidate-learnings.md: Graduate high-confidence learnings into ast-grep rules
---
