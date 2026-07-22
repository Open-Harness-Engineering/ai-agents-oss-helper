---
name: oss-ci-sweeper
description: >
  CI sweeper loop. Monitors CI on watched branches, classifies failures
  (flake, regression, infra), and proposes minimal fixes as draft PRs.
  Uses sub-agents for parallel fix and verification with a maker/checker pattern.
  Reads project config from .oss-ai-helper-rules/.
guidelines:
  - ci-sweeper.md: Main CI sweeper orchestrator loop
  - ci-triage.md: Classify CI failures (flake, regression, infra)
---

# IMPORTANT — Read ci-sweeper.md Before Doing Anything

**You MUST read and follow `ci-sweeper.md` step by step.** Do NOT attempt to
implement the CI sweeper from the description above — the guideline contains
mandatory blocking scripts that must run before any GitHub API calls.

Start by reading `ci-sweeper.md` now. Step 0 is a blocking precondition that
you MUST execute before proceeding.
