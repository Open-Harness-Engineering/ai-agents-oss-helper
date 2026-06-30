### 1. Parse Input

Determine whether the source argument is a URL or a text description:

- **URL** - Starts with `http://` or `https://`
- **Text description** - Everything else

### 2. Retrieve Information

**If URL:**

1. Fetch the document content using WebFetch or equivalent
2. Extract relevant project conventions from the document (build tools, branching strategy, commit formats, code style, CI/CD setup, contribution guidelines, etc.)
3. Summarize the extracted conventions

**If text description:**

1. Use the description directly as the source of changes

### 3. Read Current Rules

Read the three rule files for the matched project:

- `<project>/project-info.md`
- `<project>/project-standards.md`
- `<project>/project-guidelines.md`

### 4. Analyze & Propose Changes

Compare the retrieved information against the current rule file contents. Identify:

1. **Fields to update** - Values that differ from the source
2. **Fields to add** - New information not currently in the rules
3. **Fields unchanged** - Values that already match (no action needed)

For each proposed change, note:

- Which file it affects
- The current value
- The new value

### 5. Confirm with User

Present the proposed changes to the user in a clear format:

```text
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

### 6. Apply Changes

Once confirmed, update the rule files with the approved changes. Preserve the existing file format and structure - only modify the specific values that were approved.

### 7. Publish the Updated Rules

If the rules being updated live in:

- `<repo-root>/.oss-ai-helper-rules/` (project-local): commit the edits in the project repository and open a PR there. The rules travel with the project, so no other repository needs to change.
- `ai-agents-oss-known-projects` (centralized): commit the edits in that repository and open a PR. Once merged, users can pick up the changes by re-running the Install Info guideline (`install-info.md`). The `## Version` SHA at the bottom of each rule file should be bumped to the new commit so the version check during OSS Helper initialization detects the update.

Renaming a project directory inside `ai-agents-oss-known-projects` is a breaking change — coordinate with users that have already installed the old slug before doing it.

### 8. Constraints

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

### 9. Acceptance Criteria

- The correct project was detected and its rule files were read
- The source was correctly parsed (URL fetched or text used directly)
- Proposed changes were presented to the user for review
- Only approved changes were applied to the rule files
- Rule file format and structure remain consistent with other projects
