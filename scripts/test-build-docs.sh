#!/usr/bin/env bash
# Verify the docs generator runs and produces the expected site.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() { echo "FAIL: $1" >&2; exit 1; }

rm -rf site
node scripts/build-docs.mjs

[[ -f site/index.html ]] || fail "site/index.html not created"
[[ -f site/.nojekyll ]] || fail "site/.nojekyll not created"

# Every command in the install.sh registry must appear on the page.
missing=0
while IFS='|' read -r _skill _file command _desc; do
    grep -q "/${command}<" site/index.html || { echo "missing command: /${command}" >&2; missing=1; }
done < <(grep -oE '"oss-[a-z0-9-]+\|[^|]+\|oss-[a-z0-9-]+\|[^"]+"' install.sh | tr -d '"')
[[ "$missing" -eq 0 ]] || fail "one or more registry commands are missing from the site"

# The workflow must be documented.
grep -q "oss-security-case" site/index.html || fail "workflow oss-security-case missing from the site"

# Usage examples (from docs/reference.json) must render.
grep -q 'class="usage"' site/index.html || fail "no usage blocks rendered"
grep -q '/oss-backport-pr 138 branch=1.x' site/index.html || fail "expected command usage example missing"

# No generation artefacts leaked into the output.
! grep -qE 'undefined|\[object Object\]|\$\{' site/index.html || fail "generation artefact leaked into the site"

echo "PASS: docs site generated ($(grep -c 'class="cmd"' site/index.html) command cards)"
