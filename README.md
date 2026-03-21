# AI Agents OSS Helper

Generic commands for AI coding agents (Claude, Bob, Gemini) to help contribute to open source projects. Commands auto-detect the current project via `git remote get-url origin` and load project-specific configuration from rule files.

## Supported Projects

| Project | Issue Tracker | Repository |
|---------|--------------|------------|
| Wanaku | GitHub | `wanaku-ai/wanaku` |
| Wanaku Capabilities Java SDK | GitHub | `wanaku-ai/wanaku-capabilities-java-sdk` |
| Camel Integration Capability | GitHub | `wanaku-ai/camel-integration-capability` |
| Apache Camel (camel-core) | Jira | `apache/camel` |
| Apache Camel Quarkus | GitHub | `apache/camel-quarkus` |
| Apache Camel Spring Boot | Jira | `apache/camel-spring-boot` |
| Apache Camel Kafka Connector | GitHub | `apache/camel-kafka-connector` |
| Apache Camel K | GitHub | `apache/camel-k` |
| Hawtio | GitHub | `hawtio/hawtio` |
| Kaoto | GitHub | `KaotoIO/kaoto` |
| Forage | GitHub | `KaotoIO/forage` |
| AI Agents OSS Helper | GitHub | `orpiske/ai-agents-oss-helper` |
| Generic GitHub | GitHub | _(any unmatched GitHub repo)_ |

## Installation

### Quick Install (All Agents)

```bash
curl -fsSL https://raw.githubusercontent.com/orpiske/ai-agents-oss-helper/main/install.sh | bash
```

### Selective Install

```bash
# Clone the repository
git clone https://github.com/orpiske/ai-agents-oss-helper.git
cd ai-agents-oss-helper

# Install for specific agent
./install.sh claude    # Claude only
./install.sh bob       # Bob only
./install.sh gemini    # Gemini CLI only
./install.sh opencode  # OpenCode only
./install.sh           # All agents
```

## Available Commands

| Command                                   | Description                                                             |
|-------------------------------------------|-------------------------------------------------------------------------|
| `/oss-fix-issue <issue>`                  | Fix an issue from the project's tracker (GitHub or Jira)                |
| `/oss-find-task`                          | Find an issue to contribute based on experience level                   |
| `/oss-create-issue <title>`               | Create a new issue in the project's GitHub repository                   |
| `/oss-quick-fix <description>`            | Apply a quick fix without a tracked issue (CI, docs, deps, etc.)        |
| `/oss-analyze-issue <issue>`              | Analyze an issue to understand the problem and investigate the codebase |
| `/oss-fix-sonarcloud <rule>`              | Fix SonarCloud issues for a given rule                                  |
| `/oss-add-project <name> <description>`  | Add a new project with the helper                                       |
| `/oss-update-knowledge <source>`          | Update a project's rule files from a description or URL                 |
| `/oss-fix-ci-errors [run-id]`             | Download CI build reports, identify errors, and fix them                |

All commands auto-detect the project from the current directory's git remote.

## Usage Examples

### Fix an Issue

```bash
# Navigate to any supported project, then:

# GitHub project - using issue number
/oss-fix-issue 42

# GitHub project - using full URL
/oss-fix-issue https://github.com/wanaku-ai/wanaku/issues/42

# Jira project (camel-core) - using issue ID
/oss-fix-issue CAMEL-20410

# Jira project - using full URL
/oss-fix-issue https://issues.apache.org/jira/browse/CAMEL-22326
```

### Find a Task

```bash
# Interactive - asks about your experience level
/oss-find-task
```

The command will:
1. Detect the current project
2. Ask about your experience level
3. Search for appropriate issues (good first issue, help wanted, etc.)
4. Present a list of options
5. Guide you to use `/oss-fix-issue` to implement

### Analyze an Issue

```bash
# Using issue number
/oss-analyze-issue 42

# Using full URL
/oss-analyze-issue https://github.com/wanaku-ai/wanaku/issues/42
```

The command will:
1. Fetch the issue details and comments
2. Investigate the codebase for relevant code
3. Check related repos if configured
4. Provide a structured analysis report
5. Suggest next steps (fix, ask for more info, etc.)

### Create an Issue

```bash
# Interactive - will prompt for details
/oss-create-issue

# With title provided
/oss-create-issue "Add support for custom headers in HTTP requests"
```

