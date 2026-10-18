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

# Bob gets the guideline and its command, but no workflow.
HOME="$test_home" bash "$repo_root/install.sh" bob > "$test_root/install-bob.log"
[[ -f "$test_home/.bob/skills/oss-security/security-case.md" ]]
grep -Fq 'security-case.md' "$test_home/.bob/commands/oss-security-case.md"
[[ ! -e "$test_home/.bob/workflows" ]]

echo 'PASS: the Claude install ships the oss-security-case workflow, guideline and command; Bob gets no workflow'
