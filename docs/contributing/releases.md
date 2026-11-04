---
title: "Prepare releases and versions"
description: "Understand marketplace tracking, intentional version omissions, generated package versions and the tag-driven GitHub release process before a release."
---

# Prepare releases and versions

Understand marketplace tracking, intentional version omissions, generated package versions and the tag-driven GitHub release process before a release.

## Before you begin

Use [Build bundles locally](build-locally.md) and include regenerated assets in the source checkout.

## Version and release policy

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Notable changes are recorded in [`CHANGELOG.md`](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/CHANGELOG.md).

The marketplaces track `main`. The Claude manifest and Claude marketplace entry
intentionally omit `version`, so Claude uses the installed directory's commit SHA
to detect updates between releases. Do not add a fixed version to those files.
The portable plugin and Gemini/Bob extension manifests use a deterministic
prerelease version derived from the assembled package content and templates, so
changes produce a new version without a fixed release number.
See [Claude plugin version resolution](https://code.claude.com/docs/en/plugins/loading#how-claude-code-computes-the-version).
Claude validation reports an advisory about the omitted version; this is
intentional, so `--strict` treats that advisory as a failure.
Before tagging a release, run `./build.sh claude` and commit any regenerated
`plugin/` output and root `bob-extension.json` / `BOB.md`. Do not edit generated versions
manually.

Releases are cut by pushing a `vMAJOR.MINOR.PATCH` tag (for example `v1.0.0`). A
GitHub Actions workflow (`.github/workflows/release.yml`) then publishes the
matching [GitHub Release](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/releases)
with generated notes. The marketplace reads the committed Claude bundle; local
builds use the checked-out source version.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Check source and generated ownership](skill-sources.md) before committing release assets.
- [Follow the contribution workflow](contribute.md) when preparing release changes.
