#!/usr/bin/env bash
# Exercise Codex upgrades without touching the user's installation or network.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_home="$test_root/home"
skills_root="$test_home/.agents/skills"
legacy_skills=(
    oss-helper oss-create-rules oss-triage-issue oss-review-prs
    oss-security-scan oss-workspace-init oss-workspace-status
    oss-create-multi-repo-issue oss-fix-multi-repo-issue
    oss-qe-create-test-plan oss-qe-verify oss-qe-module-audit
    README _common-init _build-workflow
)

for skill in "${legacy_skills[@]}"; do
    mkdir -p "$skills_root/$skill"
    echo 'Before you begin, read and follow the OSS Helper init file at ~/.codex/oss-helper/.oss-init.md.' > "$skills_root/$skill/SKILL.md"
done
mkdir -p "$skills_root/unrelated" "$test_home/.codex/oss-helper/rules/example"
echo 'User skill' > "$skills_root/unrelated/SKILL.md"
echo 'Project rules' > "$test_home/.codex/oss-helper/rules/example/project-info.md"
echo 'Legacy init' > "$test_home/.codex/oss-helper/.oss-init.md"

HOME="$test_home" bash "$repo_root/install.sh" codex > "$test_root/install.log"

for skill in "${legacy_skills[@]}"; do
    [[ ! -e "$skills_root/$skill" ]]
done
[[ ! -e "$test_home/.codex/oss-helper/.oss-init.md" ]]
[[ "$(cat "$skills_root/unrelated/SKILL.md")" == 'User skill' ]]
[[ "$(cat "$test_home/.codex/oss-helper/rules/example/project-info.md")" == 'Project rules' ]]

for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
    cmp "$repo_root/skills/$skill/SKILL.md" "$skills_root/$skill/SKILL.md"
    cmp "$repo_root/skills/_shared/init.md" "$skills_root/$skill/init.md"
done
[[ -f "$skills_root/oss-project/oss-workspace-init.md" ]]
[[ -f "$test_home/.codex/agents/oss-code-reviewer.toml" ]]
if grep -R -Fq '.oss-init.md' "$skills_root"; then
    echo 'FAIL: installed skills still reference the legacy init file' >&2
    exit 1
fi

# Reinstallation preserves same-named fragments that belong to the user.
for skill in README _common-init _build-workflow; do
    mkdir -p "$skills_root/$skill"
    echo 'User fragment' > "$skills_root/$skill/SKILL.md"
done
HOME="$test_home" bash "$repo_root/install.sh" codex > "$test_root/reinstall.log"
for skill in README _common-init _build-workflow; do
    [[ "$(cat "$skills_root/$skill/SKILL.md")" == 'User fragment' ]]
done

echo 'PASS: Codex upgrade removes legacy skills and preserves user skills and rules'
