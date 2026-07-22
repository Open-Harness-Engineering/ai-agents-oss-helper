#!/usr/bin/env bash
#
# wait-for-pr-update.sh — Block until a specific PR has new activity.
#
# Polls the PR's events using ETag-based conditional requests (free on 304).
# Returns when: new commit, new comment/review, CI status change, or merge.
#
# Usage: ./wait-for-pr-update.sh [OPTIONS] --pr NUMBER
#
#   --pr NUMBER         PR number (required)
#   --repo OWNER/REPO   Override upstream repo detection
#   --timeout SECONDS   Max wait (default: 0 = block forever)
#   --interval SECONDS  Poll interval (default: 30)
#
# Exit 0: activity detected (stdout describes what changed)
# Exit 1: timeout or error
#
# stdout signals (one per line):
#   CI_FAILED           — latest CI run failed
#   CI_GREEN            — latest CI run passed
#   NEW_COMMENTS        — new comments or reviews since last check
#   MERGED              — PR was merged
#   CLOSED              — PR was closed without merge
#   PUSHED              — new commits pushed
#
# Dependencies: curl, gh CLI

set -euo pipefail

# -- Parse arguments --
TIMEOUT=0
POLL_INTERVAL=30
REPO_OVERRIDE=""
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)        PR_NUMBER="$2"; shift 2 ;;
    --repo)      REPO_OVERRIDE="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --interval)  POLL_INTERVAL="$2"; shift 2 ;;
    -*)          echo "Unknown option: $1" >&2; exit 1 ;;
    *)           shift ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: $0 --pr NUMBER [--repo OWNER/REPO] [--timeout N] [--interval N]" >&2
  exit 1
fi

# -- Detect upstream repo --
REPO="$REPO_OVERRIDE"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ -z "$REPO" ]] && [[ -f "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" ]]; then
  REPO=$(grep -i 'Remote pattern:' "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" \
    | sed 's/.*Remote pattern:[* ]*//' | tr -d '`*' | xargs 2>/dev/null || true)
fi
if [[ -z "$REPO" ]]; then
  REPO=$(git remote get-url origin 2>/dev/null \
    | sed -E 's#.*github.com[:/]##; s#\.git$##')
fi
if [[ -z "$REPO" ]]; then
  echo "Cannot determine upstream repo." >&2
  exit 1
fi

# -- Get initial state to compare against --
GH_TOKEN="$(gh auth token 2>/dev/null || echo "")"
if [[ -z "$GH_TOKEN" ]]; then
  echo "No GitHub token available." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETAG_FILE="${SCRIPT_DIR}/.wait-pr-${PR_NUMBER}-etag-$(echo "$REPO" | tr '/' '-')"

# Snapshot: latest commit SHA, comment count, PR state
get_pr_snapshot() {
  gh api "repos/$REPO/pulls/$PR_NUMBER" \
    --jq '{state: .state, merged: .merged, draft: .draft, head_sha: .head.sha, updated_at: .updated_at}' 2>/dev/null
}

get_ci_status() {
  # Get combined status for head SHA
  local sha="$1"
  gh api "repos/$REPO/commits/$sha/status" --jq '.state' 2>/dev/null || echo "unknown"
  # Also check check-runs (GitHub Actions uses checks, not statuses)
  local check_conclusion
  check_conclusion=$(gh api "repos/$REPO/commits/$sha/check-runs" \
    --jq '[.check_runs[] | .conclusion // "pending"] | if any(. == "failure") then "failure" elif all(. == "success") then "success" else "pending" end' 2>/dev/null || echo "unknown")
  echo "$check_conclusion"
}

INITIAL_SNAPSHOT=$(get_pr_snapshot)
if [[ -z "$INITIAL_SNAPSHOT" ]]; then
  echo "Failed to fetch PR #$PR_NUMBER." >&2
  exit 1
fi

