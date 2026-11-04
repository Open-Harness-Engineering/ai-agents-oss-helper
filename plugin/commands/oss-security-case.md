---
disable-model-invocation: true
description: "Drive a security report through triage, reply, CVE, issue, fix, backports and CVE draft"
---

Read and follow the guideline in `${CLAUDE_PLUGIN_ROOT}/skills/oss-security/security-case.md`. In workflow mode (its step 2), skip the skill's initialization steps: the workflow's loader resolves the project and its rules itself. In manual mode, first follow the initialization steps in `${CLAUDE_PLUGIN_ROOT}/skills/oss-security/init.md`.
