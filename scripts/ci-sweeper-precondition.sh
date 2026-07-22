#!/usr/bin/env bash
# CI Sweeper loop precondition script.
#
# Two-tier check:
#   Tier 1: ETag-based conditional request to GitHub Events API (free on 304).
#   Tier 2: Check each watched branch for a failed CI run (1 API call/branch).
#
# Exit 0  -> a failure exists on a watched branch; run the sweeper.
# Exit 1  -> all branches green or in-progress; skip this iteration.
#
# Costs:
#   - Idle: 0 API calls (304 Not Modified doesn't count against rate limit)
#   - Active: 1 API call per watched branch
#   - First run: 1 + N API calls (no cached ETag -> always falls through)
#
# This script runs BEFORE the model is invoked, so it costs zero tokens
# when CI is green.  The full sweeper skill is only loaded when there is
# an actual failure to triage.
#
# Configuration is read from LOOP.md in the project root.
# Expected format in LOOP.md:
#   | Watched branches | main, release-branch |
#   | CI workflow | Main build |
#
# If LOOP.md is not found, falls back to checking 'main' branch only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# -- Detect upstream repo --
REPO=""
if [[ -f "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" ]]; then
  REPO=$(grep -i 'Remote pattern:' "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" | sed 's/.*Remote pattern:[* ]*//' | tr -d '`*' | xargs 2>/dev/null || true)
fi
if [[ -z "$REPO" ]]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
fi
if [[ -z "$REPO" ]]; then
  echo "precondition: cannot determine upstream repo -- skipping"
  exit 1
fi

# -- Kill switch --
STATE_FILE="$REPO_ROOT/STATE.md"
if [[ -f "$STATE_FILE" ]] && grep -qP '^loop-pause-all' "$STATE_FILE" 2>/dev/null; then
  echo "precondition: kill switch active -- skipping"
  exit 1
fi

# -- Tier 1: ETag-based conditional request --
ETAG_FILE="${SCRIPT_DIR}/.ci-loop-etag-$(echo "$REPO" | tr '/' '-')"
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
  echo "precondition: no repo activity since last check (ETag 304, free) -- skipping"
  exit 1
fi

# -- Tier 2: Check each watched branch --
echo "precondition: repo activity detected -- checking CI status..."

BRANCHES=()
LOOP_FILE="$REPO_ROOT/LOOP.md"
if [[ -f "$LOOP_FILE" ]]; then
  raw=$(sed -n 's/.*Watched branches\s*|\s*\(.*\)\s*|.*/\1/p' "$LOOP_FILE" 2>/dev/null || true)
  if [[ -n "$raw" ]]; then
    IFS=',' read -ra BRANCHES <<< "$raw"
    for i in "${!BRANCHES[@]}"; do
      BRANCHES[$i]=$(echo "${BRANCHES[$i]}" | xargs)
    done
  fi

  CI_WORKFLOW=$(sed -n 's/.*CI workflow\s*|\s*\(.*\)\s*|.*/\1/p' "$LOOP_FILE" 2>/dev/null | xargs || true)
fi

if [[ ${#BRANCHES[@]} -eq 0 ]]; then
  BRANCHES=("main")
fi

for branch in "${BRANCHES[@]}"; do
  if [[ -n "${CI_WORKFLOW:-}" ]]; then
    conclusion=$(gh run list --repo "$REPO" --branch "$branch" \
      --workflow "$CI_WORKFLOW" --limit 1 \
      --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
  else
    conclusion=$(gh api "repos/${REPO}/actions/runs?branch=${branch}&per_page=1&status=completed" \
      --jq '.workflow_runs[0].conclusion // "none"' 2>/dev/null || echo "unknown")
  fi

  if [[ "$conclusion" == "failure" ]]; then
    echo "precondition: FAILURE on $branch -- proceeding"
    exit 0
  fi
done

echo "precondition: all watched branches green -- skipping"
exit 1
