---
title: "Upgrade OSS Helper"
description: "Update native marketplace plugins, Gemini skills, Bob Shell assets or compatibility installations while following the current packages on main."
---

# Upgrade OSS Helper

Update native marketplace plugins, Gemini skills, Bob Shell assets or compatibility installations while following the current packages on main.

## Before you begin

Identify your installation method in [Install OSS Helper](../get-started/install.md).

## Choose your update method

Plugins currently follow the latest committed packages on `main`; these steps
update that source rather than select a numbered plugin release. Git-hosted
marketplace users do not need to clone the repository or run the builder.

## Claude Code

Refresh the marketplace, then update the installed plugin:

```bash
claude plugin marketplace update ai-agents-oss-helper
claude plugin update oss-helper@ai-agents-oss-helper
```

Start a new Claude session to load the updated plugin.

## Codex

Refresh the marketplace snapshot, then install the updated package:

```bash
codex plugin marketplace upgrade ai-agents-oss-helper
codex plugin add oss-helper@ai-agents-oss-helper
```

Start a new Codex session to load the updated skills.

## Gemini CLI

For skills installed from Git, repeat the native installation command:

```bash
gemini skills install https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git --path plugin/skills
```

For an extension installed from a local build, update its source checkout and
rebuild before refreshing the installed copy:

```bash
git pull --ff-only
./build.sh gemini
gemini extensions update oss-helper
```

Confirm replacement or update prompts, then restart Gemini.

## Bob Shell

From your checkout, pull the latest changes and rerun the installer:

```bash
git pull --ff-only
./install.sh bob
```

For an installation without a checkout, rerun the Bob `curl` command in [Install OSS Helper](../get-started/install.md#bob-shell-installation).
Start a new Bob Shell session after updating.

## Compatibility and local installations

From your source checkout, update and rerun the installer for the agent you use:

```bash
git pull --ff-only
./install.sh codex
```

Replace `codex` with `claude`, `bob`, `gemini`, `opencode` or `agy`, or omit it to
update all six. No uninstall step is required. For remote-script installations,
rerun the unpinned [compatibility installation command](../get-started/install.md#compatibility-installer). Omit `--version` and unset
`OSS_HELPER_VERSION` when you want to follow `main`.

If you registered a local checkout as a marketplace during testing, run
`git pull --ff-only` and `./build.sh claude` there. Restart Claude to reload its
local bundle; for Codex, rerun `codex plugin add oss-helper@ai-agents-oss-helper`
and start a new session. The Git marketplace refresh steps above are not needed
for local sources.

## Next steps

- [Installation management guides](index.md) for the section map.
- [Remove legacy assets](remove-legacy.md) when switching installation methods.
- [Set recurring preferences](preferences.md) before your next task.
