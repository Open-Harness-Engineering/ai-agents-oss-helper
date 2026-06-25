# Common Initialization

**This fragment is referenced by all OSS Helper commands. Do not invoke it directly.**

## Project Context Initialization

**MANDATORY:** Every OSS Helper command must begin by reading and processing the `.oss-init.md` file to:

1. Detect the current project via `git remote get-url origin`
2. Load project-specific rules in priority order:
   - Project-local `.oss-ai-helper-rules/` (highest priority)
   - Installed rules matching the remote pattern
   - Auto-generated rules (fallback)
3. Load three required rule files:
   - `project-info.md` - Repository metadata, issue tracker, related repos
   - `project-standards.md` - Build tools, commands, code style
   - `project-guidelines.md` - Branch naming, commit formats, PR policies
4. Optionally load `project-security.md` (security commands only)

All subsequent command steps assume this context is loaded and available.

## What Gets Loaded

After initialization, you have access to:

### Repository Information

- **GitHub repo** or **Jira project key**
- **Issue tracker type** (GitHub/Jira) and **Issue tracker URL**
- **Issue ID format** (numeric or alphanumeric)
- **Related repositories** (for workspace commands)
- **Create-issue supported** flag

### Build & Test Configuration

- **Build tool** (Maven, Gradle, Go, yarn, npm, Cargo, Make, none)
- **Build command** (e.g., `mvn verify`, `./gradlew build`)
- **Test command** (e.g., `mvn test`, `yarn test`)
- **Test with coverage command** (if available)
- **Format command** (e.g., `mvn process-sources`, `yarn format`)
- **Module-specific build** requirements (yes/no)
- **Parallelized Maven** policy (yes/no/n/a)

### Contribution Guidelines

- **Branch naming patterns**:
  - Fix branch (e.g., `fix/<ISSUE_NUMBER>`)
  - Feature branch (e.g., `feature/<ISSUE_NUMBER>-<slug>`)
  - Bugfix branch (e.g., `bugfix/<ISSUE_NUMBER>`)
  - Quick-fix branch (e.g., `quick-fix/<slug>`)
  - CI-issue branch (e.g., `ci-issue/<slug>`)
  - SonarCloud branch (if configured)
- **Commit message formats**:
  - Fix commits (e.g., `Fix #<ISSUE_NUMBER>: <description>`)
  - Quick-fix commits (e.g., `chore: <description>`)
  - CI-issue commits (e.g., `ci: <description>`)
  - SonarCloud commits (if configured)
- **PR creation policy** (always/on request)
- **Backport upgrade-guide policy** (for projects with version-specific upgrade guides)

### Task Discovery

- **Find-task source** (GitHub labels or Jira JQL)
- **Find-task beginner label/JQL** (e.g., `good first issue`)
- **Find-task intermediate** (filter ID or JQL, if configured)
- **Find-task experienced label/JQL** (e.g., `help wanted`)
- **Scope-too-large redirect** (e.g., `/oss-create-issue`)

### Code Style & Constraints

- **Code style restrictions** (e.g., no Records/Lombok, no API changes without justification)
- **Dependency policy** (e.g., no new dependencies without justification)
- **Backwards compatibility** requirements

### Optional Configuration

- **SonarCloud component key** (if configured)
- **Documentation URL** (if available)
- **Security/CVE workflow** (from `project-security.md`, if present)

## Error Handling

If `.oss-init.md` processing fails:

- Stop immediately
- Report the specific failure:
  - Missing git remote
  - No rules found (suggest `/oss-install-info` or `/oss-add-project`)
  - Invalid rule files (missing required fields)
  - Rule version mismatch (offer to update)
- Do not proceed with the command

## Version Checking

The initialization process includes automatic version checking:

1. Extract local version from `## Version` section in `project-info.md`
2. Fetch remote version from the project's GitHub repository (if `.oss-ai-helper-rules/` exists)
3. Compare versions (git SHAs)
4. If versions differ:
   - Inform the user of available update
   - Ask for confirmation before updating
   - Download and overwrite local rules if confirmed
   - Re-read updated rules before continuing
5. If user declines update, continue with existing local rules

## Auto-Discovery Fallback

If no rules exist (neither project-local nor installed):

1. Auto-discover project configuration:
   - Detect build tool from repository files (`pom.xml`, `build.gradle`, `package.json`, etc.)
   - Infer build/test/format commands
   - Check for `CONTRIBUTING.md` for guidelines
   - Use sensible defaults for missing information
2. Generate rule files in `.oss-ai-helper-rules/` (for git repositories) or agent's local rules directory (for non-git)
3. Inform the user that rules were auto-generated
4. Suggest reviewing and adjusting the generated files
5. For git repositories, suggest committing the rules to share with other contributors
6. Continue with the newly generated rules

## Command-Specific Initialization

Some commands require additional validation after loading rules:

### SonarCloud Commands

Verify the **SonarCloud component key** is configured. If it shows `_(none)_`, stop and inform the user: "SonarCloud is not configured for this project."

### Security Commands

Load `project-security.md` if present. If the command requires security configuration and the file is missing, inform the user and suggest creating it based on examples from the `ai-agents-oss-known-projects` repository.

### Workspace Commands

After loading the primary project's rules, locate and load workspace metadata (`.oss-helper-workspace.json`). For each workspace repository, load that repository's own rules independently.

### Multi-Repo Commands

Check the **Related repositories** field. If empty and the command requires multiple repositories, ask the user to provide them explicitly or run `/oss-workspace-init` first.

## Best Practices

1. **Always initialize first**: Never skip initialization, even for read-only commands
2. **Respect loaded rules**: Use the project's actual build commands, branch patterns, and commit formats
3. **Handle missing rules gracefully**: Offer to generate rules rather than failing
4. **Keep rules independent**: Don't assume all repositories in a workspace share the same rules
5. **Version awareness**: Always check for rule updates before long-running operations
