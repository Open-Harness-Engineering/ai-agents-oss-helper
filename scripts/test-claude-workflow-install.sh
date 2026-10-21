#!/usr/bin/env bash
# Exercise the Claude workflow install without touching the user's installation or network.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_home="$test_root/home"

# A workflow that belongs to the user must survive the install.
mkdir -p "$test_home/.claude/workflows"
echo "export const meta = { name: 'user-workflow', description: 'not ours' }" > "$test_home/.claude/workflows/user-workflow.js"

HOME="$test_home" bash "$repo_root/install.sh" claude > "$test_root/install.log"

workflows="$test_home/.claude/workflows"
cmp "$repo_root/workflows/oss-security-case.js" "$workflows/oss-security-case.js"
[[ "$(cat "$workflows/user-workflow.js")" == "export const meta = { name: 'user-workflow', description: 'not ours' }" ]]

# Claude Code looks a saved workflow up by the name in its meta block, so it must match the file name.
for file in "$repo_root"/workflows/*.js; do
    name="$(basename "$file" .js)"
    head -1 "$file" | grep -Fq 'export const meta = {'
    grep -Eq "^  name: '$name'," "$file"
done

cmp "$repo_root/skills/oss-security/security-case.md" "$test_home/.claude/skills/oss-security/security-case.md"
grep -Fq 'security-case.md' "$test_home/.claude/commands/oss-security-case.md"

# The loader's probe ships with the skill, parses, and runs read-only against any clone (gh may be absent).
probe="$test_home/.claude/skills/oss-security/security-case-probe.sh"
cmp "$repo_root/skills/oss-security/security-case-probe.sh" "$probe"
bash -n "$probe"
env -i HOME="$test_home" PATH="$PATH" bash "$probe" demo-case "$repo_root" > "$test_root/probe.out"
grep -Fq "repoRoot: $repo_root" "$test_root/probe.out"
grep -Fq "caseDir: $test_home/.oss-helper/security-cases/demo-case (does not exist yet)" "$test_root/probe.out"
grep -Fq '=== end' "$test_root/probe.out"
if env -i HOME="$test_home" PATH="$PATH" bash "$probe" > /dev/null 2>&1; then
    echo 'FAIL: the probe accepted a missing case slug' >&2
    exit 1
fi

# Bob gets the guideline and its command, but no workflow.
HOME="$test_home" bash "$repo_root/install.sh" bob > "$test_root/install-bob.log"
[[ -f "$test_home/.bob/skills/oss-security/security-case.md" ]]
grep -Fq 'security-case.md' "$test_home/.bob/commands/oss-security-case.md"
[[ ! -e "$test_home/.bob/workflows" ]]

echo 'PASS: the Claude install ships the oss-security-case workflow, guideline and command; Bob gets no workflow'
