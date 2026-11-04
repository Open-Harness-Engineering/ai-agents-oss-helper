---
title: "Understand project rule loading"
description: "Understand how the helper selects project-local rules, installed fallback rules or discovered configuration before applying project-specific guidelines."
---

# Understand project rule loading

Understand how the helper selects project-local rules, installed fallback rules or discovered configuration before applying project-specific guidelines.

## Before you begin

Use [Configure a project](add-project.md) to create or install a rule set.

## Project rule files

The helper provides guidelines that are project-agnostic. Project-specific configuration is stored in rule files with three files per project:

- **`project-info.md`** - Repository URLs, issue trackers, SonarCloud keys, related repos
- **`project-standards.md`** - Build tools, commands, code style restrictions
- **`project-guidelines.md`** - Branch naming, commit formats, PR policies, task labels

## Rule loading priority

Each skill initializes by loading project rules in this priority order:

1. **Project-local rules** - `.oss-ai-helper-rules/` directory in the repository root. Highest priority, versioned with the project.
2. **Installed fallback rules** - A subdirectory under the agent's local rules directory (for example `~/.claude/oss-helper/rules/<project>/`) whose `project-info.md` declares a matching `Remote pattern`. Install these on demand with the Install Info guideline. Claude and Bob keep them under `oss-helper/rules/`, not `~/.claude/rules/`, because Claude Code loads every file under `~/.claude/rules/` into every session in every repository. Legacy rule sets remain readable in the old location; move them to `oss-helper/rules/` manually to stop Claude from preloading them.
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files in `.oss-ai-helper-rules/` so they can be committed and shared.

Projects should adopt project-local rules so that configuration travels with the repository and stays in sync across all contributors and agents.

## Next steps

- [Project configuration guides](index.md) for the section map.
- [Choose a rules repository](rules-repositories.md) to change the source of installed rules.
- [Run maintenance tasks](../use/run-tasks.md) using the selected configuration.
