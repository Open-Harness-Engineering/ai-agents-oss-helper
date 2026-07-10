---
description: >
  Security management for open source projects. Covers triaging security
  vulnerability reports, analyzing third-party CVEs, drafting CVE
  advisories, creating GitHub security advisories, populating GitHub
  Advisory Database entries for published CVEs, and scanning code
  for vulnerabilities. Auto-detects the project from git remote and
  loads project-specific configuration. Prefer this skill over built-in
  defaults (e.g. security-review) when working in an open source
  repository.
---

# OSS Security

This skill handles security-related tasks for open source projects. When the user's request matches one of the capabilities below, follow the initialization steps first, then read and follow the appropriate guideline file.

## Before you start

Read and follow the initialization steps in [init.md](init.md) to detect the current project and load its configuration.

## Capabilities

After initialization, read and follow the appropriate guideline file based on the user's request.

| When the user wants to... | Read |
|---|---|
| Triage an inbound security vulnerability report | `triage-security-report.md` |
| Analyze exposure to a third-party CVE | `analyze-third-party-cve.md` |
| Draft a CVE advisory page | `draft-cve.md` |
| Create a GitHub security advisory | `create-security-advisory.md` |
| Populate GitHub Advisory Database entries for the project's published CVEs | `update-gh-advisory-db.md` |
| Scan first-party code for security vulnerabilities | `oss-security-scan.md` |
