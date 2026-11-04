#!/usr/bin/env bash
# Exercise local assembly without changing the checkout output or the user's home.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
# No live GitHub calls while exercising local runtime discovery.
mkdir -p "$test_root/bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$test_root/bin/gh"
chmod +x "$test_root/bin/gh"
export PATH="$test_root/bin:$PATH"
fail() { echo "FAIL: $1" >&2; exit 1; }
export HOME="$test_root/home"
mkdir -p "$HOME/.claude/rules/example"
printf 'keep\n' > "$HOME/.claude/rules/example/project-info.md"
cp -R "$HOME" "$test_root/home-before"

# Work from outside the checkout, including a path containing spaces.
cd "$test_root"
for agent in claude bob gemini opencode codex agy; do
    output="$test_root/output $agent"
    bash "$repo_root/build.sh" --output-dir "$output" "$agent" > "$test_root/$agent.log"
    [[ -d "$output/agents" ]] || fail "$agent agents missing"
    if [[ "$agent" == gemini ]]; then
        [[ -f "$output/commands/oss-fix-issue.toml" ]]
    elif [[ "$agent" == opencode ]]; then
        [[ -f "$output/commands/oss-fix-issue.md" ]]
    else
        for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
            cmp "$repo_root/skills/$skill/SKILL.md" "$output/skills/$skill/SKILL.md"
            cmp "$repo_root/skills/_shared/init.md" "$output/skills/$skill/init.md"
            cmp "$repo_root/skills/_shared/oss-init.sh" "$output/skills/$skill/oss-init.sh"
            [[ -f "$output/skills/$skill/_fragments/_checkpoint.md" ]]
        done
    fi
    cp -R "$output" "$test_root/before-$agent"
    touch "$output/stale-generated-file"
    bash "$repo_root/build.sh" --output-dir "$output/" "$agent" >> "$test_root/$agent.log"
    diff -r "$test_root/before-$agent" "$output"
done
diff -r "$test_root/home-before" "$HOME"
plugin="$test_root/output claude"
[[ -f "$plugin/.claude-plugin/plugin.json" && -f "$plugin/LICENSE" ]]
[[ ! -e "$plugin/commands/_fragments" && ! -e "$plugin/skills/_shared" ]]
if grep -R -F '~/.claude/skills/' "$plugin/commands"; then fail 'Claude commands reference legacy installation'; fi

# A relocated bundle must be self-contained.
mv "$plugin" "$test_root/relocated plugin"
probe="$test_root/relocated plugin/skills/oss-security/security-case-probe.sh"
bash "$probe" sample "$repo_root" > "$test_root/probe.out"
grep -Fq "skillsRoot: $test_root/relocated plugin/skills" "$test_root/probe.out"

# Manifest wiring must resolve to a self-contained plugin directory.
python3 - "$repo_root" "$test_root/relocated plugin" <<'PYJSON'
import json, pathlib, sys
repo, plugin = map(pathlib.Path, sys.argv[1:])
catalog = json.loads((repo / '.claude-plugin/marketplace.json').read_text())
manifest = json.loads((plugin / '.claude-plugin/plugin.json').read_text())
assert catalog['name'] == 'ai-agents-oss-helper'
assert catalog['owner']['name']
assert catalog['plugins'][0]['source'] == './plugin'
assert catalog['plugins'][0]['name'] == manifest['name'] == 'oss-helper'
assert manifest['version'] and manifest['license'] == 'Apache-2.0'
PYJSON

# A builder refuses to overwrite a directory it does not own.
mkdir "$test_root/user-output"
echo keep > "$test_root/user-output/notes"
if bash "$repo_root/build.sh" --output-dir "$test_root/user-output" claude > /dev/null 2>&1; then
    fail 'build accepted unmarked output'
fi
[[ "$(cat "$test_root/user-output/notes")" == keep ]]
ln -s "$test_root/user-output" "$test_root/output-link"
if bash "$repo_root/build.sh" --output-dir "$test_root/output-link" claude > /dev/null 2>&1; then
    fail 'build accepted symlinked output'
fi
[[ -L "$test_root/output-link" && "$(cat "$test_root/user-output/notes")" == keep ]]

# Missing checkout inputs fail locally; no network fallback may hide the failure.
mkdir "$test_root/incomplete"
cp "$repo_root/build.sh" "$test_root/incomplete/"
# Copy any sourced packaging helpers, but deliberately omit source assets.
if [[ -d "$repo_root/scripts" ]]; then cp -R "$repo_root/scripts" "$test_root/incomplete/"; fi
if bash "$test_root/incomplete/build.sh" --output-dir "$test_root/incomplete-output" claude > "$test_root/missing.log" 2>&1; then
    fail 'build accepted missing source assets'
fi
mkdir -p "$test_root/previous-output"
printf 'OSS Helper generated output: claude\n' > "$test_root/previous-output/.oss-helper-build"
echo 'previous complete bundle' > "$test_root/previous-output/notes"
cp -R "$test_root/previous-output" "$test_root/previous-before"
if bash "$test_root/incomplete/build.sh" --output-dir "$test_root/previous-output" claude > "$test_root/previous.log" 2>&1; then
    fail 'build accepted missing source assets over existing output'
fi
diff -r "$test_root/previous-before" "$test_root/previous-output"
if bash "$repo_root/build.sh" unknown-agent > /dev/null 2>&1; then fail 'build accepted an unknown agent'; fi
if bash "$repo_root/build.sh" 'claude bob' > /dev/null 2>&1; then fail 'build accepted multiple agents as one'; fi
if bash "$repo_root/build.sh" --version v1.0.0 > /dev/null 2>&1; then fail 'build accepted removed remote-version option'; fi

echo 'PASS: six local bundles, deterministic clean rebuilds, untouched HOME and relocatable Claude assets'
