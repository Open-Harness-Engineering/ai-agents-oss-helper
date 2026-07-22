#!/usr/bin/env python3
"""
triage-issues.py — Deterministic issue triage against JSON state.

No LLM needed. Fetches open issues from GitHub (or Jira), filters out
already-handled ones, and outputs actionable issues as JSON.

Usage:
    python3 triage-issues.py <upstream-repo> <state-file> [--max N] [--labels bug,help-wanted]
    python3 triage-issues.py <upstream-repo> <state-file> --jira <project-key>

Exit codes:
    0 — actionable issues found (JSON to stdout)
    1 — no actionable issues
    2 — error

Dependencies: gh CLI in PATH, Python 3.8+
"""

import json
import subprocess
import sys
from datetime import datetime, timezone


def gh_json(args: list[str]):
    """Run gh CLI and parse JSON output."""
    result = subprocess.run(
        ["gh"] + args,
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        return None
    return json.loads(result.stdout) if result.stdout.strip() else None


def load_state(path: str) -> dict:
    """Load state.json, return empty state if missing."""
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"handled_issues": [], "skipped_issues": []}


def parse_iso(ts: str) -> datetime:
    """Parse ISO 8601 timestamp."""
    ts = ts.replace("Z", "+00:00")
    return datetime.fromisoformat(ts)


def fetch_github_issues(repo: str, labels: list[str] | None, limit: int) -> list[dict] | None:
    """Fetch open issues from GitHub."""
    search_parts = ["is:issue", "is:open", "-label:dependencies"]
    if labels:
        for label in labels:
            search_parts.append(f"label:{label}")

    return gh_json([
        "issue", "list", "--repo", repo,
        "--search", " ".join(search_parts),
        "--limit", str(limit),
        "--json", "number,title,author,createdAt,updatedAt,labels,assignees,comments"
    ])


def fetch_jira_issues(project_key: str) -> list[dict] | None:
    """Fetch open issues from Jira via gh CLI (requires Jira MCP or API token)."""
    # This is a placeholder — actual Jira integration depends on the project setup.
    # Most OSS projects use GitHub issues or have a Jira→GitHub mirror.
    print(f"Jira integration for {project_key} not yet implemented.", file=sys.stderr)
    return None


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Deterministic issue triage")
    parser.add_argument("repo", help="Upstream org/repo (e.g. apache/camel)")
    parser.add_argument("state_file", help="Path to state.json")
    parser.add_argument("--max", type=int, default=3, help="Max issues to return")
    parser.add_argument("--labels", type=str, default=None,
                        help="Comma-separated labels to filter (e.g. bug,help-wanted)")
    parser.add_argument("--jira", type=str, default=None,
                        help="Jira project key (e.g. CAMEL)")
    parser.add_argument("--format", choices=["json", "summary"], default="json")
    args = parser.parse_args()

    state = load_state(args.state_file)

    # Build lookup tables
    handled = set()
    for issue in state.get("handled_issues", []):
        handled.add(issue["number"])

    skipped = set()
    for issue in state.get("skipped_issues", []):
        skipped.add(issue["number"])

    # Fetch issues
    label_list = args.labels.split(",") if args.labels else None

    if args.jira:
        issues = fetch_jira_issues(args.jira)
    else:
        issues = fetch_github_issues(args.repo, label_list, limit=50)

    if issues is None:
        print("Failed to fetch issues.", file=sys.stderr)
        sys.exit(2)

    # Filter
    BOT_AUTHORS = {"dependabot", "renovate", "github-actions",
                   "app/dependabot", "app/github-actions"}
    now = datetime.now(timezone.utc)
    actionable = []

    for issue in issues:
        num = issue["number"]
        author = issue.get("author", {}).get("login", "")
        labels = [l.get("name", "") for l in issue.get("labels", [])]
        assignees = [a.get("login", "") for a in issue.get("assignees", [])]

        # Skip bots
        if author in BOT_AUTHORS:
            continue

        # Skip already handled
        if num in handled:
            continue

        # Skip permanently skipped
        if num in skipped:
            continue

        # Skip if already assigned to someone (they're working on it)
        if assignees:
            continue

        # Determine priority
        created_at = issue.get("createdAt", "")
        age_days = 0
        try:
            age_days = (now - parse_iso(created_at)).days
        except (ValueError, TypeError):
            pass

        priority = "low"
        if "bug" in labels or "regression" in labels:
            priority = "high"
        elif "good first issue" in labels or "good-first-issue" in labels:
            priority = "medium"
        elif "help wanted" in labels or "help-wanted" in labels:
            priority = "medium"
        elif age_days > 30:
            priority = "medium"

        actionable.append({
            "number": num,
            "title": issue["title"],
            "author": author,
            "labels": labels,
            "priority": priority,
            "age_days": age_days,
            "comments": issue.get("comments", 0),
        })

    # Sort by priority
    priority_order = {"high": 0, "medium": 1, "low": 2}
    actionable.sort(key=lambda x: (priority_order.get(x["priority"], 3), -x["age_days"]))

    # Limit
    actionable = actionable[:args.max]

    if not actionable:
        print("No actionable issues.", file=sys.stderr)
        sys.exit(1)

    # Output
    if args.format == "summary":
        print(f"{len(actionable)} actionable issue(s):")
        for issue in actionable:
            labels_str = ", ".join(issue["labels"][:3]) if issue["labels"] else "-"
            print(f"  #{issue['number']} [{issue['priority']}] {issue['title'][:60]} ({labels_str})")
    else:
        json.dump(actionable, sys.stdout, indent=2)
        print()

    sys.exit(0)
