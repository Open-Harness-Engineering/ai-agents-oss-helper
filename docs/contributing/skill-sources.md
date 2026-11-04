---
title: "Edit skill sources and regenerate bundles"
description: "Edit source skill guidelines, regenerate the committed native plugin bundle and include generated assets with the source changes in each contribution."
---

# Edit skill sources and regenerate bundles

Edit source skill guidelines, regenerate the committed native plugin bundle and include generated assets with the source changes in each contribution.

## Before you begin

Work in a source checkout; use [Source layout](source-layout.md) to find the editable files.

## Source and generated copies

The [skills directory](https://github.com/Open-Harness-Engineering/ai-agents-oss-helper/tree/main/skills) contains the editable skill sources. Files such as
`oss-project/add-project.md` also appear under `plugin/skills/` because native
marketplace and skill installers use the committed plugin bundle without running
the builder.
The bundle needs its own copies of the skills and their supporting files.

Make changes in `skills/`, then regenerate the shared native bundle:

```bash
./build.sh claude
```

Commit the source changes together with the updated `plugin/` output and root
`bob-extension.json` and `BOB.md`. Do not edit
the generated copies directly; the next build replaces them. CI checks that the
committed bundle matches its sources.

Other agent bundles are generated under `build/<agent>/` and are not committed.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Build bundles locally](build-locally.md) to test your changes.
- [Follow the contribution workflow](contribute.md) before opening a pull request.
