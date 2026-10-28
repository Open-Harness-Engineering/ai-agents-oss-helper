#!/usr/bin/env bash
# Exercise the helper scripts (oss-init.sh, pr-report.sh, skip-list.sh) as installed, without
# touching the user's installation or network: a stand-in gh on PATH answers from fixtures.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
test_home="$test_root/home"
fixtures="$test_root/fixtures"
mkdir -p "$test_root/bin" "$fixtures/raw"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

# expect <file> <fixed string>: the output must contain the line fragment.
expect() {
    grep -Fq -- "$2" "$1" || { echo "--- $1:" >&2; cat "$1" >&2; fail "missing: $2"; }
}

command -v jq > /dev/null || fail "jq is required by pr-report.sh"

cat > "$test_root/bin/gh" <<'EOF'
#!/usr/bin/env bash
# A stand-in for gh that answers the calls of the helper scripts from $FAKE_GH_DIR.
echo "$*" >> "$FAKE_GH_DIR/calls.log"
case "$1 ${2:-}" in
    "api -H")
        f="$FAKE_GH_DIR/raw/$(printf '%s' "$4" | tr '/' '_')"
        if [ -f "$f" ]; then cat "$f"; exit 0; fi
        echo '{"message":"Not Found"}'
        echo 'gh: Not Found (HTTP 404)' >&2
        exit 1
        ;;
    "pr list")
        n="$(cat "$FAKE_GH_DIR/pr-list-count" 2> /dev/null || echo 0)"
        n=$((n + 1))
        echo "$n" > "$FAKE_GH_DIR/pr-list-count"
        case " $* " in *" --author @me "*) fixture=mine ;; *) fixture=list ;; esac
        if [ -f "$FAKE_GH_DIR/$fixture-$n.json" ]; then cat "$FAKE_GH_DIR/$fixture-$n.json"; else cat "$FAKE_GH_DIR/$fixture.json"; fi
        ;;
    "pr view") cat "$FAKE_GH_DIR/status.json" ;;
    "repo view") echo "example/current" ;;
    *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$test_root/bin/gh"
export FAKE_GH_DIR="$fixtures"
export PATH="$test_root/bin:$PATH"

HOME="$test_home" bash "$repo_root/install.sh" claude > "$test_root/install-claude.log"
HOME="$test_home" bash "$repo_root/install.sh" bob > "$test_root/install-bob.log"
HOME="$test_home" bash "$repo_root/install.sh" codex > "$test_root/install-codex.log"

# The scripts ship with their skills, for every agent that installs skill directories.
for skills in "$test_home/.claude/skills" "$test_home/.bob/skills" "$test_home/.agents/skills"; do
    for skill in oss-issues oss-review oss-ci oss-security oss-project oss-qe; do
        cmp "$repo_root/skills/_shared/oss-init.sh" "$skills/$skill/oss-init.sh"
    done
    cmp "$repo_root/skills/oss-review/pr-report.sh" "$skills/oss-review/pr-report.sh"
    cmp "$repo_root/skills/oss-security/skip-list.sh" "$skills/oss-security/skip-list.sh"
    cmp "$repo_root/skills/oss-security/skip_cves_apache_unmappable.txt" "$skills/oss-security/skip_cves_apache_unmappable.txt"
done
for script in "$repo_root/skills/_shared/oss-init.sh" "$repo_root/skills/oss-review/pr-report.sh" "$repo_root/skills/oss-security/skip-list.sh"; do
    bash -n "$script"
done

# --- oss-init.sh -------------------------------------------------------------------------------

# make_rules <dir> <remote pattern> <github repo> [version]
make_rules() {
    mkdir -p "$1"
    {
        printf '# Project Information\n\n- **Remote pattern:** `%s`\n- **GitHub repo:** `%s`\n' "$2" "$3"
        if [ -n "${4:-}" ]; then printf '\n## Version\n\n%s\n' "$4"; fi
    } > "$1/project-info.md"
    printf '# Project Standards\n\n- **Build tool:** none\n' > "$1/project-standards.md"
    printf '# Project Guidelines\n' > "$1/project-guidelines.md"
}

