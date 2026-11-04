# Skill sources and generated copies

This directory contains the editable skill sources. Files such as
`oss-project/add-project.md` also appear under `plugin/skills/` because native
marketplace and skill installers use the committed plugin bundle without running
the builder.
The bundle needs its own copies of the skills and their supporting files.

Make changes here, then regenerate the shared native bundle:

```bash
./build.sh claude
```

Commit the source changes together with the updated `plugin/` output and root
`bob-extension.json` and `BOB.md`. Do not edit
the generated copies directly; the next build replaces them. CI checks that the
committed bundle matches its sources.

Other agent bundles are generated under `build/<agent>/` and are not committed.
