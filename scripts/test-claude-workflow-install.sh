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

# Report commands run in a forked context: the body names the files a fresh sub-agent needs and
# passes the arguments. Commands that stop at a gate or ask questions stay inline.
for cmd in oss-list-prs oss-list-pr-status oss-pr-status oss-list-issues oss-analyze-issue oss-workspace-status; do
    file="$test_home/.claude/commands/$cmd.md"
    grep -Fxq 'context: fork' "$file"
    grep -Fxq 'background: false' "$file"
    grep -Fq 'Arguments: $ARGUMENTS' "$file"
    paths="$(grep -oE '~/\.claude/skills/[a-z-]+/[a-z-]+\.md' "$file")"
    [[ "$(printf '%s\n' "$paths" | wc -l)" -eq 2 ]]
    for path in $paths; do
        [[ -f "$test_home/${path:2}" ]]
    done
done
for cmd in oss-fix-issue oss-review-pr oss-merge-pr oss-address-review oss-find-task oss-security-case; do
    if grep -q '^context: fork' "$test_home/.claude/commands/$cmd.md"; then
        echo "FAIL: $cmd runs in a fork but stops for the user" >&2
        exit 1
    fi
done

# The fragments the guidelines reference ship in every skill.
for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
    for fragment in _build-workflow.md _issue-ownership.md _operator-preferences.md _checkpoint.md; do
        cmp "$repo_root/commands/_fragments/$fragment" "$test_home/.claude/skills/$skill/_fragments/$fragment"
    done
done

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
if grep -l '^context: fork' "$test_home"/.bob/commands/*.md; then
    echo 'FAIL: a Bob command carries the Claude-only context: fork field' >&2
    exit 1
fi

# agy gets the guideline and its command, but no workflow.
HOME="$test_home" bash "$repo_root/install.sh" agy > "$test_root/install-agy.log"
[[ -f "$test_home/.agy/skills/oss-security/security-case.md" ]]
grep -Fq 'security-case.md' "$test_home/.agy/commands/oss-security-case.md"
[[ ! -e "$test_home/.agy/workflows" ]]

echo 'PASS: the Claude install ships the oss-security-case workflow, guideline and command; Bob and agy get no workflow'
