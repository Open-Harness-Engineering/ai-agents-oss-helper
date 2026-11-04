---
title: "Remove legacy installations"
description: "Preview and remove legacy OSS Helper assets, preserve unrelated files and project rules, and identify leftovers before changing installation methods."
---

# Remove legacy installations

Preview and remove legacy OSS Helper assets, preserve unrelated files and project rules, and identify leftovers before changing installation methods.

## Before you begin

Identify the agent you want to clean up. Keep any installation you still use until you choose its replacement.

## Preview and remove legacy assets

Before switching from the old installer, preview the legacy files to remove:

```bash
./uninstall.sh claude          # Preview only
./uninstall.sh --yes claude    # Remove legacy Claude assets
./uninstall.sh --yes           # All six agents
```

The uninstaller preserves project rules, security case data and unrelated user
assets. It does not remove marketplace-managed plugins. To remove the Claude
plugin, run `claude plugin uninstall oss-helper@ai-agents-oss-helper`. After
removing legacy Claude assets, install the marketplace plugin and start a fresh
session.

The uninstaller's filename lists cover recent OSS Helper versions. Much older
installers may have left additional files or directories behind. The uninstaller
reports possible leftovers by filename and leaves them untouched, even with
`--yes`; these candidates may belong to other projects. This scan is a heuristic
and may miss files with other names. Inspect your
agent's skill, command, agent and workflow directories after uninstalling. For
Claude these are `~/.claude/skills/`, `~/.claude/commands/`, `~/.claude/agents/`
and `~/.claude/workflows/`; [Agent support and paths](../reference/agent-support.md#manual-installation-paths) lists the copy destinations for other agents.
You may need to forcefully remove remaining OSS Helper files and directories
manually. Verify that each item belongs to OSS Helper before deleting it; an
`oss-*` wildcard can also match unrelated skills or commands.

## Next steps

- [Installation management guides](index.md) for the section map.
- [Install the current packages](../get-started/install.md) after removing obsolete assets.
- [Check agent support and paths](../reference/agent-support.md) before inspecting remaining files.
