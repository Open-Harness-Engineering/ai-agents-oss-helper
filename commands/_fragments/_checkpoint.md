# Checkpoint Fragment

**DO NOT INVOKE THIS FRAGMENT DIRECTLY.** Guidelines reference it at a gate: the point where they stop and ask the operator before a public action, such as posting a review, merging, creating an issue or pushing changes.

## Purpose

The answer to a gate often comes hours later. Answering in the same session then makes the agent re-read, and after an hour re-cache, the whole conversation, which is often hundreds of thousands of tokens. A checkpoint saves what the gate needs, so the operator can answer later from a fresh session instead:

```text
/oss-<command> <id> resume
```

## Writing a Checkpoint

Right before asking the gate question, write the checkpoint:

- **Directory:** `${XDG_STATE_HOME:-$HOME/.local/state}/oss-helper/checkpoints/<org>__<repo>/`. Create it with `mkdir -p`, then `chmod 700` it: a checkpoint holds text that is not public yet.
- **File:** `<guideline>-<id>.md`, with the id the guideline names (for example `review-pr-42.md` or `merge-pr-42.md`). Write it with `umask 077`. A newer checkpoint for the same id replaces the older one.
- **Content:**

  ```markdown
  # Checkpoint: <guideline> <id>

  - **Repository:** <org>/<repo>
  - **Created:** <UTC timestamp>
  - **Guideline:** <guideline file>
  - **Target:** <PR #N, issue, or branch>
  - **State at checkpoint:** <the facts that must still hold, such as the PR's head SHA and state>

  ## Pending action

  <exactly what will run on approval: every command with every argument>

  ## Text to post

  <the exact text, verbatim, when the action posts text>

  ## Question

  <the gate question, with its options>
  ```

Text too long to keep inline (review bodies, for example) goes into files next to the checkpoint, named after it (`review-prs-1.md`, ...), and the checkpoint lists them.

After the gate question, add one line:

> You can also answer later from a fresh session: `/oss-<command> <id> resume`.

Agents without slash commands say instead: run the `<guideline>` guideline with `<id> resume`.

Never write a checkpoint into the repository or anywhere public. Embargoed security material does not go into checkpoints: the security guidelines keep their own case directories.

## Resuming

When a guideline that supports checkpoints is invoked with `resume`:

1. Initialize as usual, then read the checkpoint `<guideline>-<id>.md`. Without an id, list that guideline's checkpoints for the repository: use the only one, or ask which one. If there is none, say so and run the guideline from the start.
2. Check the **State at checkpoint** against the live state, for example with `gh pr view <N> --json state,headRefOid,mergeable,reviewDecision`, plus the checks the guideline names for its resume. If anything changed (new commits, the PR closed or merged, the text already posted), report the difference and run the guideline from the start: never act on a stale checkpoint.
3. Otherwise show the pending action and the text, ask the gate question again, and act on the answer exactly as the guideline's gate step says.
4. Delete the checkpoint and its files after acting, or once the operator declines for good.

## Housekeeping

When the gate is passed in the original session, delete the checkpoint there too. Delete any checkpoint older than 30 days that you come across: it is stale.

## Version

1.0.0
