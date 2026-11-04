---
title: "Contribute a change"
description: "Prepare a contribution by editing the appropriate guidelines, updating build inputs, testing workflows and including regenerated plugin assets."
---

# Contribute a change

Prepare a contribution by editing the appropriate guidelines, updating build inputs, testing workflows and including regenerated plugin assets.

## Before you begin

Fork the repository and use a feature branch for your change.

## Prepare a contribution

1. Fork the repository
2. Create a feature branch
3. Add or modify guideline files in the appropriate `skills/oss-*/` directory
4. Update `build.sh` if adding new files
5. For a Claude Code workflow, add the script to `workflows/` (its `meta.name` must match the file name), list it in `WORKFLOW_FILES` in `build.sh`, give it a guideline that also works by hand for the other agents, and add a test under `tests/workflows/`
6. Run `./build.sh claude` and include updated `plugin/`, `bob-extension.json` and `BOB.md`
7. Submit a pull request

## Examples and shared fragments

The [sample test plans](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/tree/main/sample-plans) illustrate reusable plan procedures. The [fragment guide](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/blob/main/commands/_fragments/README.md) describes shared command instructions; keep those runtime sources at their current paths.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Edit skill sources and regenerate bundles](skill-sources.md) for source ownership.
- [Build bundles locally](build-locally.md) before submitting your change.
- [Write documentation](write-docs.md) when the change affects reader guidance.
