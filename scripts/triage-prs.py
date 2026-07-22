#!/usr/bin/env python3
"""
triage-prs.py — Deterministic PR triage against JSON state.

No LLM needed. Reads state.json, fetches open PRs from GitHub,
checks for new comments/activity since last review, and outputs
actionable PRs as JSON to stdout.

Usage:
    python3 triage-prs.py <upstream-repo> <state-file> [--max N] [--format json|summary]

Example:
    python3 triage-prs.py jline/jline3 state.json --max 3
    python3 triage-prs.py apache/camel state.json --format summary

Exit codes:
    0 — actionable PRs found (output to stdout)
    1 — no actionable PRs
    2 — error

Dependencies: gh CLI in PATH, Python 3.8+
"""

import json
import subprocess
import sys
from datetime import datetime, timezone

def gh_json(args: list[str]) -> any:
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
        return {"reviewed_prs": [], "skipped_prs": []}

def has_other_ai_review(repo: str, pr_number: int, operator: str) -> bool:
    """Check if another AI agent (not ours) already reviewed this PR
    AND the PR has not been updated since that review.

    Detects reviews from other Claude Code operators by looking for the
    AI disclaimer pattern. Skips reviews from our own operator to avoid
    self-exclusion. Does NOT skip CodeRabbit/Copilot (complementary tools).

    Returns False (= don't skip) if the PR has new commits after the
    latest AI review — the previous review may be stale and we can take over.
    """
    reviews = gh_json([
        "api", f"repos/{repo}/pulls/{pr_number}/reviews",
        "--jq", '[.[] | {login: .user.login, body: .body, submitted_at: .submitted_at}]'
    ])
    if not reviews or not isinstance(reviews, list):
        return False

    # Find the latest AI review from another operator
    latest_ai_review_ts = None
    for r in reviews:
        body = r.get("body", "") or ""
        login = r.get("login", "") or ""
        submitted = r.get("submitted_at", "") or ""
        if "AI agent" in body and "Claude Code" in body and login != operator:
            if latest_ai_review_ts is None or submitted > latest_ai_review_ts:
                latest_ai_review_ts = submitted

    if not latest_ai_review_ts:
        return False

    # Check if there are new commits after the AI review
    latest_commit_date = gh_json([
        "api", f"repos/{repo}/pulls/{pr_number}/commits",
        "--jq", '.[-1].commit.committer.date'
    ])
    if latest_commit_date and isinstance(latest_commit_date, str):
        if latest_commit_date > latest_ai_review_ts:
            return False  # New commits since AI review — we can review

    # Check if there are new comments after the AI review
    new_comments = gh_json([
        "api", f"repos/{repo}/issues/{pr_number}/comments",
        "--jq", f'[.[] | select(.created_at > "{latest_ai_review_ts}")] | length'
    ])
    if new_comments and isinstance(new_comments, int) and new_comments > 0:
        return False  # New comments since AI review — we can review

    return True  # AI review exists, no new activity — skip

def parse_iso(ts: str) -> datetime:
    """Parse ISO 8601 timestamp."""
    ts = ts.replace("Z", "+00:00")
    return datetime.fromisoformat(ts)

