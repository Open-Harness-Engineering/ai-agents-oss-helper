# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-26

First tagged release. Captures the existing feature set at the point versioning
was introduced.

### Added

- Guidelines for AI coding agents (Claude, Bob, Gemini, OpenCode, Codex, agy)
  contributing to open source projects, with project auto-detection from the
  git remote (`git remote get-url origin`).
- Six user-invocable skills grouping 37 guidelines: `oss-issues`, `oss-review`,
  `oss-ci`, `oss-security`, `oss-project` and `oss-qe`.
- `install.sh` installer supporting all six agents, individually or together.
- Project-local rule files (`.oss-ai-helper-rules/`), with installed-rule and
  auto-discovery fallbacks.
- Helper scripts for deterministic steps (`oss-init.sh`, `pr-report.sh`,
  `skip-list.sh`).
- Claude Code workflow for driving a security report end to end
  (`workflows/oss-security-case.js`).
- Apache-2.0 `LICENSE` and `NOTICE` files.

[Unreleased]: https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/releases/tag/v1.0.0
