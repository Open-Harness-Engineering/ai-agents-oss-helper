#!/usr/bin/env bash
# Check what the Claude install adds to every session, without touching the user's installation or
# network: the command wrappers stay out of the model's context, the agent descriptions stay short,
# and no agent preloads a skill that does not exist.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_home="$test_root/home"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

HOME="$test_home" bash "$repo_root/install.sh" claude > "$test_root/install-claude.log"
HOME="$test_home" bash "$repo_root/install.sh" bob > "$test_root/install-bob.log"

# Every Claude command wrapper is user-only; the skill groups stay model-invocable.
count=0
for cmd in "$test_home"/.claude/commands/oss-*.md; do
    [[ -f "$cmd" ]] || fail "no Claude command wrappers were installed"
    grep -Fxq 'disable-model-invocation: true' "$cmd" || fail "$cmd is model-invocable"
    count=$((count + 1))
done
expected="$(grep -cE '^    "oss-[a-z-]+\|[^|]+\|oss-[a-z-]+\|' "$repo_root/install.sh")"
[[ "$count" -eq "$expected" ]] || fail "found $count Claude command wrappers, expected $expected"
if grep -l 'disable-model-invocation' "$test_home"/.claude/skills/oss-*/SKILL.md; then
    fail "a skill group is hidden from the model"
fi

# The field is Claude Code's; Bob's wrappers do not get it.
if grep -l 'disable-model-invocation' "$test_home"/.bob/commands/oss-*.md; then
    fail "a Bob command wrapper carries the Claude-only disable-model-invocation field"
fi

# Claude Code lists every agent description in every session: keep them to a sentence or two.
for agent in "$repo_root"/agents/*.md; do
    frontmatter="$(awk 'BEGIN { c = 0 } /^---[[:space:]]*$/ { c++; next } c == 1' "$agent")"
    description="$(printf '%s\n' "$frontmatter" | grep -m1 '^description:' || true)"
    [[ -n "$description" ]] || fail "$agent has no description"
    [[ "${#description}" -le 400 ]] || fail "$agent: the description line is ${#description} characters (limit 400)"

    # A skill listed under skills: is preloaded into the agent; it has to exist.
    for skill in $(printf '%s\n' "$frontmatter" | awk '/^skills:/ { s = 1; next } s && /^[[:space:]]+- / { print $2; next } { s = 0 }'); do
        [[ -d "$repo_root/skills/$skill" ]] || fail "$agent preloads the skill '$skill', which does not exist"
    done
done

echo "PASS: $count Claude command wrappers are user-only, Bob's are unchanged, and the agent descriptions are short"
