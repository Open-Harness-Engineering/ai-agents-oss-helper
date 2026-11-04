---
disable-model-invocation: true
description: "List issues assigned to you"
context: fork
background: false
---

Read and follow the initialization steps in `${CLAUDE_PLUGIN_ROOT}/skills/oss-issues/init.md` to detect the current project and load its configuration. Then read and follow the guideline in `${CLAUDE_PLUGIN_ROOT}/skills/oss-issues/list-issues.md`.

Arguments: $ARGUMENTS

You run in a forked context: a fresh sub-agent that sees none of the conversation that started you, and whose tool calls stay out of it. Your final message is all the user sees, so make it the complete report the guideline describes. You cannot ask questions while you work: where the guideline asks the user to choose or to answer, end the report with that question, and the conversation that started you takes the answer.
