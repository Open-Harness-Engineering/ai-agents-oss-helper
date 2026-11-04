---
title: "Install OSS Helper"
description: "Install OSS Helper for your coding agent using native packages or the compatibility installer. These instructions describe the packages on main."
---

# Install OSS Helper

Install OSS Helper for your coding agent using native packages or the compatibility installer. These instructions describe the packages on main.

## Before you begin

Choose your coding agent below. For builds from a checkout, see [Build bundles locally](../contributing/build-locally.md).

## Claude Code marketplace

```bash
claude plugin marketplace add Open-Harness-Engineering/ai-agents-oss-helper
claude plugin install oss-helper@ai-agents-oss-helper
```

The Claude marketplace installs the committed `plugin/` bundle; users do not run a build.
Plugin skills and commands are namespaced, for example `/oss-helper:oss-issues`
and `/oss-helper:oss-fix-issue 42`.

## Codex marketplace

```bash
codex plugin marketplace add Open-Harness-Engineering/ai-agents-oss-helper
codex plugin add oss-helper@ai-agents-oss-helper
```

Start a new session, open `/skills`, and try `$oss-helper:oss-review` to list this
repository's pull requests. The Codex plugin exposes the six skill groups;
Claude-specific command wrappers and workflows remain Claude-only. Native
marketplace support requires a current Codex client.

## Gemini CLI native installation

Install the assembled skills directly from Git:

```bash
gemini skills install https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git --path plugin/skills
```

Run `gemini skills list` to check discovery. For local development, build the Gemini extension with its native command and
agent formats:

```bash
./build.sh gemini
gemini extensions install ./build/gemini
```

Gemini's Git extension installer cannot select a repository subdirectory. Use
the native skills command above for remote installation; the repository root
contains editable sources, while `plugin/skills/` contains assembled skills.
See the [Gemini skill installer](https://geminicli.com/docs/cli/skills/).

## Bob Shell installation

Clone the repository and install the Bob assets:

```bash
git clone https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git
cd ai-agents-oss-helper
./install.sh bob
```

Or install without keeping a checkout:

```bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash -s -- bob
```

Start a new Bob Shell session after installing. This installs Bob Shell assets,
not a Bob IDE plugin.

## Compatibility installer

Existing automation can continue using `install.sh`. From a checkout:

```bash
./install.sh codex    # Install one agent
./install.sh          # Install all six agents
```

The existing remote installation path also remains available:

```bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash -s -- --version v1.0.0 codex
```

`--version <tag>`, `--version=<tag>` and `OSS_HELPER_VERSION` select a remote
version; the flag takes precedence over the environment variable. Without a
version selection, a checkout uses its local sources and a standalone or piped
script downloads `main`. Remote installation requires `curl` or `wget` and `tar`.
The wrapper builds in a temporary directory and copies the selected assets to
user directories. It preserves unrelated files and project rules; use
`uninstall.sh` separately to remove obsolete assets.

Direct Claude installations retain `/oss-*` commands and files under
`~/.claude/`. Choose either that installation or the marketplace plugin to avoid
duplicate skills and commands. The marketplace remains the recommended Claude
installation path.

## Next steps

- [Getting started guides](index.md) for the section map.
- [Configure a project](../configure/add-project.md) so the helper loads its rules.
- [Check agent support and paths](../reference/agent-support.md) for manual copy destinations.
- [Upgrade an existing installation](../manage/upgrade.md) when you already have the helper.
