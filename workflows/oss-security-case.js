export const meta = {
  name: 'oss-security-case',
  description: 'OSS Helper: advance one security report through triage, reporter reply, CVE reservation, sanitized issue, fix, backports and CVE draft, stopping at every maintainer gate',
  whenToUse: 'Invoked by the /oss-security-case command (oss-security skill, security-case.md). New report: args.case plus args.report (a file) or args.threads (mail-archive thread ids). Existing case: args.case plus the maintainer decisions or approvals. args.mode "plan" tests the routing without agents; "status" only refreshes STATUS.md.',
  phases: [
    { title: 'Load', detail: 'resolve the project rules and operator config, read the case, refresh PR, issue and CVE facts' },
    { title: 'Triage', detail: 'triage-security-report.md, then a two-lens verdict challenge' },
    { title: 'Drafts', detail: 'reporter reply, CVE reservation fields, sanitized issue; nothing is sent' },
    { title: 'Act', detail: 'approved issue, final reply, fix-issue.md in a worktree, approved PR' },
    { title: 'Backport', detail: 'backport-pr.md per supported line once the main PR merges, plus the upgrade-note sync' },
    { title: 'CVE', detail: 'draft-cve.md once the CVE is reserved and the fixed versions are released' },
    { title: 'Persist', detail: 'node files, decisions.json, STATUS.md, mail-archive state' },
  ],
}

// One inbound security report is one "case". Each run loads the case, works out which nodes are
// ready, runs them in waves, and stops at the first gate that needs the maintainer.
//
//   triage --> challenge (scope, code) + drafts (reply, CVE fields, issue)   for the recommended verdict
//      |
//   G verdict (maintainer rules)
//      +-- VALID ............ G cve (maintainer reserves) --> final reply --> G send (maintainer)
//      |                      G approve=issue --> issue --> fix (local) --> G approve=pr --> PR
//      |                      G merge (human review) --> backports (local) --> G approve=backports --> PRs
//      |                                                 --> upgrade-note sync on the default branch --> PR
//      |                      cve + fixed versions released --> cve draft (local, or a private draft repository)
//      |                                                        --> G CNA import, signing, publication PR (maintainer)
//      +-- HARDENING ........ same issue/fix/backport path, no CVE; the final reply cites the issue
//      +-- DEFENSE_IN_DEPTH . as HARDENING, default branch only unless targets= says otherwise
//      +-- INVALID, DUPLICATE  final reply --> G send
//
// Configuration comes from four places, resolved by the loader on every run:
//   - the project's rule files (init.md): project-info.md, project-standards.md, project-guidelines.md,
//     and the optional project-security.md (CNA, advisory template and location, supported lines);
//   - git and gh: the upstream and fork remotes, the default branch, the operator's login;
//   - environment variables: OSS_SECURITY_CASES_DIR, OSS_WORKTREE_ROOT, OSS_PUSH_REMOTE,
//     OSS_SECURITY_CASE_PREFS, OSS_SECURITY_NOTES_DIR, OSS_CVE_RECORDS_DIR, OSS_JIRA_USER;
//   - an optional operator-preferences file (~/.config/oss-helper/security-case.md by default), whose
//     text is handed to every node verbatim: signing flags, build tricks, reply sign-off, and so on.
//
// State lives in <casesRoot>/<case>/: report.txt, report-meta.json, decisions.json, nodes/<node>.json,
// STATUS.md, log.md, work/ and the drafts. Decisions (verdict, cve, issue, pr, credit, targets,
// fixModel, template) and done flags are sticky. Approvals (issue, pr, backports) count for one run
// only, and only for drafts and branches that existed before that run started.
//
// Cost: every node is a fresh subagent that starts with the session's full context, and a tool call that
// runs longer than five minutes expires that context's prompt cache, so the preamble keeps every call under
// four minutes, the loader starts from a read-only probe script instead of probing one command at a time,
// and the mechanical nodes run on cheaper models (MODEL_TIERS; options.economy = false turns that off).
// The case state reaches the script only through the loader's output, so the probe reduces the node files to
// a digest of the fields the script reads; the nodes read the full records from nodes/ themselves.

// ---------------------------------------------------------------------------------------------
// Policy
// ---------------------------------------------------------------------------------------------

const VERDICTS = ['VALID', 'HARDENING', 'DEFENSE_IN_DEPTH', 'INVALID', 'DUPLICATE']

// What a ruled verdict sets in motion. 'lines' means every supported line from project-security.md;
// targets= on a case overrides it.
const POLICY = {
  VALID: { cve: true, issue: true, fix: true, backports: 'lines', issueType: 'Bug', archive: 'ACCEPTED' },
  HARDENING: { cve: false, issue: true, fix: true, backports: 'lines', issueType: 'Improvement', archive: 'REJECTED' },
  DEFENSE_IN_DEPTH: { cve: false, issue: true, fix: true, backports: [], issueType: 'Improvement', archive: 'REJECTED' },
  INVALID: { cve: false, issue: false, fix: false, backports: [], issueType: null, archive: 'REJECTED' },
  DUPLICATE: { cve: false, issue: false, fix: false, backports: [], issueType: null, archive: 'DUPLICATE' },
}

// Public text (issue, commit messages, added diff lines, PR text, test names) is linted with these,
// plus the project's denyTerms (project-security.md) and the case's own (payload fragments, the
// reporter's name, handle and address).
const DENY_HARD = ['vulnerab', 'exploit', 'CVE-', 'CVSS', 'CWE-', 'attacker', 'RCE', 'remote code execution', 'PoC', 'proof of concept', 'embargo', 'security@', 'reported by']
const DENY_SOFT = ['attack', 'bypass', 'malicious', 'payload', 'injection', 'traversal', 'SSRF', 'XXE', 'leak', 'disclos', 'advisory', 'security issue', 'reporter', 'unauthori', 'hijack', 'spoof', 'forged']

const PR_FOOTER = '🤖 Generated with [Claude Code](https://claude.com/claude-code)'
const MAX_WAVES = 6
// The fields a publish step owns: its result updates only these on the prepared node record.
const PUBLISH_FIELDS = ['status', 'pr', 'url', 'reviewers', 'blockedReason']

// Cheaper models for the mechanical nodes. The loader and the persistence step copy and write what the probe
// and the script hand them: Haiku. The issue creation, the final reply and the nodes that push and open PRs
// run scripts and gh commands: Sonnet. The judgement nodes (triage, challenge lenses, drafts, fix, backports,
// CVE draft) keep the session model. options.economy === false runs every node on it.
const MODEL_TIERS = { light: 'claude-sonnet-5-5', mechanical: 'claude-haiku-5-5' }
const NODE_TIER = { load: 'mechanical', persist: 'mechanical', issue: 'light', reply: 'light', publish: 'light' }
function modelFor(options, node) {
  if (options && options.economy === false) return undefined
  const tier = NODE_TIER[node]
  return tier ? MODEL_TIERS[tier] : undefined
}

// ---------------------------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------------------------

const STR = { type: 'string' }
const NSTR = { type: ['string', 'null'] }
const STRS = { type: 'array', items: { type: 'string' } }
const OBJ = { type: 'object', additionalProperties: true }
const INT = { type: 'integer' }
const BOOL = { type: 'boolean' }
const NUM = { type: 'number' }
const VERDICT = { type: 'string', enum: VERDICTS }
const DONE_ERR = { type: 'string', enum: ['done', 'error'] }

const CONFIG_SCHEMA = {
  type: 'object',
  required: ['repoRoot', 'repo', 'upstreamRemote', 'defaultBranch', 'tracker', 'worktreeRoot', 'casesRoot', 'skillsRoot', 'security'],
  properties: {
    repoRoot: STR,
    repo: STR,
    repoBase: STR,
    upstreamRemote: STR,
    defaultBranch: STR,
    shallow: BOOL,
    login: NSTR,
    gitName: NSTR,
    gitEmail: NSTR,
    pushRemote: NSTR,
    tracker: { type: 'string', enum: ['GitHub', 'Jira'] },
    trackerUrl: NSTR,
    jiraProject: NSTR,
    jiraUser: NSTR,
    fixBranchPattern: NSTR,
    commitFormatFix: NSTR,
    upgradeGuidePolicy: NSTR,
    buildCommand: NSTR,
    testCommand: NSTR,
    formatCommand: NSTR,
    moduleSpecificBuild: NSTR,
    parallelBuild: NSTR,
    security: {
      type: 'object',
      required: ['present'],
      properties: {
        present: BOOL,
        reportingChannel: NSTR,
        cna: NSTR,
        cnaUrl: NSTR,
        advisoryTemplate: NSTR,
        publicationLocation: NSTR,
        signing: NSTR,
        lines: STRS,
        eol: STRS,
        disclosure: NSTR,
        fixModel: { type: ['string', 'null'], enum: ['public', 'ghsa', null] },
        denyTerms: STRS,
      },
    },
    worktreeRoot: STR,
    casesRoot: STR,
    cveRecordsDir: NSTR,
    prefsFile: NSTR,
    operatorNotes: STR,
    notesDir: NSTR,
    mailArchive: NSTR,
    skillsRoot: STR,
  },
}

const LOAD_SCHEMA = {
  type: 'object',
  required: ['initialized'],
  properties: {
    initialized: BOOL,
    created: BOOL,
    error: STR,
    warnings: STRS,
    caseDir: STR,
    today: STR,
    config: CONFIG_SCHEMA,
    report: OBJ,
    decisionsFile: OBJ,
    nodes: OBJ,
    live: {
      type: 'object',
      properties: {
        mainPr: OBJ,
        issue: OBJ,
        relatedPrs: { type: 'array', items: OBJ },
        cveCandidates: { type: 'array', items: OBJ },
        archiveNewest: STR,
        replyEvidence: { type: 'array', items: OBJ },
        releases: OBJ,
      },
    },
  },
}

const TRIAGE_SCHEMA = {
  type: 'object',
  required: ['status', 'summary', 'files'],
  properties: {
    status: DONE_ERR,
    error: STR,
    recommendedVerdict: VERDICT,
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    summary: STR,
    files: STRS,
    worktree: STR,
    reporter: STR,
    credit: STR,
    components: STRS,
    modules: STRS,
    cwe: STR,
    cvssVector: STR,
    cvssScore: NUM,
    suggestedCveTitle: STR,
    affected: STR,
    fixVersionsByLine: { type: 'object', additionalProperties: STR },
    introducedBy: STR,
    duplicateOf: STR,
    neverCite: STRS,
    denyTerms: STRS,
    guideNoteLikely: BOOL,
    backportNotes: STR,
  },
}

const CHALLENGE_SCHEMA = {
  type: 'object',
  required: ['status', 'agree', 'reasons'],
  properties: { status: DONE_ERR, agree: BOOL, proposedVerdict: VERDICT, reasons: STRS, missedFacts: STRS },
}

const DRAFT_REPLY_SCHEMA = {
  type: 'object',
  required: ['status', 'forVerdict', 'file'],
  properties: { status: DONE_ERR, forVerdict: VERDICT, file: STR, alreadyReplied: BOOL, archiveNewest: STR, notes: STRS },
}

const DRAFT_CVE_SCHEMA = {
  type: 'object',
  required: ['status', 'file'],
  properties: {
    status: DONE_ERR,
    file: STR,
    title: STR,
    cwe: STR,
    cvssVector: STR,
    cvssScore: NUM,
    candidates: { type: 'array', items: { type: 'object', properties: { cve: STR, titlePrefix: STR, date: STR, threadId: STR } } },
    notes: STRS,
  },
}

const DRAFT_ISSUE_SCHEMA = {
  type: 'object',
  required: ['status', 'forVerdict', 'payloadFile', 'scriptFile'],
  properties: {
    status: DONE_ERR,
    forVerdict: VERDICT,
    payloadFile: STR,
    scriptFile: STR,
    summary: STR,
    issueType: STR,
    components: STRS,
    fixVersions: STRS,
    missingVersions: STRS,
    duplicates: STRS,
    lintHard: STRS,
    lintSoft: STRS,
  },
}

const ISSUE_SCHEMA = {
  type: 'object',
  required: ['status'],
  properties: { status: { type: 'string', enum: ['created', 'exists', 'handoff', 'error'] }, key: STR, url: STR, inProgress: BOOL, note: STR },
}

const REPLY_SCHEMA = {
  type: 'object',
  required: ['status', 'forVerdict', 'file'],
  properties: { status: DONE_ERR, forVerdict: VERDICT, forCve: NSTR, forIssue: NSTR, file: STR, alreadyReplied: BOOL, notes: STRS },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['status'],
  properties: {
    status: { type: 'string', enum: ['local', 'pr-open', 'blocked'] },
    blockedReason: STR,
    summary: STR,
    worktree: STR,
    branch: STR,
    commits: STRS,
    tests: STR,
    build: { type: 'string', enum: ['green', 'red', 'not-run'] },
    guideNote: BOOL,
    guideFile: STR,
    lintHard: STRS,
    lintSoft: STRS,
    prBodyFile: STR,
    prScript: STR,
    pr: INT,
    url: STR,
    reviewers: STRS,
  },
}

