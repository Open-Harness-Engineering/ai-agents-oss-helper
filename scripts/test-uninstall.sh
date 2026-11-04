#!/usr/bin/env bash
# Remove legacy bundles only after an explicit --yes, preserving user data.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
export HOME="$test_root/home"
fail() { echo "FAIL: $1" >&2; exit 1; }
for agent in claude bob gemini opencode codex agy; do
    if [[ "$agent" == opencode ]]; then base="$HOME/.config/opencode"; else base="$HOME/.$agent"; fi
    skills="$base/skills"
    [[ "$agent" != codex ]] || skills="$HOME/.agents/skills"
    mkdir -p "$skills/oss-issues" "$skills/oss-helper" "$skills/unrelated" "$base/commands" "$base/agents" "$base/oss-helper/rules/example" "$base/rules/example"
    printf 'legacy\n' > "$skills/oss-issues/SKILL.md"
    printf 'legacy\n' > "$skills/oss-helper/SKILL.md"
    printf 'user\n' > "$skills/unrelated/SKILL.md"
    printf 'legacy\n' > "$base/commands/oss-fix-issue.md"
    printf 'legacy\n' > "$base/commands/camel-fix-sonarcloud.md"
    printf 'legacy\n' > "$base/commands/oss-fix-issue.toml"
    printf 'user\n' > "$base/commands/unrelated.md"
    if [[ "$agent" == codex ]]; then ext=toml; else ext=md; fi
    printf 'legacy\n' > "$base/agents/oss-code-reviewer.$ext"
    printf 'user\n' > "$base/agents/user.$ext"
    printf 'rules\n' > "$base/oss-helper/rules/example/project-info.md"
    printf 'rules\n' > "$base/rules/example/project-info.md"
    printf 'legacy\n' > "$base/oss-helper/.oss-init.md"
done
mkdir -p "$HOME/.claude/workflows" "$HOME/.claude/plugins" "$HOME/.oss-helper/security-cases/example" "$HOME/.agents/skills/README" "$HOME/.agents/skills/_common-init"
printf 'legacy\n' > "$HOME/.claude/workflows/oss-security-case.js"
printf 'user\n' > "$HOME/.claude/workflows/user.js"
printf 'plugin state\n' > "$HOME/.claude/plugins/installed_plugins.json"
printf 'private case\n' > "$HOME/.oss-helper/security-cases/example/STATUS.md"
printf 'Before you begin, read and follow the OSS Helper init file at ~/.codex/oss-helper/.oss-init.md.\n' > "$HOME/.agents/skills/README/SKILL.md"
printf 'User fragment\n' > "$HOME/.agents/skills/_common-init/SKILL.md"
cp -R "$HOME" "$test_root/before"
bash "$repo_root/uninstall.sh" > "$test_root/preview.log"
diff -r "$test_root/before" "$HOME"
grep -Fq 'Would remove' "$test_root/preview.log"
# Selecting one agent must leave other agents' files alone.
bash "$repo_root/uninstall.sh" --yes claude > "$test_root/claude.log"
[[ ! -e "$HOME/.claude/skills/oss-issues" ]]
[[ -f "$HOME/.bob/skills/oss-issues/SKILL.md" ]]
bash "$repo_root/uninstall.sh" --yes > "$test_root/remove.log"
for agent in claude bob gemini opencode codex agy; do
    if [[ "$agent" == opencode ]]; then base="$HOME/.config/opencode"; else base="$HOME/.$agent"; fi
    skills="$base/skills"
    [[ "$agent" != codex ]] || skills="$HOME/.agents/skills"
    [[ ! -e "$skills/oss-issues" && ! -e "$skills/oss-helper" ]]
    [[ ! -e "$base/commands/oss-fix-issue.md" && ! -e "$base/commands/camel-fix-sonarcloud.md" ]]
    if [[ "$agent" == gemini ]]; then [[ ! -e "$base/commands/oss-fix-issue.toml" ]]; fi
    if [[ "$agent" == codex ]]; then ext=toml; else ext=md; fi
    [[ ! -e "$base/agents/oss-code-reviewer.$ext" && ! -e "$base/oss-helper/.oss-init.md" ]]
    [[ -f "$base/commands/unrelated.md" && -f "$base/agents/user.$ext" && -f "$skills/unrelated/SKILL.md" ]]
    [[ -f "$base/oss-helper/rules/example/project-info.md" && -f "$base/rules/example/project-info.md" ]]
