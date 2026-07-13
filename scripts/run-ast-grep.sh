#!/usr/bin/env bash
# run-ast-grep.sh — Wrapper to run ast-grep scan with project rules
# Usage: ./scripts/run-ast-grep.sh [path...] [--json] [--sarif]
#
# If no paths are given, scans the current directory.
# Requires ast-grep (sg) to be installed: npm install -g @ast-grep/cli

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SGCONFIG="$REPO_ROOT/sgconfig.yml"

if ! command -v ast-grep &>/dev/null; then
    echo "Error: ast-grep (ast-grep) not found in PATH." >&2
    echo "Install with: npm install -g @ast-grep/cli" >&2
    exit 1
fi

if [ ! -f "$SGCONFIG" ]; then
    echo "Error: sgconfig.yml not found at $SGCONFIG" >&2
    exit 1
fi

# Parse arguments: separate flags from paths
PATHS=()
FLAGS=()
JSON_OUTPUT=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_OUTPUT=true
            FLAGS+=("--json=compact")
            ;;
        --sarif)
            FLAGS+=("--format" "sarif")
            ;;
        --*)
            FLAGS+=("$arg")
            ;;
        *)
            PATHS+=("$arg")
            ;;
    esac
done

# Default to current directory if no paths given
if [ ${#PATHS[@]} -eq 0 ]; then
    PATHS=(".")
fi

exec ast-grep scan \
    --config "$SGCONFIG" \
    "${FLAGS[@]}" \
    "${PATHS[@]}"
