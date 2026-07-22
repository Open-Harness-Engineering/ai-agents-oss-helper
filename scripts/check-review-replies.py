#!/usr/bin/env python3
"""
check-review-replies.py — Detect unanswered replies to our review comments.

Scans PRs we reviewed for replies to OUR inline comments or review body
that we haven't responded to yet. These are questions/discussions directed
at us that need a response.

This is the "outbound babysitting" side — someone replied to our review
and is waiting for an answer.

Usage:
    python3 check-review-replies.py <upstream-repo> <state-file> [--days 14]

Output (JSON to stdout):
    [
      {
        "pr": 2107,
        "title": "fix: clamp truecolor SGR",
        "thread_id": 12345,
        "our_comment": "This could overflow if...",
        "reply_author": "uchiha-bug-hunter",
        "reply_body": "Good point, but what about...",
        "reply_at": "2026-07-20T15:00:00Z",
        "type": "question"  // question | acknowledgment | disagreement
      }
    ]

Exit codes:
    0 — unanswered replies found
    1 — no unanswered replies
    2 — error

Dependencies: gh CLI, Python 3.8+
"""

import json
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta

AI_MARKER = "AI agent"
ACKNOWLEDGMENT_PATTERNS = [
    r"(?i)\b(thanks|thank you|done|fixed|applied|good catch|will do|addressed)\b"
]
QUESTION_PATTERNS = [
    r"\?$", r"(?i)\b(why|how|what|could you|can you|should we|do you mean)\b"
]

def gh_json(args: list[str]) -> any:
    result = subprocess.run(
        ["gh"] + args,
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        return None
    out = result.stdout.strip()
    if not out:
        return None
    return json.loads(out)

def load_state(path: str) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"reviewed_prs": []}

def classify_reply(body: str) -> str:
    """Classify a reply as question, acknowledgment, or disagreement."""
    body = body.strip()
    for pat in QUESTION_PATTERNS:
        if re.search(pat, body):
            return "question"
    for pat in ACKNOWLEDGMENT_PATTERNS:
        if re.search(pat, body):
            return "acknowledgment"
    return "disagreement"

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Check for replies to our reviews")
    parser.add_argument("repo", help="Upstream org/repo")
    parser.add_argument("state_file", help="Path to state.json")
    parser.add_argument("--days", type=int, default=14, help="Look back N days")
    args = parser.parse_args()

    state = load_state(args.state_file)
    cutoff = (datetime.now(timezone.utc) - timedelta(days=args.days)).strftime("%Y-%m-%dT%H:%M:%SZ")

    recent = [p for p in state.get("reviewed_prs", []) if p.get("reviewed_at", "") >= cutoff]
    if not recent:
        sys.exit(1)

    unanswered = []

    for pr_entry in recent:
        num = pr_entry["number"]
        review_ts = pr_entry.get("reviewed_at", "")

        # Get all review comments (inline) on this PR
        comments = gh_json([
            "api", f"repos/{args.repo}/pulls/{num}/comments",
            "--paginate",
            "--jq", "."
        ])
        if not comments or not isinstance(comments, list):
            continue

        # Find OUR comments (contain AI marker)
        our_comment_ids = set()
        our_comments = {}
        for c in comments:
            if AI_MARKER in (c.get("body") or ""):
                our_comment_ids.add(c["id"])
                our_comments[c["id"]] = c

        if not our_comment_ids:
            continue

        # Find replies to our comments (in_reply_to_id points to ours)
        for c in comments:
            reply_to = c.get("in_reply_to_id")
            if reply_to and reply_to in our_comment_ids:
                # Is this reply from someone else (not us)?
                reply_body = c.get("body", "")
                if AI_MARKER in reply_body:
                    continue  # Our own follow-up

                # Check if we already replied after this reply
                reply_created = c.get("created_at", "")
                already_responded = False
                for c2 in comments:
                    if (c2.get("in_reply_to_id") == reply_to and
                        AI_MARKER in (c2.get("body") or "") and
                        c2.get("created_at", "") > reply_created):
                        already_responded = True
                        break

                if not already_responded:
                    unanswered.append({
                        "pr": num,
                        "title": pr_entry.get("title", ""),
                        "thread_id": reply_to,
                        "our_comment": (our_comments[reply_to].get("body", ""))[:200],
                        "reply_author": c.get("user", {}).get("login", ""),
                        "reply_body": reply_body,
                        "reply_at": reply_created,
                        "type": classify_reply(reply_body),
                    })

        # Also check issue comments (general PR discussion)
        issue_comments = gh_json([
            "api", f"repos/{args.repo}/issues/{num}/comments",
            "--jq", f'[.[] | select(.created_at > "{review_ts}")]'
        ])
        if issue_comments and isinstance(issue_comments, list):
            for c in issue_comments:
                body = c.get("body", "")
                author = c.get("user", {}).get("login", "")
                # Skip our own comments
                if AI_MARKER in body:
                    continue
                # Check if this mentions us or is a question about the review
                if any(kw in body.lower() for kw in ["@", "review", "suggestion", "your comment"]):
                    unanswered.append({
                        "pr": num,
                        "title": pr_entry.get("title", ""),
                        "thread_id": c["id"],
                        "our_comment": "(general PR discussion)",
                        "reply_author": author,
                        "reply_body": body[:500],
                        "reply_at": c.get("created_at", ""),
                        "type": classify_reply(body),
                    })

    if not unanswered:
        sys.exit(1)

    # Sort: questions first, then by date
    type_order = {"question": 0, "disagreement": 1, "acknowledgment": 2}
    unanswered.sort(key=lambda x: (type_order.get(x["type"], 9), x["reply_at"]))

    json.dump(unanswered, sys.stdout, indent=2)
    print()
    sys.exit(0)

if __name__ == "__main__":
    main()
