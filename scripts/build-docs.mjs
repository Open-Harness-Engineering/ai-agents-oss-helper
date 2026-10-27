#!/usr/bin/env node
// Build the GitHub Pages documentation site for the OSS Helper commands and
// workflows. Dependency-free: it reads the existing sources so the docs cannot
// drift from them, and writes a self-contained static site into ./site.
//
//   Sources
//     - install.sh            GUIDELINE_COMMANDS registry -> the /oss-* commands
//     - skills/<id>/SKILL.md   frontmatter description      -> per-skill blurb
//     - workflows/*.js         `export const meta`          -> the workflows
//     - docs/reference.json    authored summaries + usage examples (merged in)
//
//   Every registry command must have a docs/reference.json entry; the build
//   fails otherwise, so new commands cannot ship undocumented.
//
//   Usage: node scripts/build-docs.mjs   (run from the repository root)

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const OUT = join(ROOT, 'site')

const REPO = 'Open-Harness-Engineering/ai-agents-oss-helper'
const REPO_URL = `https://github.com/${REPO}`

// --- helpers ---------------------------------------------------------------

const esc = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const usageBlock = (usage) =>
  usage && usage.length
    ? `<pre class="usage"><code>${usage.map(esc).join('\n')}</code></pre>`
    : ''

// --- reference content (authored summaries + usage examples) ---------------

function readReference() {
  const p = join(ROOT, 'docs', 'reference.json')
  const ref = JSON.parse(readFileSync(p, 'utf8'))
  return { commands: ref.commands || {}, workflows: ref.workflows || {} }
}

// --- commands (install.sh GUIDELINE_COMMANDS) ------------------------------

function readCommands() {
  const text = readFileSync(join(ROOT, 'install.sh'), 'utf8')
  const re = /^\s*"(oss-[a-z0-9-]+)\|([^|]+)\|(oss-[a-z0-9-]+)\|([^"]+)"/gm
  const groups = new Map() // skill -> [{command, file, description}]
  let m
  while ((m = re.exec(text)) !== null) {
    const [, skill, file, command, description] = m
    if (!groups.has(skill)) groups.set(skill, [])
    groups.get(skill).push({ command, file, description })
  }
  return groups
}

// --- per-skill blurb (first sentence of SKILL.md frontmatter description) ---

function skillBlurb(skill) {
  const p = join(ROOT, 'skills', skill, 'SKILL.md')
  if (!existsSync(p)) return ''
  const fm = readFileSync(p, 'utf8').match(/^---\n([\s\S]*?)\n---/)
  if (!fm) return ''
  const lines = fm[1].split('\n')
  let desc = ''
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^description:\s*(.*)$/)
    if (!m) continue
    let val = m[1].trim()
    if (['', '>', '|', '>-', '|-', '>+', '|+'].includes(val)) {
      const buf = []
      for (let j = i + 1; j < lines.length; j++) {
        if (/^\s+\S/.test(lines[j])) buf.push(lines[j].trim())
        else if (lines[j].trim() === '') buf.push('')
        else break
      }
      val = buf.join(' ')
    }
    desc = val.replace(/\s+/g, ' ').trim()
    break
  }
  const first = desc.split(/\.\s/)[0]
  return first ? (first.endsWith('.') ? first : first + '.') : desc
}

// --- workflows (export const meta literal) ---------------------------------

function extractMeta(src) {
  const idx = src.indexOf('export const meta')
  if (idx < 0) return null
  const start = src.indexOf('{', idx)
  let depth = 0, inStr = null, esc2 = false, i = start
  for (; i < src.length; i++) {
    const c = src[i]
    if (inStr) {
      if (esc2) esc2 = false
      else if (c === '\\') esc2 = true
      else if (c === inStr) inStr = null
    } else if (c === '"' || c === "'" || c === '`') inStr = c
    else if (c === '{') depth++
    else if (c === '}' && --depth === 0) { i++; break }
  }
  // meta is required to be a pure literal, so evaluating it is deterministic.
  return new Function('return (' + src.slice(start, i) + ')')()
}

