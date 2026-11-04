#!/usr/bin/env bash
# Check portable native metadata and versioning in a private source fixture.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT
fixture="$test_root/source"
mkdir -p "$fixture"
for item in build.sh skills agents commands workflows packaging LICENSE .claude-plugin .agents bob-extension.json BOB.md; do
    cp -R "$repo_root/$item" "$fixture/$item"
done
HOME="$test_root/home" bash "$fixture/build.sh" claude > "$test_root/build.log"
HOME="$test_root/home" bash "$fixture/build.sh" --output-dir "$test_root/repeat" claude >> "$test_root/build.log"
diff -r "$fixture/plugin" "$test_root/repeat"
HOME="$test_root/home" bash "$fixture/build.sh" gemini >> "$test_root/build.log"
HOME="$test_root/home" bash "$fixture/build.sh" --output-dir "$test_root/repeat-gemini" gemini >> "$test_root/build.log"
diff -r "$fixture/build/gemini" "$test_root/repeat-gemini"

python3 - "$fixture" "$test_root/version-before" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
plugin = root / 'plugin'
skills = {'oss-issues', 'oss-review', 'oss-ci', 'oss-security', 'oss-project', 'oss-qe'}
versions = []
for filename in ('plugin.json', 'bob-extension.json'):
    manifest = json.loads((plugin / filename).read_text())
    assert manifest['name'] == 'oss-helper', filename
    version = manifest['version']
    assert re.fullmatch(r'0\.0\.0-dev\.sha[0-9a-f]{64}', version), (filename, version)
    versions.append(version)
assert len(set(versions)) == 1, versions
assert not (plugin / 'gemini-extension.json').exists()
gemini = root / 'build/gemini'
extension = json.loads((gemini / 'gemini-extension.json').read_text())
assert extension['name'] == 'oss-helper'
assert re.fullmatch(r'0\.0\.0-dev\.sha[0-9a-f]{64}', extension['version'])
assert extension['version'] != versions[0], 'each native target hashes its own converted output'
assert (gemini / extension['contextFileName']).is_file()
assert extension['contextFileName'] == 'GEMINI.md'
assert not (gemini / '.claude-plugin').exists()
assert {p.parent.name for p in (gemini / 'skills').glob('*/SKILL.md')} == skills
for agent in (gemini / 'agents').glob('*.md'):
    frontmatter = agent.read_text().split('---', 2)[1]
    fields = set(re.findall(r'^([a-zA-Z][a-zA-Z-]*):', frontmatter, re.M))
    assert fields == {'name', 'description'}, (agent, fields)
pathlib.Path(sys.argv[2]).write_text(versions[0])
assert 'version' not in json.loads((plugin / '.claude-plugin/plugin.json').read_text())
assert not (plugin / 'commands/_fragments').exists()
assert {p.parent.name for p in (plugin / 'skills').glob('*/SKILL.md')} == skills
for name in skills:
    source = (root / 'skills' / name / 'SKILL.md').read_text()
    assert re.search(rf'^name:\s*[\'"]?{re.escape(name)}[\'"]?\s*$', source, re.M), name
    for bundle in (plugin, gemini):
        assert (bundle / 'skills' / name / 'SKILL.md').read_bytes() == (root / 'skills' / name / 'SKILL.md').read_bytes()
        assert (bundle / 'skills' / name / 'init.md').read_bytes() == (root / 'skills/_shared/init.md').read_bytes()
        assert (bundle / 'skills' / name / 'oss-init.sh').read_bytes() == (root / 'skills/_shared/oss-init.sh').read_bytes()
        assert (bundle / 'skills' / name / '_fragments/_checkpoint.md').is_file()
# Bob reads root context when installing the repository, and bundled context in a plugin cache.
for base, filename in ((root, 'bob-extension.json'), (plugin, 'bob-extension.json'), (gemini, 'gemini-extension.json')):
    manifest = json.loads((base / filename).read_text())
    if base != gemini:
        assert manifest['version'] == versions[0], base
    assert manifest['name'] == 'oss-helper'
    context = base / manifest['contextFileName']
    assert context.is_file(), context
    targets = []
    for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', context.read_text()):
        if re.match(r'https?://', link):
            continue
        target = (context.parent / link.strip('<>').split('#')[0]).resolve()
        assert target.is_relative_to(base.resolve()), (context, link)
        assert target.is_file(), (context, link)
        targets.append(target)
    assert {target.parent.name for target in targets if target.name == 'SKILL.md'} == skills, context
catalog = json.loads((root / '.agents/plugins/marketplace.json').read_text())
assert catalog['name'] == 'ai-agents-oss-helper'
entry = next(entry for entry in catalog['plugins'] if entry['name'] == 'oss-helper')
assert entry['source'] == {'source': 'local', 'path': './plugin'}
assert entry['policy'] == {'installation': 'AVAILABLE', 'authentication': 'ON_INSTALL'}
assert entry['category'] == 'Developer Tools'
# Native clients discover the default skills/ directory without manifest path overrides.
assert (plugin / 'skills').is_dir()
PY

# Identical inputs keep the version; source and template edits both invalidate caches.
printf '\n<!-- Native packaging version fixture -->\n' >> "$fixture/skills/oss-issues/SKILL.md"
HOME="$test_root/home" bash "$fixture/build.sh" claude >> "$test_root/build.log"
python3 - "$fixture/plugin/plugin.json" "$test_root/version-before" "$test_root/version-source" <<'PY'
import json, pathlib, sys
version = json.loads(pathlib.Path(sys.argv[1]).read_text())['version']
assert version != pathlib.Path(sys.argv[2]).read_text()
pathlib.Path(sys.argv[3]).write_text(version)
PY
printf '\n' >> "$fixture/packaging/gemini-extension.json"
HOME="$test_root/home" bash "$fixture/build.sh" claude >> "$test_root/build.log"
python3 - "$fixture/plugin/plugin.json" "$test_root/version-source" <<'PY'
import json, pathlib, sys
assert json.loads(pathlib.Path(sys.argv[1]).read_text())['version'] != pathlib.Path(sys.argv[2]).read_text()
PY
echo 'PASS: native metadata, Bob context links, portable skills and deterministic content versions'
