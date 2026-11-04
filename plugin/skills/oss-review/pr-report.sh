#!/usr/bin/env bash
# pr-report.sh: the pull-request reports of list-prs.md, list-pr-status.md and pr-status.md, each
# from one gh call, with the CI rollup, the review decision and merge conflicts already classified.
#
#   bash pr-report.sh list   [--repo org/repo] [--author login] [--label name] [--limit N]
#                            [--include-drafts] [--exclude-mine]
#   bash pr-report.sh mine   [--repo org/repo]
#   bash pr-report.sh status [number|url] [--repo org/repo]    (no number: the current branch's PR)
#
# For repeated runs (a loop or a schedule):
#   --state <file>   print "UNCHANGED since <time>" when the report is the one the previous run saved
#                    in <file>; otherwise print the report and save it.
#   bash pr-report.sh watch <list|mine|status> [options] [--state <file>] [--interval S] [--max-wait S]
#                    re-run the report every S seconds (default 300) and exit as soon as it differs
#                    from the saved one (without --state, from the first one), printing it. After
#                    --max-wait seconds (default 3600) it prints UNCHANGED and exits. Run it in the
#                    background: whatever started it wakes up only when something changed.
#
# Read-only: it never modifies a pull request. Needs gh (logged in) and jq. Exit codes: 0 a report
# or UNCHANGED was printed, 1 a gh or jq failure (an ERROR line says which), 2 bad arguments.
set -u

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0" >&2
    exit 2
}

watch=0
if [ "${1:-}" = "watch" ]; then
    watch=1
    shift
fi
mode="${1:-}"
case "$mode" in
    list | mine | status) shift ;;
    *) usage ;;
esac

repo="" author="" label="" limit=20 include_drafts=0 exclude_mine=0 pr="" state="" interval=300 max_wait=3600
while [ $# -gt 0 ]; do
    case "$1" in
        --repo) repo="${2:-}"; shift 2 ;;
        --author) author="${2:-}"; shift 2 ;;
        --label) label="${2:-}"; shift 2 ;;
        --limit) limit="${2:-}"; shift 2 ;;
        --include-drafts) include_drafts=1; shift ;;
        --exclude-mine) exclude_mine=1; shift ;;
        --state) state="${2:-}"; shift 2 ;;
        --interval) interval="${2:-}"; shift 2 ;;
        --max-wait) max_wait="${2:-}"; shift 2 ;;
        -*) echo "pr-report.sh: unknown option $1" >&2; usage ;;
        *)
            [ "$mode" = "status" ] && [ -z "$pr" ] || usage
            pr="$1"
            shift
            ;;
    esac
done
for n in "$limit" "$interval" "$max_wait"; do
    case "$n" in '' | *[!0-9]*) echo "pr-report.sh: expected a number, got '$n'" >&2; exit 2 ;; esac
done

# A PR URL names its repository too.
case "$pr" in
    http*://*/pull/*)
        url_repo="$(printf '%s' "$pr" | sed -E 's#^https?://[^/]+/([^/]+/[^/]+)/pull/.*#\1#')"
        pr="$(printf '%s' "$pr" | sed -E 's#.*/pull/([0-9]+).*#\1#')"
        repo="${repo:-$url_repo}"
        ;;
esac

for tool in gh jq; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "ERROR $tool is not installed"
        exit 1
    fi
done
err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT

if [ -z "$repo" ]; then
    repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2> "$err_file")" || {
        echo "ERROR no --repo given and gh found no repository here: $(head -2 "$err_file" | tr '\n' ' ')"
        exit 1
    }
fi

query="is:pr is:open"
filters="open"
if [ "$include_drafts" -eq 0 ]; then query="$query -is:draft"; filters="$filters, non-draft"; fi
if [ -n "$author" ]; then query="$query author:$author"; filters="$filters, author=$author"; fi
if [ "$exclude_mine" -eq 1 ]; then query="$query -author:@me"; filters="$filters, excluding my PRs"; fi
if [ -n "$label" ]; then query="$query label:\"$label\""; filters="$filters, label=\"$label\""; fi

fetch() {
    case "$mode" in
        list)
            gh pr list --repo "$repo" --search "$query" --limit "$limit" \
                --json number,title,author,headRefName,baseRefName,isDraft,updatedAt,reviewDecision
            ;;
        mine)
            gh pr list --repo "$repo" --author @me --state open --limit 100 \
                --json number,title,headRefName,baseRefName,isDraft,updatedAt,reviewDecision,mergeable,statusCheckRollup
            ;;
        status)
            # shellcheck disable=SC2086 # an empty $pr means the current branch's PR
            gh pr view $pr --repo "$repo" \
                --json number,title,state,isDraft,mergeable,mergeStateStatus,baseRefName,headRefName,author,reviewDecision,reviewRequests,createdAt,updatedAt,statusCheckRollup,latestReviews,comments
            ;;
    esac
}

