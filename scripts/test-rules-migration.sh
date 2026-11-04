#!/usr/bin/env bash
# Runtime rule lookup supports both current and legacy locations; builds never migrate them.
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
export HOME="$test_root/home"
make_rules() {
    mkdir -p "$1"
    printf '# Project Information\n\n- **Remote pattern:** `%s`\n' "$2" > "$1/project-info.md"
    printf '# Project Standards\n' > "$1/project-standards.md"
    printf '# Project Guidelines\n' > "$1/project-guidelines.md"
}
legacy="$HOME/.claude/rules"
rules="$HOME/.claude/oss-helper/rules"
make_rules "$rules/current" example/current
make_rules "$legacy/old" example/old
cp -R "$HOME" "$test_root/home-before"
bash "$repo_root/build.sh" --output-dir "$test_root/plugin" claude > /dev/null
diff -r "$test_root/home-before" "$HOME"
clone="$test_root/clone"
git init -q "$clone"
git -C "$clone" remote add origin https://github.com/example/current.git
probe="$test_root/plugin/skills/oss-security/security-case-probe.sh"
bash "$probe" sample "$clone" > "$test_root/current.out"
grep -Fq "source: installed rules $rules/current (Remote pattern: example/current)" "$test_root/current.out"
git -C "$clone" remote set-url origin https://github.com/example/old.git
bash "$probe" sample "$clone" > "$test_root/old.out"
grep -Fq "source: installed rules $legacy/old (Remote pattern: example/old)" "$test_root/old.out"
echo 'PASS: builds preserve rules and runtime lookup supports current and legacy locations'
