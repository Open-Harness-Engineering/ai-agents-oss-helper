#!/usr/bin/env bash
# Exercise the move of installed project rules out of ~/.claude/rules/ and ~/.bob/rules/, which
# Claude Code loads into every session, without touching the user's installation or network.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_home="$test_root/home"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

# make_rules <dir> <remote pattern>: a minimal OSS Helper rule set.
make_rules() {
    mkdir -p "$1"
    printf '# Project Information\n\n- **Remote pattern:** `%s`\n' "$2" > "$1/project-info.md"
    printf '# Project Standards\n' > "$1/project-standards.md"
    printf '# Project Guidelines\n' > "$1/project-guidelines.md"
}

legacy="$test_home/.claude/rules"
rules="$test_home/.claude/oss-helper/rules"

make_rules "$legacy/camel-core" "apache/camel"
make_rules "$legacy/wanaku" "wanaku-ai/wanaku"
# The same project already in the new location: the installer keeps it and leaves the old copy.
make_rules "$rules/wanaku" "wanaku-ai/wanaku"
echo 'newer copy' >> "$rules/wanaku/project-guidelines.md"
# What is not an OSS Helper rule set stays where it is.
echo 'My own rule' > "$legacy/my-style.md"
mkdir -p "$legacy/notes"
echo 'Not a rule set' > "$legacy/notes/project-info.md"

HOME="$test_home" bash "$repo_root/install.sh" claude > "$test_root/install.log" 2>&1

[[ -f "$rules/camel-core/project-info.md" && -f "$rules/camel-core/project-guidelines.md" ]] || fail "camel-core was not moved"
[[ ! -e "$legacy/camel-core" ]] || fail "camel-core is still under ~/.claude/rules"
grep -q 'newer copy' "$rules/wanaku/project-guidelines.md" || fail "the rules already in the new location were overwritten"
[[ -f "$legacy/wanaku/project-info.md" ]] || fail "the old wanaku copy was removed"
grep -q "Rules for wanaku are in both" "$test_root/install.log" || fail "no warning for the rules found in both locations"
[[ "$(cat "$legacy/my-style.md")" == 'My own rule' ]] || fail "a user rule file was touched"
[[ -f "$legacy/notes/project-info.md" ]] || fail "a directory without a Remote pattern was moved"

# A second run changes nothing.
HOME="$test_home" bash "$repo_root/install.sh" claude > "$test_root/reinstall.log" 2>&1
[[ -f "$rules/camel-core/project-info.md" ]] || fail "camel-core is gone after a second install"
if grep -q 'Moved project rules' "$test_root/reinstall.log"; then
    fail "a second install moved rules again"
fi

# Bob gets the same layout.
make_rules "$test_home/.bob/rules/hawtio" "hawtio/hawtio"
HOME="$test_home" bash "$repo_root/install.sh" bob > "$test_root/install-bob.log" 2>&1
[[ -f "$test_home/.bob/oss-helper/rules/hawtio/project-info.md" ]] || fail "Bob's rules were not moved"
[[ ! -e "$test_home/.bob/rules/hawtio" ]] || fail "hawtio is still under ~/.bob/rules"

# The security-case probe finds rules in the new location, and still in the old one.
clone="$test_root/clone"
git init -q "$clone"
git -C "$clone" remote add origin https://github.com/apache/camel.git
probe="$test_home/.claude/skills/oss-security/security-case-probe.sh"
env -i HOME="$test_home" PATH="$PATH" bash "$probe" demo-case "$clone" > "$test_root/probe.out"
grep -Fq "source: installed rules $rules/camel-core (Remote pattern: apache/camel)" "$test_root/probe.out" || fail "the probe did not find the moved rules"

make_rules "$legacy/legacy-only" "example/legacy-only"
git -C "$clone" remote set-url origin git@github.com:example/legacy-only.git
env -i HOME="$test_home" PATH="$PATH" bash "$probe" demo-case "$clone" > "$test_root/probe-legacy.out"
grep -Fq "source: installed rules $legacy/legacy-only (Remote pattern: example/legacy-only)" "$test_root/probe-legacy.out" || fail "the probe did not fall back to ~/.claude/rules"

echo 'PASS: installed rules move to ~/.<agent>/oss-helper/rules/, other files stay, and the probe reads both locations'
