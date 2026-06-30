---
description: >
  CI/CD and code quality for open source projects. Covers fixing CI
  errors, SonarCloud issues, GitHub security/quality alerts, and
  applying quick fixes without a tracked issue. Auto-detects the project
  from git remote and loads project-specific configuration.
---

# OSS CI

This skill handles CI/CD and code quality issues for open source projects. When the user's request matches one of the capabilities below, follow the initialization steps first, then read and follow the appropriate guideline file.

## Before you start

Read and follow the initialization steps in [init.md](init.md) to detect the current project and load its configuration.

## Capabilities

After initialization, read and follow the appropriate guideline file based on the user's request.

| When the user wants to... | Read |
|---|---|
| Fix CI errors from a failed build | `fix-ci-errors.md` |
| Fix SonarCloud issues for a rule | `fix-sonarcloud.md` |
| Fix a GitHub security or quality alert | `fix-github-alert.md` |
| Apply a quick fix (CI, docs, deps, etc.) without a tracked issue | `quick-fix.md` |
