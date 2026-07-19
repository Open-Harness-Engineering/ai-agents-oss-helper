---
description: >
  Project setup and workspace management for open source projects.
  Covers adding new projects, installing project rules, generating
  rules, updating knowledge, and managing multi-repo workspaces.
  Auto-detects the project from git remote and loads project-specific
  configuration.
---

# OSS Project

This skill handles project setup and workspace management for open source projects. When the user's request matches one of the capabilities below, follow the initialization steps first, then read and follow the appropriate guideline file.

## Before you start

Read and follow the initialization steps in [init.md](init.md) to detect the current project and load its configuration.

## Capabilities

After initialization, read and follow the appropriate guideline file based on the user's request.

| When the user wants to... | Read |
|---|---|
| Add a new project to the helper | `add-project.md` |
| Install project rules from the known-projects repository | `install-info.md` |
| Generate project rule files for a repository | `oss-create-rules.md` |
| Update project rule files | `update-knowledge.md` |
| Initialize or rediscover a multi-repo workspace | `oss-workspace-init.md` |
| Report status of all repos in a workspace | `oss-workspace-status.md` |
| Update the OSS Helper itself | `self-update.md` |