# clone <name> <remote url>: an empty repository with one remote.
clone() {
    git init -q "$test_root/$1"
    git -C "$test_root/$1" remote add origin "$2"
}

init_claude="$test_home/.claude/skills/oss-issues/oss-init.sh"

# Project-local rules, and the version check against the project's repository.
clone local-rules git@github.com:example/with-rules.git
make_rules "$test_root/local-rules/.oss-ai-helper-rules" "example/with-rules" "example/with-rules" "local-sha"
printf '# Project Information\n\n## Version\n\nremote-sha\n' > "$fixtures/raw/repos_example_with-rules_contents_.oss-ai-helper-rules_project-info.md"
HOME="$test_home" bash "$init_claude" "$test_root/local-rules" > "$test_root/init-local.out"
expect "$test_root/init-local.out" "source: project-local $test_root/local-rules/.oss-ai-helper-rules"
expect "$test_root/init-local.out" "- **Build tool:** none"
expect "$test_root/init-local.out" "project-security.md: not present (optional)"
expect "$test_root/init-local.out" "local: local-sha"
expect "$test_root/init-local.out" "remote: remote-sha (example/with-rules)"
expect "$test_root/init-local.out" "status: update-available"
expect "$test_root/init-local.out" "=== end"
printf '## Version\n\nlocal-sha\n' > "$fixtures/raw/repos_example_with-rules_contents_.oss-ai-helper-rules_project-info.md"
HOME="$test_home" bash "$init_claude" "$test_root/local-rules" > "$test_root/init-same.out"
expect "$test_root/init-same.out" "status: up-to-date"

# Installed rules, matched through any remote; the project ships no rules of its own (404).
clone installed https://github.com/fork-owner/installed.git
git -C "$test_root/installed" remote add upstream https://github.com/Example/Installed.git
make_rules "$test_home/.claude/oss-helper/rules/installed" "example/installed" "example/installed" "v1"
HOME="$test_home" bash "$init_claude" "$test_root/installed" > "$test_root/init-installed.out"
expect "$test_root/init-installed.out" "source: installed $test_home/.claude/oss-helper/rules/installed (Remote pattern: example/installed)"
expect "$test_root/init-installed.out" "remote: none (example/installed has no .oss-ai-helper-rules/project-info.md)"
expect "$test_root/init-installed.out" "status: skipped"

# Rules not yet moved out of ~/.claude/rules are still found.
clone legacy https://github.com/example/legacy.git
make_rules "$test_home/.claude/rules/legacy" "example/legacy" "example/legacy"
HOME="$test_home" bash "$init_claude" "$test_root/legacy" > "$test_root/init-legacy.out"
expect "$test_root/init-legacy.out" "source: installed $test_home/.claude/rules/legacy"
expect "$test_root/init-legacy.out" "local: unknown (no ## Version section)"

# Codex reads its own rules directory, not Claude's.
clone codex https://github.com/example/codex.git
make_rules "$test_home/.claude/oss-helper/rules/codex-in-claude" "example/codex" "example/codex"
make_rules "$test_home/.codex/oss-helper/rules/codex" "example/codex" "example/codex"
HOME="$test_home" bash "$test_home/.agents/skills/oss-review/oss-init.sh" "$test_root/codex" > "$test_root/init-codex.out"
expect "$test_root/init-codex.out" "source: installed $test_home/.codex/oss-helper/rules/codex"

# OSS_RULES_DIR overrides the search; no match and no repository are reported, not fatal.
make_rules "$test_root/custom-rules/codex" "example/codex" "example/codex"
OSS_RULES_DIR="$test_root/custom-rules" HOME="$test_home" bash "$init_claude" "$test_root/codex" > "$test_root/init-custom.out"
expect "$test_root/init-custom.out" "source: installed $test_root/custom-rules/codex"
clone nothing https://github.com/example/nothing.git
HOME="$test_home" bash "$init_claude" "$test_root/nothing" > "$test_root/init-none.out"
expect "$test_root/init-none.out" "source: NONE"
expect "$test_root/init-none.out" "status: skipped (no rules loaded)"
mkdir -p "$test_root/not-a-repo"
HOME="$test_home" bash "$init_claude" "$test_root/not-a-repo" > "$test_root/init-norepo.out"
expect "$test_root/init-norepo.out" "repoRoot: NONE"

