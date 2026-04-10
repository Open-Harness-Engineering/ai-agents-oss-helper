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

### 3. Check for Existing and Project-Provided Rules

#### 3.1 Check if rules already exist locally

Check if `rules/<project>/` already exists with rule files. If it does, read the `## Version` section from the local `project-info.md` to get the local version.

#### 3.2 Check remote repository for `.oss-ai-helper-rules/`

Check if the GitHub repository already ships `.oss-ai-helper-rules/`:

```bash
gh api repos/<org>/<repo>/contents/.oss-ai-helper-rules --jq '.[].name' 2>/dev/null
```

If the directory exists and contains rule files (`project-info.md`, `project-standards.md`, `project-guidelines.md`):

- If rules **already exist locally**: compare the `## Version` from the remote `project-info.md` against the local version. If versions differ, inform the user:
  > Project rules update available. Local version: `<local-version>`, remote version: `<remote-version>`. Do you want to update?

  Only proceed with the download if the user confirms. If the user declines, skip to the end.

- If rules **do not exist locally**: download them directly into `rules/<project>/`:

```bash
mkdir -p rules/<project>
gh api repos/<org>/<repo>/contents/.oss-ai-helper-rules/project-info.md --jq '.content' | base64 -d > rules/<project>/project-info.md
gh api repos/<org>/<repo>/contents/.oss-ai-helper-rules/project-standards.md --jq '.content' | base64 -d > rules/<project>/project-standards.md
gh api repos/<org>/<repo>/contents/.oss-ai-helper-rules/project-guidelines.md --jq '.content' | base64 -d > rules/<project>/project-guidelines.md
```

After downloading, skip to **step 5** (Update install.sh) - no need to create rule files manually.

If the remote `.oss-ai-helper-rules/` directory does not exist or is incomplete, proceed to step 4 to create them.

### 4. Create Rule Files

Determine where to create the rule files based on the current working directory:

- **If you are inside the target project's repository:** Create the rules in `<repo-root>/.oss-ai-helper-rules/`. This is the **recommended** approach — rules are versioned with the project and shared automatically across all contributors and agents.
- **If you are inside the `ai-agents-oss-helper` repository** (or not inside the target project): Create a new subdirectory under `rules/` named after the project (e.g., `rules/my-project/`). These will be installed globally as a fallback.

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
- Fix-issue branch naming pattern
- Quick-fix branch naming pattern
- SonarCloud branch naming pattern
- Commit format (fix-issue)
- Commit format (quick-fix)
- CI-fix branch naming pattern
- Commit format (ci-fix)
- PR creation policy (always/on request)
- Find-task source (GitHub labels or Jira JQL)
- Find-task beginner label
- Find-task intermediate label
- Find-task experienced label
- Scope-too-large redirect
- `## Version` section with the current git SHA of the project being configured

Use existing project files (e.g., `rules/wanaku/`) as a template for the exact format.

### 5. Update install.sh, .oss-init.md, and README.md

**If rules were created in `.oss-ai-helper-rules/` (project-local):** Skip steps 5a–5c. The rules travel with the repository and do not need global installation. Inform the user:
> Project rules created in `.oss-ai-helper-rules/`. Review and commit them to share with other contributors.

**If rules were created in `rules/<project>/` (installed rules):** Perform steps 5a–5c:

#### 5a. Update install.sh

Add the three new rule file paths to the `RULE_FILES` array in `install.sh`:
```
"rules/<project>/project-info.md"
"rules/<project>/project-standards.md"
"rules/<project>/project-guidelines.md"
```

#### 5b. Update .oss-init.md

Add the new remote pattern -> project directory mapping to the "Installed rules" section (step 2B) in `commands/.oss-init.md`.

#### 5c. Update README.md

Add the new project to the supported projects table in README.md.

### 8. Constraints

You MUST:
- Follow the existing format of each rule file exactly (use other project directories as templates)
- Confirm all details with the user before making changes
- Create all three rule files in the new subdirectory
- Update install.sh with the new file paths
- Update the remote pattern mapping in `.oss-init.md`

You MUST NOT:
- Create per-project command files (all commands are generic)
- Modify existing project directories without user consent
- Skip creating any of the three rule files

### 9. Output

After adding the project, confirm:
- Where the rule files were created (`.oss-ai-helper-rules/` or `rules/<project>/`)
- If project-local: remind the user to commit and push the `.oss-ai-helper-rules/` directory
- If installed: list which files were updated (`install.sh`, `.oss-init.md`, `README.md`)
- How to use the project with existing commands (e.g., `cd my-project && /oss-fix-issue 42`)
