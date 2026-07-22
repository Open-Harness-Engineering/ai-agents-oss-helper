#!/usr/bin/env python3
"""
detect-feedback.py — Deterministic feedback detection on past reviews.

Scans reviewed PRs for feedback signals (dismissed, merged, comments)
and updates learnings.json accordingly. No LLM needed.

Usage:
    python3 detect-feedback.py <upstream-repo> <state-file> <learnings-file> [--days 7]

Example:
    python3 detect-feedback.py jline/jline3 state.json learnings.json

Exit codes:
    0 — feedback detected and learnings updated
    1 — no feedback found
    2 — error

Dependencies: gh CLI, Python 3.8+
"""

import json
import subprocess
import sys
import uuid
from datetime import datetime, timezone, timedelta

def gh_json(args: list[str]) -> any:
    result = subprocess.run(
        ["gh"] + args,
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        return None
    return json.loads(result.stdout) if result.stdout.strip() else None

def parse_iso(ts: str) -> datetime:
    ts = ts.replace("Z", "+00:00")
    return datetime.fromisoformat(ts)

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load_json(path: str, default: dict) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default

def save_json(path: str, data: dict):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

def update_learning(learnings: dict, finding_rule: str, file_pattern: str,
                    signal: str, pr_number: int, pattern_desc: str) -> dict:
    """Update or create a learning based on feedback signal."""
    # Find existing
    existing = None
    for l in learnings.get("learnings", []):
        if l.get("source", {}).get("finding_rule") == finding_rule and \
           l.get("source", {}).get("file_pattern", "") == file_pattern:
            existing = l
            break

    if existing:
        if signal == "accepted":
            existing["confidence"] = min(1.0, existing["confidence"] + 0.15)
            existing["type"] = "accepted"
        elif signal == "rejected":
            existing["confidence"] = max(0.0, existing["confidence"] - 0.25)
            existing["type"] = "rejected"

        existing["occurrences"] = existing.get("occurrences", 1) + 1
        existing["last_seen"] = now_iso()

        # Auto-suppress
        if existing["confidence"] < 0.1 and existing["occurrences"] >= 3:
            existing["suppressed"] = True
    else:
        entry = {
            "id": str(uuid.uuid4()),
            "type": signal,
            "source": {
                "pr": pr_number,
                "review_date": now_iso(),
                "finding_rule": finding_rule,
                "file_pattern": file_pattern,
            },
            "pattern": pattern_desc,
            "action": "flag as issue" if signal == "accepted" else "suppress — dismissed by maintainer",
            "confidence": 0.65 if signal == "accepted" else 0.25,
            "occurrences": 1,
            "last_seen": now_iso(),
            "suppressed": False,
        }
        learnings.setdefault("learnings", []).append(entry)

    return learnings

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Detect review feedback")
    parser.add_argument("repo", help="Upstream org/repo")
    parser.add_argument("state_file", help="Path to state.json")
    parser.add_argument("learnings_file", help="Path to learnings.json")
    parser.add_argument("--days", type=int, default=7, help="Look back N days")
    args = parser.parse_args()

    state = load_json(args.state_file, {"reviewed_prs": []})
    learnings = load_json(args.learnings_file, {"version": "1.0", "project": args.repo, "learnings": []})

    cutoff = (datetime.now(timezone.utc) - timedelta(days=args.days)).strftime("%Y-%m-%dT%H:%M:%SZ")
    recent = [p for p in state.get("reviewed_prs", []) if p.get("reviewed_at", "") >= cutoff]

    if not recent:
        print("No recent reviews to check for feedback.")
        sys.exit(1)

    updates = 0

    for pr in recent:
        num = pr["number"]
        review_ts = pr.get("reviewed_at", "")

        # Check our reviews on this PR
        reviews = gh_json([
            "api", f"repos/{args.repo}/pulls/{num}/reviews",
            "--jq", '[.[] | select(.body | contains("AI agent")) | {id: .id, state: .state, body: .body}]'
        ])
        if not reviews:
            continue

        for review in reviews:
            review_state = review.get("state", "")

            if review_state == "DISMISSED":
                # Our review was dismissed — rejected signal
                rule = f"review-{num}"
                learnings = update_learning(
                    learnings, rule, "*",
                    "rejected", num,
                    f"Review on PR #{num} was dismissed"
                )
                updates += 1
                print(f"  PR #{num}: review DISMISSED → rejected")

        # Check if PR was merged
        pr_data = gh_json([
            "pr", "view", str(num), "--repo", args.repo,
            "--json", "state,mergedAt"
        ])
        if pr_data and pr_data.get("state") == "MERGED":
            # Check if our review had findings that were not addressed
            if pr.get("verdict") == "REQUEST_CHANGES":
                rule = f"review-{num}"
                learnings = update_learning(
                    learnings, rule, "*",
                    "rejected", num,
                    f"PR #{num} merged despite REQUEST_CHANGES — findings likely false positives"
                )
                updates += 1
                print(f"  PR #{num}: merged despite REQUEST_CHANGES → rejected")
            elif pr.get("verdict") == "APPROVE":
                rule = f"review-{num}"
                learnings = update_learning(
                    learnings, rule, "*",
                    "accepted", num,
                    f"PR #{num} merged after APPROVE — review aligned with maintainer"
                )
                updates += 1
                print(f"  PR #{num}: merged after APPROVE → accepted")

        # Check for new commits after our review (suggestion applied?)
        if review_ts:
            commits = gh_json([
                "api", f"repos/{args.repo}/pulls/{num}/commits",
                "--jq", f'[.[] | select(.commit.committer.date > "{review_ts}")] | length'
            ])
            if commits and isinstance(commits, int) and commits > 0 and pr.get("verdict") in ("COMMENT", "REQUEST_CHANGES"):
                rule = f"review-{num}"
                learnings = update_learning(
                    learnings, rule, "*",
                    "accepted", num,
                    f"PR #{num} had {commits} commit(s) after review — suggestions likely applied"
                )
                updates += 1
                print(f"  PR #{num}: {commits} commit(s) after review → accepted")

    if updates == 0:
        print("No feedback signals detected.")
        sys.exit(1)

    save_json(args.learnings_file, learnings)
    print(f"\n{updates} learning(s) updated in {args.learnings_file}")
    sys.exit(0)

if __name__ == "__main__":
    main()
