---
title: "Drive a security case"
description: "Follow the security-report example through triage, CVE and issue gates, fixes, backports and advisory drafts while retaining maintainer decisions."
---

# Drive a security case

Follow the security-report example through triage, CVE and issue gates, fixes, backports and advisory drafts while retaining maintainer decisions.

## Before you begin

Read the [security-case guideline](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/skills/oss-security/security-case.md) and your project’s `project-security.md` before starting.

## Start and advance a case

```text
# Start a case from a report file; it stops at the verdict gate:
/oss-security-case xml-entities report=/path/to/report.txt

# Each later run records your decisions and approvals, and advances to the next gate:
/oss-security-case xml-entities verdict=VALID approve=issue
/oss-security-case xml-entities cve=CVE-2026-12345 approve=pr
/oss-security-case xml-entities done=reply approve=backports

# Once every fixed version is released, the next run drafts the advisory and the CVE record,
# kept in the case directory and archived only to your private draft repository, if you set one:
/oss-security-case xml-entities
```

Every run leaves a `STATUS.md` in the private case directory listing what is done, what waits on you, and the next command. Nothing is sent, reserved, merged, signed or published by the agent: those stay maintainer actions. The project's `project-security.md` supplies the CNA, the advisory template and the supported lines; see the [security-case guideline](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/skills/oss-security/security-case.md) for the other settings.

Each node is a separate subagent. The mechanical ones (the loader, the persistence step, the issue creation, the final reply and the PR publishing) run on cheaper models; pass `economy=off` to run everything on the session model. The loader starts from `security-case-probe.sh`, a read-only script installed with the skill that prints the clone facts, the rule files, the environment, the operator preferences and the case files, with the node files reduced to the fields the workflow routes on; run it by hand to see what the workflow will read.

## Next steps

- [Maintenance task guides](index.md) for the section map.
- [Look up security commands](../reference/commands.md) for related tasks.
- [Set preferences and resume work](../manage/preferences.md) for recurring choices and pending gates.
