#!/usr/bin/env bash
# security-case-probe.sh: the read-only probe of the oss-security-case loader (security-case.md).
#
#   bash security-case-probe.sh <case> [repo-path]
#
# Prints, in "=== section" blocks, what the loader otherwise collects one command at a time: the clone
# (root, remotes, default branch, shallow flag), the operator (gh login, git identity, the upstream and
# push remotes), the project's rule files, the environment variables the workflow reads and the directories
# they resolve to, the operator preferences, and the case directory with its JSON files (the node files as a
# digest of the fields the workflow reads, when python3 is available). Every command is
# guarded: a failure prints an ERROR marker and the probe goes on, so the exit code is 0 whenever the
# arguments are valid. Nothing is written. Secrets are reported as set or unset, never printed. The report
# itself is not printed either; only its size is.
#
# Manual mode (security-case.md, step 4) can run it too, to see what the workflow would read.
set -u

case_slug="${1:-}"
repo_arg="${2:-.}"
if [ -z "$case_slug" ]; then
    echo "usage: security-case-probe.sh <case> [repo-path]" >&2
    exit 2
fi

section() { printf '\n=== %s\n' "$1"; }

# show <label> <command...>: "label: output", or "label: ERROR <first lines>" when the command fails.
show() {
    local label="$1"
    shift
    local out
    if out="$("$@" 2>&1)"; then
        printf '%s: %s\n' "$label" "${out:-<empty>}"
    else
        printf '%s: ERROR %s\n' "$label" "$(printf '%s' "$out" | head -3 | tr '\n' ' ')"
    fi
}

# dump <path>: the file between markers, or a MISSING line.
dump() {
    if [ -f "$1" ]; then
        printf -- '--- file %s (%s bytes)\n' "$1" "$(wc -c < "$1" | tr -d ' ')"
        cat "$1"
        printf '\n--- end %s\n' "$1"
    else
        printf -- '--- file %s: MISSING\n' "$1"
    fi
}

