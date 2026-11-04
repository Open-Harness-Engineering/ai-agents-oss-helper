---
title: "Write project documentation"
description: "Write task-focused helper documentation with clear page owners, consistent metadata, useful navigation and source links that work in the repository."
---

# Write project documentation

Write task-focused helper documentation with clear page owners, consistent metadata, useful navigation and source links that work in the repository.

## Before you begin

Read the [documentation home](../index.md) and choose the section that owns your topic.

## Choose a page owner

Put human documentation in the section that serves its reader: getting started, managing installations, running tasks, configuring projects, looking up reference or contributing. Give each page one tutorial, how-to, reference or explanation purpose. Runtime skill instructions, generated bundles and sample fixtures keep their source locations.

Give each fact one owner page. Other pages may summarize it in two sentences and link to the owner. The command reference owns the capability table; the existing generated catalog supplies fuller usage examples from the registry and reference data.

## Name and describe the page

Use lowercase kebab-case filenames, at most four words, without version numbers. Prefer verb-object names for tasks and nouns for reference or concepts. Keep a filename when moving a page unless a split, merge, collision or redundant folder prefix requires a rename.

Every human page needs YAML frontmatter with a unique `title` of at most 60 characters and a unique `description` of 120–155 characters. Use one H1 with the same meaning as the title. Expand acronyms when they would prevent readers from understanding the task.

## Keep a predictable page shape

Start with one to three sentences of purpose, then prerequisites under “Before you begin,” a body with specific headings, and a final “Next steps” section with two to four reasoned links. Hubs use an audience map and page list instead of task prerequisites. Nothing follows Next steps.

Use sentence-case headings and stop at H3. Avoid numbered headings, handwritten contents lists and vague “Overview” headings. Keep tutorials and how-tos under 350 lines, explanations under 500, references under 800 and hubs under 70.

## Link pages and source files

Use relative `.md` links within docs and explicit `index.md` hub targets. Link to source files outside docs with absolute code-host URLs. Cross-page fragments should target H2 or H3 headings. Each spoke links its hub and relevant siblings.

List every human page exactly once in `docs/nav.json`, in reading order, and in its section hub. The docs home lists all section hubs. The manifest records repository navigation; the current website does not read it. Follow every changed relative link and fragment before submitting a documentation change.

## Format examples and images

Preserve command spelling, arguments and diagnostic strings when moving content. Use fenced code blocks with a language label. Use plain blockquotes with a bold label for callouts so code hosts and simple renderers show the same content.

Store new images in `docs/images/` as `<page-slug>-<subject>.png`, with useful alt text and a 500 KiB size cap.

## Use consistent terms

| Term | Meaning |
|---|---|
| OSS Helper | The product short name |
| Skill group | One of the six user-invocable bundles |
| Command | An individual `/oss-*` task entry |
| Project rules | Project-specific configuration |
| Guidelines | Executable task instructions |
| Compatibility installer | The `install.sh` installation path |
| Generated bundle | Asset output assembled from editable sources |

## Keep publication changes separate

These Markdown pages describe `main` and readers browse them in the repository. The website remains the generated command/workflow catalog. Update publication tooling separately if the project later publishes the human documentation. Keep internal proposals outside docs; record only real removed website routes in `docs/redirects.txt`.

## Next steps

- [Contributor guides](index.md) for the section map.
- [Follow the contribution workflow](contribute.md) when preparing documentation changes.
- [Check source ownership](skill-sources.md) if the change affects an executable guideline.
