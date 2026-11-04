#!/usr/bin/env bash
# Check the native Codex bundle independently of any installed user assets.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
bundle="$test_root/codex"
HOME="$test_root/home" bash "$repo_root/build.sh" --output-dir "$bundle" codex > /dev/null
for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
    cmp "$repo_root/skills/$skill/SKILL.md" "$bundle/skills/$skill/SKILL.md"
    cmp "$repo_root/skills/_shared/init.md" "$bundle/skills/$skill/init.md"
done
[[ -f "$bundle/skills/oss-project/oss-workspace-init.md" ]]
[[ -f "$bundle/agents/oss-code-reviewer.toml" ]]
if grep -R -Fq '.oss-init.md' "$bundle/skills"; then
    echo 'FAIL: bundled skills still reference the legacy init file' >&2
    exit 1
fi
# Python's TOML parser catches escaping errors in generated multiline instructions.
python3 - "$bundle" <<'PY'
import pathlib, sys, tomllib
for file in pathlib.Path(sys.argv[1], 'agents').glob('*.toml'):
    agent = tomllib.loads(file.read_text())
    assert agent['name'] and agent['description'] and agent['developer_instructions'], file
PY
echo 'PASS: Codex bundle contains current skills and valid native agent TOML'
