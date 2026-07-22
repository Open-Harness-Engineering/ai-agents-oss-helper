#!/usr/bin/env bash
#
# check-pr-work.sh — Zero-cost precondition for the PR review loop.
#
# Two-tier check:
#   Tier 1: ETag-based conditional request to GitHub Events API (free on 304).
#   Tier 2: Deterministic PR triage against state.json (1 API call).
#
# Exits 0 (prints actionable PR count) if there is work to do.
# Exits 1 if no actionable PRs found — the loop should skip this iteration.
#
# Costs:
#   - Idle: 0 API calls (304 Not Modified doesn't count against rate limit)
#   - Active: 1 API call (gh pr list)
#   - First run: 2 API calls (no cached ETag -> always falls through)
#
# Usage: ./check-pr-work.sh [path/to/state.json]
#
# Reads the upstream repo from state.json, .oss-ai-helper-rules/project-info.md,
# or git remote origin (in that order).
#
# Dependencies: gh CLI, python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

STATE_FILE="${1:-$REPO_ROOT/state.json}"

# -- Detect upstream repo --
REPO=""
# Try state.json first
if [[ -f "$STATE_FILE" ]]; then
  REPO=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('project',''))" "$STATE_FILE" 2>/dev/null || true)
fi
# Fallback to project rules
if [[ -z "$REPO" ]] && [[ -f "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" ]]; then
  REPO=$(grep -i 'Remote pattern:' "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" | sed 's/.*Remote pattern:[* ]*//' | tr -d '`*' | xargs 2>/dev/null || true)
fi
# Fallback to git remote
if [[ -z "$REPO" ]]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
fi
if [[ -z "$REPO" ]]; then
  echo "Cannot determine upstream repo. Skipping."
  exit 1
fi

# -- Kill switch --
if [[ -f "$STATE_FILE" ]]; then
  PAUSED=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('paused',False))" "$STATE_FILE" 2>/dev/null || echo "False")
  if [[ "$PAUSED" == "True" ]]; then
    echo "Kill switch active. Skipping."
    exit 1
  fi
fi

# -- Tier 1: ETag-based conditional request --
ETAG_FILE="${SCRIPT_DIR}/.pr-loop-etag-$(echo "$REPO" | tr '/' '-')"
HEADER_TMP=$(mktemp)
BODY_TMP=$(mktemp)
trap 'rm -f "$HEADER_TMP" "$BODY_TMP"' EXIT

CACHED_ETAG=""
[ -f "$ETAG_FILE" ] && CACHED_ETAG=$(cat "$ETAG_FILE")

ETAG_HEADER=()
[ -n "$CACHED_ETAG" ] && ETAG_HEADER=(-H "If-None-Match: $CACHED_ETAG")

HTTP_CODE=$(curl -s -o "$BODY_TMP" -D "$HEADER_TMP" -w "%{http_code}" \
  -H "Authorization: token $(gh auth token)" \
  -H "Accept: application/vnd.github+json" \
  "${ETAG_HEADER[@]}" \
  "https://api.github.com/repos/${REPO}/events?per_page=5" 2>/dev/null) || true

NEW_ETAG=$(grep -i '^etag:' "$HEADER_TMP" 2>/dev/null | awk '{print $2}' | tr -d '\r\n' || true)
[ -n "$NEW_ETAG" ] && echo -n "$NEW_ETAG" > "$ETAG_FILE"

if [[ "$HTTP_CODE" == "304" ]]; then
  echo "No repo activity since last check (ETag 304, free). Skipping."
  exit 1
fi

# -- Tier 2: Deterministic triage against state.json --
echo "Repo activity detected. Checking PRs..."
exec python3 "$SCRIPT_DIR/triage-prs.py" "$REPO" "$STATE_FILE" --format summary
