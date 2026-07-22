#!/usr/bin/env bash
#
# init-state-branch.sh — Create a state branch on a fork with initial state files.
#
# Usage:
#   ./init-state-branch.sh <fork-repo> <state-branch> <project-name> <loop-type>
#
# Example:
#   ./init-state-branch.sh gnodet/jline3 pr-review-loop-state "JLine3" review-loop
#   ./init-state-branch.sh gnodet/camel ci-sweeper-state "Camel" ci-sweeper
#
# Creates the branch via GitHub API and pushes initial state.json, loop-config.json,
# and loop-run-log.json. No git checkout needed — uses API exclusively.
#
# Dependencies: gh CLI, jq (or Python 3 as fallback)

set -euo pipefail

FORK_REPO="${1:?Usage: $0 <fork-repo> <state-branch> <project-name> <loop-type>}"
STATE_BRANCH="${2:?Missing state branch name}"
PROJECT_NAME="${3:?Missing project name}"
LOOP_TYPE="${4:?Missing loop type (review-loop or ci-sweeper)}"

# Detect upstream from git remote or .oss-ai-helper-rules
UPSTREAM_REPO=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ -f "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" ]]; then
  UPSTREAM_REPO=$(grep -i 'Remote pattern:' "$REPO_ROOT/.oss-ai-helper-rules/project-info.md" \
    | sed 's/.*Remote pattern:[* ]*//' | tr -d '`*' | xargs 2>/dev/null || true)
fi
if [[ -z "$UPSTREAM_REPO" ]]; then
  UPSTREAM_REPO=$(git remote get-url origin 2>/dev/null \
    | sed -E 's#.*github.com[:/]##; s#\.git$##')
fi

echo "Initializing state branch for $PROJECT_NAME ($LOOP_TYPE)"
echo "  Fork: $FORK_REPO"
echo "  Upstream: $UPSTREAM_REPO"
echo "  Branch: $STATE_BRANCH"

# Get default branch SHA
DEFAULT_BRANCH=$(gh api "repos/$FORK_REPO" --jq '.default_branch')
HEAD_SHA=$(gh api "repos/$FORK_REPO/git/ref/heads/$DEFAULT_BRANCH" --jq '.object.sha')

# Check if branch already exists
if gh api "repos/$FORK_REPO/git/ref/heads/$STATE_BRANCH" &>/dev/null; then
  echo "Branch $STATE_BRANCH already exists. Aborting."
  exit 1
fi

# Create branch
gh api "repos/$FORK_REPO/git/refs" --method POST \
  -f ref="refs/heads/$STATE_BRANCH" \
  -f sha="$HEAD_SHA" > /dev/null
echo "Created branch: $STATE_BRANCH"

# Generate initial state.json
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE_JSON=$(cat <<ENDJSON
{
  "version": "1.0",
  "project": "$UPSTREAM_REPO",
  "project_name": "$PROJECT_NAME",
  "loop_type": "$LOOP_TYPE",
  "last_run": null,
  "reviewed_prs": [],
  "skipped_prs": [],
  "review_queue": [],
  "active_failures": [],
  "escalated": [],
  "resolved": [],
  "created_at": "$NOW"
}
ENDJSON
)

# Generate loop-config.json
if [[ "$LOOP_TYPE" == "review-loop" ]]; then
  CONFIG_JSON=$(cat <<ENDJSON
{
  "version": "1.0",
  "pattern": "pr-review-loop",
  "project": "$UPSTREAM_REPO",
  "project_name": "$PROJECT_NAME",
  "cadence": "1h",
  "max_items_per_run": 3,
  "state_branch": "$STATE_BRANCH",
  "level": "L2",
  "budget": {
    "max_runs_per_day": 24,
    "max_tokens_per_day": 10000000,
    "max_subagents_per_run": 6
  },
  "constraints": {
    "never_merge": true,
    "never_close": true,
    "never_label": true,
    "never_push": true,
    "review_only": true,
    "skip_drafts": true,
    "skip_bots": ["dependabot", "renovate", "github-actions"],
    "always_verify": true,
    "always_check_history": true,
    "ai_attribution": true
  },
  "operator": "$(git config user.name 2>/dev/null || echo 'unknown')"
}
ENDJSON
)
else
  CONFIG_JSON=$(cat <<ENDJSON
{
  "version": "1.0",
  "pattern": "ci-sweeper",
  "project": "$UPSTREAM_REPO",
  "project_name": "$PROJECT_NAME",
  "cadence": "15m",
  "max_items_per_run": 2,
  "state_branch": "$STATE_BRANCH",
  "level": "L2",
  "watched_branches": ["main"],
  "budget": {
    "max_runs_per_day": 96,
    "max_tokens_per_day": 10000000,
    "max_fix_attempts": 3,
    "max_files_per_fix": 5
  },
  "constraints": {
    "never_merge": true,
    "never_close": true,
    "never_label": true,
    "always_fork": true,
    "always_draft": true,
    "never_force_push": true,
    "always_verify": true,
    "never_disable_tests": true,
    "ai_attribution": true
  },
  "operator": "$(git config user.name 2>/dev/null || echo 'unknown')"
}
ENDJSON
)
fi

# Generate empty run log
RUN_LOG_JSON='{"version": "1.0", "runs": []}'

# Generate empty learnings
LEARNINGS_JSON="{\"version\": \"1.0\", \"project\": \"$UPSTREAM_REPO\", \"learnings\": []}"

# Push files via Contents API
push_file() {
  local file="$1"
  local content="$2"
  local msg="$3"
  local b64
  b64=$(echo -n "$content" | base64 -w0)
  gh api "repos/$FORK_REPO/contents/$file" --method PUT \
    -f message="$msg" \
    -f branch="$STATE_BRANCH" \
    -f content="$b64" > /dev/null
  echo "  Pushed: $file"
}

push_file "state.json" "$STATE_JSON" "Initialize $LOOP_TYPE state"
push_file "loop-config.json" "$CONFIG_JSON" "Initialize $LOOP_TYPE config"
push_file "loop-run-log.json" "$RUN_LOG_JSON" "Initialize run log"
push_file "learnings.json" "$LEARNINGS_JSON" "Initialize learnings"

echo ""
echo "State branch initialized: $STATE_BRANCH"
echo ""
echo "Files:"
echo "  state.json         — reviewed/skipped PRs, queue, last run"
echo "  loop-config.json   — cadence, budget, constraints"
echo "  loop-run-log.json  — run history"
echo "  learnings.json     — review learnings (feedback loop)"
echo ""
echo "To start the loop:"
echo "  /loop 1h /oss-review-loop"
