---
title: "Agent support and paths"
description: "Look up agent-specific skill, command and workflow behavior, manual installation destinations and the legacy Codex initialization-file recovery procedure."
---

# Agent support and paths

Look up agent-specific skill, command and workflow behavior, manual installation destinations and the legacy Codex initialization-file recovery procedure.

## Before you begin

Choose a method in [Install OSS Helper](../get-started/install.md). Build instructions live in [Build bundles locally](../contributing/build-locally.md).

## Manual installation paths

Use `./install.sh <agent>` for automatic installation, or build the target and
copy its output to the corresponding directories. The build itself never copies
files into your home directory.

| Target | Built directory | Copy destination |
| --- | --- | --- |
| Bob | `build/bob/{skills,commands,agents}/` | `~/.bob/{skills,commands,agents}/` |
| agy | `build/agy/{skills,commands,agents}/` | `~/.agy/{skills,commands,agents}/` |
| Gemini | `build/gemini/{skills,commands,agents}/` | `~/.gemini/{skills,commands,agents}/` |
| OpenCode | `build/opencode/{commands,agents}/` | `~/.config/opencode/{commands,agents}/` |
| Codex | `build/codex/skills/` | `~/.agents/skills/` |
| Codex | `build/codex/agents/` | `~/.codex/agents/` |

For example:

```bash
./build.sh codex
mkdir -p ~/.agents/skills ~/.codex/agents
cp -R build/codex/skills/. ~/.agents/skills/
cp -R build/codex/agents/. ~/.codex/agents/
```

## Claude, Bob, agy

Claude uses the marketplace plugin and its namespaced commands. Bob and agy use
6 user-invocable skills copied to `~/.{agent}/skills/oss-{issues,review,ci,security,project,qe}/` plus individual `/oss-*` commands in `~/.{agent}/commands/`. You can either describe what you want in natural language (the agent matches it to a skill automatically), invoke a skill group (e.g. `/oss-issues`), or invoke a specific command directly (e.g. `/oss-fix-issue 42`).

In Claude Code the individual commands are installed with `disable-model-invocation: true`: you type them, but their descriptions stay out of the model's context in every session. Requests in natural language reach the same guidelines through the skill groups. The sub-agent descriptions are kept to a sentence or two for the same reason, since Claude Code lists them in every session too.

The Claude plugin also bundles the workflows in `workflows/` for Claude Code's
Workflow tool. `/oss-helper:oss-security-case` uses one. Bob and agy follow the
same guideline by hand.

## Gemini CLI

The Gemini target includes six skill groups, native TOML commands, converted
agents and extension metadata. Commands activate their matching bundled skill
and resolve supporting files from that skill directory; inline guidelines
remain available for older clients. The compatibility installer copies these
components under `~/.gemini/`. Project rules remain under
`~/.gemini/rules/<project-directory>/`.

## OpenCode

Individual markdown commands with frontmatter are generated and installed to `~/.config/opencode/commands/`. Each command includes a preamble for project rule loading from `~/.config/opencode/rules/<project-directory>/`.

## Codex

Marketplace installs use Codex's managed plugin cache. Compatibility installs
and manual copies use 6 skill directories at `~/.agents/skills/oss-{issues,review,ci,security,project,qe}/` with all guideline files as supporting files. Project rule files are installed to `~/.codex/oss-helper/rules/`.

If Codex reports a missing `~/.codex/oss-helper/.oss-init.md`, remove the legacy installation with `./uninstall.sh --yes codex`, build and copy the current Codex bundle, then start a new session. Current skills use their bundled `init.md`.

## Next steps

- [Reference guides](index.md) for the section map.
- [Upgrade your installation](../manage/upgrade.md) using the matching procedure.
- [Remove legacy installations](../manage/remove-legacy.md) when old assets interfere with current skills.
