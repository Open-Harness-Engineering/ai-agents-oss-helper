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