const BACKPORT_SCHEMA = {
  type: 'object',
  required: ['status', 'line'],
  properties: {
    status: { type: 'string', enum: ['existing', 'local', 'pr-open', 'blocked'] },
    line: STR,
    blockedReason: STR,
    localBranch: STR,
    worktree: STR,
    commits: STRS,
    straight: BOOL,
    adaptations: STRS,
    fixVersion: STR,
    prBodyFile: STR,
    pr: INT,
    url: STR,
    reviewers: STRS,
  },
}

const DOCSYNC_SCHEMA = {
  type: 'object',
  required: ['status'],
  properties: {
    status: { type: 'string', enum: ['local', 'pr-open', 'blocked', 'not-needed'] },
    blockedReason: STR,
    worktree: STR,
    branch: STR,
    commit: STR,
    files: STRS,
    prBodyFile: STR,
    pr: INT,
    url: STR,
  },
}

const CVEDRAFT_SCHEMA = {
  type: 'object',
  required: ['status'],
  properties: {
    status: { type: 'string', enum: ['drafted', 'blocked'] },
    blockedReason: STR,
    forCve: STR,
    files: STRS,
    omittedBlocks: STRS,
    todos: STRS,
    archived: BOOL,
    checklistFile: STR,
  },
}

const PERSIST_SCHEMA = { type: 'object', required: ['written'], properties: { written: STRS, errors: STRS } }

// ---------------------------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------------------------

function oneLine(x) { return String(x || '').split('\n')[0].slice(0, 180) }
function pick(o, keys) { const r = {}; for (const k of keys) if (o && o[k] !== undefined) r[k] = o[k]; return r }
function gate(id, text, unblock) { return { id, text, unblock } }
function lineShort(line) { return String(line).replace(/[^A-Za-z0-9]+/g, '-').replace(/^-+|-+$/g, '') }
function issueNum(key) { const m = String(key || '').match(/(\d+)$/); return m ? m[1] : 'x' }
function lintCount(node) { return `${((node && node.lintHard) || []).length} hard, ${((node && node.lintSoft) || []).length} soft` }

function verdictOf(s) { return s.decisions.verdict || (s.nodes.triage || {}).recommendedVerdict || null }
function issueKeyOf(s) {
  const k = s.decisions.issue || (s.nodes.issue && s.nodes.issue.key) || null
  if (!k) return null
  return s.config.tracker === 'GitHub' ? '#' + issueNum(k) : k
}
function lines(s) { return ((s.config.security || {}).lines || []).slice() }
// A case is tied to the mail archive only when it has case threads the maintainer named with
// threads=. A report given as a file (or a paste) with no threads= is not in the archive, so the
// loader does not search it, triage leaves it out of the prior-work search, the reply drafts fall
// back to "check your mail", and nothing is mirrored. threads= attaches the archive on any run.
function archiveLinked(s) { return !!(s.config.mailArchive && ((s.report && s.report.threads) || []).length) }

// The backport targets of the effective verdict, and whether they are still unknown.
function targetsInfo(s) {
  if (Array.isArray(s.decisions.backportTargets)) return { targets: s.decisions.backportTargets, unknown: false }
  const P = POLICY[verdictOf(s)]
  if (!P) return { targets: [], unknown: false }
  if (P.backports !== 'lines') return { targets: P.backports, unknown: false }
  const l = lines(s)
  return { targets: l, unknown: l.length === 0 }
}
function targetsOf(s) { return targetsInfo(s).targets }

// How a VALID fix is coordinated: through a sanitized public issue and PR, or a private GitHub
// security advisory. Not a vulnerability means public.
function fixModelOf(s) {
  const P = POLICY[verdictOf(s)]
  if (P && !P.cve) return 'public'
  return s.decisions.fixModel || (s.config.security || {}).fixModel || null
}

function branchFor(s) {
  const key = issueKeyOf(s), num = issueNum(key)
  const pattern = s.config.fixBranchPattern || 'fix/<ISSUE_ID>'
  const id = s.config.tracker === 'GitHub' ? num : key
  return pattern.replace(/<ISSUE_ID>/g, id).replace(/<ISSUE_NUMBER>/g, num).replace(/<short-slug>/g, 'security-fix')
}
function headRef(s, branch) {
  const c = s.config
  return c.pushRemote && c.pushRemote !== c.upstreamRemote && c.login ? `${c.login}:${branch}` : branch
}

// PRs found by the loader's search cover PRs opened by hand or by other committers' tooling.
function relatedPr(s, base, headPrefix) {
  return ((s.live && s.live.relatedPrs) || []).find(p => p.baseRefName === base && p.state !== 'CLOSED'
    && (!headPrefix || String(p.headRefName || '').startsWith(headPrefix)))
}
function mainPrOf(s) {
  if (s.decisions.pr) return s.decisions.pr
  if (s.nodes.fix && s.nodes.fix.pr) return s.nodes.fix.pr
  if (!issueKeyOf(s)) return null
  const rel = relatedPr(s, s.config.defaultBranch, branchFor(s))
  return rel ? rel.number : null
}
function mainPrState(s) {
  const pr = mainPrOf(s)
  if (!pr) return null
  if (s.live.mainPr && s.live.mainPr.number === pr && s.live.mainPr.state) return s.live.mainPr.state
  const rel = ((s.live && s.live.relatedPrs) || []).find(p => p.number === pr)
  return rel ? rel.state : (s.live.mainPr && s.live.mainPr.state) || null
}
// The fixed versions (the default branch and every backport line) that are not released yet; null when they are
// unknown. A backport's own fixVersion wins over the triage's, because a release cut can move it to the next patch.
function unreleased(s) {
  const byLine = (s.nodes.triage || {}).fixVersionsByLine || {}
  const versions = [byLine.main || byLine[s.config.defaultBranch]].concat(targetsOf(s).map(l => {
    const b = s.nodes['backport_' + l]
    return (b && b.fixVersion) || byLine[l]
  })).filter(Boolean)
  if (!versions.length) return null
  const released = (s.live && s.live.releases) || {}
  return Array.from(new Set(versions)).filter(v => released[v] !== true)
}

function fixVersionsFor(s, verdict) {
  const byLine = (s.nodes.triage || {}).fixVersionsByLine || {}
  const P = POLICY[verdict]
  const targets = Array.isArray(s.decisions.backportTargets) ? s.decisions.backportTargets : (P && P.backports === 'lines' ? lines(s) : [])
  return [byLine.main || byLine[s.config.defaultBranch]].concat(targets.map(l => byLine[l])).filter(Boolean)
}

// The challenge results with their lens, which the node name gives.
function lenses(n) {
  return [['scope', n.challengeScope], ['code', n.challengeCode]].filter(x => x[1])
}

function challengeNote(n) {
  const cs = lenses(n)
  if (!cs.length) return ''
  const against = cs.filter(([, c]) => c.agree === false)
  if (!against.length) return cs.length === 2 ? '; both challenge lenses agree' : '; one challenge lens agrees'
  return '; CONTESTED: ' + against.map(([lens, c]) => `the ${lens} lens proposes ${c.proposedVerdict || '?'} (${oneLine((c.reasons || [])[0])})`).join('; ')
}

function reporterTerms(s) {
  const r = s.report || {}
  return [r.reporter, r.reporterEmail, r.reporterHandle].filter(x => typeof x === 'string' && x.length > 2)
}

function lintRule(s) {
  const q = x => JSON.stringify(x)
  const extra = ((s.nodes.triage || {}).denyTerms || []).concat((s.config.security || {}).denyTerms || [], reporterTerms(s))
  return `Lint the public text with a case-insensitive grep (whole words for terms of four letters or fewer). Hard terms, which must not appear: ${DENY_HARD.concat(extra).map(q).join(', ')}. Soft terms, allowed only where they describe the code itself (list every hit): ${DENY_SOFT.map(q).join(', ')}.`
}

function caseFacts(s) {
  const n = s.nodes, t = n.triage || {}, d = s.decisions, c = s.config
  return JSON.stringify({
    case: s.case,
    caseDir: s.caseDir,
    today: s.today,
    project: pick(c, ['repo', 'repoRoot', 'upstreamRemote', 'defaultBranch', 'pushRemote', 'login', 'tracker', 'trackerUrl', 'jiraProject', 'jiraUser', 'fixBranchPattern', 'commitFormatFix', 'upgradeGuidePolicy', 'buildCommand', 'testCommand', 'worktreeRoot', 'notesDir', 'mailArchive']),
    security: c.security,
    public: !!s.options.public,
    report: pick(s.report, ['subject', 'reporter', 'reporterHandle', 'via', 'receivedAt', 'threads']),
    verdict: d.verdict || null,
    recommendedVerdict: t.recommendedVerdict || null,
    fixModel: fixModelOf(s),
    cve: d.cve || null,
    issue: issueKeyOf(s),
    mainPr: mainPrOf(s),
    mainPrState: mainPrState(s),
    credit: d.credit || t.credit || null,
    backportTargets: targetsOf(s),
    triage: pick(t, ['cwe', 'cvssVector', 'cvssScore', 'suggestedCveTitle', 'affected', 'fixVersionsByLine', 'duplicateOf', 'neverCite', 'guideNoteLikely', 'worktree']),
    fix: pick(n.fix || {}, ['status', 'worktree', 'branch', 'commits', 'pr', 'url', 'guideNote', 'guideFile']),
  }, null, 2)
}

// ---------------------------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------------------------

function preamble(s, nodeFile) {
  const c = s.config, sec = c.security || {}
  const record = nodeFile
    ? `- As your last step, write the object you return, as pretty JSON, to ${s.caseDir}/nodes/${nodeFile}.json. That file is this node's record: the workflow does not write it again.`
    : '- Do not write node files; the workflow records your result.'
  const lineText = sec.lines && sec.lines.length
    ? `The supported lines are ${c.defaultBranch} plus ${sec.lines.join(', ')}.${sec.eol && sec.eol.length ? ' End of life, although the branches may still exist: ' + sec.eol.join(', ') + '.' : ''}`
    : 'No supported maintenance lines are configured (project-security.md is missing or lists none); do not assume any.'
  const published = sec.publicationLocation
    ? `A CVE counts as published when its advisory is live at the project's publication location (${sec.publicationLocation}); CVE.org can lag behind it.`
    : 'A CVE counts as published only when its advisory is publicly live; CVE.org can lag behind the project.'
  const prefs = c.operatorNotes && c.operatorNotes.trim()
    ? `\n\nOperator preferences (from ${c.prefsFile}). Follow them unless they conflict with the rules above:\n<<<PREFERENCES\n${c.operatorNotes.trim()}\nPREFERENCES>>>`
    : ''
  return `You are one node of the "oss-security-case" workflow (OSS Helper). It moves one inbound security report for ${c.repo} through triage, the reply to the reporter, CVE reservation, a sanitized issue, the fix, the backports and the CVE draft. The maintainer${c.gitName ? ' (' + c.gitName + (c.login ? ', GitHub ' + c.login : '') + ')' : ''} is NOT available while you run. Where a guideline says to ask or confirm with the user, use the decisions given here. If a decision you need is missing, do not guess: stop and report the node as blocked.

Case facts:
${caseFacts(s)}

The full record of each node is in ${s.caseDir}/nodes/<node>.json, and the triage's analysis in ${s.caseDir}/triage.md: read them when your task needs more than these facts.

Rules for every node:
- Embargo. The report is private until the advisory is published. Nothing that marks the change as a security fix may reach a public place: the issue tracker, the forge (commit messages, branch names, PR text, review comments), test names, code comments, mailing lists. Public text describes the change in functional terms only. Case material stays in ${s.caseDir}.
- The project's rule files (via ${c.skillsRoot}/oss-security/init.md) and its agent instructions (CLAUDE.md, AGENTS.md, CONTRIBUTING) still apply, for example attribution, PR-volume caps and test conventions.
- Never work in the maintainer's checkout ${c.repoRoot}: not as cwd and not for reads, because it may sit on another branch. Use the worktree your task names, under ${c.worktreeRoot}, and pass absolute paths in every command, because the Bash cwd resets between calls.
- Fetch before you trust a ref: git --git-dir=${c.repoRoot}/.git fetch ${c.upstreamRemote}. ${c.shallow ? 'The clone is shallow, so take history from gh api "repos/' + c.repo + '/commits?path=<file>&sha=<branch>". ' : ''}Decide whether release Y contains commit X with gh api repos/${c.repo}/compare/<tag Y>...<X> --jq .status (behind or identical means it does); an unfetched tag makes local git checks lie.
- ${lineText}
- Only PUBLISHED CVEs may be named in anything a reporter or the public reads. ${published} Never name an unpublished CVE id, a sibling finding or another embargoed report there.
- Scratch files (calculators, fetched pages, mock servers, copies of payloads) go in ${s.caseDir}/work/, never in /tmp or a session scratchpad.
- Keep every tool call under four minutes. Builds, test runs and other long commands go to the background and are polled in slices of at most 240 seconds (for example timeout 240 tail --pid=<pid> -f /dev/null, then read the log), because a call that runs longer than five minutes expires the prompt cache and bills the whole context again.
- You never send email, reserve CVE ids, merge PRs, or publish or sign advisories. Those are the maintainer's actions.
- Issue-tracker writes, git push and PR creation happen only in the nodes whose task says so. If the permission system refuses one of them, do not retry it and do not reshape the request: report it.
${record}${prefs}`
}