# --- pr-report.sh ------------------------------------------------------------------------------

report="$test_home/.claude/skills/oss-review/pr-report.sh"

cat > "$fixtures/mine.json" <<'EOF'
[
  {"number": 10, "title": "All green", "headRefName": "green", "baseRefName": "main", "isDraft": false,
   "updatedAt": "2026-10-20T10:00:00Z", "reviewDecision": "APPROVED", "mergeable": "MERGEABLE",
   "statusCheckRollup": [
     {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "COMPLETED", "conclusion": "SUCCESS", "startedAt": "2026-10-20T09:00:00Z"},
     {"__typename": "CheckRun", "name": "sonar", "workflowName": "CI", "status": "COMPLETED", "conclusion": "SKIPPED", "startedAt": "2026-10-20T09:00:00Z"}]},
  {"number": 11, "title": "Lint fails", "headRefName": "lint", "baseRefName": "main", "isDraft": false,
   "updatedAt": "2026-10-20T10:00:00Z", "reviewDecision": null, "mergeable": "MERGEABLE",
   "statusCheckRollup": [
     {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "COMPLETED", "conclusion": "SUCCESS", "startedAt": "2026-10-20T09:00:00Z"},
     {"__typename": "StatusContext", "context": "lint", "state": "FAILURE", "targetUrl": "https://ci.example/lint"}]},
  {"number": 12, "title": "Still running", "headRefName": "running", "baseRefName": "main", "isDraft": false,
   "updatedAt": "2026-10-20T10:00:00Z", "reviewDecision": "CHANGES_REQUESTED", "mergeable": "CONFLICTING",
   "statusCheckRollup": [
     {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "IN_PROGRESS", "conclusion": "", "startedAt": "2026-10-20T09:00:00Z"}]},
  {"number": 13, "title": "Pipes | in a title", "headRefName": "draft", "baseRefName": "main", "isDraft": true,
   "updatedAt": "2026-10-20T10:00:00Z", "reviewDecision": "REVIEW_REQUIRED", "mergeable": "UNKNOWN",
   "statusCheckRollup": []},
  {"number": 14, "title": "Green after a re-run", "headRefName": "rerun", "baseRefName": "main", "isDraft": false,
   "updatedAt": "2026-10-20T10:00:00Z", "reviewDecision": null, "mergeable": "MERGEABLE",
   "statusCheckRollup": [
     {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "COMPLETED", "conclusion": "FAILURE", "startedAt": "2026-10-20T08:00:00Z"},
     {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "COMPLETED", "conclusion": "SUCCESS", "startedAt": "2026-10-20T09:00:00Z"}]}
]
EOF
bash "$report" mine --repo example/repo > "$test_root/mine.out"
expect "$test_root/mine.out" "## Your Open PRs in example/repo"
expect "$test_root/mine.out" "| #10 | All green | green -> main | passing | approved | no | 2026-10-20 |"
expect "$test_root/mine.out" "| #11 | Lint fails | lint -> main | failing | none | no | 2026-10-20 |"
expect "$test_root/mine.out" "| #12 | Still running | running -> main | pending | changes requested | no | 2026-10-20 |"
expect "$test_root/mine.out" '| #13 | Pipes \| in a title | draft -> main | none | review required | yes | 2026-10-20 |'
expect "$test_root/mine.out" "| #14 | Green after a re-run | rerun -> main | passing | none | no | 2026-10-20 |"
expect "$test_root/mine.out" "**Total:** 5 open PR(s)"
expect "$test_root/mine.out" "**Failing CI:**"
expect "$test_root/mine.out" "- #11 - Lint fails"
expect "$test_root/mine.out" "- #12 - Still running (rebase onto main)"
[ "$(head -5 "$test_root/mine.out" | grep -c '^| #14 ')" -eq 1 ] || fail "mine does not list the newest PR first"

