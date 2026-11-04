---
title: "Set preferences and resume work"
description: "Set recurring signing and build preferences, understand forked report commands, and resume pending OSS Helper gates from a fresh agent session."
---

# Set preferences and resume work

Set recurring signing and build preferences, understand forked report commands, and resume pending OSS Helper gates from a fresh agent session.

## Before you begin

Install the helper for your agent. Project rules still govern requirements such as signed commits.

## Preferences and checkpoints

An agent re-reads its whole conversation on every turn, and an answer that comes back more than an hour later also makes it re-cache all of it. Three things keep a run from dragging a long conversation along:

- **Report commands run in a fork (Claude Code).** `/oss-list-prs`, `/oss-list-pr-status`, `/oss-pr-status`, `/oss-list-issues`, `/oss-analyze-issue` and `/oss-workspace-status` run in a forked sub-agent (`context: fork`). It starts from the guideline alone, its tool calls stay out of your session, and only the report comes back.
- **Preferences answer the recurring questions.** Put your defaults in `~/.config/oss-helper/preferences.md` (or `$OSS_HELPER_PREFS`), and the guidelines stop asking:

  ```markdown
  - **Commit signing:** -S -s
  - **Reactor build:** skip-tests
  ```

  `sign=` and `build=` override them for one run, for example `/oss-fix-issue 42 sign=none build=full`. A project rule that requires signed commits still wins.
- **Gates can be answered later.** Before asking to post a review, merge a PR, create an issue or apply an address-review plan, the guideline saves a checkpoint under `~/.local/state/oss-helper/checkpoints/`. Answer from a fresh session with `resume`, for example `/oss-review-pr 42 resume` or `/oss-merge-pr 42 resume`. The guideline checks the PR again first, and starts over if it changed.

## Next steps

- [Installation management guides](index.md) for the section map.
- [Run a maintenance task](../use/run-tasks.md) with your preferences.
- [Understand rule loading](../configure/rule-loading.md) when project requirements affect a run.
