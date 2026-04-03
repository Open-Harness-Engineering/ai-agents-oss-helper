# OSS Helper - Self Update

Update the OSS Helper commands and rules to the latest version from the remote repository.

## Usage

`/oss-self-update`

## Instructions

### 1. Locate Repository

Find the OSS Helper repository:

```bash
test -d ~/.oss-helper/.git 2>/dev/null || test -d "$(readlink -f ~/.oss-helper 2>/dev/null)/.git" 2>/dev/null
```

If `~/.oss-helper` does not exist or is not a git repository, inform the user and stop:

> OSS Helper was not installed via git. Please reinstall:
> ```
> git clone https://github.com/orpiske/ai-agents-oss-helper.git ~/.oss-helper
> ~/.oss-helper/install.sh
> ```

### 2. Show Available Updates

Fetch the latest changes and show what is available:

```bash
git -C ~/.oss-helper fetch --quiet 2>/dev/null
git -C ~/.oss-helper log HEAD..origin/main --oneline
```

If no output, inform the user and stop:

> OSS Helper is already up to date.

Otherwise, show the list of incoming changes to the user.

### 3. Apply Updates

Pull the latest changes:

```bash
git -C ~/.oss-helper pull --quiet
```

### 4. Re-install for Conversion Agents

For agents that use symlinks (Claude, Bob), no further action is needed — the symlinks already point to the updated files.

For agents that require format conversion (Gemini, OpenCode, Codex), re-run the install script to regenerate converted files:

```bash
~/.oss-helper/install.sh <agent>
```

Detect the current agent:
- If running as a Claude command → `claude`
- If running as a Bob command → `bob`
- If running as a Gemini command → `gemini`
- If running as an OpenCode command → `opencode`
- If running as a Codex skill → `codex`

For Claude and Bob, skip this step (symlinks handle it automatically).

### 5. Reset Update Check

Reset the update check throttle so the next check starts fresh:

```bash
touch ~/.oss-helper/.last-update-check
```

### 6. Report Results

Show the user what was updated:

```bash
git -C ~/.oss-helper log --oneline -10
```

> OSS Helper updated successfully.
