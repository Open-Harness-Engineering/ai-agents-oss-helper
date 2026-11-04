---
title: "Choose a rules repository"
description: "Find the shared known-projects rule collection and override its repository or branch when your team maintains configuration in a separate source."
---

# Choose a rules repository

Find the shared known-projects rule collection and override its repository or branch when your team maintains configuration in a separate source.

## Before you begin

Read [Understand project rule loading](rule-loading.md) before changing the source of installed rules.

## Shared rule collection

Project rules are not bundled with the plugin. They live in a separate repository, [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects), and are installed on demand via the Install Info guideline. This keeps the helper focused on guidelines and lets projects that prefer not to host AI-agent metadata in their source tree have rules hosted centrally instead.

## Point at a different repository

The default source is [`Open-Harness-Engineering/ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects) on the `main` branch. You can override either part with environment variables — useful for teams that maintain a private fork of the rules repo:

| Variable | Default | Purpose |
|----------|---------|---------|
| `OSS_KNOWN_PROJECTS_REPO` | `Open-Harness-Engineering/ai-agents-oss-known-projects` | GitHub `org/repo` to read rules from |
| `OSS_KNOWN_PROJECTS_BRANCH` | `main` | Branch within that repository |

## Next steps

- [Project configuration guides](index.md) for the section map.
- [Install project rules](add-project.md#install-known-project-rules) from your chosen collection.
- [Return to rule loading](rule-loading.md) to understand local-rule precedence.