def check_new_comments(repo: str, pr_number: int, since: str) -> dict:
    """Check for new comments on a PR since a timestamp.

    Checks THREE sources (all via single API calls each):
    1. Review comments (inline on diff)
    2. Issue comments (general PR discussion)
    3. New reviews submitted

    Returns {has_activity: bool, new_comments: int, new_reviews: int,
             latest_commit_after: bool, reason: str}
    """
    result = {"has_activity": False, "new_comments": 0, "new_reviews": 0,
              "latest_commit_after": False, "reason": ""}

    # 1. Review comments (inline on diff lines)
    review_comments = gh_json([
        "api", f"repos/{repo}/pulls/{pr_number}/comments",
        "--jq", f'[.[] | select(.created_at > "{since}")] | length'
    ])
    if review_comments and isinstance(review_comments, int) and review_comments > 0:
        result["new_comments"] += review_comments
        result["has_activity"] = True

    # 2. Issue comments (general discussion on the PR)
    issue_comments = gh_json([
        "api", f"repos/{repo}/issues/{pr_number}/comments",
        "--jq", f'[.[] | select(.created_at > "{since}")] | length'
    ])
    if issue_comments and isinstance(issue_comments, int) and issue_comments > 0:
        result["new_comments"] += issue_comments
        result["has_activity"] = True

    # 3. New reviews submitted (approvals, change requests, comments)
    new_reviews = gh_json([
        "api", f"repos/{repo}/pulls/{pr_number}/reviews",
        "--jq", f'[.[] | select(.submitted_at > "{since}") | select(.body | contains("AI agent") | not)] | length'
    ])
    if new_reviews and isinstance(new_reviews, int) and new_reviews > 0:
        result["new_reviews"] = new_reviews
        result["has_activity"] = True

    # 4. New commits (author pushed changes)
    latest_commit_date = gh_json([
        "api", f"repos/{repo}/pulls/{pr_number}/commits",
        "--jq", '.[-1].commit.committer.date'
    ])
    if latest_commit_date and isinstance(latest_commit_date, str):
        try:
            if parse_iso(latest_commit_date) > parse_iso(since):
                result["latest_commit_after"] = True
                result["has_activity"] = True
        except (ValueError, TypeError):
            pass

    # Build reason string
    reasons = []
    if result["latest_commit_after"]:
        reasons.append("new commits")
    if result["new_comments"] > 0:
        reasons.append(f"{result['new_comments']} new comment(s)")
    if result["new_reviews"] > 0:
        reasons.append(f"{result['new_reviews']} new review(s)")
    result["reason"] = ", ".join(reasons)

    return result

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Deterministic PR triage")
    parser.add_argument("repo", help="Upstream org/repo (e.g. jline/jline3)")
    parser.add_argument("state_file", help="Path to state.json")
    parser.add_argument("--max", type=int, default=3, help="Max PRs to return")
    parser.add_argument("--format", choices=["json", "summary"], default="json")
    args = parser.parse_args()

    state = load_state(args.state_file)

    # Detect operator's GitHub login (to exclude our own AI reviews from the check)
    operator = state.get("operator_login", "")
    if not operator:
        result = subprocess.run(
            ["gh", "api", "user", "--jq", ".login"],
            capture_output=True, text=True, timeout=10
        )
        operator = result.stdout.strip() if result.returncode == 0 else ""

    # Build lookup tables from state
    reviewed = {}  # pr_number -> {reviewed_at, verdict, ...}
    for pr in state.get("reviewed_prs", []):
        reviewed[pr["number"]] = pr

    skipped = set()
    for pr in state.get("skipped_prs", []):
        skipped.add(pr["number"])

    # Fetch open PRs
    prs = gh_json([
        "pr", "list", "--repo", args.repo,
        "--search", "is:pr is:open -is:draft",
        "--limit", "50",
        "--json", "number,title,author,createdAt,updatedAt,labels,reviewDecision,additions,deletions,changedFiles"
    ])
    if prs is None:
        sys.exit(2)

    # Filter
    BOT_AUTHORS = {"dependabot", "renovate", "github-actions",
                   "app/dependabot", "app/github-actions"}
    now = datetime.now(timezone.utc)
    actionable = []

    for pr in prs:
        num = pr["number"]
        author = pr.get("author", {}).get("login", "")
        is_bot = pr.get("author", {}).get("is_bot", False)
        labels = [l.get("name", "") for l in pr.get("labels", [])]
        updated_at = pr.get("updatedAt", "")

        # Skip bots
        if author in BOT_AUTHORS or is_bot:
            continue

        # Skip dependency-only PRs
        if "dependencies" in labels:
            continue

        # Skip permanently skipped
        if num in skipped:
            continue

        # Skip PRs already reviewed by another Claude Code operator
        if num not in reviewed and has_other_ai_review(args.repo, num, operator):
            continue

        # Check if already reviewed
        re_review = False
        re_review_reason = ""
        if num in reviewed:
            review_ts = reviewed[num].get("reviewed_at", "")
            if not review_ts:
                continue

            # Check for ANY new activity since our review:
            # comments, reviews from others, new commits
            activity = check_new_comments(args.repo, num, review_ts)
            if not activity["has_activity"]:
                continue  # Nothing new — skip

            re_review = True
            re_review_reason = activity["reason"]

        # Determine priority
        review_decision = pr.get("reviewDecision", "")
        created_at = pr.get("createdAt", "")
        age_days = 0
        try:
            age_days = (now - parse_iso(created_at)).days
        except (ValueError, TypeError):
            pass

        if re_review:
            # Re-reviews are always high priority — someone is waiting
            priority = "high"
        elif review_decision == "REVIEW_REQUIRED" or age_days > 7:
            priority = "high"
        elif updated_at and (now - parse_iso(updated_at)).days < 2:
            priority = "medium"
        else:
            priority = "low"

        actionable.append({
            "number": num,
            "title": pr["title"],
            "author": author,
            "priority": priority,
            "age_days": age_days,
            "additions": pr.get("additions", 0),
            "deletions": pr.get("deletions", 0),
            "changed_files": pr.get("changedFiles", 0),
            "review_decision": review_decision,
            "updated_at": updated_at,
            "is_re_review": re_review,
            "re_review_reason": re_review_reason,
        })

    # Sort: high > medium > low, then by age (oldest first)
    priority_order = {"high": 0, "medium": 1, "low": 2}
    actionable.sort(key=lambda x: (priority_order.get(x["priority"], 9), -x["age_days"]))

    # Limit
    actionable = actionable[:args.max]

    if not actionable:
        if args.format == "summary":
            print("No actionable PRs found.")
        sys.exit(1)

    if args.format == "json":
        json.dump(actionable, sys.stdout, indent=2)
        print()
    else:
        print(f"{len(actionable)} PR(s) need review:")
        for pr in actionable:
            re = f" (re-review: {pr['re_review_reason']})" if pr["is_re_review"] else ""
            print(f"  #{pr['number']} [{pr['priority']}] {pr['title']} — {pr['author']}{re}")

    sys.exit(0)

if __name__ == "__main__":
    main()
