---
name: oss-loop-core
description: >
  Shared loop infrastructure for ForgeBot: circuit breaker (loop-guard),
  token budget enforcement (loop-budget), and safety constraints (loop-constraints).
  These skills are used by all ForgeBot loops (ci-sweeper, review-loop).
guidelines:
  - loop-guard.md: Circuit breaker — prevents burning tokens on unsolvable problems
  - loop-budget.md: Token budget enforcement — daily caps and early exit
  - loop-constraints.md: Safety rules enforcer — reads and applies binding constraints
  - loop-init.md: Initialize loop config files for a new project
  - self-update.md: Update ForgeBot skills to latest version via git pull
---
