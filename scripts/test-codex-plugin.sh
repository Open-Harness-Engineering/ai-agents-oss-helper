#!/usr/bin/env bash
# Optional native Codex CLI proof; all configuration, cache and manual assets are isolated.
set -euo pipefail
if ! command -v codex > /dev/null 2>&1; then
    echo 'SKIP: native Codex plugin smoke test requires a Codex CLI with plugin marketplace support'
    exit 0
fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
export HOME="$test_root/home"
export CODEX_HOME="$HOME/.codex"
mkdir -p "$CODEX_HOME"
if ! codex plugin marketplace add --help > /dev/null 2>&1; then
    echo 'SKIP: native Codex plugin smoke test requires a Codex CLI with plugin marketplace support'
    exit 0
fi
mkdir -p "$CODEX_HOME/oss-helper/rules/example" "$HOME/.agents/skills/oss-issues" "$HOME/.claude/skills/user-skill"
printf '%s\n' '---' 'name: oss-issues' 'description: Manual user skill' '---' 'Manual fixture' > "$HOME/.agents/skills/oss-issues/SKILL.md"
printf 'manual rule\n' > "$CODEX_HOME/oss-helper/rules/example/project-info.md"
printf 'other agent\n' > "$HOME/.claude/skills/user-skill/SKILL.md"
cp -R "$HOME/.agents" "$test_root/manual-before"
codex plugin marketplace add "$repo_root" --json > "$test_root/marketplace.json"
codex plugin add oss-helper@ai-agents-oss-helper --json > "$test_root/install.json"
codex plugin list --marketplace ai-agents-oss-helper --json > "$test_root/list.json"
python3 - "$CODEX_HOME" "$test_root" <<'PY'
import json, pathlib, sys
codex_home, output = map(pathlib.Path, sys.argv[1:])
for filename in ('marketplace.json', 'install.json', 'list.json'):
    json.loads((output / filename).read_text())
assert 'oss-helper' in (output / 'list.json').read_text()
skills = list((codex_home / 'plugins').rglob('SKILL.md'))
expected = {'oss-issues', 'oss-review', 'oss-ci', 'oss-security', 'oss-project', 'oss-qe'}
assert {skill.parent.name for skill in skills} == expected, skills
assert len(skills) == 6, skills
for skill in skills:
    for filename in ('init.md', 'oss-init.sh', '_fragments/_checkpoint.md'):
        assert (skill.parent / filename).is_file(), (skill, filename)
(output / 'cached-skills.txt').write_text('\n'.join(str(skill) for skill in skills))
PY
# Ask the local app server to discover skills; never start a thread or model request.
python3 - "$test_root" <<'PYDISCOVERY'
import json, pathlib, subprocess, sys, threading
workspace = pathlib.Path(sys.argv[1]) / 'workspace'
workspace.mkdir()
with (workspace / 'app-server.stderr').open('w') as stderr:
    process = subprocess.Popen(['codex', 'app-server', '--stdio'], cwd=workspace, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr, text=True)
    timer = threading.Timer(20, process.kill)
    timer.start()
    try:
        def request(identifier, method, params):
            process.stdin.write(json.dumps({'id': identifier, 'method': method, 'params': params}) + '\n')
            process.stdin.flush()
            for line in process.stdout:
                message = json.loads(line)
                if message.get('id') == identifier:
                    assert 'error' not in message, message
                    return message['result']
            raise AssertionError('app-server closed before responding')
        request(1, 'initialize', {'clientInfo': {'name': 'oss-helper-test', 'version': '1.0.0'}, 'capabilities': {'explicitGatewayOauth': True}})
        process.stdin.write('{"method":"initialized","params":{}}\n')
        process.stdin.flush()
        result = request(2, 'skills/list', {'cwds': [str(workspace)], 'forceReload': True})
        skills = [skill for entry in result['data'] for skill in entry['skills'] if skill.get('pluginId') == 'oss-helper@ai-agents-oss-helper']
        expected = {'oss-helper:' + name for name in ('oss-issues', 'oss-review', 'oss-ci', 'oss-security', 'oss-project', 'oss-qe')}
        assert {skill['name'] for skill in skills} == expected, result
        assert all(skill['enabled'] for skill in skills), skills
        assert all(not entry['errors'] for entry in result['data']), result
    finally:
        timer.cancel()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
PYDISCOVERY
codex plugin remove oss-helper@ai-agents-oss-helper --json > "$test_root/remove.json"
python3 - "$test_root" <<'PY'
import json, pathlib, sys
output = pathlib.Path(sys.argv[1])
json.loads((output / 'remove.json').read_text())
for filename in (output / 'cached-skills.txt').read_text().splitlines():
    assert not pathlib.Path(filename).exists(), filename
PY
diff -r "$test_root/manual-before" "$HOME/.agents"
[[ "$(cat "$CODEX_HOME/oss-helper/rules/example/project-info.md")" == 'manual rule' ]]
[[ "$(cat "$HOME/.claude/skills/user-skill/SKILL.md")" == 'other agent' ]]
echo 'PASS: native Codex marketplace add/install/list/discover/remove, six cached skills and preserved manual assets'
