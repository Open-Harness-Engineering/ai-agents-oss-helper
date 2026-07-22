#!/usr/bin/env bash
#
# wait-for-pr-work.sh — Blocking precondition for the PR review loop.
#
# Polls the GitHub Events API using ETag-based conditional requests (free on
# 304 Not Modified) until repository activity is detected, then runs a
# deterministic PR triage to check if there is actual review work to do.
#
# Designed to be called at the start of a /loop iteration in Claude Code:
#   /loop 15m /oss-review-loop
# The skill's step 0 runs this script. It blocks until there is work,
# or until the timeout expires (exit 1 = skip this iteration).
#
# Cost:
#   - Idle: 0 API calls (304 doesn't count against rate limit)
#   - Active: 1 API call (gh pr list) per activity burst
#   - Zero LLM tokens consumed while waiting
#
# Usage: ./wait-for-pr-work.sh [OPTIONS] [path/to/STATE.md]
#
#   --timeout SECONDS   Max time to wait (default: 0 = no timeout, block forever)
#   --interval SECONDS  Poll interval (default: 60)
#   --repo OWNER/REPO   Override upstream repo detection
#
# Exit 0: actionable PRs found (stdout has summary)
# Exit 1: timeout or no work (skip this iteration)
#
# Dependencies: curl, gh CLI, python3

set -euo pipefail

# -- Parse arguments --
TIMEOUT=0
POLL_INTERVAL=60
REPO_OVERRIDE=""
STATE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --interval)  POLL_INTERVAL="$2"; shift 2 ;;
    --repo)      REPO_OVERRIDE="$2"; shift 2 ;;
    -*)          echo "Unknown option: $1" >&2; exit 1 ;;
    *)           STATE_FILE="$1"; shift ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_FILE="${STATE_FILE:-$REPO_ROOT/STATE.md}"

# -- Detect upstream repo --
REPO="$REPO_OVERRIDE"
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

# -- Kill switch --
if [[ -f "$STATE_FILE" ]] && grep -qP '^loop-pause-all' "$STATE_FILE" 2>/dev/null; then
  echo "Kill switch active. Skipping."
  exit 1
fi

# -- ETag polling loop --
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETAG_FILE="${SCRIPT_DIR}/.wait-pr-etag-$(echo "$REPO" | tr '/' '-')"
GH_TOKEN="$(gh auth token 2>/dev/null || echo "")"

if [[ -z "$GH_TOKEN" ]]; then
  echo "No GitHub token available (gh auth token failed)." >&2
  exit 1
fi

CACHED_ETAG=""
[[ -f "$ETAG_FILE" ]] && CACHED_ETAG=$(cat "$ETAG_FILE")

START_TIME=$(date +%s)

while true; do
  # Check timeout (0 = no timeout)
  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [[ $TIMEOUT -gt 0 ]] && [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo "Timeout (${TIMEOUT}s) — no actionable activity detected."
    exit 1
  fi

  # ETag-based conditional request (free on 304)
  HEADER_TMP=$(mktemp)
  BODY_TMP=$(mktemp)

  ETAG_HEADER=()
  [[ -n "$CACHED_ETAG" ]] && ETAG_HEADER=(-H "If-None-Match: $CACHED_ETAG")

  HTTP_CODE=$(curl -s -o "$BODY_TMP" -D "$HEADER_TMP" -w "%{http_code}" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${ETAG_HEADER[@]}" \
    "https://api.github.com/repos/${REPO}/events?per_page=5" 2>/dev/null) || true

  NEW_ETAG=$(grep -i '^etag:' "$HEADER_TMP" 2>/dev/null \
    | awk '{print $2}' | tr -d '\r\n' || true)
  [[ -n "$NEW_ETAG" ]] && echo -n "$NEW_ETAG" > "$ETAG_FILE"

  rm -f "$HEADER_TMP" "$BODY_TMP"

  if [[ "$HTTP_CODE" == "304" ]]; then
    # No activity — sleep and retry
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

  # Activity detected — Tier 2: check if there are actionable PRs
  echo "Activity detected on $REPO. Checking for actionable PRs..."

  # Get open, non-draft PRs
  PR_COUNT=$(gh pr list --repo "$REPO" \
    --search "is:pr is:open -is:draft" \
    --limit 30 \
    --json number,updatedAt \
    --jq 'length' 2>/dev/null || echo "0")

  if [[ "$PR_COUNT" -gt 0 ]]; then
    echo "$PR_COUNT open PR(s) found."
    exit 0
  fi

  # False alarm — activity but no actionable PRs. Keep polling.
  echo "Activity detected but no actionable PRs. Resuming wait..."
  if [[ $TIMEOUT -gt 0 ]]; then
    REMAINING=$(( TIMEOUT - $(( $(date +%s) - START_TIME )) ))
    SLEEP_TIME=$(( POLL_INTERVAL < REMAINING ? POLL_INTERVAL : REMAINING ))
    [[ $SLEEP_TIME -le 0 ]] && exit 1
  else
    SLEEP_TIME=$POLL_INTERVAL
  fi
  sleep "$SLEEP_TIME"
done
