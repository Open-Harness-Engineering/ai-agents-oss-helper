#!/usr/bin/env bash
# Compatibility installation uses isolated homes and fake archive downloads only.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
unset OSS_HELPER_VERSION OSS_HELPER_ARCHIVE_URL
export HOME="$test_root/home"
export FAKE_CURL_LOG="$test_root/downloads.log"
mkdir -p "$test_root/bin" "$HOME/.claude/rules/example" "$HOME/.claude/skills/user-skill" "$HOME/.claude/commands" "$HOME/.codex/oss-helper/rules/example"
printf 'user rule\n' > "$HOME/.claude/rules/example/project-info.md"
printf 'codex rule\n' > "$HOME/.codex/oss-helper/rules/example/project-info.md"
printf 'user skill\n' > "$HOME/.claude/skills/user-skill/SKILL.md"
printf 'user command\n' > "$HOME/.claude/commands/user-command.md"
cat > "$test_root/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_CURL_LOG"
output=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [[ -n "$output" ]]; then cp "$FAKE_ARCHIVE" "$output"; else cat "$FAKE_ARCHIVE"; fi
CURL
cat > "$test_root/bin/gh" <<'GH'
#!/usr/bin/env bash
exit 1
GH
chmod +x "$test_root/bin/curl" "$test_root/bin/gh"
export PATH="$test_root/bin:$PATH"
# Capture existing project output; compatibility installation must build elsewhere.
cp -R "$repo_root/plugin" "$test_root/plugin-before"
if [[ -d "$repo_root/build" ]]; then cp -R "$repo_root/build" "$test_root/build-before"; fi
cd "$test_root"
bash "$repo_root/install.sh" > "$test_root/install-all.log"
[[ ! -e "$FAKE_CURL_LOG" ]] || fail 'local install downloaded assets'
for agent in claude bob gemini opencode codex agy; do
    if [[ "$agent" == opencode ]]; then base="$HOME/.config/opencode"; else base="$HOME/.$agent"; fi
    if [[ "$agent" == codex ]]; then
        skills="$HOME/.agents/skills"
        [[ -f "$base/agents/oss-code-reviewer.toml" ]]
    else
        skills="$base/skills"
        [[ -f "$base/agents/oss-code-reviewer.md" ]]
    fi
    case "$agent" in
        gemini) [[ -f "$base/commands/oss-fix-issue.toml" ]] ;;
        opencode) [[ -f "$base/commands/oss-fix-issue.md" ]] ;;
        *)
            for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
                cmp "$repo_root/skills/$skill/SKILL.md" "$skills/$skill/SKILL.md"
                cmp "$repo_root/skills/_shared/init.md" "$skills/$skill/init.md"
                [[ -f "$skills/$skill/_fragments/_checkpoint.md" ]]
            done
            ;;
    esac
done
[[ "$(cat "$HOME/.claude/rules/example/project-info.md")" == 'user rule' ]]
[[ "$(cat "$HOME/.codex/oss-helper/rules/example/project-info.md")" == 'codex rule' ]]
[[ -f "$HOME/.claude/skills/user-skill/SKILL.md" && -f "$HOME/.claude/commands/user-command.md" ]]
[[ ! -e "$HOME/.claude/.oss-helper-build" && ! -e "$HOME/.claude/.claude-plugin" ]]
# Legacy commands must work without a plugin namespace or plugin cache.
grep -Fq 'Invoke the oss-issues skill.' "$HOME/.claude/commands/oss-fix-issue.md"
grep -Fq '~/.claude/skills/oss-issues/init.md' "$HOME/.claude/commands/oss-analyze-issue.md"
if grep -R -E 'CLAUDE_PLUGIN_ROOT|oss-helper:' "$HOME/.claude/commands"; then fail 'plugin syntax leaked into legacy wrappers'; fi
cmp "$repo_root/workflows/oss-security-case.js" "$HOME/.claude/workflows/oss-security-case.js"
cp -R "$HOME" "$test_root/installed-before"
bash "$repo_root/install.sh" claude > "$test_root/reinstall.log"
diff -r "$test_root/installed-before" "$HOME"
diff -r "$test_root/plugin-before" "$repo_root/plugin"
if [[ -d "$test_root/build-before" ]]; then diff -r "$test_root/build-before" "$repo_root/build"; else [[ ! -e "$repo_root/build" ]]; fi
# Invalid CLI arguments fail before downloading or creating a home directory.
for invalid in unknown-agent 'claude bob' --bad-option --version --version=; do
    if HOME="$test_root/invalid-home" bash "$repo_root/install.sh" "$invalid" > /dev/null 2>&1; then fail "accepted invalid argument: $invalid"; fi
    [[ ! -e "$test_root/invalid-home" && ! -e "$FAKE_CURL_LOG" ]]
done
if HOME="$test_root/invalid-home" bash "$repo_root/install.sh" claude bob > /dev/null 2>&1; then fail 'accepted two agents'; fi
[[ ! -e "$test_root/invalid-home" && ! -e "$FAKE_CURL_LOG" ]]