function loadPrompt(a) {
  const threads = threadList(a)
  const sources = []
  if (a.report) sources.push(`copy ${a.report} to <caseDir>/report.txt (cp, keep the original)`)
  if (threads.length) sources.push(`for each mail-archive thread id in ${JSON.stringify(threads)}: read the thread with the mail archive's thread-reading tool, and append each message (From, Date, Subject, body) to <caseDir>/report.txt`)
  return `You are the loader of the "oss-security-case" workflow (OSS Helper), case "${a.case}". You are read-only, except that you create and fill the case directory. Do not build, push, or write to an issue tracker or forge.

1. Configuration. Start with the probe, once: bash ~/.claude/skills/oss-security/security-case-probe.sh ${a.case} ${a.repo ? a.repo : '.'}. It is read-only and prints, in sections, the clone (root, remotes with their org/repo, default branch, shallow flag), the operator (gh login, git identity, the upstream and push remotes it worked out), the project's rule files, the environment variables and the directories they resolve to, the operator preferences, and the case directory with its JSON files. Take every value it answers from that output; run only what it leaves open (an ERROR marker, a missing section, the Jira user, the mail archive, and the live facts of step 4). The definitions below are the contract for each field. Return every value in config; use null when a value is unknown, never guess.
   - repoRoot: the clone root (git rev-parse --show-toplevel in ${a.repo ? a.repo : 'the current working directory'}). If that is not a git repository, return initialized=false with error "run from a clone of the project, or pass repo=<path>". repoBase: its directory name.
   - Follow steps 1 and 2 of ~/.claude/skills/oss-security/init.md from repoRoot (skip step 3) to find the project's rule files. repo (org/repo) from project-info.md's GitHub repo; upstreamRemote = the git remote whose URL points at that repo; defaultBranch: gh repo view <repo> --json defaultBranchRef --jq .defaultBranchRef.name; shallow: git rev-parse --is-shallow-repository.
   - login: gh api /user --jq .login. gitName and gitEmail: git config user.name and user.email. pushRemote: $OSS_PUSH_REMOTE if set, else the remote whose URL points at <login>/<repository name>, else null.
   - tracker (GitHub or Jira), trackerUrl and jiraProject from project-info.md. jiraUser: $OSS_JIRA_USER if set, else, for Jira with $JIRA_TOKEN set, one GET of <REST base>/rest/api/2/myself (field name), else null.
   - fixBranchPattern and commitFormatFix from project-guidelines.md (the fix entries). upgradeGuidePolicy: the project's rule on where upgrade or migration notes go when a fix is backported, quoted from its rule files or agent instructions, else null.
   - buildCommand, testCommand, formatCommand, moduleSpecificBuild, parallelBuild from project-standards.md.
   - security, from project-security.md when the rules include it (present=true): reportingChannel, cna, cnaUrl, advisoryTemplate, publicationLocation, signing, disclosure; lines = the supported maintenance branches as branch names (for example release-2.x); eol = end-of-life branches that still exist; fixModel = "public" when undisclosed fixes go through a neutral public issue and PR, "ghsa" when they go through a private GitHub security advisory, null when the file does not say; denyTerms = any public-text denylist it lists. Without the file: {"present": false}.
   - worktreeRoot: $OSS_WORKTREE_ROOT, else the parent directory of repoRoot. casesRoot: $OSS_SECURITY_CASES_DIR, else $HOME/.oss-helper/security-cases. cveRecordsDir: $OSS_CVE_RECORDS_DIR, else null. skillsRoot: $HOME/.claude/skills.
   - prefsFile: $OSS_SECURITY_CASE_PREFS, else $HOME/.config/oss-helper/security-case.md, when that file exists; operatorNotes: its full text ("" when there is none).
   - notesDir: $OSS_SECURITY_NOTES_DIR when it is set and the directory exists, else null.
   - mailArchive: the name of the MCP server that the operator preferences designate as the archive of the project's private security mailing list, when its tools are available to you (check with ToolSearch), else null. Without one there is no mail archive: skip every mail-archive step below.
2. Case directory <casesRoot>/${a.case} (caseDir).
   - If it does not exist: mkdir -p <caseDir>/nodes <caseDir>/cve <caseDir>/work, and chmod 700 <casesRoot> and <caseDir>. Then get the report: ${sources.length ? sources.join('; ') : 'NO report source was given, so return initialized=false with error "no report: pass report=<file> or threads=<thread id>"'}.
   - If it exists and a report file was given while report.txt is already there, do not overwrite report.txt; add a warning.${threads.length ? `
   - If it exists and report-meta.json lacks some of the thread ids ${JSON.stringify(threads)}: add them to its "threads" list, read them with the mail archive's thread-reading tool, append their messages to <caseDir>/report-threads.txt (report.txt stays as it is), and fill in "via", "receivedAt" and "participants" where they are empty.` : ''}
   - If report-meta.json is missing, write it: {"threads": [...], "subject", "reporter", "reporterEmail", "reporterHandle", "via", "receivedAt", "participants": [...]}. Take what report.txt shows. Set "threads" to the ids in ${JSON.stringify(threads)} (an empty list when none were given); do not search the mail archive for this report's thread, even when one is configured. A case is tied to the archive only by the thread ids the maintainer passes with threads=.
3. The probe's case section prints <caseDir>/report-meta.json, <caseDir>/decisions.json ({} when missing) and a digest of the node files between "--- nodes digest" and "--- end nodes digest": return that JSON object as nodes, exactly as printed. If the probe printed the node files themselves instead of a digest, return them as an object keyed by file name without ".json", exactly as they are. Read the files yourself only if the probe could not; never summarize or edit them.
4. Live facts. Read-only, one request each:
   - today: date -u +%F.
   - The main PR number is ${a.decision && a.decision.pr ? a.decision.pr : 'decisions.decisions.pr, else nodes.fix.pr'}. If there is one: gh pr view <n> --repo <repo> --json number,state,isDraft,mergedAt,mergeCommit,url,reviewDecision -> live.mainPr.
   - The issue is ${a.decision && a.decision.issue ? a.decision.issue : 'decisions.decisions.issue, else nodes.issue.key'}. If there is one: its status, assignee and fix versions (Jira: one GET of /rest/api/2/issue/<key>?fields=status,assignee,fixVersions; GitHub: gh issue view <n> --repo <repo> --json state,assignees,milestone) -> live.issue; and every PR that names it, including backports opened by others: gh pr list --repo <repo> --state all --search "<the issue key, or the main PR number for GitHub>" --json number,title,state,baseRefName,headRefName,author,url -> live.relatedPrs.
   - With a mail archive: live.archiveNewest = the date of the newest message it holds (from its status tool, if it has one). Only when report-meta.json lists case threads (ids the maintainer passed with threads=): live.replyEvidence = the maintainer's messages in those threads (git config user.email, or another address the operator preferences give) after the report: {date, threadId, firstLine}; with no case threads there is nothing about this report to search, so omit replyEvidence. When the verdict (decisions.decisions.verdict${a.decision && a.decision.verdict ? ' = ' + a.decision.verdict : ''}, else nodes.triage.recommendedVerdict) is VALID and no CVE id is decided${a.decision && a.decision.cve ? ' (one is: skip this)' : ''}, live.cveCandidates: if the project's CNA announces reservations on a list the archive holds (the operator preferences say how to recognize them), the reservations newer than the report whose title matches nodes.triage.suggestedCveTitle: {cve, titlePrefix, date, threadId}.
   - live.releases, only when a CVE id is decided (decisions.decisions.cve${a.decision && a.decision.cve ? ' = ' + a.decision.cve : ''}): for each version in nodes.triage.fixVersionsByLine and each nodes.backport_<line>.fixVersion, whether it is released to the project's distribution channel. If project-security.md says how releases are checked, follow it. Otherwise: for a Maven project, the POM of its main artifact answers 200 on Maven Central (https://repo1.maven.org/maven2/<group path>/<artifact>/<version>/<artifact>-<version>.pom); for npm, npm view <package>@<version> version prints it; for PyPI, https://pypi.org/pypi/<package>/<version>/json answers 200; for crates.io, https://crates.io/api/v1/crates/<crate>/<version> answers 200; else a published (not draft) GitHub release exists for the version's tag. A git tag alone is not a release. Return {"<version>": true|false}.
Return the structured result, with decisionsFile = the content of decisions.json.`
}

function triagePrompt(s) {
  const c = s.config
  const pub = s.options.public ? 'PUBLIC (already disclosed)' : `PRIVATE (received through ${(c.security && c.security.reportingChannel) || 'a private channel'})`
  return `${preamble(s, 'triage')}

NODE: triage
TASK: triage the report with the triage guideline, without a maintainer.

1. Read ${c.skillsRoot}/oss-security/init.md and ${c.skillsRoot}/oss-security/triage-security-report.md, then follow the triage guideline with these overrides:
   - Step 1: the report is ${s.caseDir}/report.txt; its metadata (threads, reporter, dates) is in ${s.caseDir}/report-meta.json.
   - Step 2: the public status is ${pub}. Do not ask.
   - Step 3: do not wait for the claims to be confirmed. List them in the triage file; the maintainer reviews it at the verdict gate.
   - Step 6: propose only. Create no issue, PR, advisory or email.
2. Work in a detached worktree: git --git-dir=${c.repoRoot}/.git worktree add --detach ${c.worktreeRoot}/${c.repoBase}-triage-${s.case} ${c.upstreamRemote}/${c.defaultBranch} (fetch first; reuse it if it already exists for this case). Run init.md's project detection from that worktree.
3. Verify statically. Read the code at the cited refs on ${c.upstreamRemote}/${c.defaultBranch}${lines(s).map(l => ', ' + c.upstreamRemote + '/' + l).join('')}, and at the latest release tags. Do not write anything that performs the reported attack or stands up an attacker-controlled endpoint. When reading is not conclusive, a logic-only check is fine: a standalone class or script that calls the code, with no network. If you ran nothing, write "no runtime reproduction" in the triage.
4. Search for prior work before you decide:
   - the history of the cited files, one read-only issue-tracker search${archiveLinked(s) ? ', and the case threads in the mail archive (search by reporter and by subject, and note how fresh it is, since an archive can lag)' : ''};
   - ${c.notesDir ? 'the maintainer\'s notes: grep -il the component, class and option names in ' + c.notesDir + '/*.md and read the hits. They record earlier reports, duplicates, sibling CVEs, rulings, and what must never be cited to a reporter;' : 'the project\'s published advisories, for earlier reports in the same area;'}
   - whether the defect is already fixed on ${c.defaultBranch}, or in a sibling component on the same code path.
5. Classify against the project's security model or threat model, when it has one (look for a security-model or threat-model page in the docs, or SECURITY.md), into exactly one verdict:
   - VALID: untrusted input crosses a trust boundary the project should hold, in a default or reasonably expected configuration. Needs a CVE.
   - HARDENING: not a vulnerability under the model (trusted input, documented behaviour, operator responsibility, explicit opt-in), but the code or a default should still change, in public. No CVE.
   - DEFENSE_IN_DEPTH: nothing is reachable, but an extra safeguard is worth adding. No CVE.
   - INVALID: the claims are refuted or out of model, and nothing should change.
   - DUPLICATE: the same defect is already reported, fixed or has a CVE. Name it in the triage file only (duplicateOf).
6. Severity (required for VALID, for reference otherwise): write the CVSS 3.1 vector first and compute the score yourself, then pick the severity. Do not copy the rating of a similar advisory: some published ones are under-scored. Check your calculator first: AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:N must give 6.5. PR:L is right when the attacker must first be able to write to a backing system (a queue, a cluster, a store). Give the CWE and a title in the style of the project's earlier advisories.
7. Versions: find the commit that introduced the defect (introducedBy). Give the affected range per line, for example "from 1.0.0 before 1.9.4, from 2.0.0 before 2.5.1". Take each line's fix version from its build file (strip -SNAPSHOT or the equivalent), and move to the next patch if that version is already tagged or has a release branch: releases are often cut before the version is bumped. Return them in fixVersionsByLine, keyed by "main" for ${c.defaultBranch} and by branch name for the other lines.
8. Sibling sweep: look for the same defect pattern in sibling components. Record what you find as PRIVATE in the triage file, and add every sibling, every unpublished CVE id and every other embargoed report you mention to neverCite.
9. Write ${s.caseDir}/triage.md: the guideline's summary template with the :robot: disclaimer, plus the sections "Verdict", "CVSS", "Proposed CVE fields" (VALID only), "Never cite to the reporter or in public", "Fix plan" (files, approach, tests named for the behaviour, whether an upgrade or migration note is needed), "Backport notes" (what differs on each supported line: test framework versions, annotations, generated files), and "Questions for the reporter".
10. denyTerms: strings from the report that must never appear in public text (payload fragments, the reporter's own wording of the flaw, names, handles, addresses).

Return the structured result. files lists every file you wrote.`
}

function challengePrompt(s, lens) {
  const t = s.nodes.triage, c = s.config
  const refs = [c.defaultBranch].concat(lines(s)).map(b => c.upstreamRemote + '/' + b).join(', ')
  const focus = lens === 'scope'
    ? `SCOPE lens. Build the strongest evidence-based case that the verdict is wrong on scope. Read the project's security or threat model (trust assumptions, out-of-scope opt-ins), the component documentation on each supported line (is the behaviour documented? is it behind an explicit insecure option?), and the defaults on each line.${c.notesDir ? ' Check how the project ruled on similar reports in ' + c.notesDir + '/*.md.' : ''} A HARDENING or DEFENSE_IN_DEPTH call that should be VALID matters as much as the reverse.`
    : `CODE lens. Re-verify the claims the verdict rests on, at ${refs}. Is the path reachable in the DEFAULT configuration, or does a codec, filter, converter or default option drop or mask it? Is it already fixed on ${c.defaultBranch} or in a sibling component? Are the affected range and the fix versions right (gh api compare against the release tags)?`
  return `${preamble(s, lens === 'scope' ? 'challengeScope' : 'challengeCode')}

NODE: ${lens === 'scope' ? 'challengeScope' : 'challengeCode'}
TASK: challenge the triage verdict ${t.recommendedVerdict} (${t.confidence || '?'} confidence). Read ${s.caseDir}/report.txt and ${s.caseDir}/triage.md. Work read-only in ${c.worktreeRoot}/${c.repoBase}-triage-${s.case} (git show, gh api) and write no file except your node JSON.
${focus}
Agree only if you could not refute the verdict. missedFacts lists the facts the triage file does not record. Verify statically; do not run anything that performs the attack.`
}

function draftReplyPrompt(s, verdict, ruled) {
  const c = s.config
  const threads = archiveLinked(s)
    ? `Then read every case thread listed in report-meta.json in the mail archive (the reporter's own thread and any forwarded thread, where the maintainers' replies may sit). Note whether the maintainer has already replied, and compare the archive's freshness with the report date: a stale archive proves nothing.`
    : 'This report is not tied to a mail-archive thread, so say in the header that the maintainer must check their mail for an earlier reply.'
  return `${preamble(s, 'draftReply')}

NODE: draftReply
TASK: draft the reply to the reporter for the verdict ${verdict} (${ruled ? 'ruled by the maintainer' : 'recommended by the triage; the maintainer has not ruled yet'}). Write ${s.caseDir}/reply-draft.txt. Send nothing.

Read report.txt, report-meta.json and triage.md ("Never cite", "Questions for the reporter", corrections) in ${s.caseDir}. ${threads}

The draft:
- A header for the maintainer only: "DRAFT - not sent", what you checked for earlier replies, and "Do NOT mention:" followed by the never-cite list.
- "Subject: Re: <original subject>", then "Hi <the reporter's first name>,".
- Thank them, say what was verified (against ${c.defaultBranch} and the release tags), then give the verdict in plain words:
  - VALID: it is valid and we reserved <CVE-ID> for it (keep that literal placeholder until the id is known); we will tell them which releases include the fix; ask them to keep it private until the advisory, which includes no public PR or issue even with neutral wording; ask how they want to be credited.
  - HARDENING or DEFENSE_IN_DEPTH: not a vulnerability under the project's security model, so no CVE; give the model's reasoning; we will change it in public as <ISSUE> (placeholder); since there is no advisory, offer a credit note on the issue.
  - INVALID: what was verified and why it is not a vulnerability. Do not be dismissive; add configuration advice when it helps.
  - DUPLICATE: the flaw is already known and being handled; name the other report's CVE only if it is published; write "TODO maintainer: credit?" where the credit would go.
- "Some corrections to the report:" when the triage found any (version range, component, defaults).
- A mitigation the reporter can apply now, when there is one.
- Sign with the name from git config user.name, plus a role line if the operator preferences give one.
Leave out siblings, unpublished CVE ids, other reports, internal notes, and any exploit detail beyond what the reporter sent.
Your result's forVerdict is ${verdict}.`
}

function draftCvePrompt(s) {
  const sec = s.config.security || {}
  const cna = sec.cna ? `${sec.cna}${sec.cnaUrl ? ' (' + sec.cnaUrl + ')' : ''}` : 'the project\'s CNA'
  const reserved = s.config.mailArchive
    ? 'If the project\'s CNA announces reservations on a list the mail archive holds (the operator preferences say how to recognize them), list the reservations dated after the report, with their title and date. Also read any forwarded summary in the case threads: it sometimes names an id already reserved for the same flaw. Give the archive\'s freshness.'
    : 'There is no mail archive here: write that the maintainer must check the CNA tool for an existing reservation of the same flaw.'
  return `${preamble(s, 'draftCve')}

NODE: draftCve
TASK: prepare the CVE reservation fields. The maintainer reserves the id with ${cna}; you reserve nothing and do not touch that tool. Write ${s.caseDir}/cve-reservation.md with:
- The title in the style of the project's earlier advisories, the CWE id with its official title, the CVSS 3.1 vector and score with the alternatives you considered, the affected product and packages, the affected ranges per line, the planned fixed versions, the credit (the name the reporter asked for), and a two or three sentence description without exploit detail. Take them from triage.md. Do not invent missing data; write TODO instead.
- "Already reserved?": ${reserved}`
}

function draftIssuePrompt(s, verdict) {
  const c = s.config, P = POLICY[verdict]
  const versions = JSON.stringify(fixVersionsFor(s, verdict))
  const body = c.tracker === 'Jira'
    ? `Fields: project ${c.jiraProject || '<from project-info.md>'}; issuetype ${P.issueType}; priority Major; components checked against GET <REST base>/rest/api/2/project/<key>/components (component names can differ from module names); assignee ${c.jiraUser ? '{"name": "' + c.jiraUser + '"}' : 'leave it out and say so (no Jira user is known)'}; fixVersions ${versions} checked against GET .../project/<key>/versions (list the missing ones in missingVersions; do not create versions).
- Duplicate check: one read-only JQL text search on the main keywords.
Write ${s.caseDir}/issue-draft.json (the POST /issue payload) and ${s.caseDir}/issue-create.sh. The script must: POST the payload with "Authorization: Bearer $JIRA_TOKEN" and "Content-Type: application/json" to <REST base>/rest/api/2/issue (the REST base is the tracker URL without "browse/"); stop and print the response if no key comes back; print the key; write {"status": "created", "key": "<key>", "url": "<tracker URL><key>", "via": "script"} to ${s.caseDir}/nodes/issue.json; then GET /issue/<key>/transitions and POST the "Start Progress" transition only if it is offered.`
    : `Labels: ${P.issueType === 'Bug' ? '"bug"' : '"enhancement"'} (check that they exist with gh label list --repo ${c.repo}). Assignee: @me.
- Duplicate check: one gh issue list --repo ${c.repo} --state all --search on the main keywords.
Write ${s.caseDir}/issue-draft.json ({"title", "body", "labels"}) and ${s.caseDir}/issue-create.sh. The script must: create the issue with gh issue create --repo ${c.repo} --title <title> --body-file <the body written to a file> --label <labels> --assignee @me; print the URL; write {"status": "created", "key": "#<number>", "url": "<url>", "via": "script"} to ${s.caseDir}/nodes/issue.json.`
  return `${preamble(s, 'draftIssue')}

NODE: draftIssue
TASK: draft the sanitized public issue (the ${c.tracker} path of the create-issue guideline) and a hand-off script. Create nothing.
Read ${c.skillsRoot}/oss-issues/create-issue.md (${c.tracker} path) and the "Fix plan" in ${s.caseDir}/triage.md.
- Title under 80 characters, "<component> - <functional change>", for example "http-server - match authorization roles by exact name".
- Description: the behaviour today and after the change, the classes involved, the code-level change and the tests. No attack scenario, payload, CVE or severity, no reporter identity, and nothing that frames it as a vulnerability.
- ${body}
- ${lintRule(s)} Apply it to the title and the description.
chmod +x the script: the maintainer may run it as "! bash ${s.caseDir}/issue-create.sh".
Your result's forVerdict is ${verdict}.`
}

function issuePrompt(s) {
  return `${preamble(s, 'issue')}

NODE: issue
TASK: create the sanitized issue. The maintainer reviewed ${s.caseDir}/issue-draft.json and approved it.
1. Check that it does not exist yet: one search for its title in the issue tracker. If it exists, return status "exists" with the key.
2. Lint the draft again. ${lintRule(s)} On any hard hit, create nothing and return status "error" with the hits.
3. Run the hand-off script once: bash ${s.caseDir}/issue-create.sh. If the permission system refuses the call, or the call fails, do not retry and do not reshape the request: return status "handoff", so that the maintainer runs "! bash ${s.caseDir}/issue-create.sh" themselves.
4. On success, confirm with one read (status, assignee, fix versions or labels) and return the key${s.config.tracker === 'GitHub' ? ' as "#<number>"' : ''} and URL.`
}

function replyPrompt(s) {
  const d = s.decisions, pr = mainPrOf(s), c = s.config
  return `${preamble(s, 'reply')}

NODE: reply
TASK: finalize the reply to the reporter for the ruled verdict ${d.verdict}. Write ${s.caseDir}/reply-final.txt from ${s.caseDir}/reply-draft.txt. Send nothing.
- Fill in the placeholders: <CVE-ID> = ${d.cve || 'not applicable'}, <ISSUE> = ${issueKeyOf(s) || 'not applicable'}. For HARDENING or DEFENSE_IN_DEPTH you may also give the fix PR (${pr ? 'https://github.com/' + c.repo + '/pull/' + pr : 'none yet'}); for VALID, never point at public work before the advisory.
- ${archiveLinked(s) ? 'Re-read the case threads in the mail archive first. If the maintainer has already answered, do not repeat it: write only what is new, or say in the header that no reply is needed.' : 'Keep the header line telling the maintainer to check their mail for an earlier reply.'}
- Check the final text against the never-cite list, and check that every CVE id in it is either published (by the rule above) or this case's own reserved id.
- Keep the maintainer header; the maintainer sends the reply.
Return forVerdict, forCve (the CVE id you used, or null) and forIssue (the issue key you used, or null).`
}

function prCapNote(s) {
  return `If the project's agent instructions cap PRs per day or per operator, recount right before creating: gh pr list --repo ${s.config.repo} --author ${s.config.login || '<login>'} --state all --limit 40 --json number,createdAt --jq '[.[] | select(.createdAt | startswith("${s.today}"))] | length', and stop with status "local" and blockedReason "PR cap" when the cap is reached.`
}

function fixPrompt(s) {
  const c = s.config, key = issueKeyOf(s), num = issueNum(key), branch = branchFor(s)
  const wt = `${c.worktreeRoot}/${c.repoBase}-${num}`
  const guide = c.upgradeGuidePolicy
    ? `- Upgrade or migration notes, only when users see a behaviour change, following the project's rule: "${c.upgradeGuidePolicy}". Use neutral wording, and insert the note between two existing notes of the newest section, never at the end of the file. Return guideNote=true and guideFile.`
    : '- Upgrade or migration notes: only when users see a behaviour change and the project keeps such a guide; neutral wording. Return guideNote and guideFile.'
  return `${preamble(s, 'fix')}

NODE: fix
TASK: implement the fix for ${key} with the fix-issue guideline (${c.skillsRoot}/oss-issues/init.md, then fix-issue.md), without a maintainer, up to a LOCAL commit. Do not push and do not open a PR in this node.
Overrides:
- Ownership: ${key} is the maintainer's own issue. Before you start, make sure nobody else works on it: gh pr list --repo ${c.repo} --state all --search "${key}", the issue's linked PRs, and no other session working on it (ListAgents, if you have it). If ${wt} exists and holds work that this case did not make, stop with status "blocked".
- Resume: if ${wt} already exists on branch ${branch} with this case's work, continue from there.
- Worktree: git --git-dir=${c.repoRoot}/.git worktree add -b ${branch} ${wt} ${c.upstreamRemote}/${c.defaultBranch}. Ignore the guideline's "git checkout main".
- Implement the "Fix plan" in ${s.caseDir}/triage.md. Keep the change minimal. Name new tests for the behaviour (for example ...PathNormalizationTest), never for the attack, and follow the module's test conventions.
- Prove the test: it must fail on the unfixed code for the reason the fix addresses, not with a compile error and not as a vacuous pass. Revert only the production change, run the test, restore the change.
${guide}
- Build, test and format with the guideline's build workflow and project-standards.md${c.buildCommand ? ' (build: ' + c.buildCommand + ')' : ''}. Commit every regenerated file; git status must be clean at the end. Run one build at a time; start long builds in the background and poll them in slices of at most 240 seconds, as the rules above say, never in one long wait.
- Commit message in the project's fix format${c.commitFormatFix ? ' ("' + c.commitFormatFix + '")' : ''}, with a neutral description, ending with the co-author trailer your attribution settings require. Sign the commit if the operator preferences ask for it. No session id anywhere.
- ${lintRule(s)} Apply it to the commit message, to the added lines of the diff, and to the test class and method names. Fix the hard hits; list the soft hits.
- Write ${s.caseDir}/pr-body.md: the problem in functional terms, the change, the tests; any attribution the project's agent instructions require; the last line is exactly "${PR_FOOTER}".
- Write ${s.caseDir}/pr-create.sh for the maintainer, in case the agent is refused later: it pushes with git -C ${wt} push -u ${c.pushRemote || '<push remote>'} ${branch}, then runs gh pr create --repo ${c.repo} --base ${c.defaultBranch} --head ${headRef(s, branch)} --title "<the commit subject>" --body-file ${s.caseDir}/pr-body.md, and prints the PR URL. chmod +x it.
Return status "local" with worktree, branch, commits, tests (test counts), build, guideNote, guideFile, lint hits, prBodyFile and prScript; or status "blocked" with the reason.`
}

function fixPublishPrompt(s) {
  const c = s.config, f = s.nodes.fix, branch = f.branch || branchFor(s)
  const head = (f.commits || []).slice(-1)[0] || 'the prepared commit'
  return `${preamble(s, null)}

NODE: fix (publish)
TASK: publish the fix that the maintainer approved: push ${branch} from ${f.worktree} and open the pull request.
1. Check the worktree: HEAD is ${head}, the tree is clean, and the commits are signed if the operator preferences ask for signing. If ${c.defaultBranch} moved and the branch no longer merges cleanly, rebase it (keep the signatures: git rebase --gpg-sign), re-run the module tests, and say so.
2. ${prCapNote(s)}
3. ${c.pushRemote ? 'git -C ' + f.worktree + ' push -u ' + c.pushRemote + ' ' + branch + '.' + (c.pushRemote !== c.upstreamRemote ? ' Never push the branch to ' + c.upstreamRemote + ', the upstream repository.' : '') : 'No push remote is known (no fork remote for the operator and no OSS_PUSH_REMOTE): stop with status "local" and blockedReason "no push remote".'}
4. gh pr create --repo ${c.repo} --base ${c.defaultBranch} --head ${headRef(s, branch)} --title "<the commit subject>" --body-file ${f.prBodyFile || s.caseDir + '/pr-body.md'}. Not a draft.
5. Reviewers: at least two active maintainers who changed the touched files in the last year (gh api "repos/${c.repo}/commits?path=<file>&per_page=50" --jq '.[].author.login'), excluding ${c.login || 'the operator'} and bots: gh pr edit <n> --add-reviewer <a>,<b>.
If a push or the PR creation is refused, return status "local" with blockedReason "permission: the maintainer can run ! bash ${f.prScript || s.caseDir + '/pr-create.sh'}".
Return status "pr-open" with pr (the number), url and reviewers.`
}

function backportPrompt(s, line) {
  const c = s.config, key = issueKeyOf(s), pr = mainPrOf(s), num = issueNum(key), sh = lineShort(line)
  const wt = `${c.worktreeRoot}/${c.repoBase}-bp-${num}-${sh}`
  const guide = c.upgradeGuidePolicy
    ? `- Upgrade or migration notes follow the project's rule: "${c.upgradeGuidePolicy}". When that rule keeps the notes on ${c.defaultBranch}, drop every note change from the backport; the doc-sync node writes the per-line notes there.`
    : '- Keep any upgrade or migration note change only if the line keeps its own guide.'
  return `${preamble(s, 'backport_' + line)}

NODE: backport_${line}
TASK: prepare the backport of the merged PR #${pr} (${key}) to ${line} with the backport guideline (${c.skillsRoot}/oss-review/init.md, then backport-pr.md), up to a LOCAL commit. Do not push and do not open a PR here.
Overrides:
- Remotes: the guideline uses one <REMOTE>. Here the base comes from ${c.upstreamRemote} (the upstream repository) and the branch goes to ${c.pushRemote || 'the push remote'} later. Base = ${c.upstreamRemote}/${line}.
- Look for an existing port first: gh pr list --repo ${c.repo} --state all --search "${key}". Other maintainers' tooling sometimes opens "[backport ${line}] ..." within minutes of the merge. If one exists for ${line}, do not duplicate it: compare gh pr diff <it> with gh pr diff ${pr}, and return status "existing" with its number and whether it is a straight cherry-pick.
- Commits: gh pr view ${pr} --repo ${c.repo} --json commits,mergeCommit,files. A squash merge is the single merge commit; a rebase merge put several commits on ${c.defaultBranch}: cherry-pick those copies, oldest first. Compare the PR's file list with what you picked.
- Worktree: git --git-dir=${c.repoRoot}/.git worktree add -b backport/${pr}-to-${sh} ${wt} ${c.upstreamRemote}/${line}. Cherry-pick with -x.
${guide}
- Adapt to ${line} where needed, using the "Backport notes" of ${s.caseDir}/triage.md (test framework versions, annotations or generated files missing on older lines). Anything beyond a mechanical port makes straight=false; list the adaptations.
- Build and test per project-standards.md, in the background and polled in slices of at most 240 seconds; generated files must come from this branch's own build, never copied from ${c.defaultBranch}. git status must be clean at the end.
- Commit with the original message, the "(cherry picked from commit <sha>)" line and the co-author trailer your attribution settings require; sign it if the operator preferences ask for it.
- fixVersion: ${line}'s next unreleased version from its build file, moved to the next patch if that version is already tagged or has a release branch.
- Write ${s.caseDir}/backport-${sh}-pr-body.md: "Backport of #${pr}" with the original title, whether it is straight or adapted (list the adaptations), any attribution the project requires, and last "${PR_FOOTER}".
Return line "${line}" and status "local" (or "existing" or "blocked"), with localBranch, worktree, commits, straight, adaptations, fixVersion and prBodyFile.`
}

function backportPublishPrompt(s, line) {
  const c = s.config, b = s.nodes['backport_' + line], pr = mainPrOf(s)
  return `${preamble(s, null)}

NODE: backport_${line} (publish)
TASK: publish the backport that the maintainer approved: push ${b.localBranch} from ${b.worktree} and open the PR against ${line}.
1. Check that the worktree is clean and HEAD is the prepared commit. If ${line} moved and the branch conflicts, rebase it (git rebase --gpg-sign keeps signatures), re-run the module tests, and say so.
2. Make sure no other backport PR for ${line} appeared meanwhile (gh pr list --repo ${c.repo} --state all --search "${issueKeyOf(s)}"); if one did, return status "existing" with its number.
3. ${prCapNote(s)}
4. ${c.pushRemote ? 'git -C ' + b.worktree + ' push -u ' + c.pushRemote + ' ' + b.localBranch + ' (never to the upstream remote unless it is the push remote).' : 'No push remote is known: stop with status "local" and blockedReason "no push remote".'}
5. gh pr create --repo ${c.repo} --base ${line} --head ${headRef(s, b.localBranch)} --title "[backport ${line}] <the title of #${pr}>" --label backport --body-file ${b.prBodyFile || s.caseDir + '/backport-' + lineShort(line) + '-pr-body.md'}. If the label does not exist, create the PR without it.
6. Reviewers: ${b.straight ? 'none, because this is a straight cherry-pick of a reviewed PR (unless the project rules say otherwise)' : 'at least two maintainers, as for the main PR, because the port was adapted'}.
If a push or the PR creation is refused, return status "local" with blockedReason "permission" and the two commands for the maintainer.
Return line "${line}", status "pr-open", pr and url.`
}

function docSyncPrompt(s) {
  const c = s.config, key = issueKeyOf(s), num = issueNum(key), f = s.nodes.fix || {}
  const lineList = targetsOf(s).map(l => `${l} (fix version ${(s.nodes['backport_' + l] || {}).fixVersion || 'from its build file'})`)
  return `${preamble(s, 'docSync')}

NODE: docSync
TASK: write the per-line upgrade or migration notes for the backports of ${key} on ${c.defaultBranch}, following the project's rule: "${c.upgradeGuidePolicy}". The main PR #${mainPrOf(s)} added its note to ${f.guideFile || 'the current guide'}.
- Worktree: git --git-dir=${c.repoRoot}/.git worktree add -b docs/${lineShort(key)}-guide-sync ${c.worktreeRoot}/${c.repoBase}-docsync-${num} ${c.upstreamRemote}/${c.defaultBranch}.
- For each of ${lineList.join(', ')}: add the note to that line's guide on ${c.defaultBranch}, in the section for the patch release that ships the fix (create the section, newest first, if it is missing). Insert between two existing notes, never at the end of the file. Word it for that line: what is true on ${c.defaultBranch} may not be true on an older line.
- Commit with a neutral message in the project's format, the co-author trailer your attribution settings require, signed if the operator preferences ask for it.
- ${lintRule(s)}
- Write ${s.caseDir}/docsync-pr-body.md: the notes it adds, the backport PRs it accompanies (by number, once they exist), that it merges after them, any attribution the project requires, and last "${PR_FOOTER}".
Return status "local" with worktree, branch, commit, files and prBodyFile.`
}

function docSyncPublishPrompt(s) {
  const c = s.config, ds = s.nodes.docSync
  const bps = targetsOf(s).map(l => s.nodes['backport_' + l]).filter(b => b && b.pr).map(b => b.line + ' #' + b.pr).join(', ')
  return `${preamble(s, null)}

NODE: docSync (publish)
TASK: publish the upgrade-note sync that the maintainer approved: push ${ds.branch} from ${ds.worktree} and open the PR against ${c.defaultBranch}.
1. Check that the worktree is clean. If ${c.defaultBranch} moved and the guides conflict, rebase (git rebase --gpg-sign) and re-check where the notes sit.
2. ${prCapNote(s)}
3. ${c.pushRemote ? 'git -C ' + ds.worktree + ' push -u ' + c.pushRemote + ' ' + ds.branch + '.' : 'No push remote is known: stop with status "local" and blockedReason "no push remote".'}
4. gh pr create --repo ${c.repo} --base ${c.defaultBranch} --head ${headRef(s, ds.branch)} --title "<the commit subject>" --body-file ${ds.prBodyFile || s.caseDir + '/docsync-pr-body.md'}. Make the body name the backport PRs (${bps || 'none recorded'}) and say that it merges after them.
5. Reviewers: two maintainers, as for the main PR.
Return status "pr-open", pr and url.`
}

function cveDraftPrompt(s) {
  const c = s.config, sec = c.security || {}, d = s.decisions, pr = mainPrOf(s)
  const template = d.template || sec.advisoryTemplate
  return `${preamble(s, 'cveDraft')}

NODE: cveDraft
TASK: draft the advisory and the CVE Record JSON for ${d.cve} with the CVE-draft guideline (${c.skillsRoot}/oss-security/init.md, then draft-cve.md), without a maintainer.
Arguments for the guideline:
- cve_id=${d.cve}
- template=${template ? template + ' (the maintainer configured it, so fetching it needs no further confirmation)' : '<none configured>: look at the operator preferences for a template; if none is given, stop with status "blocked" and blockedReason "template: pass template=<url or path>"'}
- triage_ref=${s.caseDir}/triage.md, fix_pr=${pr}
- backup_repo: as the guideline resolves it (OSS_CVE_BACKUP_REPO). Its privacy gate is mandatory. Make any clone of it under ${s.caseDir}/cve/ and delete the clone afterwards.
Where the drafts go: they are written to ${s.caseDir}/cve/ and stay there. When a private draft repository is configured (the backup_repo above) and its privacy gate confirms it is private, they are also archived there, and archived=true. With none configured, they stay local only, and archived=false. Never push them to any other remote, and never open a pull request with them: signing the advisory and opening the publication PR are the maintainer's steps.
Overrides:
- Step 4: do not wait for the skeleton to be confirmed; put it in the checklist.
- Steps 6 and 7: write the files to ${s.caseDir}/cve/, not to a repository root.${c.cveRecordsDir ? ' Then copy ' + d.cve + '.cve5.json to ' + c.cveRecordsDir + '/.' : ''}
- Versions: this node runs only after the fixed versions are released, so "Versions fixed" should be final. Start from the triage's ranges and fix versions (a backport's own fixVersion wins). A version counts as fixed only if it is released to the project's distribution channel (for example Maven Central, npm, PyPI or crates.io; a git tag alone is not a release) and contains the fix commit (gh api compare). Keep a TODO marker for anything not released yet.
- Credit: ${JSON.stringify(d.credit || (s.nodes.triage || {}).credit || 'TODO: ask the maintainer')}.
- Do not sign, publish, open PRs, touch the publication repository${sec.publicationLocation ? ' (' + sec.publicationLocation + ')' : ''}, or drive the CNA tool.
- Write ${s.caseDir}/cve/CHECKLIST.md: the step 8 checklist, the JSON blocks you omitted and why, the template skeleton, and the remaining TODOs.
Return status "drafted" with forCve, files, omittedBlocks, todos, archived and checklistFile; or status "blocked" with the reason.`
}

function persistPrompt(s, p) {
  const author = `${s.config.login || 'maintainer'} via oss-security-case`
  const mirror = p.mirror
    ? `5. Mail archive (${s.config.mailArchive}): for each thread id in ${JSON.stringify(p.mirror.threads)}, record the triage state "${p.mirror.state}" with the archive's tool for triage states, and add the note ${JSON.stringify(p.mirror.note)} with its tool for notes, both with author "${author}". Skip whichever tool the archive does not have.`
    : '5. No mail-archive update in this run.'
  return `You are the persistence step of the "oss-security-case" workflow, case "${s.case}". Write exactly what is given below and nothing else.
1. For each key K of NODES, write ${s.caseDir}/nodes/K.json with the value, pretty-printed (overwrite). Each node of CHECK wrote ${s.caseDir}/nodes/K.json itself: write that file with the value only if it is missing or is not valid JSON. For each name in REMOVE, delete ${s.caseDir}/nodes/<name>.json if it exists.
2. Write ${s.caseDir}/decisions.json with DECISIONS, pretty-printed.
3. Write ${s.caseDir}/STATUS.md with the text between the STATUS markers, verbatim.
4. Append each LOG entry as one line to ${s.caseDir}/log.md, prefixed with the time from date -u +%FT%TZ.
${mirror}
Return written (the paths) and errors.

NODES = ${JSON.stringify(p.nodes, null, 2)}

CHECK = ${JSON.stringify(p.check || {}, null, 2)}

REMOVE = ${JSON.stringify(p.remove)}

DECISIONS = ${JSON.stringify(p.decisions, null, 2)}

LOG = ${JSON.stringify(p.log, null, 2)}

<<<STATUS
${p.status}
STATUS>>>`
}

// ---------------------------------------------------------------------------------------------
// The graph: which nodes are ready, and which gates hold the rest
// ---------------------------------------------------------------------------------------------

function replyCurrent(r, V, P, cve, key) {
  if (!r || r.status === 'error' || r.forVerdict !== V) return false
  if (P.cve) return (r.forCve || null) === cve
  if (P.issue) return (r.forIssue || null) === key
  return true
}

// fresh = node ids produced during this run; approvals never cover them.
function plan(s, fresh) {
  const n = s.nodes, d = s.decisions, ap = s.approvals, dn = s.done, o = s.options, c = s.config, sec = c.security || {}
  const ready = [], gates = [], info = []
  const t = n.triage
  if (!t || (t.status === 'error' && o.retry)) return { ready: ['triage'], gates, info }
  if (t.status === 'error') {
    gates.push(gate('triage-failed', `Triage failed: ${oneLine(t.error) || 'see log.md'}.`, 'retry'))
    return { ready, gates, info }
  }
  const rec = t.recommendedVerdict, V = d.verdict, eff = V || rec, P = POLICY[eff]

  if (o.challenge !== false) {
    if (!n.challengeScope) ready.push('challengeScope')
    if (!n.challengeCode) ready.push('challengeCode')
  }
  if (!n.draftReply || n.draftReply.forVerdict !== eff) ready.push('draftReply')
  if (P.cve && !n.draftCve) ready.push('draftCve')
  if (P.issue && fixModelOf(s) !== 'ghsa' && (!n.draftIssue || n.draftIssue.forVerdict !== eff)) ready.push('draftIssue')

  if (!V) {
    const files = ['triage.md', 'reply-draft.txt'].concat(P.cve ? ['cve-reservation.md'] : [], P.issue && n.draftIssue ? ['issue-draft.json'] : [])
    gates.push(gate('verdict', `Rule on the verdict. The triage recommends ${rec} (${t.confidence || '?'} confidence)${challengeNote(n)}. Read ${files.join(', ')}.`, `verdict=${rec}`))
    return { ready, gates, info }
  }

  const key = issueKeyOf(s), cve = d.cve || null, model = fixModelOf(s)

  // CVE reservation is the maintainer's.
  if (P.cve && !cve) {
    const cands = ((s.live && s.live.cveCandidates) || []).map(x => `${x.cve} ("${x.titlePrefix}", ${x.date})`).join('; ')
    const where = sec.cna ? `${sec.cna}${sec.cnaUrl ? ' (' + sec.cnaUrl + ')' : ''}` : 'your CNA (for GitHub-hosted projects, request a CVE from a GitHub security advisory)'
    gates.push(gate('cve', `Reserve the CVE with ${where}, using the fields in cve-reservation.md${cands ? '. Possibly reserved already: ' + cands : ''}.`, 'cve=CVE-YYYY-NNNNN'))
  }

  // How the fix is coordinated, for a vulnerability.
  if (P.issue && !model) {
    gates.push(gate('fix-model', 'Decide how this fix is coordinated: "public" (a neutral public issue and PR before disclosure, as projects that coordinate on a private security list do) or "ghsa" (a private GitHub security advisory and its temporary fork). Add the answer to project-security.md to stop being asked.', 'fix-model=public or fix-model=ghsa'))
  } else if (P.issue && model === 'ghsa') {
    gates.push(gate('ghsa', `This fix is coordinated through a private GitHub security advisory: follow the security-advisory guideline (create-security-advisory.md) and fix it in the advisory's private fork. The graph's public issue, fix and backport nodes stay off for this case. Once the fix is merged, pass pr=<number> to let the CVE draft run.`, 'pr=<number> once merged'))
  } else if (P.issue && !key) {
    const draftOk = n.draftIssue && n.draftIssue.forVerdict === V
    if (n.issue && n.issue.status === 'handoff') gates.push(gate('issue-handoff', `The agent was not allowed to create the issue. Run: ! bash ${s.caseDir}/issue-create.sh`, 'run again afterwards'))
    else if (!draftOk) info.push(`The issue draft is being regenerated for ${V}.`)
    else if (ap.issue && !fresh.has('draftIssue')) ready.push('issue')
    else gates.push(gate('approve-issue', `Review issue-draft.json (lint: ${lintCount(n.draftIssue)}${(n.draftIssue.missingVersions || []).length ? '; missing fix versions ' + n.draftIssue.missingVersions.join(', ') : ''}).`, `approve=issue (or file it yourself and pass issue=${c.tracker === 'Jira' ? 'KEY-NNN' : '<number>'})`))
  }

  // Final reply to the reporter.
  if (!dn.reply) {
    const waitFor = P.cve ? (cve ? null : 'the CVE id') : (P.issue && !key ? 'the issue' : null)
    if (waitFor) info.push(`The final reply waits for ${waitFor}.`)
    else if (!replyCurrent(n.reply, V, P, cve, key)) ready.push('reply')
    else gates.push(gate('send-reply', `Send reply-final.txt to the reporter (check ${archiveLinked(s) ? 'the thread' : 'your mail'} for any earlier answer first).`, 'done=reply'))
  }

  // The fix on the default branch.
  const pr = mainPrOf(s), prState = mainPrState(s)
  if (P.fix && model === 'public' && !key) info.push('The fix starts once the issue exists.')
  if (P.fix && model === 'public' && key) {
    const f = n.fix
    if (pr) {
      if (prState !== 'MERGED') gates.push(gate('merge', `Main PR #${pr} is ${prState || 'OPEN'}. It needs a genuine human maintainer approval and a merge; AI-generated approvals do not count.`, 'wait, then run again'))
    } else if (!f || (f.status === 'blocked' && o.retry)) ready.push('fix')
    else if (f.status === 'blocked') gates.push(gate('fix-blocked', `The fix is blocked: ${oneLine(f.blockedReason)}.`, 'retry'))
    else if (f.status === 'local') {
      if (ap.pr && !fresh.has('fix')) ready.push('fix:publish')
      else gates.push(gate('approve-pr', `Review the fix in ${f.worktree} (git -C ${f.worktree} show --stat HEAD; lint: ${lintCount(f)}) and pr-body.md.`, `approve=pr${f.blockedReason ? ' (last attempt: ' + oneLine(f.blockedReason) + ')' : ''}`))
    } else gates.push(gate('fix-pr-unknown', 'The fix reports an open PR without a number.', 'pr=<number>'))
  }

  // Backports and the upgrade-note sync, once the default branch has the fix.
  const merged = prState === 'MERGED'
  const ti = targetsInfo(s)
  if (P.fix && model === 'public' && pr && merged) {
    if (ti.unknown) gates.push(gate('targets', 'No supported maintenance lines are configured for this project (project-security.md is missing or lists none).', 'targets=<branch,...> or targets=none'))
    let allOpen = true
    for (const line of ti.targets) {
      const id = 'backport_' + line, b = n[id]
      const ext = relatedPr(s, line, null)
      if (ext && (!b || b.status === 'blocked' || b.status === 'local')) {
        info.push(`Backport to ${line} exists: #${ext.number} by ${(ext.author && ext.author.login) || '?'} (${ext.state}). Check that it is a straight cherry-pick.`)
        continue
      }
      if (!b || (b.status === 'blocked' && o.retry)) { ready.push(id); allOpen = false }
      else if (b.status === 'blocked') { allOpen = false; gates.push(gate('backport-blocked', `The backport to ${line} is blocked: ${oneLine(b.blockedReason)}.`, 'retry')) }
      else if (b.status === 'local') {
        allOpen = false
        if (ap.backports && !fresh.has(id)) ready.push(id + ':publish')
        else gates.push(gate('approve-backports', `Review the ${line} backport in ${b.worktree} (${b.straight ? 'straight cherry-pick' : 'adapted: ' + ((b.adaptations || []).join('; ') || '?')}).`, 'approve=backports'))
      }
    }
    if (n.fix && n.fix.guideNote && c.upgradeGuidePolicy && ti.targets.length) {
      const ds = n.docSync
      if (!ds || (ds.status === 'blocked' && o.retry)) ready.push('docSync')
      else if (ds.status === 'blocked') gates.push(gate('docsync-blocked', `The upgrade-note sync is blocked: ${oneLine(ds.blockedReason)}.`, 'retry'))
      else if (ds.status === 'local') {
        if (!allOpen) info.push('The upgrade-note sync PR opens after the backport PRs.')
        else if (ap.backports && !fresh.has('docSync')) ready.push('docSync:publish')
        else gates.push(gate('approve-backports', `Review the upgrade-note sync commit in ${ds.worktree}.`, 'approve=backports'))
      }
    }
  } else if (P.fix && model === 'public' && pr && (ti.targets.length || ti.unknown)) info.push('The backports start once the main PR is merged.')

  // CVE draft: only once the fixed versions are released, not at the merge. Signing the advisory and opening the
  // publication PR follow it, and stay with the maintainer.
  if (V === 'VALID' && cve) {
    const pending = unreleased(s)
    if (!pr || !merged) info.push('The CVE draft, its signing and the publication PR come after the fixed versions are released.')
    else if (pending === null && !dn.release) gates.push(gate('release', 'The fixed versions are unknown, so their release cannot be checked. The CVE draft, its signing and the publication PR come after the release.', 'done=release once every fixed version is released'))
    else if (pending && pending.length && !dn.release) gates.push(gate('release', `The CVE draft, its signing and the publication PR wait for the release of ${pending.join(', ')}.`, 'wait for the release, then run again (or done=release)'))
    else {
      const cd = n.cveDraft
      if (!cd || cd.forCve !== cve || o.redraftCve || (cd.status === 'blocked' && o.retry)) ready.push('cveDraft')
      else if (cd.status === 'blocked') gates.push(gate('cve-draft-blocked', `The CVE draft is blocked: ${oneLine(cd.blockedReason)}.`, /template/.test(cd.blockedReason || '') ? 'template=<url or path>, then retry' : 'retry'))
      else gates.push(gate('cve-record', `The fixed versions are released, and the drafts are in cve/${cd.archived ? ' and in the private draft repository' : ' (local only)'}. Work through cve/CHECKLIST.md, load cve/${cve}.cve5.json into ${sec.cna ? 'the CNA tool of ' + sec.cna : 'your CNA tool'}, sign the advisory text${sec.signing ? ' (' + oneLine(sec.signing) + ')' : ''}, and open the publication PR${sec.publicationLocation ? ' for ' + sec.publicationLocation : ''} yourself. Then send the reporter the final notice and remove the case worktrees.`, 'redraft-cve to refresh the draft'))
    }
  }

  if (!ready.length && !gates.length) info.push('Nothing left for the graph in this case.')
  return { ready, gates: mergeGates(gates), info }
}

function mergeGates(gates) {
  const out = []
  for (const g of gates) {
    const same = out.find(x => x.id === g.id)
    if (same) same.text += ' ' + g.text
    else out.push(Object.assign({}, g))
  }
  return out
}

function nextCommand(s, p) {
  const parts = ['/oss-security-case', s.case], approve = []
  for (const g of p.gates) {
    if (g.id === 'verdict') parts.push(g.unblock)
    else if (g.id === 'cve') parts.push('cve=CVE-YYYY-NNNNN')
    else if (g.id === 'fix-model') parts.push('fix-model=public')
    else if (g.id === 'targets') parts.push('targets=<branch,...>')
    else if (g.id === 'approve-issue') approve.push('issue')
    else if (g.id === 'approve-pr') approve.push('pr')
    else if (g.id === 'approve-backports') approve.push('backports')
    else if (g.id === 'send-reply') parts.push('done=reply')
    else if (/blocked|failed/.test(g.id)) parts.push('retry')
    else if (g.id === 'fix-pr-unknown' || g.id === 'ghsa') parts.push('pr=<number>')
  }
  if (approve.length) parts.push('approve=' + Array.from(new Set(approve)).join(','))
  return Array.from(new Set(parts)).join(' ')
}

// ---------------------------------------------------------------------------------------------
// Running nodes
// ---------------------------------------------------------------------------------------------

function nodeSpec(s, id, mode) {
  const eff = verdictOf(s)
  if (id === 'triage') return { prompt: triagePrompt(s), schema: TRIAGE_SCHEMA, phase: 'Triage', label: 'triage' }
  if (id === 'challengeScope') return { prompt: challengePrompt(s, 'scope'), schema: CHALLENGE_SCHEMA, phase: 'Triage', label: 'challenge:scope', effort: 'high' }
  if (id === 'challengeCode') return { prompt: challengePrompt(s, 'code'), schema: CHALLENGE_SCHEMA, phase: 'Triage', label: 'challenge:code', effort: 'high' }
  if (id === 'draftReply') return { prompt: draftReplyPrompt(s, eff, !!s.decisions.verdict), schema: DRAFT_REPLY_SCHEMA, phase: 'Drafts', label: 'draft:reply', effort: 'medium' }
  if (id === 'draftCve') return { prompt: draftCvePrompt(s), schema: DRAFT_CVE_SCHEMA, phase: 'Drafts', label: 'draft:cve-fields', effort: 'medium' }
  if (id === 'draftIssue') return { prompt: draftIssuePrompt(s, eff), schema: DRAFT_ISSUE_SCHEMA, phase: 'Drafts', label: 'draft:issue', effort: 'medium' }
  if (id === 'issue') return { prompt: issuePrompt(s), schema: ISSUE_SCHEMA, phase: 'Act', label: 'issue:create', effort: 'medium' }
  if (id === 'reply') return { prompt: replyPrompt(s), schema: REPLY_SCHEMA, phase: 'Act', label: 'reply:final', effort: 'medium' }
  if (id === 'fix') {
    return mode === 'publish'
      ? { prompt: fixPublishPrompt(s), schema: FIX_SCHEMA, phase: 'Act', label: 'fix:publish', effort: 'medium' }
      : { prompt: fixPrompt(s), schema: FIX_SCHEMA, phase: 'Act', label: 'fix:' + issueKeyOf(s) }
  }
  if (id.indexOf('backport_') === 0) {
    const line = id.slice('backport_'.length)
    return mode === 'publish'
      ? { prompt: backportPublishPrompt(s, line), schema: BACKPORT_SCHEMA, phase: 'Backport', label: 'backport:' + line + ':publish', effort: 'medium' }
      : { prompt: backportPrompt(s, line), schema: BACKPORT_SCHEMA, phase: 'Backport', label: 'backport:' + line, effort: 'high' }
  }
  if (id === 'docSync') {
    return mode === 'publish'
      ? { prompt: docSyncPublishPrompt(s), schema: DOCSYNC_SCHEMA, phase: 'Backport', label: 'docsync:publish', effort: 'medium' }
      : { prompt: docSyncPrompt(s), schema: DOCSYNC_SCHEMA, phase: 'Backport', label: 'docsync', effort: 'medium' }
  }
  if (id === 'cveDraft') return { prompt: cveDraftPrompt(s), schema: CVEDRAFT_SCHEMA, phase: 'CVE', label: 'cve:draft', effort: 'high' }
  throw new Error('unknown node ' + id)
}

async function runAction(s, action, run) {
  run.tried.add(action)
  const parts = action.split(':'), id = parts[0], mode = parts[1]
  const spec = nodeSpec(s, id, mode)
  const res = await agent(spec.prompt, { label: spec.label, phase: spec.phase, schema: spec.schema, effort: spec.effort, model: modelFor(s.options, mode === 'publish' ? 'publish' : id) })
  const prev = s.nodes[id]
  // A node that ran to the end wrote its own record (the preamble); the persistence step writes the ones the
  // script makes or changes: publish merges, failed agents, a triage without a verdict.
  let out, ownRecord = false
  if (!res) {
    out = mode === 'publish'
      ? Object.assign({}, prev, { blockedReason: 'the publish agent failed' })
      : { status: id === 'triage' || id.indexOf('challenge') === 0 || id.indexOf('draft') === 0 || id === 'reply' ? 'error' : 'blocked', error: 'agent failed', blockedReason: 'agent failed' }
  } else if (mode === 'publish') {
    // A publish owns the PR fields only; the prepared record (branch, worktree, adaptations) stays as it was.
    out = Object.assign({}, prev, pick(res, PUBLISH_FIELDS))
    if (!res.blockedReason) delete out.blockedReason
  } else {
    out = res
    ownRecord = true
  }
  if (id === 'triage' && out.status === 'done' && VERDICTS.indexOf(out.recommendedVerdict) < 0) {
    out.status = 'error'
    out.error = 'no verdict returned'
    ownRecord = false
  }
  s.nodes[id] = out
  if (ownRecord) run.ownRecords.add(id)
  else run.ownRecords.delete(id)
  run.fresh.add(id)
  run.ran.push(action)
  run.log.push(`${action}: ${out.status || 'done'}${out.blockedReason && out.status !== 'pr-open' ? ' (' + oneLine(out.blockedReason) + ')' : ''}`)
}

const isHeavy = x => x === 'fix' || /^backport_[^:]+$/.test(x)
const isPublish = x => /:publish$/.test(x)
const publishRank = x => (x.indexOf('fix') === 0 ? 0 : x.indexOf('backport_') === 0 ? 1 : 2)

async function runWave(s, actions, run) {
  // Builds never run concurrently; PR-opening nodes run one at a time so a daily cap is recounted
  // between them; everything else runs in parallel.
  const heavy = actions.filter(isHeavy)
  const publish = actions.filter(isPublish).sort((x, y) => publishRank(x) - publishRank(y))
  const light = actions.filter(x => !isHeavy(x) && !isPublish(x))
  const lane = async list => { for (const x of list) await runAction(s, x, run) }
  await parallel(light.map(x => () => runAction(s, x, run)).concat([() => lane(heavy), () => lane(publish)]))
}

// ---------------------------------------------------------------------------------------------
// STATUS.md, memory pointer, arguments
// ---------------------------------------------------------------------------------------------

function filesOf(s) {
  const n = s.nodes, out = []
  const add = x => { if (x && out.indexOf(x) < 0) out.push(x) }
  ;((n.triage || {}).files || []).forEach(add)
  add((n.draftReply || {}).file)
  add((n.draftCve || {}).file)
  add((n.draftIssue || {}).payloadFile)
  add((n.draftIssue || {}).scriptFile)
  add((n.reply || {}).file)
  add((n.fix || {}).prBodyFile)
  add((n.fix || {}).worktree)
  for (const k of Object.keys(n)) if (k.indexOf('backport_') === 0) { add(n[k].worktree); add(n[k].prBodyFile) }
  add((n.docSync || {}).worktree)
  ;((n.cveDraft || {}).files || []).forEach(add)
  add((n.cveDraft || {}).checklistFile)
  return out
}

function renderStatus(s, p, ran) {
  const n = s.nodes, t = n.triage || {}, d = s.decisions, r = s.report || {}, live = s.live || {}, c = s.config
  const pr = mainPrOf(s), key = issueKeyOf(s)
  const replyState = s.done.reply ? 'sent' : n.reply ? 'final draft ready' : n.draftReply ? 'draft for ' + n.draftReply.forVerdict : '-'
  const L = [
    `# Security case ${s.case} (${c.repo})`,
    '',
    `PRIVATE, embargoed material. Updated ${s.today} by the oss-security-case workflow.`,
    '',
    `- Report: ${r.subject || '?'}, from ${r.reporter || '?'}${r.via ? ', via ' + r.via : ''}, received ${r.receivedAt || '?'}${s.options.public ? ' (already public)' : ''}`,
    `- Verdict: ${d.verdict ? d.verdict + ' (maintainer ruling)' : 'not ruled yet'}; triage recommends ${t.recommendedVerdict || '-'}${t.confidence ? ' (' + t.confidence + ' confidence)' : ''}${challengeNote(n)}`,
  ]
  if (t.cvssVector) L.push(`- Severity: CVSS ${t.cvssScore} ${t.cvssVector}${t.cwe ? ', ' + t.cwe : ''}${t.suggestedCveTitle ? '; title "' + t.suggestedCveTitle + '"' : ''}`)
  if (t.affected) L.push(`- Affected: ${t.affected}`)
  L.push(`- CVE: ${d.cve || '-'} | issue: ${key || '-'} | main PR: ${pr ? '#' + pr + ' (' + (mainPrState(s) || 'OPEN') + ')' : '-'} | reply: ${replyState}`)
  for (const line of targetsOf(s)) {
    const b = n['backport_' + line]
    if (b) L.push(`- Backport ${line}: ${b.status}${b.pr ? ' #' + b.pr : ''}${b.straight === false ? ' (adapted)' : ''}`)
  }
  if (n.docSync) L.push(`- Upgrade-note sync: ${n.docSync.status}${n.docSync.pr ? ' #' + n.docSync.pr : ''}`)
  if (n.cveDraft) L.push(`- CVE draft: ${n.cveDraft.status}, ${n.cveDraft.archived ? 'stored in cve/ and archived to the private draft repository' : 'stored locally in cve/ only'}`)
  if (!(c.security || {}).present) L.push('- project-security.md: not found, so the CNA, advisory template and supported lines come from your decisions')
  if (live.archiveNewest) L.push(`- Mail archive, newest message: ${live.archiveNewest}`)
  if ((live.replyEvidence || []).length) L.push(`- Maintainer replies seen in the archive: ${live.replyEvidence.map(x => x.date).join(', ')}`)
  L.push('', '## Waiting on you', '')
  if (p.gates.length) p.gates.forEach((g, i) => L.push(`${i + 1}. ${g.text} Unblock: ${g.unblock}`))
  else L.push('Nothing.')
  L.push('', '## Next run', '', '    ' + nextCommand(s, p))
  if (p.info.length) { L.push('', '## Notes', ''); p.info.forEach(x => L.push('- ' + x)) }
  const missed = []
  for (const [lens, ch] of lenses(n)) (ch.missedFacts || []).forEach(f => missed.push(`- (${lens} lens) ${f}`))
  if (missed.length) { L.push('', '## Facts the challenge lenses say the triage missed', ''); missed.forEach(x => L.push(x)) }
  L.push('', '## This run', '')
  if (ran.length) ran.forEach(x => {
    const node = n[x.split(':')[0]] || {}
    L.push(`- ${x}: ${node.status || '?'}${node.blockedReason && node.status !== 'pr-open' ? ' (' + oneLine(node.blockedReason) + ')' : ''}${node.summary ? ', ' + oneLine(node.summary) : ''}`)
  })
  else L.push('- No node ran.')
  const files = filesOf(s)
  if (files.length) { L.push('', '## Files', ''); files.forEach(f => L.push('- ' + f)) }
  return L.join('\n') + '\n'
}

function memoryFor(s, p) {
  const t = s.nodes.triage || {}, d = s.decisions, r = s.report || {}
  const slug = 'project_seccase_' + s.case.replace(/-/g, '_')
  const waiting = p.gates.map(g => g.id).join(', ') || 'nothing'
  const verdict = d.verdict || ('verdict pending (triage recommends ' + (t.recommendedVerdict || '?') + ')')
  const pr = mainPrOf(s)
  const bits = [d.cve, issueKeyOf(s), pr ? 'PR #' + pr : null].filter(Boolean).join(' ')
  const description = `PRIVATE security case ${s.case} for ${s.config.repo} (${oneLine(r.subject || '?')}; ${r.reporter || '?'}): ${verdict}${bits ? '; ' + bits : ''}; waiting on ${waiting}. State in ${s.caseDir}/STATUS.md`
  const content = [
    '---',
    'name: ' + slug,
    'description: ' + JSON.stringify(description),
    'metadata:',
    '  type: project',
    '---',
    '',
    `Embargoed security report tracked by the oss-security-case workflow; advance it with "/oss-security-case ${s.case}". The case directory ${s.caseDir} is the source of truth (STATUS.md, triage.md, nodes/*.json); this note only points at it.`,
    '',
    `- ${s.today}: ${verdict}${bits ? ', ' + bits : ''}.`,
    `- Waiting on: ${waiting}.`,
  ].concat((t.neverCite || []).length ? [`- Never cite to the reporter or in public: ${t.neverCite.join('; ')}.`] : []).join('\n') + '\n'
  return { file: slug + '.md', content, indexLine: `- [seccase-${s.case}](${slug}.md) — ${verdict}${bits ? '; ' + bits : ''}; waiting: ${waiting}` }
}

function threadList(a) {
  if (!a.threads) return []
  return (Array.isArray(a.threads) ? a.threads : String(a.threads).split(',')).map(x => String(x).trim()).filter(Boolean)
}

function validateArgs(a) {
  const problems = []
  const d = a.decision || {}
  if (d.verdict !== undefined && VERDICTS.indexOf(d.verdict) < 0) problems.push(`verdict must be one of ${VERDICTS.join(', ')}`)
  if (d.cve !== undefined && !/^CVE-\d{4}-\d{4,}$/.test(d.cve)) problems.push('cve must look like CVE-YYYY-NNNNN')
  if (d.issue !== undefined && !/^([A-Z][A-Z0-9_]*-\d+|#?\d+)$/.test(String(d.issue))) problems.push('issue must be a Jira key (KEY-123) or a GitHub issue number (#123)')
  if (d.pr !== undefined && !(Number.isInteger(d.pr) && d.pr > 0)) problems.push('pr must be a PR number')
  if (d.fixModel !== undefined && ['public', 'ghsa'].indexOf(d.fixModel) < 0) problems.push('fix-model must be public or ghsa')
  if (d.backportTargets !== undefined) {
    if (!Array.isArray(d.backportTargets)) problems.push('targets must be a list of branches')
    else for (const b of d.backportTargets) if (!/^[A-Za-z0-9._\/-]+$/.test(b)) problems.push(`${b} is not a branch name`)
  }
  for (const k of Object.keys(a.approve || {})) if (['issue', 'pr', 'backports'].indexOf(k) < 0) problems.push(`unknown approval ${k} (issue, pr, backports)`)
  for (const k of Object.keys(a.done || {})) if (['reply', 'release'].indexOf(k) < 0) problems.push(`unknown done flag ${k} (reply, release)`)
  if (a.report !== undefined && !/^\//.test(String(a.report))) problems.push('report must be an absolute file path')
  if (a.repo !== undefined && !/^\//.test(String(a.repo))) problems.push('repo must be an absolute path')
  for (const tid of threadList(a)) if (!/^[^\s,]{1,200}$/.test(tid)) problems.push(`${tid} does not look like a mail-archive thread id`)
  if (a.mode !== undefined && ['run', 'plan', 'status'].indexOf(a.mode) < 0) problems.push('mode must be run, plan or status')
  if (a.options && a.options.economy !== undefined && typeof a.options.economy !== 'boolean') problems.push('options.economy must be true or false')
  return problems
}

// Checks that need the project's configuration.
function validateAgainstConfig(s) {
  const problems = [], c = s.config, sec = c.security || {}, d = s.decisions
  if (Array.isArray(d.backportTargets) && (sec.lines || []).length) {
    for (const b of d.backportTargets) {
      if ((sec.eol || []).indexOf(b) >= 0) problems.push(`${b} is end of life for ${c.repo}; supported lines: ${sec.lines.join(', ')}`)
      else if (sec.lines.indexOf(b) < 0) problems.push(`${b} is not a supported line for ${c.repo} (${sec.lines.join(', ')})`)
    }
  }
  if (d.issue !== undefined) {
    const jira = /^[A-Z][A-Z0-9_]*-\d+$/.test(String(d.issue))
    if (c.tracker === 'Jira' && !jira) problems.push(`${c.repo} uses Jira: issue must be a key like ${c.jiraProject || 'KEY'}-123`)
    if (c.tracker === 'GitHub' && jira) problems.push(`${c.repo} uses GitHub issues: issue must be a number`)
  }
  return problems
}

// The example project of plan mode. Nothing here is read or written.
const DEFAULT_CONFIG = {
  repoRoot: '/path/to/project',
  repo: 'example/project',
  repoBase: 'project',
  upstreamRemote: 'origin',
  defaultBranch: 'main',
  shallow: false,
  login: 'maintainer',
  gitName: 'A Maintainer',
  pushRemote: 'fork',
  tracker: 'Jira',
  jiraProject: 'PROJ',
  jiraUser: 'maintainer',
  fixBranchPattern: 'fix/<ISSUE_ID>',
  commitFormatFix: '<ISSUE_ID>: <brief description of fix>',
  upgradeGuidePolicy: null,
  security: { present: true, lines: ['release-1.x'], eol: [], fixModel: 'public', denyTerms: [] },
  worktreeRoot: '/path/to',
  casesRoot: '/path/to/security-cases',
  cveRecordsDir: null,
  prefsFile: null,
  operatorNotes: '',
  notesDir: null,
  mailArchive: null,
  skillsRoot: '/path/to/skills',
}

// base supplies the example project of plan mode; a real run passes {} so that nothing the loader
// did not find gets invented.
function normalize(st, base) {
  st = st || {}
  base = base || {}
  const c = st.case || 'example'
  const config = Object.assign({}, base, st.config)
  config.security = Object.assign({ present: false }, st.config && st.config.security ? st.config.security : base.security)
  if (typeof config.operatorNotes !== 'string') config.operatorNotes = ''
  return {
    case: c,
    caseDir: st.caseDir || config.casesRoot + '/' + c,
    today: st.today || 'YYYY-MM-DD',
    config,
    report: st.report || {},
    nodes: st.nodes || {},
    live: st.live || {},
    decisions: st.decisions || {},
    approvals: st.approvals || {},
    done: st.done || {},
    options: st.options || {},
    mirrored: st.mirrored || {},
    history: st.history || [],
  }
}

// ---------------------------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------------------------

const a = args || {}

if (a.mode === 'plan') {
  // Routing test: no agents, no files.
  const scenarios = a.scenarios || [{ name: 'given', state: a.state }]
  return scenarios.map(sc => {
    const st = normalize(sc.state, DEFAULT_CONFIG)
    const p = plan(st, new Set(sc.fresh || []))
    return { name: sc.name, ready: p.ready, gates: p.gates.map(g => g.id + ': ' + g.text + ' => ' + g.unblock), info: p.info, next: nextCommand(st, p) }
  })
}

if (typeof a.case !== 'string' || !/^[a-z0-9][a-z0-9-]{1,60}$/.test(a.case)) {
  return { error: 'args.case is required: a slug of lowercase letters, digits and dashes.', example: { case: 'xml-parser-entities', report: '/absolute/path/report.txt' } }
}
const argProblems = validateArgs(a)
if (argProblems.length) return { case: a.case, error: 'invalid arguments', problems: argProblems }

const loaded = await agent(loadPrompt(a), { label: 'load', phase: 'Load', schema: LOAD_SCHEMA, effort: 'medium', model: modelFor(a.options, 'load') })
if (!loaded || !loaded.initialized || !loaded.config) {
  return { case: a.case, error: (loaded && loaded.error) || 'the loader failed', warnings: (loaded && loaded.warnings) || [] }
}

const stored = loaded.decisionsFile || {}
const s = normalize({
  case: a.case,
  caseDir: loaded.caseDir,
  today: loaded.today,
  config: loaded.config,
  report: loaded.report,
  nodes: loaded.nodes,
  live: loaded.live,
  decisions: Object.assign({}, stored.decisions, a.decision),
  approvals: Object.assign({}, a.approve),
  done: Object.assign({}, stored.done, a.done),
  options: Object.assign({ public: !!(a.public || (stored.options && stored.options.public)) }, a.options),
  mirrored: stored.mirrored,
  history: (stored.history || []).slice(),
})
const configProblems = validateAgainstConfig(s)
if (configProblems.length) return { case: a.case, error: 'invalid arguments for this project', problems: configProblems }
if (a.decision || a.approve || a.done) s.history.push({ at: s.today, decision: a.decision || null, approve: a.approve || null, done: a.done || null })

const run = { fresh: new Set(), tried: new Set(), ran: [], log: [], ownRecords: new Set() }
const removed = []
if (s.options.retriage) {
  for (const k of ['triage', 'challengeScope', 'challengeCode', 'draftReply', 'draftCve', 'draftIssue']) {
    if (s.nodes[k]) { delete s.nodes[k]; removed.push(k) }
  }
  run.log.push('retriage: dropped ' + (removed.join(', ') || 'nothing'))
}
;(loaded.warnings || []).forEach(w => run.log.push('loader: ' + w))

if (a.mode !== 'status') {
  for (let wave = 0; wave < MAX_WAVES; wave++) {
    const p = plan(s, run.fresh)
    const ready = p.ready.filter(x => !run.tried.has(x))
    if (!ready.length) break
    log(`wave ${wave + 1}: ${ready.join(', ')}`)
    await runWave(s, ready, run)
    if (s.options.stopAfter && run.ran.some(x => x.split(':')[0] === s.options.stopAfter)) { run.log.push('stopped after ' + s.options.stopAfter); break }
    if (wave === MAX_WAVES - 1) run.log.push('wave limit reached')
  }
}

const final = plan(s, run.fresh)
final.ready.filter(x => !run.tried.has(x)).forEach(x => final.info.push(`Ready for the next run: ${x}.`))

const V = s.decisions.verdict
let mirror = null
if (V && s.config.mailArchive && s.mirrored.verdict !== V && (s.report.threads || []).length) {
  mirror = { threads: s.report.threads, state: POLICY[V].archive, note: `${V} (maintainer ruling). ${oneLine(final.gates.map(g => g.id).join(', ') || 'no open gate')}. Case ${s.caseDir}` }
  s.mirrored = { verdict: V, at: s.today }
}

const status = renderStatus(s, final, run.ran)
const changed = {}, check = {}
run.fresh.forEach(id => { (run.ownRecords.has(id) ? check : changed)[id] = s.nodes[id] })
const persisted = await agent(persistPrompt(s, {
  nodes: changed,
  check,
  // A node the retriage dropped and this run produced again is rewritten, not deleted.
  remove: removed.filter(k => !run.fresh.has(k)),
  decisions: { decisions: s.decisions, done: s.done, options: { public: s.options.public }, mirrored: s.mirrored, history: s.history },
  log: run.log,
  status,
  mirror,
}), { label: 'persist', phase: 'Persist', schema: PERSIST_SCHEMA, effort: 'low', model: modelFor(s.options, 'persist') })

return {
  case: s.case,
  caseDir: s.caseDir,
  repo: s.config.repo,
  verdict: V || null,
  recommended: (s.nodes.triage || {}).recommendedVerdict || null,
  challenge: challengeNote(s.nodes).replace(/^; /, '') || null,
  ran: run.ran,
  waitingOn: final.gates,
  notes: final.info,
  next: nextCommand(s, final),
  status: s.caseDir + '/STATUS.md',
  memory: memoryFor(s, final),
  persistErrors: persisted ? (persisted.errors || []) : ['the persist agent failed: node results of this run are only in this return value'],
}
