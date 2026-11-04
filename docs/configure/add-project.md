---
title: "Configure a project"
description: "Add shared project rule files to a repository or install known-project rules so the helper can load its build settings and contribution conventions."
---

# Configure a project

Add shared project rule files to a repository or install known-project rules so the helper can load its build settings and contribution conventions.

## Before you begin

[Install OSS Helper](../get-started/install.md) and open the repository you want to work on.

## Add project-local rules

Any project can use the helper by adding an `.oss-ai-helper-rules/` directory to its repository root with three rule files:

```text
my-project/
├── .oss-ai-helper-rules/
│   ├── project-info.md          # Repository URLs, issue trackers, related repos
│   ├── project-standards.md     # Build tools, commands, code style restrictions
│   └── project-guidelines.md    # Branch naming, commit formats, PR policies
└── ...
```

Use the Add Project guideline to generate initial rule files for any project. Once committed, every contributor gets the right configuration automatically — no per-user installation of project-specific rules required.

## Install known-project rules

```text
# Natural language:
install project rules for camel-core

# Command:
/oss-install-info camel-core
/oss-install-info auto           # detect from git remote
/oss-install-info all            # install all known projects
```

## Next steps

- [Project configuration guides](index.md) for the section map.
- [Understand rule loading](rule-loading.md) to see which rules take priority.
- [Choose a rules repository](rules-repositories.md) when your team hosts a separate collection.