INITIAL_SHA=$(echo "$INITIAL_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['head_sha'])")
INITIAL_STATE=$(echo "$INITIAL_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
INITIAL_MERGED=$(echo "$INITIAL_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['merged'])")
INITIAL_UPDATED=$(echo "$INITIAL_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['updated_at'])")

# Already merged?
if [[ "$INITIAL_MERGED" == "True" ]]; then
  echo "MERGED"
  exit 0
fi
if [[ "$INITIAL_STATE" == "closed" ]]; then
  echo "CLOSED"
  exit 0
fi

CACHED_ETAG=""
[[ -f "$ETAG_FILE" ]] && CACHED_ETAG=$(cat "$ETAG_FILE")

START_TIME=$(date +%s)

while true; do
  # Check timeout
  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [[ $TIMEOUT -gt 0 ]] && [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo "Timeout (${TIMEOUT}s) — no activity on PR #$PR_NUMBER."
    exit 1
  fi

  # ETag-based poll on PR timeline events (free on 304)
  HEADER_TMP=$(mktemp)
  BODY_TMP=$(mktemp)

  ETAG_HEADER=()
  [[ -n "$CACHED_ETAG" ]] && ETAG_HEADER=(-H "If-None-Match: $CACHED_ETAG")

  HTTP_CODE=$(curl -s -o "$BODY_TMP" -D "$HEADER_TMP" -w "%{http_code}" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${ETAG_HEADER[@]}" \
    "https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/timeline?per_page=5" 2>/dev/null) || true

  NEW_ETAG=$(grep -i '^etag:' "$HEADER_TMP" 2>/dev/null \
    | awk '{print $2}' | tr -d '\r\n' || true)
  [[ -n "$NEW_ETAG" ]] && echo -n "$NEW_ETAG" > "$ETAG_FILE"

  rm -f "$HEADER_TMP" "$BODY_TMP"

  if [[ "$HTTP_CODE" == "304" ]]; then
    # No activity — sleep
    if [[ $TIMEOUT -gt 0 ]]; then
      REMAINING=$(( TIMEOUT - ELAPSED ))
      SLEEP_TIME=$(( POLL_INTERVAL < REMAINING ? POLL_INTERVAL : REMAINING ))
      [[ $SLEEP_TIME -le 0 ]] && exit 1
    else
      SLEEP_TIME=$POLL_INTERVAL
    fi
    sleep "$SLEEP_TIME"
    continue
  fi

  # Activity detected — determine what changed
  CURRENT_SNAPSHOT=$(get_pr_snapshot)
  if [[ -z "$CURRENT_SNAPSHOT" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  CURRENT_SHA=$(echo "$CURRENT_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['head_sha'])")
  CURRENT_STATE=$(echo "$CURRENT_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  CURRENT_MERGED=$(echo "$CURRENT_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['merged'])")
  CURRENT_UPDATED=$(echo "$CURRENT_SNAPSHOT" | python3 -c "import sys,json; print(json.load(sys.stdin)['updated_at'])")

  SIGNALS=""

  # Check merge
  if [[ "$CURRENT_MERGED" == "True" ]]; then
    echo "MERGED"
    exit 0
  fi

  # Check closed
  if [[ "$CURRENT_STATE" == "closed" ]]; then
    echo "CLOSED"
    exit 0
  fi

  # Check new commits
  if [[ "$CURRENT_SHA" != "$INITIAL_SHA" ]]; then
    SIGNALS="${SIGNALS}PUSHED\n"
    INITIAL_SHA="$CURRENT_SHA"
  fi

  # Check CI status on current head
  CI_STATUSES=$(get_ci_status "$CURRENT_SHA")
  CI_STATUS=$(echo "$CI_STATUSES" | tail -1)  # check-runs result
  COMMIT_STATUS=$(echo "$CI_STATUSES" | head -1)  # commit status

  if [[ "$CI_STATUS" == "failure" ]] || [[ "$COMMIT_STATUS" == "failure" ]]; then
    SIGNALS="${SIGNALS}CI_FAILED\n"
  elif [[ "$CI_STATUS" == "success" ]] && [[ "$COMMIT_STATUS" != "failure" ]]; then
    SIGNALS="${SIGNALS}CI_GREEN\n"
  fi

  # Check for new comments/reviews (updated_at changed but SHA didn't)
  if [[ "$CURRENT_UPDATED" != "$INITIAL_UPDATED" ]] && [[ "$CURRENT_SHA" == "$INITIAL_SHA" ]]; then
    SIGNALS="${SIGNALS}NEW_COMMENTS\n"
  fi

  INITIAL_UPDATED="$CURRENT_UPDATED"

  if [[ -n "$SIGNALS" ]]; then
    echo -e "$SIGNALS" | grep -v '^$'
    exit 0
  fi

  # Activity detected but nothing actionable changed — keep polling
  if [[ $TIMEOUT -gt 0 ]]; then
    REMAINING=$(( TIMEOUT - $(( $(date +%s) - START_TIME )) ))
    SLEEP_TIME=$(( POLL_INTERVAL < REMAINING ? POLL_INTERVAL : REMAINING ))
    [[ $SLEEP_TIME -le 0 ]] && exit 1
  else
    SLEEP_TIME=$POLL_INTERVAL
  fi
  sleep "$SLEEP_TIME"
done
