// Offline test of workflows/oss-security-case.js: the workflow runs against mocked agents, so no
// model, network, tracker or forge is touched.  Run with: node tests/workflows/oss-security-case.test.mjs
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const src = readFileSync(join(root, 'workflows', 'oss-security-case.js'), 'utf8')
const guideline = readFileSync(join(root, 'skills', 'oss-security', 'security-case.md'), 'utf8')
const probe = readFileSync(join(root, 'skills', 'oss-security', 'security-case-probe.sh'), 'utf8')
const installer = readFileSync(join(root, 'install.sh'), 'utf8')
if (!/^export const meta = \{/.test(src)) throw new Error('the script must begin with export const meta')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const wf = new AsyncFunction('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', 'workflow', src.replace(/^export const meta/m, 'const meta'))

const sleep = ms => new Promise(r => setTimeout(r, ms))
const clone = x => JSON.parse(JSON.stringify(x))
let failures = 0
const check = (cond, msg) => { if (!cond) { failures++; console.log('  FAIL: ' + msg) } else console.log('  ok: ' + msg) }
const gateIds = r => (r.waitingOn || []).map(g => g.id)

// The mocked loader returns what the real one returns: the probe's digest of the node files, computed by the
// python embedded in security-case-probe.sh. Without python3 the probe prints the full files, and so does this.
const digestScript = (probe.match(/python3 - "\$1" <<'PY'\n([\s\S]*?)\nPY\n/) || [])[1]
let python3 = true
try { execFileSync('python3', ['-c', 'pass']) } catch { python3 = false }
function probeDigest(disk) {
  if (!digestScript || !python3) return clone(disk.nodes)
  const dir = mkdtempSync(join(tmpdir(), 'seccase-'))
  try {
    mkdirSync(join(dir, 'nodes'))
    for (const [name, record] of Object.entries(disk.nodes)) writeFileSync(join(dir, 'nodes', name + '.json'), JSON.stringify(record))
    writeFileSync(join(dir, 'decisions.json'), JSON.stringify(disk.decisions || {}))
    return JSON.parse(execFileSync('python3', ['-', dir], { input: digestScript }).toString())
  } finally { rmSync(dir, { recursive: true, force: true }) }
}

const JIRA_PROJECT = {
  repoRoot: '/work/server', repo: 'example/server', repoBase: 'server', upstreamRemote: 'origin', defaultBranch: 'main', shallow: true,
  login: 'maintainer', gitName: 'A Maintainer', pushRemote: 'fork', tracker: 'Jira', trackerUrl: 'https://issues.example.org/jira/browse/',
  jiraProject: 'PROJ', jiraUser: 'amaintainer', fixBranchPattern: 'fix/<ISSUE_ID>', commitFormatFix: '<ISSUE_ID>: <brief description of fix>',
  upgradeGuidePolicy: 'upgrade notes for every release line live on main',
  security: { present: true, cna: 'Example CNA', cnaUrl: 'https://cna.example.org', lines: ['release-2.x', 'release-1.x'], eol: ['release-0.x'], fixModel: 'public', denyTerms: [] },
  worktreeRoot: '/work', casesRoot: '/path/to/security-cases', cveRecordsDir: null, prefsFile: null, operatorNotes: '', notesDir: null,
  mailArchive: 'security-list', skillsRoot: '/path/to/skills',
}
const GITHUB_PROJECT = Object.assign({}, JIRA_PROJECT, {
  repoRoot: '/work/tool', repo: 'example/tool', repoBase: 'tool', tracker: 'GitHub', jiraProject: null, jiraUser: null,
  fixBranchPattern: 'fix/<ISSUE_NUMBER>', commitFormatFix: 'Fix #<ISSUE_NUMBER>: <brief description>', upgradeGuidePolicy: null,
  security: { present: false }, mailArchive: null,
})

function makeSim(rec, config) {
  const caseDir = config.casesRoot + '/demo'
  const disk = { nodes: {}, decisions: {}, report: { subject: 'component: exception echoed', reporter: 'Jane Doe', reporterEmail: 'jane@example.org', via: 'security team', threads: config.mailArchive ? ['thread-0001'] : [] }, status: '' }
  const sim = { rec, live: {}, active: { heavy: 0, publish: 0 }, maxActive: { heavy: 0, publish: 0 }, mirrors: [], prompts: {}, opts: {} }
  const between = (p, a, b) => { const i = p.indexOf(a); const j = b ? p.indexOf(b, i + a.length) : p.length; return p.slice(i + a.length, j) }
  async function agent(prompt, opts) {
    const label = opts.label
    sim.prompts[label] = prompt
    sim.opts[label] = opts
    const heavy = /^fix:(?!publish)/.test(label) || /^backport:[^:]+$/.test(label)
    const publish = /publish$/.test(label)
    const lane = heavy ? 'heavy' : publish ? 'publish' : null
    if (lane) { sim.active[lane]++; sim.maxActive[lane] = Math.max(sim.maxActive[lane], sim.active[lane]) }
    await sleep(5)
    try {
      if (label === 'load') return { initialized: true, caseDir, today: '2026-01-15', config: clone(config), report: disk.report, decisionsFile: clone(disk.decisions), nodes: probeDigest(disk), live: clone(sim.live) }
      if (label === 'triage') return { status: 'done', recommendedVerdict: sim.rec, confidence: 'high', summary: 'consumer echoes exception', files: [caseDir + '/triage.md'], components: ['http-server'], fixVersionsByLine: { main: '3.0.0', 'release-2.x': '2.5.1', 'release-1.x': '1.9.4' }, neverCite: ['CVE-2026-99999'], denyTerms: ['payload-x'], cvssVector: 'AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N', cvssScore: 5.3, cwe: 'CWE-209', suggestedCveTitle: 'Example: Information Disclosure via Unmuted Exceptions' }
      if (label.startsWith('challenge:')) return { status: 'done', agree: label === 'challenge:scope', proposedVerdict: label === 'challenge:code' ? 'HARDENING' : undefined, reasons: ['default codec writes nothing'], missedFacts: label === 'challenge:code' ? ['a non-default codec is needed'] : [] }
      if (label === 'draft:reply') return { status: 'done', forVerdict: prompt.match(/for the verdict (\w+)/)[1], file: caseDir + '/reply-draft.txt' }
      if (label === 'draft:cve-fields') return { status: 'done', file: caseDir + '/cve-reservation.md' }
      if (label === 'draft:issue') return { status: 'done', forVerdict: prompt.match(/Your result's forVerdict is (\w+)/)[1], payloadFile: caseDir + '/issue-draft.json', scriptFile: caseDir + '/issue-create.sh', lintHard: [], lintSoft: ['leak'] }
      if (label === 'issue:create') return { status: 'created', key: config.tracker === 'Jira' ? 'PROJ-123' : '#42', url: 'https://tracker.example.org/x' }
      if (label === 'reply:final') {
        const cve = (prompt.match(/<CVE-ID> = (CVE-\d{4}-\d+)/) || [])[1] || null
        const issue = (prompt.match(/<ISSUE> = (PROJ-\d+|#\d+)/) || [])[1] || null
        return { status: 'done', forVerdict: prompt.match(/ruled verdict (\w+)/)[1], forCve: cve, forIssue: issue, file: caseDir + '/reply-final.txt' }
      }
      if (/^fix:(PROJ-\d+|#\d+)$/.test(label)) return { status: 'local', worktree: '/work/x-123', branch: prompt.match(/worktree add -b (\S+)/)[1], commits: ['abc123'], guideNote: true, guideFile: 'upgrade-guide.md', prBodyFile: caseDir + '/pr-body.md', prScript: caseDir + '/pr-create.sh', lintHard: [], lintSoft: [], build: 'green' }
      if (label === 'fix:publish') return { status: 'pr-open', pr: 28001, url: 'https://github.com/example/server/pull/28001' }
      if (/^backport:[^:]+$/.test(label)) {
        const line = label.slice('backport:'.length)
        return { status: 'local', line, localBranch: 'backport/28001-to-' + line, worktree: '/work/bp-' + line, straight: line !== 'release-1.x', adaptations: line === 'release-1.x' ? ['older test framework'] : [], fixVersion: line === 'release-1.x' ? '1.9.4' : '2.5.1', prBodyFile: caseDir + '/bp.md' }
      }
      if (/^backport:.*:publish$/.test(label)) return { status: 'pr-open', line: label.split(':')[1], pr: label.includes('release-2.x') ? 28002 : 28003 }
      if (label === 'docsync') return { status: 'local', worktree: '/work/docsync', branch: 'docs/PROJ-123-guide-sync', commit: 'def456', files: ['guide-2.x.md', 'guide-1.x.md'], prBodyFile: caseDir + '/docsync.md' }
      if (label === 'docsync:publish') return { status: 'pr-open', pr: 28004 }
      if (label === 'cve:draft') return { status: 'drafted', forCve: prompt.match(/for (CVE-\d{4}-\d+) with/)[1], files: [caseDir + '/cve/x.md'], archived: true, checklistFile: caseDir + '/cve/CHECKLIST.md' }
      if (label === 'persist') {
        const nodes = JSON.parse(between(prompt, 'NODES = ', '\n\nREMOVE = '))
        const remove = JSON.parse(between(prompt, 'REMOVE = ', '\n\nDECISIONS = '))
        const decisions = JSON.parse(between(prompt, 'DECISIONS = ', '\n\nLOG = '))
        JSON.parse(between(prompt, 'LOG = ', '\n\n<<<STATUS'))
        Object.assign(disk.nodes, nodes)
        for (const r of remove) delete disk.nodes[r]
        disk.decisions = decisions
        disk.status = between(prompt, '<<<STATUS\n', '\nSTATUS>>>')
        const m = prompt.match(/record the triage state "(\w+)"/)
        if (m) sim.mirrors.push(m[1])
        return { written: Object.keys(nodes), errors: [] }
      }
      throw new Error('unexpected label ' + label)
    } finally { if (lane) sim.active[lane]-- }
  }
  async function parallel(thunks) { return Promise.all(thunks.map(t => Promise.resolve().then(t).catch(e => { console.log('  thunk error: ' + e.message); failures++; return null }))) }
  const runIt = async a => { sim.prompts = {}; return wf(agent, parallel, null, () => {}, () => {}, Object.assign({ case: 'demo' }, a), { total: null }, null) }
  return { sim, disk, runIt }
}

// ---- The shipped files stay neutral ---------------------------------------------------------
{
  console.log('\nNeutrality')
  const banned = /ponymail|apache|camel|cveprocess|vulnogram|\/home\/|\.claude\/projects/i
  check(!banned.test(src), 'the workflow names no local tool, local path or specific foundation')
  check(!banned.test(guideline), 'the guideline names no local tool, local path or specific foundation')
  check(!banned.test(probe), 'the probe script names no local tool, local path or specific foundation')
  check(installer.includes('skills/oss-security/security-case-probe.sh'), 'the installer ships the probe with the oss-security skill')
  check(digestScript && python3, 'the routing test runs on the probe\'s digest of the node files' + (python3 ? '' : ' (python3 missing: full files)'))
}

// ---- Jira project with project-security.md: the full VALID lifecycle -----------------------
{
  console.log('\nJira project, VALID lifecycle')
  const { sim, disk, runIt } = makeSim('VALID', JIRA_PROJECT)

  let r = await runIt({ report: '/tmp/report.txt' })
  check(r.ran[0] === 'triage', 'run 1 starts with triage')
  check(['challengeScope', 'challengeCode', 'draftReply', 'draftCve', 'draftIssue'].every(x => r.ran.includes(x)), 'run 1 runs both challenge lenses and the three drafts')
  check(gateIds(r).join() === 'verdict', 'run 1 stops at the verdict gate')
  check(/CONTESTED/.test(r.challenge || ''), 'a disagreeing lens marks the verdict CONTESTED')
  check(r.next === '/oss-security-case demo verdict=VALID', 'next command proposes the recommended verdict: ' + r.next)
  check(/release-2\.x, release-1\.x/.test(sim.prompts.triage) && /cna\.example\.org/.test(sim.prompts['draft:cve-fields']), 'project-security.md lines and CNA reach the prompts')
  check(/read every case thread/.test(sim.prompts['draft:reply']), 'with a mail archive, the reply draft reads the case threads')
  check(sim.opts.load.model === 'claude-haiku-5-5' && sim.opts.persist.model === 'claude-haiku-5-5', 'the loader and the persistence step run on Haiku')
  check(/between "--- nodes digest" and "--- end nodes digest": return that JSON object as nodes/.test(sim.prompts.load), 'the loader returns the probe\'s digest, not the node files')
  check(sim.opts.triage.model === undefined && sim.opts['challenge:code'].model === undefined && sim.opts['draft:reply'].model === undefined, 'triage, the challenge lenses and the drafts keep the session model')
  check(/security-case-probe\.sh demo /.test(sim.prompts.load), 'the loader starts from the probe script')
  check(/slices of at most 240 seconds/.test(sim.prompts.triage), 'every node is told to keep tool calls under the cache TTL')

  r = await runIt({ decision: { verdict: 'VALID' }, approve: { issue: true } })
  check(r.ran.includes('issue') && r.ran.includes('fix'), 'run 2 creates the issue, then prepares the fix')
  check(/worktree add -b fix\/PROJ-123 /.test(sim.prompts['fix:PROJ-123']), 'the fix branch follows the project pattern')
  check(!r.ran.includes('reply'), 'the VALID reply waits for the CVE id')
  check(sim.opts['fix:PROJ-123'].model === undefined && sim.opts['issue:create'].model === 'claude-sonnet-5-5', 'the fix keeps the session model; the issue creation runs on Sonnet')
  check(/slices of at most 240 seconds, as the rules above say/.test(sim.prompts['fix:PROJ-123']), 'the fix node polls builds in slices under the cache TTL')
  check(!/consumer echoes exception/.test(sim.prompts['fix:PROJ-123']) && /\/demo\/nodes\/<node>\.json/.test(sim.prompts['fix:PROJ-123']), 'the case facts leave the triage text out and point at the full records')
  check(gateIds(r).includes('cve') && gateIds(r).includes('approve-pr'), 'run 2 stops at the cve and approve-pr gates')
  check(sim.mirrors.join() === 'ACCEPTED', 'the ruling is recorded in the mail archive once, as ACCEPTED')

  r = await runIt({ decision: { cve: 'CVE-2026-11111' }, approve: { pr: true } })
  check(r.ran.includes('reply') && r.ran.includes('fix:publish'), 'run 3 finalizes the reply and opens the PR')
  check(/--head maintainer:fix\/PROJ-123/.test(sim.prompts['fix:publish']), 'the PR head points at the fork')
  check(sim.opts['fix:publish'].model === 'claude-sonnet-5-5' && sim.opts['reply:final'].model === 'claude-sonnet-5-5', 'the publish node and the final reply run on Sonnet')
  check(gateIds(r).includes('send-reply') && gateIds(r).includes('merge'), 'run 3 waits for the reply to be sent and for the merge')
  check(disk.decisions.decisions.verdict === 'VALID' && disk.decisions.decisions.cve === 'CVE-2026-11111', 'decisions are sticky across runs')
  check(sim.mirrors.length === 1, 'no second record for the same ruling')

  r = await runIt({})
  check(r.ran.length === 0 && gateIds(r).includes('merge'), 'a run before the merge does nothing and still waits for it')

  sim.live = { mainPr: { number: 28001, state: 'MERGED' } }
  r = await runIt({ done: { reply: true } })
  check(['backport_release-2.x', 'backport_release-1.x', 'docSync'].every(x => r.ran.includes(x)), 'after the merge: both backports and the note sync')
  check(!r.ran.includes('cveDraft') && gateIds(r).includes('release'), 'the CVE draft waits for the release, not for the merge')
  check(sim.maxActive.heavy === 1, 'build-heavy nodes never ran concurrently')
  check(/polled in slices of at most 240 seconds/.test(sim.prompts['backport:release-1.x']) && sim.opts['backport:release-1.x'].model === undefined, 'backports poll builds in slices and keep the session model')
  check(/"Backport notes" of \/path\/to\/security-cases\/demo\/triage\.md/.test(sim.prompts['backport:release-1.x']), 'backports read their notes from triage.md')
  check(gateIds(r).includes('approve-backports'), 'stops at approve-backports')

  r = await runIt({ approve: { backports: true } })
  check(r.ran.join() === 'backport_release-2.x:publish,backport_release-1.x:publish,docSync:publish', 'backport PRs open first, then the note-sync PR, in one run')
  check(sim.maxActive.publish === 1, 'PR-opening nodes never ran concurrently')
  check(gateIds(r).join() === 'release', 'only the release is left before the CVE draft')
  check(disk.nodes['backport_release-1.x'].worktree === '/work/bp-release-1.x', 'publish results merge into the prepared node record')

  sim.live = { mainPr: { number: 28001, state: 'MERGED' }, releases: { '3.0.0': true, '2.5.1': true, '1.9.4': false } }
  r = await runIt({})
  const releaseGate = (r.waitingOn || []).find(g => g.id === 'release') || {}
  check(r.ran.length === 0 && /1\.9\.4/.test(releaseGate.text || '') && !/3\.0\.0|2\.5\.1/.test(releaseGate.text || ''), 'a partial release keeps the CVE draft waiting and names only what is missing')

  sim.live.releases['1.9.4'] = true
  r = await runIt({})
  check(r.ran.join() === 'cveDraft' && gateIds(r).join() === 'cve-record', 'once every fixed version is released: the CVE draft, then the signing and publication PR gate')
  check(/never open a pull request with them/.test(sim.prompts['cve:draft'] || '') && /stay local only/.test(sim.prompts['cve:draft'] || ''), 'the CVE draft stays local or goes to the private draft repository, never into a PR')
  check(/in the private draft repository/.test(((r.waitingOn || []).find(g => g.id === 'cve-record') || {}).text || ''), 'the final gate says where the drafts are')
  check(/Waiting on you/.test(disk.status) && /CNA tool/.test(disk.status) && /archived to the private draft repository/.test(disk.status), 'STATUS.md is rendered and says where the drafts are')
  check(r.memory && r.memory.file === 'project_seccase_demo.md', 'a memory pointer is returned')

  const bad = await runIt({ decision: { backportTargets: ['release-0.x'] } })
  check(bad.error && /end of life/.test(bad.problems.join()), 'an EOL line from project-security.md is rejected as a target')
}

// ---- Approvals never cover what the run itself produced -------------------------------------
{
  console.log('\nHARDENING override with a same-run approval')
  const { sim, runIt } = makeSim('VALID', JIRA_PROJECT)
  await runIt({ report: '/tmp/report.txt' })
  let r = await runIt({ decision: { verdict: 'HARDENING' }, approve: { issue: true } })
  check(r.ran.includes('draftReply') && r.ran.includes('draftIssue'), 'the drafts are regenerated for the new verdict')
  check(!r.ran.includes('issue'), 'the issue is NOT created from a draft the maintainer has not seen')
  check(gateIds(r).includes('approve-issue'), 'the maintainer is asked to approve the new draft')
  check(sim.mirrors.join() === 'REJECTED', 'HARDENING is recorded as REJECTED')
  r = await runIt({ approve: { issue: true } })
  check(r.ran.includes('issue') && r.ran.includes('reply') && r.ran.includes('fix'), 'next run: the issue, the reply that cites it, then the fix')
}

// ---- GitHub project without project-security.md or a mail archive ---------------------------
{
  console.log('\nGitHub project without project-security.md')
  const { sim, disk, runIt } = makeSim('VALID', GITHUB_PROJECT)
  let r = await runIt({ report: '/tmp/report.txt' })
  check(/check their mail/.test(sim.prompts['draft:reply'] || '') && !/read every case thread/.test(sim.prompts['draft:reply'] || ''), 'without a mail archive, the reply draft tells the maintainer to check their mail')
  r = await runIt({ decision: { verdict: 'VALID', cve: 'CVE-2026-22222' }, approve: { issue: true } })
  check(gateIds(r).includes('fix-model') && !r.ran.includes('issue'), 'an unknown fix model stops the issue path and asks')
  check(r.next.includes('fix-model=public'), 'the next command proposes a fix model: ' + r.next)
  check(sim.mirrors.length === 0, 'nothing is recorded without a mail archive')
  r = await runIt({ decision: { fixModel: 'public' }, approve: { issue: true } })
  check(r.ran.includes('issue') && r.ran.includes('fix'), 'fix-model=public opens the issue path')
  check(/worktree add -b fix\/42 /.test(sim.prompts['fix:#42']), 'GitHub issue numbers fill the branch pattern')
  check(/--head maintainer:fix\/42/.test(sim.prompts['fix:#42']), 'the hand-off script pushes to the fork')
  r = await runIt({ approve: { pr: true } })
  sim.live = { mainPr: { number: 28001, state: 'MERGED' } }
  r = await runIt({})
  check(gateIds(r).includes('targets') && !r.ran.some(x => x.startsWith('backport_')), 'unknown supported lines ask for targets instead of guessing')
  check(!r.ran.includes('cveDraft') && gateIds(r).includes('release'), 'the CVE draft waits for the release of the default-branch version')
  r = await runIt({ decision: { backportTargets: [] }, done: { release: true } })
  check(!gateIds(r).includes('targets'), 'targets=none clears the targets gate')
  check(r.ran.includes('cveDraft') && /template=<none configured>/.test(sim.prompts['cve:draft']), 'done=release lets the CVE draft run, and it is told no template is configured')
  check(disk.decisions.decisions.fixModel === 'public', 'the fix model is sticky')
  const bad = await runIt({ decision: { issue: 'PROJ-1' } })
  check(bad.error && /GitHub issues/.test(bad.problems.join()), 'a Jira key is rejected for a GitHub project')
}

// ---- A fix coordinated through a private GitHub security advisory ----------------------------
{
  console.log('\nGHSA-coordinated fix')
  const ghsa = Object.assign({}, GITHUB_PROJECT, { security: { present: true, lines: ['v1.x'], fixModel: 'ghsa' } })
  const { sim, runIt } = makeSim('VALID', ghsa)
  let r = await runIt({ report: '/tmp/report.txt' })
  check(!r.ran.includes('draftIssue'), 'no public issue draft when the fix goes through a private advisory')
  r = await runIt({ decision: { verdict: 'VALID', cve: 'CVE-2026-33333' }, approve: { issue: true } })
  check(gateIds(r).includes('ghsa') && !r.ran.includes('issue') && !r.ran.includes('fix'), 'the graph hands the fix to the advisory flow')
  sim.live = { mainPr: { number: 77, state: 'MERGED' } }
  r = await runIt({ decision: { pr: 77 } })
  check(!r.ran.includes('cveDraft') && gateIds(r).includes('release') && !r.ran.some(x => x.startsWith('backport_')), 'after pr=, the CVE draft still waits for the release, and no public backport starts')
  sim.live = { mainPr: { number: 77, state: 'MERGED' }, releases: { '3.0.0': true } }
  r = await runIt({})
  check(r.ran.includes('cveDraft'), 'once released, the CVE draft runs for the advisory-coordinated fix')
}

// ---- INVALID -------------------------------------------------------------------------------
{
  console.log('\nINVALID')
  const { runIt } = makeSim('INVALID', JIRA_PROJECT)
  let r = await runIt({ report: '/tmp/report.txt' })
  check(!r.ran.includes('draftIssue') && !r.ran.includes('draftCve'), 'no issue or CVE drafts for INVALID')
  r = await runIt({ decision: { verdict: 'INVALID' } })
  check(r.ran.join() === 'reply' && gateIds(r).join() === 'send-reply', 'INVALID: final reply, then the send gate')
  r = await runIt({ done: { reply: true } })
  check(r.ran.length === 0 && gateIds(r).length === 0, 'INVALID: nothing left after the reply is sent')
}

// ---- Retriage: the persist step keeps what the run produced again ----------------------------
{
  console.log('\nRetriage')
  const triageNodes = ['triage', 'challengeScope', 'challengeCode', 'draftReply', 'draftCve', 'draftIssue']
  const removeOf = p => JSON.parse(p.split('REMOVE = ')[1].split('\n\nDECISIONS = ')[0])
  let { sim, disk, runIt } = makeSim('VALID', JIRA_PROJECT)
  await runIt({ report: '/tmp/report.txt' })
  let r = await runIt({ options: { retriage: true } })
  check(triageNodes.every(x => r.ran.includes(x)), 'a retriage runs the triage, both lenses and the drafts again')
  check(removeOf(sim.prompts.persist).length === 0, 'nothing the run produced again is in REMOVE: ' + JSON.stringify(removeOf(sim.prompts.persist)))
  check(triageNodes.every(x => disk.nodes[x]), 'the fresh results are on disk after the persist step (write, then delete)')
  ;({ sim, disk, runIt } = makeSim('VALID', JIRA_PROJECT))
  await runIt({ report: '/tmp/report.txt' })
  r = await runIt({ options: { retriage: true, stopAfter: 'triage' } })
  check(r.ran.join() === 'triage' && removeOf(sim.prompts.persist).join() === triageNodes.slice(1).join(), 'stop-after=triage: the dropped nodes that did not run again are deleted')
  check(disk.nodes.triage && !disk.nodes.challengeScope && !disk.nodes.draftIssue, 'stop-after=triage: only the fresh triage is left of the dropped nodes')
}

// ---- economy=off runs every node on the session model ---------------------------------------
{
  console.log('\neconomy=off')
  const { sim, runIt } = makeSim('INVALID', JIRA_PROJECT)
  let r = await runIt({ report: '/tmp/report.txt', options: { economy: false } })
  check(r.ran.includes('triage') && sim.opts.load.model === undefined && sim.opts.persist.model === undefined, 'economy=off: the loader and the persistence step inherit the session model')
  r = await runIt({ options: { economy: 'no' } })
  check(r.error === 'invalid arguments', 'a non-boolean economy option is rejected before any agent runs')
}

// ---- A file report with a mail archive configured but no threads= stays off the archive -----
{
  console.log('\nFile report, mail archive configured, no threads')
  const { sim, disk, runIt } = makeSim('VALID', JIRA_PROJECT) // JIRA_PROJECT names a mail archive
  disk.report.threads = [] // the report arrived as a file; no threads= was passed
  await runIt({ report: '/tmp/report.txt' })
  check(/do not search the mail archive for this report/.test(sim.prompts.load) && !/search it for the reporter/.test(sim.prompts.load), 'the loader does not search the archive for a file report')
  check(!/an archive can lag/.test(sim.prompts.triage) && !/search by reporter and by subject/.test(sim.prompts.triage), 'triage leaves the mail archive out of the prior-work search')
  check(/check their mail/.test(sim.prompts['draft:reply']) && !/read every case thread/.test(sim.prompts['draft:reply']), 'the reply draft falls back to the check-your-mail header')
  await runIt({ decision: { verdict: 'VALID' } })
  check(sim.mirrors.length === 0, 'nothing is recorded in the archive for a file report with no threads')
}

// ---- Argument validation and plan mode ------------------------------------------------------
{
  console.log('\nArguments and plan mode')
  const { runIt } = makeSim('VALID', JIRA_PROJECT)
  let r = await runIt({ decision: { cve: 'CVE-26-1' } })
  check(r.error === 'invalid arguments', 'a malformed CVE id is rejected before any agent runs')
  r = await runIt({ approve: { jira: true } })
  check(r.error === 'invalid arguments', 'an unknown approval is rejected')
  r = await runIt({ threads: 'has space' })
  check(r.error === 'invalid arguments', 'a malformed thread id is rejected')
  r = await wf(null, null, null, () => {}, () => {}, { mode: 'plan', scenarios: [{ name: 'new', state: {} }] }, { total: null }, null)
  check(r[0].ready.join() === 'triage', 'plan mode routes a new case to triage without agents')
}

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED')
process.exit(failures ? 1 : 0)
