#!/usr/bin/env python3
"""
update-state.py — Deterministic state updates for the review loop.

Updates state.json after a review is posted. No LLM needed.

Usage:
    # Record a review
    python3 update-state.py state.json reviewed \\
        --pr 2107 \\
        --title "fix: clamp out-of-range truecolor SGR" \\
        --author uchiha-bug-hunter \\
        --verdict APPROVE \\
        --notes "Bit-overflow fix. Good test."

    # Skip a PR
    python3 update-state.py state.json skip \\
        --pr 2084 \\
        --reason "Bot PR (dependabot)"

    # Record a run
    python3 update-state.py state.json run \\
        --prs-checked 5 \\
        --reviews-posted 2 \\
        --tokens 52000

    # Pause/unpause
    python3 update-state.py state.json pause
    python3 update-state.py state.json unpause

    # Prune old entries (resolved > 30 days, runs > 30 days)
    python3 update-state.py state.json prune

Exit codes: 0 success, 1 error
Dependencies: Python 3.8+
"""

import json
import sys
from datetime import datetime, timezone, timedelta

def load_state(path: str) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "version": "1.0",
            "project": "",
            "last_run": None,
            "reviewed_prs": [],
            "skipped_prs": [],
            "review_queue": [],
            "paused": False,
            "created_at": now_iso()
        }

def save_state(path: str, state: dict):
    with open(path, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def cmd_reviewed(state: dict, args) -> dict:
    """Record a reviewed PR. Preserves interaction history for babysitting."""
    now = now_iso()

    # Find existing entry to preserve history
    existing_idx = None
    existing_entry = None
    for i, p in enumerate(state["reviewed_prs"]):
        if p["number"] == args.pr:
            existing_idx = i
            existing_entry = p
            break

    # Build interaction record
    interaction = {
        "at": now,
        "verdict": args.verdict.upper(),
        "notes": args.notes or "",
    }

    if existing_entry:
        # Append to interaction history
        history = existing_entry.get("interactions", [])
        # If no history yet, seed it from the old flat fields
        if not history and existing_entry.get("reviewed_at"):
            history.append({
                "at": existing_entry["reviewed_at"],
                "verdict": existing_entry.get("verdict", ""),
                "notes": existing_entry.get("notes", ""),
            })
        history.append(interaction)

        existing_entry.update({
            "reviewed_at": now,
            "verdict": args.verdict.upper(),
            "notes": args.notes or "",
            "interactions": history,
            "review_count": len(history),
        })
    else:
        entry = {
            "number": args.pr,
            "title": args.title or "",
            "author": args.author or "",
            "reviewed_at": now,
            "verdict": args.verdict.upper(),
            "notes": args.notes or "",
            "interactions": [interaction],
            "review_count": 1,
        }
        state["reviewed_prs"].append(entry)

    # Remove from queue if present
    state["review_queue"] = [p for p in state.get("review_queue", []) if p.get("number") != args.pr]

    return state

def cmd_skip(state: dict, args) -> dict:
    """Skip a PR permanently."""
    entry = {
        "number": args.pr,
        "reason": args.reason or "",
        "since": now_iso()
    }

    existing = [i for i, p in enumerate(state["skipped_prs"]) if p["number"] == args.pr]
    if existing:
        state["skipped_prs"][existing[0]] = entry
    else:
        state["skipped_prs"].append(entry)

    return state

def cmd_run(state: dict, args) -> dict:
    """Record a loop run."""
    state["last_run"] = {
        "timestamp": now_iso(),
        "prs_checked": args.prs_checked or 0,
        "reviews_posted": args.reviews_posted or 0,
        "tokens_estimate": args.tokens or 0
    }
    return state

def cmd_pause(state: dict, _args) -> dict:
    state["paused"] = True
    return state

def cmd_unpause(state: dict, _args) -> dict:
    state["paused"] = False
    return state

def cmd_prune(state: dict, _args) -> dict:
    """Prune old reviewed PRs (> 90 days) and old skipped PRs (> 90 days)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=90)).strftime("%Y-%m-%dT%H:%M:%SZ")

    before_reviewed = len(state["reviewed_prs"])
    state["reviewed_prs"] = [
        p for p in state["reviewed_prs"]
        if p.get("reviewed_at", "") >= cutoff
    ]
    pruned_reviewed = before_reviewed - len(state["reviewed_prs"])

    if pruned_reviewed > 0:
        print(f"Pruned {pruned_reviewed} reviewed PR(s) older than 90 days")

    return state

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Deterministic state updates")
    parser.add_argument("state_file", help="Path to state.json")
    sub = parser.add_subparsers(dest="command", required=True)

    p_rev = sub.add_parser("reviewed", help="Record a reviewed PR")
    p_rev.add_argument("--pr", type=int, required=True)
    p_rev.add_argument("--title", default="")
    p_rev.add_argument("--author", default="")
    p_rev.add_argument("--verdict", required=True, choices=["APPROVE", "COMMENT", "REQUEST_CHANGES"])
    p_rev.add_argument("--notes", default="")

    p_skip = sub.add_parser("skip", help="Skip a PR")
    p_skip.add_argument("--pr", type=int, required=True)
    p_skip.add_argument("--reason", default="")

    p_run = sub.add_parser("run", help="Record a loop run")
    p_run.add_argument("--prs-checked", type=int, default=0)
    p_run.add_argument("--reviews-posted", type=int, default=0)
    p_run.add_argument("--tokens", type=int, default=0)

    sub.add_parser("pause", help="Activate kill switch")
    sub.add_parser("unpause", help="Deactivate kill switch")
    sub.add_parser("prune", help="Prune old entries")

    args = parser.parse_args()
    state = load_state(args.state_file)

    handlers = {
        "reviewed": cmd_reviewed,
        "skip": cmd_skip,
        "run": cmd_run,
        "pause": cmd_pause,
        "unpause": cmd_unpause,
        "prune": cmd_prune,
    }

    state = handlers[args.command](state, args)
    save_state(args.state_file, state)

if __name__ == "__main__":
    main()