done
[[ ! -e "$HOME/.claude/workflows/oss-security-case.js" && -f "$HOME/.claude/workflows/user.js" ]]
[[ ! -e "$HOME/.agents/skills/README" && -f "$HOME/.agents/skills/_common-init/SKILL.md" ]]
[[ -f "$HOME/.claude/plugins/installed_plugins.json" && -f "$HOME/.oss-helper/security-cases/example/STATUS.md" ]]
# Repeated removal succeeds without touching remaining data.
cp -R "$HOME" "$test_root/after"
bash "$repo_root/uninstall.sh" --yes > /dev/null
diff -r "$test_root/after" "$HOME"
# Refuse a symlinked component rather than following it into another tree.
mkdir -p "$test_root/external/oss-issues"
rm -rf "$HOME/.bob/skills"
ln -s "$test_root/external" "$HOME/.bob/skills"
if bash "$repo_root/uninstall.sh" --yes bob > /dev/null 2>&1; then fail 'accepted symlinked skills root'; fi
[[ -d "$test_root/external/oss-issues" ]]
if bash "$repo_root/uninstall.sh" 'claude bob' > /dev/null 2>&1; then fail 'accepted multiple agents as one'; fi
# An unsafe early target must not prevent later safe targets from being processed.
export HOME="$test_root/symlink-home"
mkdir -p "$HOME" "$test_root/external-config/opencode/skills/oss-issues" "$HOME/.agents/skills/oss-issues" "$HOME/.agy/skills/oss-issues"
ln -s "$test_root/external-config" "$HOME/.config"
cp -R "$HOME" "$test_root/symlink-before"
if bash "$repo_root/uninstall.sh" > "$test_root/symlink-preview.log" 2> "$test_root/symlink-preview.err"; then fail 'preview ignored unsafe target'; fi
diff -r "$test_root/symlink-before" "$HOME"
grep -Fq "Would remove $HOME/.agents/skills/oss-issues" "$test_root/symlink-preview.log"
grep -Fq "Would remove $HOME/.agy/skills/oss-issues" "$test_root/symlink-preview.log"
grep -Fq 'Refusing symlinked installation directories for opencode' "$test_root/symlink-preview.err"
if bash "$repo_root/uninstall.sh" --yes > "$test_root/symlink-remove.log" 2> "$test_root/symlink-remove.err"; then fail 'removal ignored unsafe target'; fi
[[ ! -e "$HOME/.agents/skills/oss-issues" && ! -e "$HOME/.agy/skills/oss-issues" ]]
[[ -L "$HOME/.config" && -d "$test_root/external-config/opencode/skills/oss-issues" ]]
# Actual rm failures also produce a failed result while later agents continue.
export HOME="$test_root/failure-home"
mkdir -p "$HOME/.claude/skills/oss-issues" "$HOME/.agy/skills/oss-issues" "$test_root/bin"
real_rm="$(command -v rm)"
cat > "$test_root/bin/rm" <<'RM'
#!/usr/bin/env bash
case "$*" in *'/.claude/skills/oss-issues'*) echo 'simulated removal failure' >&2; exit 41 ;; esac
exec "$REAL_RM" "$@"
RM
chmod +x "$test_root/bin/rm"
if PATH="$test_root/bin:$PATH" REAL_RM="$real_rm" bash "$repo_root/uninstall.sh" --yes > "$test_root/failure.log" 2> "$test_root/failure.err"; then fail 'ignored rm failure'; fi
[[ -d "$HOME/.claude/skills/oss-issues" && ! -e "$HOME/.agy/skills/oss-issues" ]]
grep -Fq 'simulated removal failure' "$test_root/failure.err"
# Report unknown candidates by filename without claiming ownership or deleting them.
export HOME="$test_root/detection-home"
base="$HOME/.claude"
mkdir -p "$base/skills/oss-unknown-skill" "$base/skills/oss-issues" "$base/skills/unrelated" "$base/commands" "$base/agents" "$base/workflows" "$HOME/.bob/skills/oss-unselected" "$test_root/scan-external/oss-nested"
for file in oss-unknown-command.md camel-unknown-command.md wanaku-unknown-command.md ai-agents-oss-helper-unknown-command.md unrelated.md; do printf 'preserve\n' > "$base/commands/$file"; done
printf 'known\n' > "$base/commands/oss-fix-issue.md"
printf 'preserve\n' > "$base/agents/oss-unknown-agent.md"
printf 'preserve\n' > "$base/workflows/oss-unknown-workflow.js"
ln -s "$test_root/scan-external" "$base/skills/oss-unknown-link"
cp -R "$HOME" "$test_root/detection-before"
bash "$repo_root/uninstall.sh" claude > "$test_root/detection-preview.log" 2> "$test_root/detection-preview.err"
diff -r "$test_root/detection-before" "$HOME"
bash "$repo_root/uninstall.sh" --yes claude > "$test_root/detection-remove.log" 2> "$test_root/detection-remove.err"
for log in "$test_root/detection-preview.log" "$test_root/detection-remove.log"; do
    for path in skills/oss-unknown-skill skills/oss-unknown-link commands/oss-unknown-command.md commands/camel-unknown-command.md commands/wanaku-unknown-command.md commands/ai-agents-oss-helper-unknown-command.md agents/oss-unknown-agent.md workflows/oss-unknown-workflow.js; do
        grep -Fq "Possible leftover (ownership unverified; preserved): $base/$path" "$log"
        [[ -e "$base/$path" || -L "$base/$path" ]]
    done
    if grep -F 'Possible leftover' "$log" | grep -Eq 'oss-issues|oss-fix-issue|unrelated|oss-unselected|oss-nested'; then fail 'reported known, unrelated, unselected or nested asset'; fi
done
[[ ! -e "$base/skills/oss-issues" && ! -e "$base/commands/oss-fix-issue.md" ]]
[[ -d "$test_root/scan-external/oss-nested" && -d "$HOME/.bob/skills/oss-unselected" ]]
grep -Fq "selected agents' skills" "$test_root/detection-preview.err"
echo 'PASS: legacy uninstall preview, selection, preservation, failure isolation and detection-only scan'
