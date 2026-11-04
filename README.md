# AI Agents OSS Helper

Project-aware guidelines for AI coding agents contributing to open source projects. Use focused skills with Claude, Bob, Codex or agy, or generated commands with Gemini and OpenCode. The helper loads repository rules for build commands, contribution conventions and project context.

[Documentation](docs/index.md) · [Command and workflow catalog](https://open-harness-engineering.github.io/ai-agents-oss-helper/) · [Releases](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/releases)

## Installation

For Claude Code, add the marketplace and install the plugin:

```bash
claude plugin marketplace add Open-Harness-Engineering/ai-agents-oss-helper
claude plugin install oss-helper@ai-agents-oss-helper
```

For Codex, Gemini CLI, Bob Shell and compatibility installations, follow [Install OSS Helper](docs/get-started/install.md). These docs describe `main`; marketplaces currently track the latest committed packages on that branch.

## Documentation

| Your next task | Guide |
|---|---|
| <a id="getting-started"></a>Install and start using the helper | [Get started](docs/get-started/index.md) |
| <a id="upgrading"></a><a id="fewer-questions-smaller-sessions"></a>Upgrade, clean up legacy assets or set preferences | [Manage installations](docs/manage/index.md) |
| <a id="usage-examples"></a>Fix issues, review changes or drive a security case | [Run maintenance tasks](docs/use/index.md) |
| <a id="how-it-works"></a>Set up shared project rules | [Configure projects](docs/configure/index.md) |
| <a id="capabilities"></a><a id="agent-specific-notes"></a>Find commands and agent-specific behavior | [Reference](docs/reference/index.md) |
| <a id="project-structure"></a><a id="releases-and-versioning"></a><a id="contributing"></a>Change guidelines, build bundles or prepare releases | [Contributing](docs/contributing/index.md) |

## License

Apache License 2.0
