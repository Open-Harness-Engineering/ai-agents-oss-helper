# Self-Update

Update the OSS Helper skills and project rules to the latest version.

## Instructions

### 1. Locate Repository

Find the OSS Helper repository:

```bash
test -d ~/.oss-helper/.git 2>/dev/null || test -d "$(readlink -f ~/.oss-helper 2>/dev/null)/.git" 2>/dev/null
```

If `~/.oss-helper` does not exist or is not a git repository, inform the user and stop:

> OSS Helper was not installed via git. Please reinstall:
> ```
> git clone https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git ~/.oss-helper
> ~/.oss-helper/install.sh
> ```

### 2. Update OSS Helper

Fetch and show available updates:

```bash
git -C ~/.oss-helper fetch --quiet 2>/dev/null
git -C ~/.oss-helper log HEAD..origin/main --oneline
```

If no output, report "OSS Helper skills are already up to date."

Otherwise, show the list of incoming changes and pull:

```bash
git -C ~/.oss-helper pull --quiet
```

### 3. Update Known-Projects

If `~/.oss-helper/known-projects/.git` exists, update it too:

```bash
git -C ~/.oss-helper/known-projects fetch --quiet 2>/dev/null
git -C ~/.oss-helper/known-projects log HEAD..origin/main --oneline
```

If updates are available, pull:

```bash
git -C ~/.oss-helper/known-projects pull --quiet
```

If the directory does not exist, skip this step.

### 4. Re-install for Conversion Agents

For agents that use symlinks (Claude, Bob), no further action is needed — the symlinks already point to the updated files.

For agents that require format conversion (Gemini, OpenCode, Codex), re-run the install script:

```bash
~/.oss-helper/install.sh <agent>
```

Detect the current agent and only re-install for conversion agents. For Claude and Bob, skip this step.

### 5. Reset Update Check

Reset the update check throttle:

```bash
touch ~/.oss-helper/.last-update-check
```

### 6. Report Results

Show the user what was updated:

```bash
git -C ~/.oss-helper log --oneline -10
```

If known-projects was also updated:

```bash
git -C ~/.oss-helper/known-projects log --oneline -10
```

> OSS Helper updated successfully.
