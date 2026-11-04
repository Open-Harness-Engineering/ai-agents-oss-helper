---
title: "Run maintenance tasks"
description: "Use natural-language requests or commands to fix issues, find contribution tasks, review pull requests, make quick fixes and backport changes."
---

# Run maintenance tasks

Use natural-language requests or commands to fix issues, find contribution tasks, review pull requests, make quick fixes and backport changes.

## Before you begin

[Install the helper](../get-started/install.md) and [configure project rules](../configure/add-project.md) for the repository you are working in.

## Fix an issue

```text
# With Claude, Bob, Codex, or agy — just ask naturally:
fix issue 42
fix issue CAMEL-20410
fix https://github.com/wanaku-ai/wanaku/issues/42

# With Gemini or OpenCode — use the command:
/oss-fix-issue 42
/oss-fix-issue CAMEL-20410
```

## Find a task

```text
# Natural language:
find me a task to contribute to

# Command:
/oss-find-task
```

## Review a pull request

```text
# Natural language:
review PR 42
review https://github.com/wanaku-ai/wanaku/pull/42

# Command:
/oss-review-pr 42
```

## Quick fix

```text
# Natural language:
upgrade Quarkus BOM to 3.18.0
fix broken link in CONTRIBUTING.md

# Command:
/oss-quick-fix upgrade Quarkus BOM to 3.18.0
```

## Backport a merged PR

```text
# Natural language:
backport PR 42 to the release/1.x branch

# Command:
/oss-backport-pr 42 branch=release/1.x
```

## Next steps

- [Maintenance task guides](index.md) for the section map.
- [Browse all commands](../reference/commands.md) for tasks beyond these examples.
- [Drive a security case](security-case.md) for the gated security-report workflow.
