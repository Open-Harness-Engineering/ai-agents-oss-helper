---
title: "Build bundles locally"
description: "Build helper bundles from the current checkout, test the Claude plugin locally and regenerate committed native assets when their source inputs change."
---

# Build bundles locally

Build helper bundles from the current checkout, test the Claude plugin locally and regenerate committed native assets when their source inputs change.

## Before you begin

Use a source checkout. The build requires `sha256sum` or `shasum` for native package versions.

## Build and test a bundle

```bash
git clone https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git
cd ai-agents-oss-helper
./build.sh          # All six targets
./build.sh claude   # plugin/ (committed)
./build.sh codex    # build/codex/ (ignored)
```

The build uses the current checkout, works offline, and writes only generated
output inside the project. It requires `sha256sum` or `shasum` for native package
versions. Check out a release tag before building to select a
specific version. Rebuild `plugin/` whenever its inputs change; CI checks it for
drift. For isolated builds, use `./build.sh --output-dir /tmp/oss-plugin claude`.

Test the Claude bundle locally with `claude --plugin-dir ./plugin`.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Check source ownership](skill-sources.md) before editing generated files.
- [Follow the contribution workflow](contribute.md) to prepare a pull request.
