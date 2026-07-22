#!/usr/bin/env bash
#
# wait-for-ci-failure.sh — Blocking precondition for the CI sweeper loop.
#
# Polls the GitHub Events API using ETag-based conditional requests (free on
# 304 Not Modified) until repository activity is detected, then checks
# watched branches for CI failures.
#
# Designed to be called at the start of a /loop iteration in Claude Code:
#   /loop 15m /oss-ci-sweeper
#
# Cost:
#   - Idle: 0 API calls (304 doesn't count against rate limit)
#   - Active: 1 API call per watched branch per activity burst
#   - Zero LLM tokens consumed while waiting
#
# Usage: ./wait-for-ci-failure.sh [OPTIONS]
#
#   --timeout SECONDS   Max time to wait (default: 0 = no timeout, block forever)
#   --interval SECONDS  Poll interval (default: 60)
#   --repo OWNER/REPO   Override upstream repo detection
#   --branches B1,B2    Override watched branches (default: from LOOP.md or "main")
#   --workflow NAME     Override CI workflow name (default: from LOOP.md)
#
# Exit 0: CI failure found (stdout has branch + details)
# Exit 1: timeout or all green (skip this iteration)
#
# Dependencies: curl, gh CLI

set -euo pipefail

# -- Parse arguments --
TIMEOUT=0
POLL_INTERVAL=60
REPO_OVERRIDE=""
BRANCHES_OVERRIDE=""
WORKFLOW_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout)    TIMEOUT="$2"; shift 2 ;;
    --interval)   POLL_INTERVAL="$2"; shift 2 ;;
    --repo)       REPO_OVERRIDE="$2"; shift 2 ;;
    --branches)   BRANCHES_OVERRIDE="$2"; shift 2 ;;
    --workflow)   WORKFLOW_OVERRIDE="$2"; shift 2 ;;
    -*)           echo "Unknown option: $1" >&2; exit 1 ;;
    *)            shift ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

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
STATE_FILE="$REPO_ROOT/STATE.md"
if [[ -f "$STATE_FILE" ]] && grep -qP '^loop-pause-all' "$STATE_FILE" 2>/dev/null; then
  echo "Kill switch active. Skipping."
  exit 1
fi

# -- Detect watched branches and CI workflow --
BRANCHES=()
CI_WORKFLOW="$WORKFLOW_OVERRIDE"

if [[ -n "$BRANCHES_OVERRIDE" ]]; then
  IFS=',' read -ra BRANCHES <<< "$BRANCHES_OVERRIDE"
else
  LOOP_FILE="$REPO_ROOT/LOOP.md"
  if [[ -f "$LOOP_FILE" ]]; then
    raw=$(sed -n 's/.*Watched branches\s*|\s*\(.*\)\s*|.*/\1/p' "$LOOP_FILE" 2>/dev/null || true)
    if [[ -n "$raw" ]]; then
      IFS=',' read -ra BRANCHES <<< "$raw"
      for i in "${!BRANCHES[@]}"; do
        BRANCHES[$i]=$(echo "${BRANCHES[$i]}" | xargs)
      done
    fi
    if [[ -z "$CI_WORKFLOW" ]]; then
      CI_WORKFLOW=$(sed -n 's/.*CI workflow\s*|\s*\(.*\)\s*|.*/\1/p' "$LOOP_FILE" 2>/dev/null | xargs || true)
    fi
  fi
fi
[[ ${#BRANCHES[@]} -eq 0 ]] && BRANCHES=("main")

# -- ETag polling loop --
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETAG_FILE="${SCRIPT_DIR}/.wait-ci-etag-$(echo "$REPO" | tr '/' '-')"
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
    echo "Timeout (${TIMEOUT}s) — no CI failures detected."
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

  # Activity detected — check CI on each watched branch
  echo "Activity detected on $REPO. Checking CI status..."

  for branch in "${BRANCHES[@]}"; do
    if [[ -n "$CI_WORKFLOW" ]]; then
      conclusion=$(gh run list --repo "$REPO" --branch "$branch" \
        --workflow "$CI_WORKFLOW" --limit 1 \
        --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
    else
      conclusion=$(gh api "repos/${REPO}/actions/runs?branch=${branch}&per_page=1&status=completed" \
        --jq '.workflow_runs[0].conclusion // "none"' 2>/dev/null || echo "unknown")
    fi

    if [[ "$conclusion" == "failure" ]]; then
      echo "CI FAILURE on branch '$branch' — proceeding."
      exit 0
    fi
  done

  # All green — keep polling
  echo "All watched branches green. Resuming wait..."
  if [[ $TIMEOUT -gt 0 ]]; then
    REMAINING=$(( TIMEOUT - $(( $(date +%s) - START_TIME )) ))
    SLEEP_TIME=$(( POLL_INTERVAL < REMAINING ? POLL_INTERVAL : REMAINING ))
    [[ $SLEEP_TIME -le 0 ]] && exit 1
  else
    SLEEP_TIME=$POLL_INTERVAL
  fi
  sleep "$SLEEP_TIME"
done