### Quick Fix

```bash
# Upgrade a dependency
/oss-quick-fix upgrade Quarkus BOM to 3.18.0

# Fix documentation
/oss-quick-fix fix broken link in CONTRIBUTING.md

# Update CI
/oss-quick-fix update GitHub Actions checkout to v4
```

### Fix SonarCloud Issues

```bash
# Fix cognitive complexity issues
/oss-fix-sonarcloud S3776

# Fix pattern matching for instanceof
/oss-fix-sonarcloud S6201

# Fix issues in a specific module only
/oss-fix-sonarcloud S3457 module=components/camel-jms

# Limit number of issues to process
/oss-fix-sonarcloud S6126 limit=10
```

### Add a New Project

```bash
/oss-add-project my-project "Java project at https://github.com/org/my-project, uses Maven, GitHub issues"
```

## How It Works

Commands are generic and project-agnostic. Project-specific configuration is stored in rule files with three files per project:
- **`project-info.md`** - Repository URLs, issue trackers, SonarCloud keys, related repos
- **`project-standards.md`** - Build tools, commands, code style restrictions
- **`project-guidelines.md`** - Branch naming, commit formats, PR policies, task labels

Every command starts by processing `.oss-init.md`, which loads project rules in this priority order:

1. **Project-local rules** - `.oss-ai-helper-rules/` directory in the repository root (highest priority, can be committed to the repo)
2. **Installed rules** - Matching `rules/<project>/` from the installed helper (remote pattern matching)
3. **Auto-discovery** - If no rules exist anywhere, the agent auto-discovers the project's configuration (build tool, conventions, etc.) and generates rule files (in `.oss-ai-helper-rules/` for git repos, or in the central `rules/` directory otherwise)

### Project-local rules (`.oss-ai-helper-rules/`)

Projects can ship their own AI helper rules by including a `.oss-ai-helper-rules/` directory in the repository root with the three rule files. This allows project maintainers to control how AI agents interact with their project, and contributors get the right configuration automatically without installing project-specific rules.

If no `.oss-ai-helper-rules/` directory exists and the project isn't in the installed rules, the agent will auto-discover the project's build tool, conventions, and metadata, then generate rule files. For git repositories, rules are created in `.oss-ai-helper-rules/` so they can be committed and shared with other contributors. For non-git directories, rules are created in the central `rules/` directory.

## OpenCode Notes

OpenCode uses markdown command files. The installer adds frontmatter descriptions and installs commands to:

- `~/.config/opencode/commands/`
- `~/.config/opencode/rules/` (project rule files)

## Gemini CLI Notes

Gemini CLI uses TOML command files instead of Markdown. The installer automatically converts `.md` commands to `.toml` format at install time, wrapping the prompt content and extracting the description.

Since Gemini CLI has no auto-loading `rules/` directory, each generated TOML command includes a preamble instructing Gemini to read project rule files from `~/.gemini/rules/<project-directory>/`.

## Project Structure

```
ai-agents-oss-helper/
├── install.sh                        # Installation script
├── README.md
├── commands/                         # Generic commands (installed to ~/.{agent}/commands/)
│   ├── oss-add-project.md
│   ├── oss-fix-issue.md
│   ├── oss-find-task.md
│   ├── oss-create-issue.md
│   ├── oss-quick-fix.md
│   ├── oss-analyze-issue.md
│   ├── oss-fix-sonarcloud.md
│   ├── oss-update-knowledge.md
│   ├── oss-fix-ci-errors.md
│   └── .oss-init.md                  # Shared preamble: project detection & rule loading
└── rules/                            # Rule files (installed to ~/.{agent}/rules/)
    ├── wanaku/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── wanaku-capabilities-java-sdk/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-integration-capability/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-core/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-quarkus/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-spring-boot/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-kafka-connector/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── camel-k/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── hawtio/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── kaoto/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── forage/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    ├── ai-agents-oss-helper/
    │   ├── project-info.md
    │   ├── project-standards.md
    │   └── project-guidelines.md
    └── generic-github/
        ├── project-info.md
        ├── project-standards.md
        └── project-guidelines.md
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or modify commands/rules
4. Update `install.sh` if adding new files
5. Submit a pull request

## License

Apache License 2.0

---

[GitHub Repository](https://github.com/orpiske/ai-agents-oss-helper)
