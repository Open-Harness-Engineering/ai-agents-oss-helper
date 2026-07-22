#!/usr/bin/env bash
#
# push-state.sh — Push state files to the state branch via GitHub API.
#
# Usage:
#   ./push-state.sh <fork-repo> <state-branch> [file1] [file2] ...
#
# Example:
#   ./push-state.sh gnodet/jline3 pr-review-loop-state state.json loop-run-log.json learnings.json
#
# If no files specified, pushes all standard state files found in the current directory.
#
# Uses GitHub Contents API — no git checkout required, safe in worktrees.
# Dependencies: gh CLI

set -euo pipefail

FORK_REPO="${1:?Usage: $0 <fork-repo> <state-branch> [files...]}"
STATE_BRANCH="${2:?Missing state branch name}"
shift 2

# Default files if none specified
if [[ $# -eq 0 ]]; then
  FILES=()
  for f in state.json loop-config.json loop-run-log.json learnings.json; do
    [[ -f "$f" ]] && FILES+=("$f")
  done
  # Also check legacy markdown files
  for f in STATE.md loop-budget.md loop-constraints.md loop-ledger.json loop-run-log.md; do
    [[ -f "$f" ]] && FILES+=("$f")
  done
else
  FILES=("$@")
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No state files found to push."
  exit 1
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ERRORS=0

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "SKIP: $file (not found)"
    continue
  fi

  # Get existing SHA (needed for updates, empty for new files)
  EXISTING_SHA=$(gh api "repos/$FORK_REPO/contents/$file?ref=$STATE_BRANCH" \
    --jq '.sha' 2>/dev/null || echo "")

  B64=$(base64 -w0 < "$file")

  ARGS=(-f message="Update state $NOW" \
        -f branch="$STATE_BRANCH" \
        -f content="$B64")
  [[ -n "$EXISTING_SHA" ]] && ARGS+=(-f sha="$EXISTING_SHA")

  if gh api "repos/$FORK_REPO/contents/$file" --method PUT "${ARGS[@]}" > /dev/null 2>&1; then
    echo "OK: $file"
  else
    echo "FAIL: $file"
    ERRORS=$((ERRORS + 1))
  fi
done

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "$ERRORS file(s) failed to push."
  exit 1
fi

echo ""
echo "State pushed to $FORK_REPO@$STATE_BRANCH"
