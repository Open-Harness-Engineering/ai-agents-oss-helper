# Command Fragments

Shared instruction fragments referenced by multiple commands. These reduce duplication and ensure consistency across all OSS Helper commands.

## Purpose

Command fragments extract common patterns that appear in multiple commands into reusable documentation. Instead of duplicating 50+ lines of initialization logic in every command, commands reference the fragment with a single line.

## Available Fragments

### Core Fragments

- **`_common-init.md`** - Project context initialization (used by all commands)
  - Detects current project via git remote
  - Loads project-specific rules (project-info, project-standards, project-guidelines)
  - Handles version checking and auto-discovery
  - Used by: All 30+ commands

### Review Fragments

- **`_static-analysis-enrichment.md`** - Static analysis enrichment for review commands
  - Detects available static analysis tools (PMD, Checkstyle, semgrep, ESLint, ruff, shellcheck, etc.)
  - Runs them scoped to PR-modified files only (or affected modules for Maven-based tools)
  - Normalizes findings and annotates with introduced-vs-pre-existing context
  - Provides structured results as input to the review evaluation
  - Java-focused: standalone CLI first, Maven plugin fallback
  - Used by: oss-review-pr, oss-review-prs

### Workflow Fragments (Planned)

- **`_git-history-investigation.md`** - Git history investigation patterns
  - Standard `git log` patterns for recent changes
  - Standard `git blame` patterns for authorship
  - Guidance on interpreting commit messages and linked issues
  - Used by: oss-fix-issue, oss-review-pr, oss-analyze-issue, oss-triage-issue, oss-address-review, oss-fix-ci-errors

- **`_build-workflow.md`** - Build/test/format workflow
  - Module-specific vs. root build decision tree
  - Format command execution
  - Test command execution
  - Full reactor build (Maven) with user prompt
  - Git status inspection for regen artifacts
  - Used by: oss-fix-issue, oss-quick-fix, oss-fix-sonarcloud, oss-fix-ci-errors, oss-address-review, oss-backport-pr

- **`_commit-signing.md`** - Commit signing prompts
  - Standard prompt for GPG/SSH signing
  - Command variations for -S, -s, both, or neither
  - Used by: oss-fix-issue, oss-quick-fix, oss-fix-ci-errors, oss-backport-pr, and others

- **`_agent-delegation.md`** - Agent delegation patterns
  - When to delegate (specialized agents available)
  - What to provide to delegated agents
  - When to perform work directly
  - Used by: oss-fix-issue, oss-review-pr, oss-analyze-issue, oss-fix-sonarcloud, oss-address-review, oss-fix-ci-errors

### API Fragments (Planned)

- **`_api-patterns.md`** - GitHub/Jira API patterns
  - Standard GitHub issue fetch (`gh issue view`)
  - Standard Jira issue fetch (curl with jq)
  - Standard PR fetch patterns
  - Rate limiting guidance
  - Error handling patterns
  - Used by: 12+ commands that interact with issue trackers

### Constraint Fragments (Planned)

- **`_common-constraints.md`** - Universal constraints
  - Never skip tests without justification
  - Never disable/weaken assertions
  - Never modify unrelated code
  - Always respect project-standards.md code style
  - Always wait for user confirmation before tracker changes
  - Used by: 15+ commands

- **`_pr-attribution.md`** - PR body attribution
  - Standard footer format
  - Logic for detecting existing footers (Claude Code)
  - When to add attribution
  - Used by: 10+ commands that create or update PRs

- **`_validation-patterns.md`** - Validation patterns
  - How to determine validation commands from project-standards.md
  - When to run validation (per-module vs. root)
  - How to handle validation failures
  - What to do with regen artifacts
  - Used by: 8+ commands that modify code

### Multi-Repo Fragments (Planned)

- **`_workspace-operations.md`** - Multi-repo operations
  - Standard workspace discovery
  - Repository registration patterns
  - Rules loading per repository
  - Worktree detection and handling
  - Used by: oss-workspace-init, oss-create-multi-repo-issue, oss-fix-multi-repo-issue

## Usage

Commands reference fragments using this pattern:

```markdown
### 1. Initialize Project Context

**MANDATORY:** Process `.oss-init.md` to load project rules. See `_fragments/_common-init.md` for details.
```

For command-specific notes, add them after the reference:

```markdown
### 1. Initialize Project Context

**MANDATORY:** Process `.oss-init.md` to load project rules. See `_fragments/_common-init.md` for details.

**For this command:** Verify the **SonarCloud component key** is configured. If it shows `_(none)_`, stop and inform the user: "SonarCloud is not configured for this project."
```

## Fragment Guidelines

### Creating New Fragments

1. **Identify duplication**: Find patterns repeated in 3+ commands
2. **Extract common logic**: Create a fragment with the shared instructions
3. **Document usage**: List which commands use the fragment
4. **Add to index**: Update this README with the new fragment
5. **Update commands**: Replace duplicated sections with fragment references

### Fragment Naming

- Prefix with underscore: `_fragment-name.md`
- Use kebab-case: `_git-history-investigation.md`
- Be descriptive: Name should clearly indicate the fragment's purpose

### Fragment Structure

Each fragment should include:

1. **Header**: Title and "do not invoke directly" warning
2. **Purpose**: What the fragment provides
3. **Instructions**: Detailed step-by-step guidance
4. **What Gets Loaded/Provided**: Clear list of available data/context
5. **Error Handling**: How to handle failures
6. **Command-Specific Notes**: Variations for different command types
7. **Best Practices**: Guidelines for using the fragment correctly

### Fragment Maintenance

- **Version fragments**: Include a version identifier for tracking changes
- **Test changes**: Verify fragment updates work across all referencing commands
- **Update references**: When changing a fragment, check all commands that use it
- **Document breaking changes**: Note any changes that require command updates

## Benefits

1. **Maintainability**: Update logic once, affects all commands
2. **Consistency**: All commands follow identical patterns
3. **Clarity**: Commands focus on their specific logic, not boilerplate
4. **Extensibility**: Easy to add new patterns without touching every command
5. **Documentation**: Comprehensive guides in one place

## Implementation Status

| Fragment | Status | Commands Affected | Lines Saved |
|----------|--------|-------------------|-------------|
| `_common-init.md` | ✅ Implemented | All (30+) | ~1,500 |
| `_static-analysis-enrichment.md` | ✅ Implemented | 2 (review commands) | ~350 |
| `_git-history-investigation.md` | 📋 Planned | 6 | ~100 |
| `_build-workflow.md` | ✅ Implemented | 7 | ~240 |
| `_commit-signing.md` | 📋 Planned | 8 | ~80 |
| `_agent-delegation.md` | 📋 Planned | 6 | ~48 |
| `_api-patterns.md` | 📋 Planned | 12 | ~180 |
| `_common-constraints.md` | 📋 Planned | 15 | ~300 |
| `_pr-attribution.md` | 📋 Planned | 10 | ~80 |
| `_validation-patterns.md` | 📋 Planned | 8 | ~96 |
| `_workspace-operations.md` | 📋 Planned | 3 | ~90 |

**Total Potential Savings**: ~2,714 lines

## Next Steps

1. Update all commands to reference `_common-init.md`
2. Create remaining workflow fragments
3. Create API and constraint fragments
4. Create multi-repo fragments
5. Add validation script to ensure all commands use fragments correctly
6. Update installer to include `_fragments/` directory