cat > "$fixtures/list.json" <<'EOF'
[
  {"number": 21, "title": "Add a feature", "author": {"login": "alice"}, "headRefName": "feature", "baseRefName": "main",
   "isDraft": false, "updatedAt": "2026-10-19T08:00:00Z", "reviewDecision": "REVIEW_REQUIRED"},
  {"number": 20, "title": "A very long title that keeps going well beyond the seventy characters the table allows", "author": {"login": "bob"},
   "headRefName": "long", "baseRefName": "main", "isDraft": false, "updatedAt": "2026-10-18T08:00:00Z", "reviewDecision": null}
]
EOF
bash "$report" list --repo example/repo --label bug --limit 5 > "$test_root/list.out"
expect "$test_root/list.out" 'Filters: open, non-draft, label="bug"'
expect "$test_root/list.out" "| 1 | #21 | Add a feature | alice | feature -> main | review required | no | 2026-10-19 |"
expect "$test_root/list.out" "| 2 | #20 | A very long title that keeps going well beyond the seventy characters…"
expect "$test_root/list.out" "**Total:** 2 PR(s)"
expect "$fixtures/calls.log" 'pr list --repo example/repo --search is:pr is:open -is:draft label:"bug" --limit 5'

cat > "$fixtures/status.json" <<'EOF'
{"number": 30, "title": "Fix the parser", "state": "OPEN", "isDraft": false, "mergeable": "MERGEABLE", "mergeStateStatus": "BLOCKED",
 "baseRefName": "main", "headRefName": "fix-parser", "author": {"login": "carol"}, "reviewDecision": "REVIEW_REQUIRED",
 "reviewRequests": [{"__typename": "User", "login": "dave"}, {"__typename": "Team", "slug": "maintainers"}],
 "createdAt": "2026-10-18T08:00:00Z", "updatedAt": "2026-10-20T08:00:00Z",
 "statusCheckRollup": [
   {"__typename": "CheckRun", "name": "test", "workflowName": "CI", "status": "COMPLETED", "conclusion": "FAILURE", "startedAt": "2026-10-20T09:00:00Z", "detailsUrl": "https://ci.example/run/1"},
   {"__typename": "CheckRun", "name": "build", "workflowName": "CI", "status": "COMPLETED", "conclusion": "SUCCESS", "startedAt": "2026-10-20T09:00:00Z"}],
 "latestReviews": [{"author": {"login": "erin"}, "state": "CHANGES_REQUESTED", "submittedAt": "2026-10-19T08:00:00Z"}],
 "comments": [
   {"author": {"login": "c1"}, "createdAt": "2026-10-18T08:00:00Z", "body": "first"},
   {"author": {"login": "c2"}, "createdAt": "2026-10-18T09:00:00Z", "body": "second"},
   {"author": {"login": "c3"}, "createdAt": "2026-10-18T10:00:00Z", "body": "third"},
   {"author": {"login": "c4"}, "createdAt": "2026-10-18T11:00:00Z", "body": "fourth"},
   {"author": {"login": "c5"}, "createdAt": "2026-10-18T12:00:00Z", "body": "fifth"},
   {"author": {"login": "c6"}, "createdAt": "2026-10-18T13:00:00Z", "body": "sixth\nwith a second line"}]}
EOF
bash "$report" status https://github.com/example/repo/pull/30 > "$test_root/status.out"
expect "$fixtures/calls.log" "pr view 30 --repo example/repo"
expect "$test_root/status.out" "## PR Status: #30 - Fix the parser"
expect "$test_root/status.out" "- **Mergeable:** yes (merge state: blocked)"
expect "$test_root/status.out" "| CI / test | fail | https://ci.example/run/1 |"
expect "$test_root/status.out" "**Overall:** 1 failing, 1 of 2 passing"
expect "$test_root/status.out" "- erin: changes requested (2026-10-19)"
expect "$test_root/status.out" "- **Requested:** dave, maintainers"
expect "$test_root/status.out" "- [ ] Failing CI checks"
expect "$test_root/status.out" "- c6 (2026-10-18): sixth with a second line"
if grep -Fq -- "- c1 (" "$test_root/status.out"; then fail "status shows more than the last five comments"; fi

