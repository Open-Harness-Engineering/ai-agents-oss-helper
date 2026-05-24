# Add New Project

Add a new project to the AI Agents OSS Helper by adding its configuration to the rule files.

## Usage

```
/oss-add-project <name> <description>
```

**Arguments:**
- `<name>` - Short project name (e.g., `my-project`)
- `<description>` - What the project is and relevant details (repo URL, issue tracker type, build tool, etc.)

**Examples:**
```
/oss-add-project my-project "Java project at https://github.com/org/my-project, uses Maven, GitHub issues"
/oss-add-project my-jira-project "Java project at https://github.com/apache/my-project, uses Jira at https://issues.apache.org/jira, SonarCloud key: apache_my-project"
```

## Instructions

### 1. Parse Input

Extract from arguments:
- **Project name** - First word
- **Description** - Everything after the name

### 2. Analyze Description

From the description, identify:
- **GitHub repository** (e.g., `org/my-project`)
- **Issue tracker type** (GitHub or Jira)
- **Issue tracker URL** (if Jira)
- **Build tool** (Maven, Gradle, etc.)
- **SonarCloud component key** (if any)
- **Related repositories** (if any)

Ask the user to confirm or provide any missing details.

### 3. Check for Project-Provided Rules

Check if the GitHub repository already ships `.oss-ai-helper-rules/`:

```bash
gh api repos/<org>/<repo>/contents/.oss-ai-helper-rules --jq '.[].name' 2>/dev/null
```

If the directory exists and contains rule files (`project-info.md`, `project-standards.md`, `project-guidelines.md`), inform the user:

> `<org>/<repo>` already ships its own `.oss-ai-helper-rules/`. Project-local rules take precedence over installed rules. To install them on this machine, clone the project and run any OSS Helper command from inside it (the helper will pick them up automatically).

Stop. No rules need to be created.

If the remote `.oss-ai-helper-rules/` directory does not exist or is incomplete, proceed to step 4 to create them.

### 4. Create Rule Files

Determine where to create the rule files based on the current working directory:

- **If you are inside the target project's repository:** Create the rules in `<repo-root>/.oss-ai-helper-rules/`. This is the **recommended** approach — rules are versioned with the project and shared automatically across all contributors and agents.
- **If you are inside the `ai-agents-oss-known-projects` repository** (or not inside the target project): Create a new subdirectory at the root named after the project (e.g., `my-project/`). These will be available for any user to install via `/oss-install-info my-project`.

Add three rule files to the chosen directory:

#### A. `project-info.md`
Create with:
- H1 heading: `# Project Information`
- Intro paragraph (same as other project-info files)
- Remote pattern
- GitHub repo
- Issue tracker type (GitHub or Jira)
- Issue tracker URL
- Issue ID format (numeric or alphanumeric)
- SonarCloud component key
- Documentation URL
- Related repositories
- Create-issue supported (yes/no)
- `## Version` section with the current git SHA of the project being configured

#### B. `project-standards.md`
Create with:
- H1 heading: `# Project Standards`
- Intro paragraph (same as other project-standards files)
- Build tool
- Build command
- Test command
- Test with coverage command
- Format command
- Module-specific build (yes/no)
- Parallelized Maven (yes/no/n/a)
- Code style restrictions
- `## Version` section with the current git SHA of the project being configured

#### C. `project-guidelines.md`
Create with:
- H1 heading: `# Project Guidelines`
- Intro paragraph (same as other project-guidelines files)
- Fix branch naming pattern
- Feature branch naming pattern
- Bugfix branch naming pattern
- Quick-fix branch naming pattern
- SonarCloud branch naming pattern
- Commit format (fix)
- Commit format (quick-fix)
- CI-issue branch naming pattern
- Commit format (ci-issue)
- PR creation policy (always/on request)
- Find-task source (GitHub labels or Jira JQL)
- Find-task beginner label
- Find-task intermediate label
- Find-task experienced label
- Scope-too-large redirect
- `## Version` section with the current git SHA of the project being configured

Use any existing project directory in the [`ai-agents-oss-known-projects`](https://github.com/Open-Harness-Engineering/ai-agents-oss-known-projects) repository (e.g., `wanaku/`) as a template for the exact format.

#### D. `project-security.md` (optional)

Create this file **only** if the project has a defined security / CVE-handling workflow worth recording (most relevant for projects that publish CVE advisories, such as ASF projects). Do **not** fabricate a workflow: if the user has not described one and you cannot determine it from the project's security policy (`SECURITY.md`, an `https://www.apache.org/security/`-style page, etc.), skip this file and tell the user it can be added later.

When you do create it, include:
- H1 heading: `# Project Security`
- Intro paragraph (note that the file is optional and consumed only by the security commands: `/oss-triage-security-report`, `/oss-create-security-advisory`, `/oss-draft-cve`, `/oss-analyze-third-party-cve`)
- Private reporting channel
- GitHub private vulnerability reporting (used / not used)
- CVE Numbering Authority (CNA)
- Severity scheme
- Advisory source format and section structure
- Advisory template (reference)
- Publication location
- Signing key
- Supported release lines / backport branches
- Disclosure & announcement steps
- Third-party CVE "not affected" notes location
- A short `## CVE Handling Workflow` section
- `## Version` section with the current git SHA of the project being configured

Use any `camel-*` project directory in the known-projects repository as a template for the exact format.

### 5. Publish the Rules

**If rules were created in `.oss-ai-helper-rules/` (project-local):** The rules travel with the repository and do not need any other publication step. Inform the user:
> Project rules created in `.oss-ai-helper-rules/`. Review and commit them to share with other contributors.

**If rules were created in the `ai-agents-oss-known-projects` repository:** Commit and open a PR so the rules become installable via `/oss-install-info <project>`:

```bash
git checkout -b add/<project>
git add <project>/
git commit -m "add: rules for <project>"
git push -u origin add/<project>
gh pr create --title "add: rules for <project>" --body "..."
```

Inform the user:
> Rules for `<project>` are queued for publication in `ai-agents-oss-known-projects`. Once the PR is merged, anyone can install them with `/oss-install-info <project>`.

### 6. Constraints

You MUST:
- Follow the existing format of each rule file exactly (use other project directories as templates)
- Confirm all details with the user before making changes
- Create all three required rule files in the new subdirectory; create the optional `project-security.md` only when a real security/CVE workflow is known (never invent one)

You MUST NOT:
- Create per-project command files (all commands are generic)
- Modify existing project directories without user consent
- Skip creating any of the three rule files
- Modify `install.sh`, `.oss-init.md`, or `README.md` in `ai-agents-oss-helper` when adding a project (the rules layout no longer requires this)

### 7. Output

After adding the project, confirm:
- Where the rule files were created (`.oss-ai-helper-rules/` in the target project, or `<project>/` in `ai-agents-oss-known-projects`)
- If project-local: remind the user to commit and push the `.oss-ai-helper-rules/` directory
- If in the known-projects repo: confirm the PR has been opened and remind the user that `/oss-install-info <project>` will work once it is merged
- How to use the project with existing commands (e.g., `cd my-project && /oss-fix-issue 42`)
