# Issue Ownership Guard Fragment

**DO NOT INVOKE THIS FRAGMENT DIRECTLY.** This fragment is referenced by the issue flows (fix, find-task, list, analyze, triage, multi-repo) to decide whether an issue may be picked up.

## Purpose

This fragment defines the ownership check every issue flow must apply **before claiming an issue** — that is, before assigning it to the operator, transitioning it to *In Progress*, or starting a fix. It exists to avoid stepping on other contributors and duplicating work already under way.

## The Rule

An issue may be worked on **only when both** of the following hold:

1. **Assignee is clear** — the issue is *Unassigned* or already assigned to the operator (per the existing ticket-ownership guideline). Never take an issue assigned to someone else.
2. **No one else has claimed it in the comments** — no comment from a person **other than the operator** indicates that another contributor is working on it, intends to work on it, or has asked for it.

Both conditions must pass. **The assignee field alone is not sufficient**: an issue can still show a default or maintainer assignee (including the operator) while a community contributor has volunteered in the comments. When the comments say someone else is taking it, the comment wins — leave the issue for them.

### Comment signals that mean "hands off"

Treat a comment from anyone other than the operator as a claim when it expresses intent to work on the issue, for example:

- "let me work on this" / "I'll take this" / "I can pick this up"
- "working on a PR" / "I'll open a PR" / "PR incoming"
- "please assign this to me" / "assign to me" / "can I take this?"
- any linked in-progress PR or fork branch opened by another contributor

A comment that only adds **context, a question answered by the operator, or analysis** is *not* a claim and does not block work. Use judgement: the test is whether another person is signalling they are (or are about to be) doing the work.

## How to Check

Fetch the comments (and the assignee) together with the issue details, in the **same** retrieval — do not add extra API round-trips:

- **GitHub:** `gh issue view <ISSUE_NUMBER> --repo <GITHUB_REPO> --json number,title,body,state,labels,assignees,comments`
- **Jira:** add `comment` and `assignee` to the fetched fields, e.g. `.../issue/<ISSUE_ID>?fields=summary,status,assignee,comment,...`

Then filter the comments to authors **other than the operator** and inspect them for the claim signals above.

## What To Do When The Guard Fails

If the guard fails (assigned to someone else, or a third-party comment has claimed it):

- **Do not** assign yourself, transition the status, or start a fix.
- **Leave the issue's state untouched.** If you already transitioned it in error (e.g. *Start Progress*), revert it (*Stop Progress* / back to its previous status) so the issue is left exactly as you found it.
- In a **single-issue** flow (fix, analyze), stop and report that the issue is already claimed, naming who claimed it and where (assignee or comment author).
- In a **selection** flow (find-task, list), exclude the issue from the actionable set — or flag it clearly as *claimed* — and move on to the next candidate.

This guard complements, and never overrides, the project's existing "only pick up Unassigned tickets" ticket-ownership guideline.
