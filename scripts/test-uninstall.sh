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
echo 'PASS: legacy uninstall preview, selection, preservation, repeatability and symlink refusal'
