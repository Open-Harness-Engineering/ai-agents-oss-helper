#!/usr/bin/env bash
# Exercise rules discovery from copied skills in native client caches, offline.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
export HOME="$test_root/home"
export CODEX_HOME="$HOME/.codex"
unset OSS_RULES_DIR
mkdir -p "$HOME" "$test_root/bin" "$test_root/clone"
git -C "$test_root/clone" init -q
git -C "$test_root/clone" remote add origin https://github.com/example/project.git
cat > "$test_root/bin/gh" <<'GH'
#!/usr/bin/env bash
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
GH
chmod +x "$test_root/bin/gh"
export PATH="$test_root/bin:$PATH"

seed_rules() {
    mkdir -p "$1/example"
    printf '# Project Information\n\n- **Remote pattern:** `example/project`\n- **GitHub repo:** `example/project`\n' > "$1/example/project-info.md"
    echo '# Project Standards' > "$1/example/project-standards.md"
    echo '# Project Guidelines' > "$1/example/project-guidelines.md"
}

expect_rules() {
    local script_dir="$1" expected="$2"
    mkdir -p "$script_dir"
    cp "$repo_root/skills/_shared/oss-init.sh" "$script_dir/oss-init.sh"
    bash "$script_dir/oss-init.sh" "$test_root/clone" > "$test_root/result"
    grep -Fq "source: installed $expected/example (Remote pattern: example/project)" "$test_root/result" || {
        cat "$test_root/result" >&2
        echo "FAIL: expected $expected from $script_dir" >&2
        exit 1
    }
    grep -Fq 'status: skipped (nothing to compare with)' "$test_root/result"
}

# Every agent has matching rules: a wrong client inference must fail these checks.
for root in "$HOME/.claude/oss-helper/rules" "$CODEX_HOME/oss-helper/rules" "$HOME/.gemini/rules" "$HOME/.bob/oss-helper/rules" "$HOME/.bob/rules" "$test_root/override"; do
    seed_rules "$root"
done
expect_rules "$CODEX_HOME/plugins/cache/catalog/oss-helper/version/skills/oss-issues" "$CODEX_HOME/oss-helper/rules"
expect_rules "$HOME/.agents/skills/oss-issues" "$CODEX_HOME/oss-helper/rules"
expect_rules "$HOME/.gemini/skills/oss-issues" "$HOME/.gemini/rules"
expect_rules "$HOME/.gemini/extensions/oss-helper/plugin/skills/oss-issues" "$HOME/.gemini/rules"
expect_rules "$HOME/.bob/extensions/oss-helper/plugin/skills/oss-issues" "$HOME/.bob/oss-helper/rules"
expect_rules "$HOME/.bob/plugins/cache/oss-helper/skills/oss-issues" "$HOME/.bob/oss-helper/rules"
expect_rules "$HOME/.bob/skills/oss-issues" "$HOME/.bob/oss-helper/rules"
expect_rules "$HOME/.claude/skills/oss-issues" "$HOME/.claude/oss-helper/rules"
# A generic clone or Claude plugin cache must not accidentally become Codex.
expect_rules "$test_root/checkout/plugin/skills/oss-issues" "$HOME/.claude/oss-helper/rules"
expect_rules "$HOME/.claude/plugins/cache/catalog/oss-helper/version/skills/oss-issues" "$HOME/.claude/oss-helper/rules"
rm -rf "$HOME/.bob/oss-helper/rules"
expect_rules "$HOME/.bob/extensions/oss-helper/plugin/skills/oss-issues" "$HOME/.bob/rules"
export CODEX_HOME="$test_root/custom codex"
seed_rules "$CODEX_HOME/oss-helper/rules"
expect_rules "$CODEX_HOME/plugins/cache/catalog/oss-helper/version/skills/oss-issues" "$CODEX_HOME/oss-helper/rules"
expect_rules "$HOME/.agents/skills/oss-issues" "$CODEX_HOME/oss-helper/rules"
OSS_RULES_DIR="$test_root/override" expect_rules "$CODEX_HOME/plugins/cache/catalog/oss-helper/version/skills/oss-issues" "$test_root/override"
echo 'PASS: native client caches select matching rules, preserve legacy fallback and honor CODEX_HOME/OSS_RULES_DIR'
