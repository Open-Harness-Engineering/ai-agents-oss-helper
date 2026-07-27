---
name: oss-container-upgrade-ci
description: >
  Container upgrade CI loop. Finds open container-image upgrade PRs that lack
  CI coverage, maps each test-infra module to its consuming component(s), and
  triggers targeted CI via /component-test comments. Tracks processed PRs in
  state.json to avoid duplicate triggers. One pass per invocation.
guidelines:
  - container-upgrade-ci.md: Main container upgrade CI orchestrator loop
---

# IMPORTANT -- Read container-upgrade-ci.md Before Doing Anything

**You MUST read and follow `container-upgrade-ci.md` step by step.** Do NOT
attempt to implement the loop from the description above -- the guideline
contains the full execution steps with precondition checks.

Start by reading `container-upgrade-ci.md` now.
