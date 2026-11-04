---
title: "OSS Helper documentation"
description: "Choose a path through OSS Helper installation, upgrades, maintenance tasks, project rules, command reference and contribution guides for the main branch."
---

# OSS Helper documentation

A collection of skills for AI coding agents (Claude, Bob, Gemini, OpenCode, Codex, agy) that provides guidelines for contributing to open source projects. The skills auto-detect the current project via `git remote get-url origin` and load project-specific configuration from rule files.

For agents that support skills natively (Claude, Bob, Codex, agy), the helper is installed as 6 focused, user-invocable skills — just describe what you want to do (or invoke `/oss-*` directly) and the agent follows the appropriate guidelines automatically. For other agents (Gemini, OpenCode), individual commands are generated from the same guidelines.

These guides describe the `main` branch; marketplaces currently track `main` rather than a numbered plugin release.

## Choose your path

| You want to… | Start here |
|---|---|
| Install the helper for your coding agent | [Get started](get-started/index.md) |
| Upgrade, remove legacy assets or set preferences | [Manage installations](manage/index.md) |
| Fix issues, review changes or handle a security case | [Run maintenance tasks](use/index.md) |
| Share repository conventions with contributors | [Configure projects](configure/index.md) |
| Find a command or agent-specific behavior | [Look up commands and agents](reference/index.md) |
| Change guidelines, build bundles or prepare a release | [Contribute to OSS Helper](contributing/index.md) |

## Is this for you?

Use these guides when you want an AI coding agent to follow the conventions of an open source repository. Start with the installation path for your agent, then add or install project rules before running maintenance tasks.

## Next steps

- [Get started](get-started/index.md) to choose your agent and install the helper.
- [Configure projects](configure/index.md) to make repository rules available to the helper.