# Existing symlinked configuration roots are supported by the compatibility path.
mkdir -p "$test_root/linked-home" "$test_root/external-config/opencode/commands"
echo keep > "$test_root/external-config/opencode/commands/user-command.md"
ln -s "$test_root/external-config" "$test_root/linked-home/.config"
HOME="$test_root/linked-home" bash "$repo_root/install.sh" opencode > "$test_root/linked.log"
[[ -L "$test_root/linked-home/.config" ]]
[[ -f "$test_root/external-config/opencode/commands/oss-fix-issue.md" ]]
[[ "$(cat "$test_root/external-config/opencode/commands/user-command.md")" == keep ]]
# A concrete generated asset symlink must still be refused before copying.
mkdir -p "$test_root/asset-home/.claude/commands"
echo protected > "$test_root/protected-command"
ln -s "$test_root/protected-command" "$test_root/asset-home/.claude/commands/oss-fix-issue.md"
cp -R "$test_root/asset-home" "$test_root/asset-before"
if HOME="$test_root/asset-home" bash "$repo_root/install.sh" claude > "$test_root/asset.log" 2>&1; then fail 'accepted symlinked generated asset'; fi
diff -r "$test_root/asset-before" "$test_root/asset-home"
[[ "$(cat "$test_root/protected-command")" == protected ]]

# A current archive serves stdin installs and explicit ref selection, with no network.
mkdir -p "$test_root/archive/current-checkout"
for item in install.sh build.sh skills agents commands workflows packaging LICENSE; do
    cp -R "$repo_root/$item" "$test_root/archive/current-checkout/$item"
done
tar -czf "$test_root/current.tar.gz" -C "$test_root/archive" current-checkout
export FAKE_ARCHIVE="$test_root/current.tar.gz"
HOME="$test_root/remote-home" bash -s -- --version v-test codex < "$repo_root/install.sh" > "$test_root/remote.log"
[[ -f "$test_root/remote-home/.agents/skills/oss-issues/SKILL.md" && ! -e "$test_root/remote-home/.claude" ]]
grep -Fq '/tar.gz/v-test' "$FAKE_CURL_LOG"

# Older tagged archives lacking build.sh delegate to their own legacy installer.
mkdir -p "$test_root/old-archive/old-checkout"
cat > "$test_root/old-archive/old-checkout/install.sh" <<'OLD'
#!/usr/bin/env bash
set -eu
printf 'ref=%s\n' "${OSS_HELPER_VERSION:-}" > "$LEGACY_CALL_LOG"
printf 'arg=%s\n' "$@" >> "$LEGACY_CALL_LOG"
mkdir -p "$HOME"
echo installed > "$HOME/old-install-marker"
OLD
tar -czf "$test_root/old.tar.gz" -C "$test_root/old-archive" old-checkout
export FAKE_ARCHIVE="$test_root/old.tar.gz"
export LEGACY_CALL_LOG="$test_root/legacy-call.log"
HOME="$test_root/old-home" OSS_HELPER_VERSION=v-old bash -s -- bob < "$repo_root/install.sh" > "$test_root/old.log"
[[ -f "$test_root/old-home/old-install-marker" ]]
grep -Fq '/tar.gz/v-old' "$FAKE_CURL_LOG"
grep -Fq 'v-old' "$LEGACY_CALL_LOG"
grep -Fxq 'arg=bob' "$LEGACY_CALL_LOG"
HOME="$test_root/flag-home" OSS_HELPER_VERSION=v-env bash "$repo_root/install.sh" --version=v-flag agy > "$test_root/flag.log"
grep -Fq '/tar.gz/v-flag' "$FAKE_CURL_LOG"
grep -Fq 'v-flag' "$LEGACY_CALL_LOG"
grep -Fxq 'arg=agy' "$LEGACY_CALL_LOG"
# A configured archive mirror works without changing the selected ref.
HOME="$test_root/mirror-home" OSS_HELPER_ARCHIVE_URL=https://archive.invalid/fixture.tar.gz bash -s -- claude < "$repo_root/install.sh" > "$test_root/mirror.log"
grep -Fq 'https://archive.invalid/fixture.tar.gz' "$FAKE_CURL_LOG"
[[ -f "$test_root/mirror-home/old-install-marker" ]]
# A standalone downloaded installer must not execute an unrelated sibling builder.
mkdir -p "$test_root/standalone"
cp "$repo_root/install.sh" "$test_root/standalone/install.sh"
export STANDALONE_SENTINEL="$test_root/unrelated-builder-executed"
printf '#!/usr/bin/env bash\necho executed > "$STANDALONE_SENTINEL"\n' > "$test_root/standalone/build.sh"
HOME="$test_root/standalone-home" bash "$test_root/standalone/install.sh" bob > "$test_root/standalone.log"
[[ ! -e "$STANDALONE_SENTINEL" && -f "$test_root/standalone-home/old-install-marker" ]]
grep -Fq '/tar.gz/main' "$FAKE_CURL_LOG"
grep -Fxq 'ref=main' "$LEGACY_CALL_LOG"

# Exercise wget fallback even on hosts that also have curl installed.
cat > "$test_root/bin/wget" <<'WGET'
#!/usr/bin/env bash
set -euo pipefail
printf 'WGET %s\n' "$*" >> "$FAKE_CURL_LOG"
output=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O|--output-document) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [[ -n "$output" && "$output" != - ]]; then cp "$FAKE_ARCHIVE" "$output"; else cat "$FAKE_ARCHIVE"; fi
WGET
chmod +x "$test_root/bin/wget"
(
    command() {
        if [[ "${1:-}" == -v && "${2:-}" == curl ]]; then return 1; fi
        builtin command "$@"
    }
    export -f command
    HOME="$test_root/wget-home" bash -s -- --version v-wget gemini < "$repo_root/install.sh" > "$test_root/wget.log"
)
grep -Fq 'WGET ' "$FAKE_CURL_LOG"
grep -Fq '/tar.gz/v-wget' "$FAKE_CURL_LOG"
[[ -f "$test_root/wget-home/old-install-marker" ]]
echo 'PASS: local and stdin compatibility installs, all targets, legacy paths, preservation, CLI validation and pinned archive delegation'