function readWorkflows() {
  const dir = join(ROOT, 'workflows')
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .filter((f) => f.endsWith('.js'))
    .sort()
    .map((f) => extractMeta(readFileSync(join(dir, f), 'utf8')))
    .filter(Boolean)
}

// --- render ----------------------------------------------------------------

function render(commandGroups, workflows, reference) {
  const totalCommands = [...commandGroups.values()].reduce((n, c) => n + c.length, 0)

  const commandsHtml = [...commandGroups.entries()]
    .map(([skill, cmds]) => {
      const blurb = skillBlurb(skill)
      const rows = cmds
        .map((c) => {
          const ref = reference.commands[c.command] || {}
          const summary = ref.summary || c.description
          return `        <div class="cmd">
          <code class="name">/${esc(c.command)}</code>
          <p class="desc">${esc(summary)}</p>
          ${usageBlock(ref.usage)}
          <p class="meta"><span class="skill">${esc(skill)}</span> · <span class="file">${esc(c.file)}</span></p>
        </div>`
        })
        .join('\n')
      return `      <section class="group" id="${esc(skill)}">
        <h3><code>${esc(skill)}</code> <span class="count">${cmds.length}</span></h3>
        ${blurb ? `<p class="blurb">${esc(blurb)}</p>` : ''}
${rows}
      </section>`
    })
    .join('\n')

  const workflowsHtml = workflows
    .map((w) => {
      const ref = reference.workflows[w.name] || {}
      const phases = (w.phases || [])
        .map(
          (p) =>
            `          <li><strong>${esc(p.title)}</strong>${p.detail ? ` — ${esc(p.detail)}` : ''}</li>`
        )
        .join('\n')
      return `      <section class="group" id="wf-${esc(w.name)}">
        <h3><code>/${esc(w.name)}</code></h3>
        <p class="desc">${esc(ref.summary || w.description || '')}</p>
        ${usageBlock(ref.usage)}
        ${w.whenToUse ? `<p class="when"><strong>When to use:</strong> ${esc(w.whenToUse)}</p>` : ''}
        ${phases ? `<p class="meta">Phases</p>\n        <ol class="phases">\n${phases}\n        </ol>` : ''}
      </section>`
    })
    .join('\n')

  const nav = [...commandGroups.keys()]
    .map((s) => `<a href="#${esc(s)}"><code>${esc(s)}</code></a>`)
    .concat(workflows.map((w) => `<a href="#wf-${esc(w.name)}"><code>/${esc(w.name)}</code></a>`))
    .join('\n          ')

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OSS Helper — Commands &amp; Workflows</title>
<meta name="description" content="Usage and reference for the AI Agents OSS Helper commands and workflows.">
<style>
  :root {
    --bg: #ffffff; --fg: #1b1f24; --muted: #596273; --line: #e3e7ee;
    --card: #f7f8fa; --accent: #2563eb; --code: #0b1b3a; --code-bg: #eef2f8;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #0d1117; --fg: #e6edf3; --muted: #9aa7b4; --line: #222b36;
      --card: #161b22; --accent: #58a6ff; --code: #e6edf3; --code-bg: #1b222c;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--fg);
    font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
  .wrap { max-width: 920px; margin: 0 auto; padding: 0 16px 64px; }
  header.top { border-bottom: 1px solid var(--line); margin-bottom: 8px; }
  header.top .wrap { padding-top: 40px; padding-bottom: 24px; }
  h1 { font-size: 1.9rem; margin: 0 0 6px; }
  .tagline { color: var(--muted); margin: 0 0 16px; font-size: 1.05rem; }
  .links a { margin-right: 18px; font-size: .95rem; }
  nav.toc {
    position: sticky; top: 0; background: var(--bg); border-bottom: 1px solid var(--line);
    padding: 12px 0; margin-bottom: 24px; z-index: 5;
  }
  nav.toc .wrap { padding-top: 0; padding-bottom: 0; display: flex; flex-wrap: wrap; gap: 8px 14px; }
  nav.toc code { font-size: .85rem; }
  h2 { font-size: 1.35rem; margin: 40px 0 4px; padding-top: 8px; }
  .section-note { color: var(--muted); margin: 0 0 8px; }
  .group { padding: 18px 0 6px; border-top: 1px solid var(--line); }
  .group h3 { margin: 0 0 4px; font-size: 1.1rem; }
  .group h3 code { background: var(--code-bg); color: var(--code); padding: 2px 8px; border-radius: 6px; }
  .count { color: var(--muted); font-size: .8rem; font-weight: 400; margin-left: 6px; }
  .blurb { color: var(--muted); margin: 0 0 14px; }
  .cmd { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px; margin: 8px 0; }
  .cmd .name { color: var(--code); font-weight: 600; }
  .cmd .desc, .group > .desc { margin: 6px 0 8px; }
  .cmd .meta, .when { color: var(--muted); font-size: .85rem; margin: 6px 0 0; }
  .usage {
    background: var(--code-bg); color: var(--code); border-radius: 6px;
    padding: 10px 12px; margin: 8px 0; overflow-x: auto; font-size: .85rem; line-height: 1.5;
  }
  .usage code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; white-space: pre; }
  .phases { margin: 6px 0 0; padding-left: 22px; }
  .phases li { margin: 3px 0; }
  footer { border-top: 1px solid var(--line); margin-top: 40px; color: var(--muted); font-size: .9rem; }
  footer .wrap { padding-top: 20px; padding-bottom: 20px; }
</style>
</head>
<body>
  <header class="top">
    <div class="wrap">
      <h1>AI Agents OSS Helper</h1>
      <p class="tagline">Commands &amp; workflows reference</p>
      <p class="links">
        <a href="${REPO_URL}">GitHub</a>
        <a href="${REPO_URL}#installation">Install</a>
        <a href="${REPO_URL}/releases">Releases</a>
      </p>
    </div>
  </header>

  <nav class="toc">
    <div class="wrap">
          ${nav}
    </div>
  </nav>

  <main class="wrap">
    <p>
      The OSS Helper gives AI coding agents guidelines for contributing to open
      source projects. With a skill-capable agent, invoke a command directly
      (e.g. <code>/oss-fix-issue</code>) or just describe what you want. See the
      <a href="${REPO_URL}">README</a> for installation and rule setup.
    </p>

    <h2>Commands <span class="count">${totalCommands}</span></h2>
    <p class="section-note">Grouped by the skill that provides them. Arguments shown in the examples are illustrative.</p>
${commandsHtml}

    <h2>Workflows</h2>
    <p class="section-note">Multi-step orchestrations (Claude Code); other agents follow the same guideline by hand.</p>
${workflowsHtml}
  </main>

  <footer>
    <div class="wrap">
      Generated from <code>install.sh</code>, <code>docs/reference.json</code> and <code>workflows/*.js</code> on ${new Date().toISOString().slice(0, 10)}.
      <a href="${REPO_URL}">${REPO}</a>
    </div>
  </footer>
</body>
</html>
`
}

// --- main ------------------------------------------------------------------

const reference = readReference()
const commandGroups = readCommands()
const workflows = readWorkflows()
const totalCommands = [...commandGroups.values()].reduce((n, c) => n + c.length, 0)

if (totalCommands === 0) {
  console.error('build-docs: no commands parsed from install.sh — aborting')
  process.exit(1)
}

// Every registry command must be documented in docs/reference.json.
const missing = []
for (const cmds of commandGroups.values()) {
  for (const c of cmds) {
    const ref = reference.commands[c.command]
    if (!ref || !ref.usage || ref.usage.length === 0) missing.push(c.command)
  }
}
if (missing.length) {
  console.error(
    `build-docs: ${missing.length} command(s) missing a docs/reference.json entry with usage: ${missing.join(', ')}`
  )
  process.exit(1)
}

mkdirSync(OUT, { recursive: true })
writeFileSync(join(OUT, 'index.html'), render(commandGroups, workflows, reference))
writeFileSync(join(OUT, '.nojekyll'), '')

console.log(
  `build-docs: wrote site/index.html — ${totalCommands} commands in ${commandGroups.size} skills, ${workflows.length} workflow(s)`
)