# slug_of <git url>: org/repo from an https, ssh or scp-style remote URL.
slug_of() {
    printf '%s' "$1" | sed -E 's#^(https?://[^/]+/|ssh://[^/]+/|[^@/]+@[^:]+:)##; s#\.git$##; s#/$##'
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# digest_nodes <case dir>: every nodes/*.json reduced to the fields the workflow script reads, as one JSON
# object keyed by node name. The loader returns it as the case's nodes; the full records stay in nodes/ for
# the nodes that need them. The missed facts of the challenge lenses are kept until the verdict is ruled.
digest_nodes() {
    python3 - "$1" <<'PY'
import glob, json, os, sys

case_dir = sys.argv[1]
common = ['status', 'error', 'blockedReason', 'at']
keep = {
    'triage': ['recommendedVerdict', 'confidence', 'cwe', 'cvssVector', 'cvssScore', 'suggestedCveTitle', 'affected',
               'fixVersionsByLine', 'credit', 'duplicateOf', 'neverCite', 'denyTerms', 'guideNoteLikely', 'worktree', 'files'],
    'challengeScope': ['agree', 'proposedVerdict', 'reasons', 'missedFacts', 'lens'],
    'challengeCode': ['agree', 'proposedVerdict', 'reasons', 'missedFacts', 'lens'],
    'draftReply': ['forVerdict', 'file', 'alreadyReplied'],
    'draftCve': ['file'],
    'draftIssue': ['forVerdict', 'title', 'payloadFile', 'scriptFile', 'lintHard', 'lintSoft', 'missingVersions'],
    'issue': ['key', 'url'],
    'reply': ['forVerdict', 'forCve', 'forIssue', 'file', 'alreadyReplied'],
    'fix': ['worktree', 'branch', 'commits', 'build', 'guideNote', 'guideFile', 'lintHard', 'lintSoft', 'prBodyFile', 'prScript', 'pr', 'url'],
    'docSync': ['worktree', 'branch', 'commit', 'files', 'prBodyFile', 'pr', 'url'],
    'cveDraft': ['forCve', 'files', 'archived', 'checklistFile'],
}
backport = ['line', 'localBranch', 'worktree', 'commits', 'straight', 'adaptations', 'fixVersion', 'prBodyFile', 'pr', 'url']
try:
    with open(os.path.join(case_dir, 'decisions.json')) as fh:
        ruled = bool((json.load(fh).get('decisions') or {}).get('verdict'))
except (OSError, ValueError):
    ruled = False
digest = {}
for path in sorted(glob.glob(os.path.join(case_dir, 'nodes', '*.json'))):
    name = os.path.basename(path)[:-len('.json')]
    with open(path) as fh:
        record = json.load(fh)
    fields = backport if name.startswith('backport_') else keep.get(name)
    if fields is None or not isinstance(record, dict):
        digest[name] = record
        continue
    d = {k: record[k] for k in common + fields if k in record}
    if name.startswith('challenge'):
        d['reasons'] = (record.get('reasons') or [])[:1]
        if ruled:
            d.pop('missedFacts', None)
    digest[name] = d
print(json.dumps(digest, indent=1, sort_keys=True))
PY
}

# A git command in the clone when one was found, else in the current directory.
repo_root=""
g() {
    if [ -n "$repo_root" ]; then git -C "$repo_root" "$@"; else git "$@"; fi
}

# remotes: "name url slug" per fetch remote.
remotes() {
    g remote -v 2>/dev/null | awk '$3 == "(fetch)" { print $1 " " $2 }' | while read -r name url; do
        printf '%s %s %s\n' "$name" "$url" "$(slug_of "$url")"
    done
}

# remote_for <org/repo>: the name of the remote whose URL points at that repository.
remote_for() {
    local want
    want="$(lower "$1")"
    remotes | while read -r name url slug; do
        if [ "$(lower "$slug")" = "$want" ]; then
            echo "$name"
        fi
    done | head -1
}

section "probe"
echo "case: $case_slug"
echo "today: $(date -u +%F)"
echo "note: read-only; ERROR marks a command that failed, so resolve that value yourself"

section "clone"
repo_root="$(git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
    echo "repoRoot: ERROR $repo_arg is not inside a git repository"
else
    echo "repoRoot: $repo_root"
    echo "repoBase: $(basename "$repo_root")"
    show "shallow" git -C "$repo_root" rev-parse --is-shallow-repository
    show "currentBranch" git -C "$repo_root" rev-parse --abbrev-ref HEAD
    echo "remotes (name url org/repo):"
    remotes | sed 's/^/  /'
fi

section "operator"
login="$(gh api /user --jq .login 2>/dev/null || true)"
echo "login: ${login:-ERROR gh api /user failed (gh not installed, or not logged in)}"
show "gitName" g config user.name
show "gitEmail" g config user.email

section "rules"
rules_dir=""

# find_rules <rules-root>: the installed rule set whose Remote pattern matches a remote of the clone.
find_rules() {
    local info pattern
    for info in "$1"/*/project-info.md; do
        [ -f "$info" ] || continue
        pattern="$(grep -m1 -E '\*\*Remote pattern:\*\*' "$info" | sed -E 's/.*\*\*Remote pattern:\*\*[[:space:]]*//; s/`//g; s/^ *//; s/ *$//')"
        [ -n "$pattern" ] || continue
        if printf '%s\n' "$slugs" | grep -F -x -i -q -- "$pattern"; then
            rules_dir="$(dirname "$info")"
            echo "source: installed rules $rules_dir (Remote pattern: $pattern)"
            return 0
        fi
    done
    return 1
}

if [ -n "$repo_root" ] && [ -d "$repo_root/.oss-ai-helper-rules" ]; then
    rules_dir="$repo_root/.oss-ai-helper-rules"
    echo "source: project-local $rules_dir"
else
    slugs="$(remotes | awk '{ print $3 }')"
    if [ -n "${OSS_RULES_DIR:-}" ]; then
        rules_roots="$OSS_RULES_DIR"
        find_rules "$OSS_RULES_DIR"
    else
        # Installed rules live in ~/.claude/oss-helper/rules/; ~/.claude/rules/ holds them on installs
        # that install.sh has not migrated yet.
        rules_roots="$HOME/.claude/oss-helper/rules or $HOME/.claude/rules"
        find_rules "$HOME/.claude/oss-helper/rules" || find_rules "$HOME/.claude/rules"
    fi
    if [ -z "$rules_dir" ]; then
        echo "source: NONE (no .oss-ai-helper-rules/ in the clone, and no project-info.md under $rules_roots has a Remote pattern matching a remote)"
    fi
fi
if [ -n "$rules_dir" ]; then
    for f in project-info.md project-standards.md project-guidelines.md project-security.md; do
        dump "$rules_dir/$f"
    done
fi

section "repository"
repo_slug=""
if [ -n "$rules_dir" ] && [ -f "$rules_dir/project-info.md" ]; then
    repo_slug="$(grep -m1 -E '\*\*GitHub repo:\*\*' "$rules_dir/project-info.md" | sed -E 's/.*\*\*GitHub repo:\*\*[[:space:]]*//; s/`//g; s/^ *//; s/ *$//')"
    case "$repo_slug" in
        */*) ;;
        *) repo_slug="" ;;
    esac
    case "$repo_slug" in
        *[[:space:]\(\)]*) repo_slug="" ;;
    esac
fi
if [ -n "$repo_slug" ]; then
    echo "repo: $repo_slug (project-info.md)"
elif [ -n "$repo_root" ]; then
    repo_slug="$(slug_of "$(g remote get-url origin 2>/dev/null || true)")"
    echo "repo: ${repo_slug:-UNKNOWN} (from the origin remote; project-info.md gave none)"
else
    echo "repo: UNKNOWN"
fi
if [ -n "$repo_slug" ]; then
    show "defaultBranch" gh repo view "$repo_slug" --json defaultBranchRef --jq .defaultBranchRef.name
    upstream="$(remote_for "$repo_slug")"
    echo "upstreamRemote: ${upstream:-NONE (no remote points at $repo_slug)}"
    repo_name="${repo_slug##*/}"
    if [ -n "${OSS_PUSH_REMOTE:-}" ]; then
        echo "pushRemote: $OSS_PUSH_REMOTE (OSS_PUSH_REMOTE)"
    elif [ -n "$login" ]; then
        push="$(remote_for "$login/$repo_name")"
        echo "pushRemote: ${push:-NONE (no remote points at $login/$repo_name)}"
    else
        echo "pushRemote: UNKNOWN (no gh login to match a fork remote against)"
    fi
fi

section "environment"
for v in OSS_SECURITY_CASES_DIR OSS_WORKTREE_ROOT OSS_PUSH_REMOTE OSS_SECURITY_CASE_PREFS OSS_SECURITY_NOTES_DIR OSS_CVE_RECORDS_DIR OSS_JIRA_USER OSS_CVE_BACKUP_REPO OSS_RULES_DIR; do
    echo "$v: ${!v:-<unset>}"
done
if [ -n "${JIRA_TOKEN:-}" ]; then echo "JIRA_TOKEN: set"; else echo "JIRA_TOKEN: unset"; fi
cases_root="${OSS_SECURITY_CASES_DIR:-$HOME/.oss-helper/security-cases}"
case_dir="$cases_root/$case_slug"
if [ -n "${OSS_WORKTREE_ROOT:-}" ]; then
    worktree_root="$OSS_WORKTREE_ROOT"
elif [ -n "$repo_root" ]; then
    worktree_root="$(dirname "$repo_root")"
else
    worktree_root=""
fi
prefs_file="${OSS_SECURITY_CASE_PREFS:-$HOME/.config/oss-helper/security-case.md}"
echo "casesRoot: $cases_root"
if [ -d "$case_dir" ]; then echo "caseDir: $case_dir (exists)"; else echo "caseDir: $case_dir (does not exist yet)"; fi
echo "worktreeRoot: ${worktree_root:-UNKNOWN}"
if [ -f "$prefs_file" ]; then echo "prefsFile: $prefs_file (exists)"; else echo "prefsFile: $prefs_file (missing)"; fi
if [ -n "${OSS_SECURITY_NOTES_DIR:-}" ]; then
    if [ -d "$OSS_SECURITY_NOTES_DIR" ]; then echo "notesDir: $OSS_SECURITY_NOTES_DIR (exists)"; else echo "notesDir: $OSS_SECURITY_NOTES_DIR (MISSING directory)"; fi
else
    echo "notesDir: <unset>"
fi
echo "cveRecordsDir: ${OSS_CVE_RECORDS_DIR:-<unset>}"
echo "skillsRoot: $HOME/.claude/skills"

section "preferences"
dump "$prefs_file"

section "case"
if [ -d "$case_dir" ]; then
    echo "listing:"
    ls -la "$case_dir" "$case_dir/nodes" "$case_dir/cve" 2>&1 | sed 's/^/  /'
    if [ -f "$case_dir/report.txt" ]; then
        echo "report.txt: present, $(wc -c < "$case_dir/report.txt" | tr -d ' ') bytes (not printed: embargoed material)"
    else
        echo "report.txt: MISSING"
    fi
    if [ -f "$case_dir/report-threads.txt" ]; then
        echo "report-threads.txt: present, $(wc -c < "$case_dir/report-threads.txt" | tr -d ' ') bytes (not printed)"
    fi
    dump "$case_dir/report-meta.json"
    dump "$case_dir/decisions.json"
    if command -v python3 >/dev/null 2>&1 && digest="$(digest_nodes "$case_dir" 2>&1)"; then
        echo "--- nodes digest (the fields the workflow reads; the full records are in $case_dir/nodes/)"
        printf '%s\n' "$digest"
        echo "--- end nodes digest"
    else
        [ -n "${digest:-}" ] && echo "nodes digest: ERROR $(printf '%s' "$digest" | tail -1)"
        for f in "$case_dir"/nodes/*.json; do
            if [ -f "$f" ]; then dump "$f"; fi
        done
    fi
    if [ -f "$case_dir/STATUS.md" ]; then echo "STATUS.md: present ($(wc -c < "$case_dir/STATUS.md" | tr -d ' ') bytes)"; fi
else
    echo "the case directory does not exist yet: the loader creates it"
fi

section "end"
exit 0