DEFS='
def cell: tostring | gsub("[\r\n]+"; " ") | gsub("\\|"; "\\|");
def short($n): if length > $n then .[0:$n - 1] + "…" else . end;
def day: if . == null or . == "" then "" else .[0:10] end;
def yesno: if . then "yes" else "no" end;
def review: {"APPROVED": "approved", "CHANGES_REQUESTED": "changes requested", "REVIEW_REQUIRED": "review required"}[. // ""] // "none";
# The latest run of each check: a re-run adds a second entry with the same workflow and name.
def latest_checks: [.statusCheckRollup[]?]
    | group_by((.__typename // "") + "|" + (.workflowName // "") + "|" + (.name // .context // ""))
    | map(max_by(.startedAt // .completedAt // ""));
def result: if .__typename == "StatusContext" then
        ({"SUCCESS": "pass", "FAILURE": "fail", "ERROR": "fail"}[.state // ""] // "pending")
    elif (.status // "") != "COMPLETED" then "pending"
    else ({"SUCCESS": "pass", "NEUTRAL": "pass", "SKIPPED": "skipped", "FAILURE": "fail", "TIMED_OUT": "fail",
           "CANCELLED": "fail", "ACTION_REQUIRED": "fail", "STARTUP_FAILURE": "fail"}[.conclusion // ""] // "pending")
    end;
def ci: (latest_checks | map(result)) as $r
    | if ($r | length) == 0 then "none"
      elif any($r[]; . == "fail") then "failing"
      elif any($r[]; . == "pending") then "pending"
      else "passing" end;
def item: "- #\(.number) - \(.title | short(70))";
'

LIST='
if length == 0 then "No open pull requests matched the requested filters in `\($repo)`."
else
  "## Open PRs in \($repo)\n\nFilters: \($filters)\n",
  "| # | PR | Title | Author | Branch | Reviews | Draft | Updated |",
  "|---|----|-------|--------|--------|---------|-------|---------|",
  (to_entries[] | .key as $i | .value
    | "| \($i + 1) | #\(.number) | \(.title | short(70) | cell) | \(.author.login // "" | cell) | \(.headRefName | cell) -> \(.baseRefName | cell) | \(.reviewDecision | review) | \(.isDraft | yesno) | \(.updatedAt | day) |"),
  "\n**Total:** \(length) PR(s)"
end
'

MINE='
if length == 0 then "No open pull requests found for your account in `\($repo)`."
else
  sort_by(-.number) as $prs
  | "## Your Open PRs in \($repo)\n",
    "| # | Title | Branch | CI | Reviews | Draft | Updated |",
    "|---|-------|--------|----|---------|-------|---------|",
    ($prs[] | "| #\(.number) | \(.title | short(70) | cell) | \(.headRefName | cell) -> \(.baseRefName | cell) | \(ci) | \(.reviewDecision | review) | \(.isDraft | yesno) | \(.updatedAt | day) |"),
    "\n**Total:** \($prs | length) open PR(s)\n",
    ([$prs[] | select(ci == "failing") | item] as $failing
     | [$prs[] | select(.reviewDecision == "CHANGES_REQUESTED") | item] as $changes
     | [$prs[] | select(.mergeable == "CONFLICTING") | "\(item) (rebase onto \(.baseRefName))"] as $conflicts
     | if ($failing + $changes + $conflicts | length) == 0 then "All your PRs are in good shape. No action needed."
       else "### Needs Attention"
         + (if ($failing | length) > 0 then "\n\n**Failing CI:**\n" + ($failing | join("\n")) else "" end)
         + (if ($changes | length) > 0 then "\n\n**Changes Requested:**\n" + ($changes | join("\n")) else "" end)
         + (if ($conflicts | length) > 0 then "\n\n**Merge Conflicts:**\n" + ($conflicts | join("\n")) else "" end)
       end)
end
'

STATUS='
latest_checks as $checks
| ($checks | map(result)) as $r
| ([$r[] | select(. == "pass")] | length) as $pass
| ([$r[] | select(. == "fail")] | length) as $fail
| ([$r[] | select(. == "pending")] | length) as $pending
| ([$r[] | select(. != "skipped")] | length) as $counted
| "## PR Status: #\(.number) - \(.title)\n",
  "### Overview",
  "- **State:** \(.state | ascii_downcase)",
  "- **Draft:** \(.isDraft | yesno)",
  "- **Author:** \(.author.login // "unknown")",
  "- **Branch:** \(.headRefName) -> \(.baseRefName)",
  "- **Created:** \(.createdAt | day)",
  "- **Updated:** \(.updatedAt | day)",
  "- **Mergeable:** \({"MERGEABLE": "yes", "CONFLICTING": "conflicting"}[.mergeable // ""] // "unknown (GitHub has not computed it yet)")\(if (.mergeStateStatus // "") != "" then " (merge state: \(.mergeStateStatus | ascii_downcase))" else "" end)",
  "\n### CI Checks",
  (if ($checks | length) == 0 then "No CI checks reported."
   else
     "| Check | Status | Details |",
     "|-------|--------|---------|",
     ($checks | sort_by((result != "fail"), (.workflowName // ""), (.name // .context // ""))[]
       | "| \(((.workflowName // "") | if . == "" then "" else . + " / " end) + (.name // .context // "?") | cell) | \(result) | \(if result == "fail" then (.detailsUrl // .targetUrl // "") else "" end) |"),
     "\n**Overall:** \(if $fail > 0 then "\($fail) failing, \($pass) of \($counted) passing"
                       elif $pending > 0 then "\($pending) pending, \($pass) of \($counted) passing"
                       else "all passing" end)"
   end),
  "\n### Reviews",
  "- **Decision:** \(.reviewDecision | review)",
  (.latestReviews[]? | "- \(.author.login // "?"): \(.state | ascii_downcase | gsub("_"; " ")) (\(.submittedAt | day))"),
  (if ((.reviewRequests // []) | length) > 0 then "- **Requested:** \([.reviewRequests[] | .login // .slug // .name] | join(", "))" else empty end),
  "\n### Pending Actions",
  ([ (if $fail > 0 then "- [ ] Failing CI checks" else empty end),
     (if $pending > 0 then "- [ ] CI checks still running" else empty end),
     (if .reviewDecision == "CHANGES_REQUESTED" then "- [ ] Changes requested"
      elif .reviewDecision == "REVIEW_REQUIRED" then "- [ ] Pending reviews" else empty end),
     (if .mergeable == "CONFLICTING" then "- [ ] Merge conflicts" else empty end),
     (if .isDraft then "- [ ] Draft status" else empty end) ]
   | if length == 0 then "Nothing blocks the merge." else join("\n") end),
  "\n### Recent Comments",
  ([.comments[]?] | if length == 0 then "No recent discussion."
   else (.[-5:][] | "- \(.author.login // "?") (\(.createdAt | day)): \(.body | gsub("[\r\n]+"; " ") | short(300))") end)
'

case "$mode" in
    list) program="$LIST" ;;
    mine) program="$MINE" ;;
    status) program="$STATUS" ;;
esac

# render: the report, or an ERROR line and a non-zero status.
render() {
    local json
    if ! json="$(fetch 2> "$err_file")"; then
        echo "ERROR gh: $(head -3 "$err_file" | tr '\n' ' ')"
        return 1
    fi
    if ! printf '%s' "$json" | jq -r --arg repo "$repo" --arg filters "$filters" "$DEFS$program" 2> "$err_file"; then
        echo "ERROR jq: $(head -3 "$err_file" | tr '\n' ' ')"
        return 1
    fi
}

digest() { printf '%s' "$1" | cksum | awk '{ print $1 "-" $2 }'; }

save_state() {
    [ -n "$state" ] || return 0
    mkdir -p "$(dirname "$state")"
    printf '%s\n%s\n' "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$state"
}

if [ "$watch" -eq 1 ]; then
    baseline=""
    if [ -n "$state" ] && [ -f "$state" ]; then
        baseline="$(head -1 "$state")"
    fi
    if [ -z "$baseline" ]; then
        report="$(render)" || { printf '%s\n' "$report"; exit 1; }
        baseline="$(digest "$report")"
        save_state "$baseline"
    fi
    started="$(date +%s)"
    while [ $(($(date +%s) - started)) -lt "$max_wait" ]; do
        sleep "$interval"
        report="$(render)" || { printf '%s\n' "$report"; exit 1; }
        current="$(digest "$report")"
        if [ "$current" != "$baseline" ]; then
            save_state "$current"
            printf '%s\n' "$report"
            exit 0
        fi
    done
    echo "UNCHANGED after $max_wait seconds"
    exit 0
fi

report="$(render)" || { printf '%s\n' "$report"; exit 1; }
if [ -n "$state" ]; then
    current="$(digest "$report")"
    if [ -f "$state" ] && [ "$(head -1 "$state")" = "$current" ]; then
        echo "UNCHANGED since $(sed -n 2p "$state")"
        exit 0
    fi
    save_state "$current"
fi
printf '%s\n' "$report"
