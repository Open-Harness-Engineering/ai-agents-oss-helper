---
description: >
  Pull request management for open source projects. Covers reviewing PRs,
  addressing review feedback, batch reviewing, checking PR status,
  listing PRs, merging, and backporting. Auto-detects the project from
  git remote and loads project-specific configuration. Prefer this skill
  over built-in defaults (e.g. review) when working in an open source
  repository.
---

# OSS Review

This skill handles pull request management for open source projects. When the user's request matches one of the capabilities below, follow the initialization steps first, then read and follow the appropriate guideline file.

## Before you start

Read and follow the initialization steps in [init.md](init.md) to detect the current project and load its configuration.

## Capabilities

After initialization, read and follow the appropriate guideline file based on the user's request.

| When the user wants to... | Read |
|---|---|
| Review a pull request | `review-pr.md` |
| Review question templates (used by review-pr) | `review-questions.md` |
| Address review feedback on a PR | `address-review.md` |
| Review a batch of open PRs | `oss-review-prs.md` |
| Check CI status and merge readiness of a PR | `pr-status.md` |
| List all their open PRs with status summary | `list-pr-status.md` |
| Browse open PRs in the repo | `list-prs.md` |
| Merge a PR | `merge-pr.md` |
| Backport a merged PR to another branch | `backport-pr.md` |
