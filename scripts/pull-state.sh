#!/usr/bin/env bash
#
# pull-state.sh — Download state files from the state branch via GitHub API.
#
# Usage:
#   ./pull-state.sh <fork-repo> <state-branch> [output-dir]
#
# Example:
#   ./pull-state.sh gnodet/jline3 pr-review-loop-state /tmp/loop-state
#
# Downloads state.json, loop-config.json, loop-run-log.json, learnings.json
# from the state branch. Creates output-dir if needed. Defaults to current dir.
#
# Dependencies: gh CLI

set -euo pipefail

FORK_REPO="${1:?Usage: $0 <fork-repo> <state-branch> [output-dir]}"
STATE_BRANCH="${2:?Missing state branch name}"
OUTPUT_DIR="${3:-.}"

mkdir -p "$OUTPUT_DIR"

FILES=(state.json loop-config.json loop-run-log.json learnings.json)
PULLED=0

for file in "${FILES[@]}"; do
  CONTENT=$(gh api "repos/$FORK_REPO/contents/$file?ref=$STATE_BRANCH" \
    --jq '.content' 2>/dev/null || echo "")

  if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT" | base64 -d > "$OUTPUT_DIR/$file"
    echo "OK: $file"
    PULLED=$((PULLED + 1))
  else
    echo "SKIP: $file (not found on $STATE_BRANCH)"
  fi
done

echo ""
echo "Pulled $PULLED file(s) to $OUTPUT_DIR"
