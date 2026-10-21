#!/usr/bin/env bash
# oss-init.sh: the OSS Helper initialization (init.md, steps 1-3) in one read-only call.
#
#   bash oss-init.sh [repo-path]
#
# Prints, in "=== section" blocks: the repository and its remotes; where the project rules come
# from (the clone's .oss-ai-helper-rules/, an installed rule set whose Remote pattern matches a
# remote, or NONE) followed by the rule files themselves; and the version check against the
# project's GitHub repository. Nothing is written and nothing is asked: init.md says what to do
# when the rules are missing or an update is available. A failing command prints an ERROR marker
# and the script goes on, so the exit code is 0 whenever the arguments are valid.
#
# Installed rules are searched in $OSS_RULES_DIR when it is set, else in the directories of the
# agent this copy was installed for, the current location first:
#   ~/.claude/skills/<skill>/oss-init.sh  ->  ~/.claude/oss-helper/rules, ~/.claude/rules
#   ~/.bob/skills/<skill>/oss-init.sh     ->  ~/.bob/oss-helper/rules, ~/.bob/rules
#   ~/.agents/skills/<skill>/oss-init.sh  ->  ~/.codex/oss-helper/rules
set -u

repo_arg="${1:-.}"

section() { printf '\n=== %s\n' "$1"; }

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

# field <file> <name>: the value of a "- **<name>:** value" line, without backticks.
field() {
    grep -m1 -E "\*\*$2:\*\*" "$1" 2>/dev/null | sed -E "s/.*\*\*$2:\*\*[[:space:]]*//; s/\`//g; s/^ *//; s/ *$//"
}

# version_of: the first non-empty line after "## Version" on stdin.
version_of() {
    awk '/^## Version/ { v = 1; next } v && NF { print $1; exit }'
}

# rules_roots: the installed-rules directories to search, one per line.
rules_roots() {
    if [ -n "${OSS_RULES_DIR:-}" ]; then
        printf '%s\n' "$OSS_RULES_DIR"
        return
    fi
    local script_dir agent_home
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    agent_home="$(dirname "$(dirname "$script_dir")")"
    case "$agent_home" in
        */.agents) printf '%s\n' "$HOME/.codex/oss-helper/rules" ;;
        */.claude | */.bob) printf '%s\n%s\n' "$agent_home/oss-helper/rules" "$agent_home/rules" ;;
        *) printf '%s\n%s\n' "$HOME/.claude/oss-helper/rules" "$HOME/.claude/rules" ;;
    esac
}

section "project"
repo_root="$(git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null || true)"
slugs=""
if [ -z "$repo_root" ]; then
    echo "repoRoot: NONE ($repo_arg is not inside a git repository)"
else
    echo "repoRoot: $repo_root"
    echo "remotes (name url org/repo):"
    remote_lines="$(git -C "$repo_root" remote -v 2>/dev/null | awk '$3 == "(fetch)" { print $1 " " $2 }')"
    if [ -z "$remote_lines" ]; then
        echo "  NONE"
    fi
    while read -r name url; do
        [ -n "$name" ] || continue
        slug="$(slug_of "$url")"
        echo "  $name $url $slug"
        slugs="$slugs$slug
"
    done <<EOF
$remote_lines
EOF
fi

section "rules"
rules_dir=""
searched=""
if [ -n "$repo_root" ] && [ -d "$repo_root/.oss-ai-helper-rules" ]; then
    rules_dir="$repo_root/.oss-ai-helper-rules"
    echo "source: project-local $rules_dir"
else
    while read -r root; do
        [ -n "$root" ] || continue
        searched="$searched $root"
        for info in "$root"/*/project-info.md; do
            [ -f "$info" ] || continue
            pattern="$(field "$info" "Remote pattern")"
            [ -n "$pattern" ] || continue
            if printf '%s' "$slugs" | grep -F -x -i -q -- "$pattern"; then
                rules_dir="$(dirname "$info")"
                echo "source: installed $rules_dir (Remote pattern: $pattern)"
                break 2
            fi
        done
    done <<EOF
$(rules_roots)
EOF
    if [ -z "$rules_dir" ]; then
        echo "source: NONE (no .oss-ai-helper-rules/ in the clone; no Remote pattern matched a remote under:$searched)"
    fi
fi
if [ -n "$rules_dir" ]; then
    for f in project-info.md project-standards.md project-guidelines.md; do
        dump "$rules_dir/$f"
    done
    if [ -f "$rules_dir/project-security.md" ]; then
        dump "$rules_dir/project-security.md"
    else
        echo "project-security.md: not present (optional)"
    fi
fi

section "version"
if [ -z "$rules_dir" ] || [ ! -f "$rules_dir/project-info.md" ]; then
    echo "status: skipped (no rules loaded)"
else
    local_version="$(version_of < "$rules_dir/project-info.md")"
    echo "local: ${local_version:-unknown (no ## Version section)}"
    repo="$(field "$rules_dir/project-info.md" "GitHub repo")"
    case "$repo" in
        */*) case "$repo" in *[[:space:]\(\)]*) repo="" ;; esac ;;
        *) repo="" ;;
    esac
    if [ -z "$repo" ] && [ -n "$repo_root" ]; then
        repo="$(slug_of "$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)")"
    fi
    if [ -z "$repo" ]; then
        echo "status: skipped (no GitHub repository to compare with)"
    elif ! command -v gh > /dev/null 2>&1; then
        echo "remote: ERROR gh is not installed"
        echo "status: skipped (check the version by hand, init.md step 3)"
    else
        err_file="$(mktemp)"
        remote_file="$(gh api -H 'Accept: application/vnd.github.raw' "repos/$repo/contents/.oss-ai-helper-rules/project-info.md" 2>"$err_file")"
        gh_status=$?
        if [ "$gh_status" -ne 0 ]; then
            if grep -q 'HTTP 404' "$err_file"; then
                echo "remote: none ($repo has no .oss-ai-helper-rules/project-info.md)"
                echo "status: skipped (nothing to compare with)"
            else
                echo "remote: ERROR $(head -2 "$err_file" | tr '\n' ' ')"
                echo "status: skipped (check the version by hand, init.md step 3)"
            fi
        else
            remote_version="$(printf '%s\n' "$remote_file" | version_of)"
            if [ -z "$remote_version" ]; then
                echo "remote: none ($repo's project-info.md has no ## Version section)"
                echo "status: skipped (nothing to compare with)"
            elif [ "$remote_version" = "$local_version" ]; then
                echo "remote: $remote_version ($repo)"
                echo "status: up-to-date"
            else
                echo "remote: $remote_version ($repo)"
                echo "status: update-available (ask before updating, init.md step 3.3)"
            fi
        fi
        rm -f "$err_file"
    fi
fi

section "end"
exit 0