# --state: the same report twice is UNCHANGED the second time.
state="$test_root/state/mine.txt"
bash "$report" mine --repo example/repo --state "$state" > "$test_root/state1.out"
expect "$test_root/state1.out" "## Your Open PRs in example/repo"
bash "$report" mine --repo example/repo --state "$state" > "$test_root/state2.out"
expect "$test_root/state2.out" "UNCHANGED since "
[ "$(wc -l < "$test_root/state2.out")" -eq 1 ] || fail "an UNCHANGED run printed more than one line"

# watch: exits as soon as the report changes (the third gh pr list call returns a new PR) ...
rm -f "$fixtures/pr-list-count"
jq '. + [{"number": 15, "title": "New PR", "headRefName": "new", "baseRefName": "main", "isDraft": false,
          "updatedAt": "2026-10-21T10:00:00Z", "reviewDecision": null, "mergeable": "MERGEABLE", "statusCheckRollup": []}]' \
    "$fixtures/mine.json" > "$fixtures/mine-3.json"
bash "$report" watch mine --repo example/repo --interval 1 --max-wait 30 > "$test_root/watch.out"
expect "$test_root/watch.out" "| #15 | New PR |"
[ "$(cat "$fixtures/pr-list-count")" -eq 3 ] || fail "watch made $(cat "$fixtures/pr-list-count") calls, expected 3"
# ... and gives up with UNCHANGED after --max-wait.
rm -f "$fixtures/pr-list-count" "$fixtures/mine-3.json"
bash "$report" watch mine --repo example/repo --interval 1 --max-wait 2 > "$test_root/watch-idle.out"
expect "$test_root/watch-idle.out" "UNCHANGED after 2 seconds"

# Bad arguments exit 2; a gh failure is an ERROR line and exit 1.
set +e
bash "$report" list --limit many > /dev/null 2>&1
[ $? -eq 2 ] || fail "a non-numeric --limit was accepted"
mv "$fixtures/status.json" "$fixtures/status.json.off"
bash "$report" status 30 --repo example/repo > "$test_root/status-error.out" 2>&1
[ $? -eq 1 ] || fail "a jq failure on missing gh output did not exit 1"
set -e
expect "$test_root/status-error.out" "ERROR"

# --- skip-list.sh ------------------------------------------------------------------------------

skip="$test_home/.claude/skills/oss-security/skip-list.sh"
list="$test_root/skip.txt"
printf '# header\nCVE-2020-0001  # dead end\nCVE-2020-0002  # another' > "$list"   # no final newline
printf 'CVE-2020-0001\tGHSA-1\ncve-2020-0002\tGHSA-2\nCVE-2021-0003\tGHSA-3\nno id\n' |
    bash "$skip" filter --list "$list" > "$test_root/filter.out" 2> "$test_root/filter.err"
[ "$(cat "$test_root/filter.out")" = "$(printf 'CVE-2021-0003\tGHSA-3\nno id')" ] || fail "filter kept the wrong rows"
expect "$test_root/filter.err" "2 candidate(s) dropped"
bash "$skip" has CVE-2020-0002 --list "$list" > /dev/null || fail "has missed a listed CVE"
if bash "$skip" has CVE-2021-0003 --list "$list" > /dev/null; then fail "has found an unlisted CVE"; fi
bash "$skip" add cve-2021-0003 "no package" --list "$list" > /dev/null
bash "$skip" add CVE-2021-0003 "twice" --list "$list" > "$test_root/add-again.out"
expect "$test_root/add-again.out" "already listed"
[ "$(tail -2 "$list")" = "$(printf 'CVE-2020-0002  # another\nCVE-2021-0003  # no package')" ] || fail "add did not append on a line of its own"
bash "$skip" filter < /dev/null 2> /dev/null || fail "filter failed on the installed list"

