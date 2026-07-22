---
name: self-update
description: >
  Update oss-helper to the latest version via git pull.
user-invocable: true
---

# Self-Update

Update oss-helper to the latest version from the remote repository.

## Instructions

### 1. Locate Repository

Find the oss-helper clone:

```bash
FORGEBOT_SKILLS_DIR=""
for dir in ~/.oss-helper "$HOME/.claude/oss-helper"; do
  if [[ -d "$dir/.git" ]] || { [[ -L "$dir" ]] && [[ -d "$(readlink -f "$dir" 2>/dev/null)/.git" ]]; }; then
    FORGEBOT_SKILLS_DIR="$dir"
    break
  fi
done
```

If `FORGEBOT_SKILLS_DIR` is empty, the skills were not installed via git clone.
Inform the user and stop:

> ForgeBot skills were not installed via git clone. Please reinstall:
> ```
> git clone https://gitea.gnodet.fr/gnodet/oss-helper.git ~/.oss-helper
> ~/.oss-helper/install.sh
> ```

### 2. Fetch and Show Available Updates

```bash
git -C "$FORGEBOT_SKILLS_DIR" fetch --quiet 2>/dev/null
UPDATES=$(git -C "$FORGEBOT_SKILLS_DIR" log HEAD..origin/main --oneline 2>/dev/null)
```

If `$UPDATES` is empty, report: "ForgeBot skills are already up to date."

Otherwise, show the incoming changes and pull:

```bash
echo "Updates available:"
echo "$UPDATES"
git -C "$FORGEBOT_SKILLS_DIR" pull --quiet
```

### 3. Update Installed Skills

For symlink-based installs (Claude), no further action is needed — symlinks
already point to the updated files.

For copy-based installs, re-run the installer:

```bash
"$FORGEBOT_SKILLS_DIR/install.sh"
```

### 4. Reset Update Check Throttle

```bash
touch "$FORGEBOT_SKILLS_DIR/.last-update-check"
```

### 5. Report Results

```
ForgeBot skills updated successfully.

Changes applied:
<list of commits from $UPDATES>

Skills are current as of: <timestamp>
```

If the pull failed (e.g. local modifications), report the error and suggest:

```
git -C ~/.oss-helper stash && git -C ~/.oss-helper pull && git -C ~/.oss-helper stash pop
```
