# Update Knowledge

Update a project's rule files when project conventions change (e.g., new build tool, updated contribution guidelines, changed branching strategy). Accepts either a textual description of changes or a URL to a document containing project conventions.

## Usage

```
/oss-update-knowledge <source>
```

**Arguments:**
- `<source>` - Either a textual description of what to update, or a URL to a document containing project conventions

**Examples:**
```
/oss-update-knowledge "Build tool changed from Maven to Gradle, new build command is gradle build"
/oss-update-knowledge https://github.com/org/repo/blob/main/CONTRIBUTING.md
/oss-update-knowledge "Added SonarCloud, component key is org_repo"
```

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

Determine whether the source argument is a URL or a text description:

- **URL** - Starts with `http://` or `https://`
- **Text description** - Everything else

### 3. Retrieve Information

**If URL:**
1. Fetch the document content using WebFetch or equivalent
2. Extract relevant project conventions from the document (build tools, branching strategy, commit formats, code style, CI/CD setup, contribution guidelines, etc.)
3. Summarize the extracted conventions

**If text description:**
1. Use the description directly as the source of changes

### 4. Read Current Rules

Read the three rule files for the matched project:
- `<project>/project-info.md`
- `<project>/project-standards.md`
- `<project>/project-guidelines.md`

### 5. Analyze & Propose Changes

Compare the retrieved information against the current rule file contents. Identify:

1. **Fields to update** - Values that differ from the source
2. **Fields to add** - New information not currently in the rules
3. **Fields unchanged** - Values that already match (no action needed)

For each proposed change, note:
- Which file it affects
- The current value
- The new value

### 6. Confirm with User

Present the proposed changes to the user in a clear format:

```
Proposed changes to <project>:

project-standards.md:
  - Build tool: Maven -> Gradle
  - Build command: mvn verify -> gradle build

project-guidelines.md:
  - (no changes)

project-info.md:
  - SonarCloud component key: (none) -> org_repo
```

Ask the user to confirm before applying. If the user rejects or wants modifications, adjust accordingly.

### 7. Apply Changes

Once confirmed, update the rule files with the approved changes. Preserve the existing file format and structure - only modify the specific values that were approved.

### 8. Update install.sh Mapping (if needed)

If the changes include a new remote pattern or project directory rename, update the remote pattern mapping in:
- `install.sh` (RULE_FILES array)
- All command files under `commands/` (Detect Project section)

This should be rare - most updates only change values within existing rule files.

### 9. Constraints

You MUST:
- Read all three rule files before proposing changes
- Show proposed changes to the user before applying them
- Wait for user confirmation before writing any files
- Preserve the existing format and structure of rule files
- Only modify values that the user has approved

You MUST NOT:
- Apply changes without user confirmation
- Delete or restructure existing rule files
- Change values that were not part of the update request
- Modify rule files for other projects
- Remove fields from rule files (set to `_(none)_` if clearing a value)

### 10. Acceptance Criteria

- The correct project was detected and its rule files were read
- The source was correctly parsed (URL fetched or text used directly)
- Proposed changes were presented to the user for review
- Only approved changes were applied to the rule files
- Rule file format and structure remain consistent with other projects