# --- security-case-probe.sh: the digest of the node files -------------------------------------

probe="$test_home/.claude/skills/oss-security/security-case-probe.sh"
cmp "$repo_root/skills/oss-security/security-case-probe.sh" "$probe"
cases="$test_root/cases"
mkdir -p "$cases/demo/nodes"
cat > "$cases/demo/nodes/triage.json" <<'EOF'
{"status": "done", "recommendedVerdict": "VALID", "fixVersionsByLine": {"main": "3.0.0"}, "summary": "LONG TRIAGE SUMMARY", "backportNotes": "LONG BACKPORT NOTES"}
EOF
cat > "$cases/demo/nodes/challengeCode.json" <<'EOF'
{"status": "done", "agree": false, "proposedVerdict": "HARDENING", "reasons": ["first reason", "SECOND REASON"], "missedFacts": ["A MISSED FACT"]}
EOF
cat > "$cases/demo/nodes/backport_release-1.x.json" <<'EOF'
{"status": "local", "line": "release-1.x", "worktree": "/w/bp", "adaptations": ["older test framework"], "fixVersion": "1.9.4", "tests": "LONG TEST REPORT"}
EOF
cat > "$cases/demo/nodes/cveDraft.json" <<'EOF'
{"status": "drafted", "archived": false, "archiveScript": "/cases/demo/cve/archive-cve.sh", "todos": ["LONG TODO LIST"]}
EOF
echo '{}' > "$cases/demo/decisions.json"
OSS_SECURITY_CASES_DIR="$cases" bash "$probe" demo "$test_root" > "$test_root/probe.out" 2>&1
expect "$test_root/probe.out" "--- nodes digest"
expect "$test_root/probe.out" '"recommendedVerdict": "VALID"'
expect "$test_root/probe.out" '"fixVersion": "1.9.4"'
expect "$test_root/probe.out" '"older test framework"'
expect "$test_root/probe.out" '"first reason"'
expect "$test_root/probe.out" "A MISSED FACT"
expect "$test_root/probe.out" '"archiveScript": "/cases/demo/cve/archive-cve.sh"'
if grep -Eq "LONG TRIAGE SUMMARY|LONG BACKPORT NOTES|SECOND REASON|LONG TEST REPORT|LONG TODO LIST" "$test_root/probe.out"; then
    fail "the digest kept a field the workflow does not read"
fi
if grep -Fq -- "--- file $cases/demo/nodes/" "$test_root/probe.out"; then fail "the probe printed the node files besides the digest"; fi
echo '{"decisions": {"verdict": "VALID"}}' > "$cases/demo/decisions.json"
OSS_SECURITY_CASES_DIR="$cases" bash "$probe" demo "$test_root" > "$test_root/probe-ruled.out" 2>&1
if grep -Fq "A MISSED FACT" "$test_root/probe-ruled.out"; then fail "the digest kept the missed facts after the verdict was ruled"; fi
# When the digest cannot be computed, the probe prints the node files themselves.
mkdir -p "$test_root/nopython"
printf '#!/bin/sh\necho "no python here" >&2\nexit 1\n' > "$test_root/nopython/python3"
chmod +x "$test_root/nopython/python3"
PATH="$test_root/nopython:$PATH" OSS_SECURITY_CASES_DIR="$cases" bash "$probe" demo "$test_root" > "$test_root/probe-fallback.out" 2>&1
expect "$test_root/probe-fallback.out" "nodes digest: ERROR"
expect "$test_root/probe-fallback.out" "--- file $cases/demo/nodes/triage.json"
expect "$test_root/probe-fallback.out" "LONG TRIAGE SUMMARY"

echo 'PASS: oss-init.sh, pr-report.sh, skip-list.sh and security-case-probe.sh ship with the skills and behave as the guidelines expect'
