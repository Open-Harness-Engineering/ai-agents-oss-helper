### Usage

```text
/oss-security-case <case> [report=<file>] [threads=<thread-id,...>]
    [verdict=VALID|HARDENING|DEFENSE_IN_DEPTH|INVALID|DUPLICATE] [cve=<CVE-ID>] [issue=<key or number>] [pr=<number>]
    [credit="<name>"] [targets=<branch,...>|none] [fix-model=public|ghsa] [template=<url|path>]
    [approve=issue,pr,backports] [done=reply,release] [public] [retry] [retriage] [redraft-cve] [no-challenge]
    [economy=off] [stop-after=<node>] [status|plan]
```

- `<case>` - a slug for the report (lowercase letters, digits and dashes, for example `xml-entities-source-body`). Required, positional. One case is one report.
- `report=` - the report as a local file, on the first run of a case. A file report (the same holds for a report pasted into the conversation) is not tied to the mail archive: with an archive configured but no `threads=`, nothing searches it for this report - the loader does not look for its thread, triage leaves it out of the prior-work search, there is no reply-evidence and nothing is recorded on a thread - and the reply drafts tell the maintainer to check their mail for an earlier reply. Pass `threads=` to tie the case to the archive.
- `threads=` - one or more mail-archive thread ids, when the operator preferences name an MCP server that archives the project's private security list (step 5). Only the threads named here tie a case to the archive. It works on the first run and later, to attach more threads; from then on the case uses the archive as usual (reply-evidence, and the ruling recorded on the threads). The CNA reservation lookup for the CVE id reads the archive's reservation announcements, not this report, so it is unaffected either way.
- `verdict=`, `cve=`, `issue=`, `pr=`, `credit=`, `targets=`, `fix-model=` and `template=` - maintainer decisions. They are sticky: the case remembers them.
- `approve=` - lets this run publish what the maintainer has reviewed: `issue` (create the sanitized issue), `pr` (push and open the fix PR), `backports` (push and open the backport and upgrade-note PRs). An approval counts for one run only, and never for a draft or branch produced in that same run.
- `done=reply` - the maintainer has sent the reply to the reporter.
- `done=release` - every fixed version is released. Each run checks this by itself (step 5); use the flag only when that check cannot see the versions.
- `public` - the report is already public. `retry` reruns blocked or failed nodes, `retriage` triages again from scratch, `redraft-cve` refreshes the CVE draft (for example after the release), `no-challenge` skips the verdict challenge, `stop-after=<node>` ends the run after that node.
- `economy=off` - run every node on the session model, for this run. By default the mechanical nodes (the loader, the persistence step, the issue creation, the final reply and the nodes that push and open PRs) run on cheaper models; triage, the challenge lenses, the drafts, the fix, the backports and the CVE draft always use the session model.
- `status` refreshes `STATUS.md` without running nodes. `plan` tests the routing without agents (workflow mode only).

### 1. What this guideline does

This guideline is the orchestration of the security guidelines. It moves one inbound security report through the triage guideline (`triage-security-report.md`), the create-issue guideline (`create-issue.md`), the fix-issue guideline (`fix-issue.md`), the backport guideline (`backport-pr.md`) and the CVE-draft guideline (`draft-cve.md`). The maintainer stays the decision maker at every gate. Each run advances the case as far as it can, then stops at the next gate and says exactly what the maintainer must do and how to resume.

```text
triage --> verdict challenge (scope lens, code lens) + drafts: reply, CVE fields, issue   (nothing is sent)
   |
[maintainer rules the verdict]
   +-- VALID ............. [maintainer reserves the CVE] --> final reply --> [maintainer sends it]
   |                       [approve=issue] --> issue --> fix in a worktree (local commit)
   |                       [approve=pr] --> PR --> [human review and merge] --> backports (local)
   |                       [approve=backports] --> backport PRs --> upgrade-note sync PR on the default branch
   |                       CVE reserved + fixed versions released --> CVE draft (local, or a private draft repository)
   |                                                               --> [CNA import, signing, publication PR]
   +-- HARDENING ......... same issue, fix and backport path, no CVE; the reply cites the issue
   +-- DEFENSE_IN_DEPTH .. as HARDENING, default branch only unless targets= says otherwise
   +-- INVALID, DUPLICATE  final reply --> [maintainer sends it]
```

The CVE draft waits for the release, not for the merge. The advisory states the fixed versions and is signed and published with them, so it is drafted only once every fixed version is released: a release can be cut before the fix lands, which moves it to the next patch, and a tag is not a release. The drafts stay in the case directory, and also go to a private draft repository when one is configured. They go nowhere else; signing the advisory and opening the publication PR stay with the maintainer.

A VALID fix follows the project's fix model. With `public`, a neutral public issue and PR carry the fix before disclosure; projects that coordinate privately, for example on a security mailing list, and fix in the open work this way. With `ghsa`, a private GitHub security advisory and its temporary fork carry it, so the graph hands the fix to the security-advisory guideline (`create-security-advisory.md`) and keeps its own issue, fix and backport nodes off.

### 2. Choose the mode

- **Workflow mode** - the agent is Claude Code, has the Workflow tool, and the `oss-security-case` workflow is installed (`~/.claude/workflows/oss-security-case.js`, installed by `install.sh claude`). Follow step 3.
- **Manual mode** - any other agent, or Claude Code without the Workflow tool. Follow step 4. It drives the same graph and the same case directory by hand, one node at a time.

### 3. Workflow mode

The workflow's loader detects the project and loads its rules and configuration itself, so workflow mode skips the skill's initialization steps.

#### 3.1 Build the arguments

Map the command arguments onto the workflow's `args`:

| Command argument | `args` |
|---|---|
| `<case>` | `case` |
| `report=<file>` | `report` (absolute path). If the maintainer pasted the report into the conversation, first write it to `<cases dir>/<case>/report.txt` (see step 5 for the cases directory), `chmod 700` that directory, and pass that path. Never put report text into `args`. |
| `threads=a,b` | `threads: ["a", "b"]` |
| `verdict=`, `cve=`, `issue=`, `pr=` (a number), `credit=`, `template=` | `decision: {verdict, cve, issue, pr, credit, template}` |
| `targets=a,b` / `targets=none` | `decision.backportTargets: ["a", "b"]` / `[]` |
| `fix-model=` | `decision.fixModel` |
| `approve=issue,pr,backports` | `approve: {issue: true, pr: true, backports: true}` |
| `done=reply`, `done=release`, `done=reply,release` | `done: {reply: true}`, `done: {release: true}`, both |
| `public` | `public: true` |
| `retry`, `retriage`, `redraft-cve`, `no-challenge`, `stop-after=<node>` | `options: {retry, retriage, redraftCve, challenge: false, stopAfter}` |
| `economy=off` | `options: {economy: false}` |
| `status`, `plan` | `mode: "status"`, `mode: "plan"` |

Run the command from a clone of the project, or pass `repo=<absolute path>` as `args.repo`.

#### 3.2 Run the workflow

Invoking this command is the maintainer's opt-in to run the workflow. Call the Workflow tool with `{name: "oss-security-case", args: <object>}` directly, without checking for the file first. If the name is not found, which happens when the workflow was installed during the current session, call it with `{scriptPath: "<home>/.claude/workflows/oss-security-case.js", args: <object>}` instead. The workflow runs in the background: wait for its notification.

#### 3.3 Relay the result

Tell the maintainer, from the workflow's return value only:

- the verdict: the ruling, the triage recommendation, and the challenge outcome;
- which nodes ran;
- what is waiting on them, giving each gate's text and unblock hint verbatim;
- the `next` command and the path of `STATUS.md`.

The return value carries all of it. Do not read the case files, query the tracker or the forge, or re-check what the workflow reported: the maintainer reads `STATUS.md` and the files it lists, and the next run reads the case again anyway.

If the agent keeps a persistent memory, store the result's `memory` pointer (`file`, `content`, `indexLine`) there with one tool call that writes the file and replaces the case's line in the memory index, or adds it, so that later sessions find the case. Keep embargoed details out of anything public.

### 4. Manual mode

Work through the same graph by hand, keeping the same case directory (step 5), so that a later run in workflow mode can pick the case up.

#### 4.1 Find the next node

Read `STATUS.md`, `decisions.json` and `nodes/*.json` in the case directory. Then run the first node whose precondition holds and whose output is missing:

| Node | Precondition | Follow | Output |
|---|---|---|---|
| triage | none | the triage guideline (`triage-security-report.md`), on `report.txt`, in a detached worktree, statically | `triage.md` with a recommended verdict, a CVSS 3.1 vector computed before the severity, affected ranges per line, a never-cite list, a fix plan and backport notes |
| challenge | triage done | re-verify the verdict twice, once against the project's security model and once against the code at every supported line | agree or disagree, with reasons and missed facts |
| drafts | triage done | write the reply draft; the CVE fields (VALID); the sanitized issue draft (when an issue is needed), using the create-issue guideline (`create-issue.md`) for the fields | `reply-draft.txt`, `cve-reservation.md`, `issue-draft.json` and `issue-create.sh` |
| **gate: verdict** | drafts done | the maintainer rules the verdict | `decisions.json` |
| issue | verdict ruled, issue approved | run `issue-create.sh` once | the issue key |
| reply | VALID: CVE reserved. HARDENING or DEFENSE_IN_DEPTH: issue created. Otherwise: verdict ruled | finalize `reply-draft.txt` | `reply-final.txt` |
| fix | issue created | the fix-issue guideline (`fix-issue.md`) in a new worktree, up to a local commit | branch, commit, `pr-body.md`, `pr-create.sh` |
| fix (publish) | fix local, PR approved | push to the fork remote and open the PR | the PR number |
| **gate: merge** | PR open | human review and merge | merged PR |
| backports | PR merged | the backport guideline (`backport-pr.md`), one worktree per supported line, one build at a time | local branches, then PRs once approved |
| upgrade-note sync | backports open, and the project keeps upgrade notes on the default branch | add the per-line notes on the default branch | PR, after the backport PRs |
| **gate: release** | fix merged | every fixed version (default branch and each supported line) released to the project's distribution channel | released versions |
| CVE draft | VALID, CVE reserved, fixed versions released | the CVE-draft guideline (`draft-cve.md`), output in `cve/`, archived only to a verified-private draft repository when one is configured | advisory page, signing plaintext, CVE5 JSON, `cve/CHECKLIST.md` |

#### 4.2 Stop at every gate

Stop and hand over to the maintainer at each gate: the verdict, the CVE reservation, every publication (issue, PR, backports), sending the reply, the merge, the release of the fixed versions (the CVE draft starts only after it), and the final CNA import, signing and publication PR. Before any publication, show the maintainer the exact text and the result of the lint in step 6, and wait for their approval in the conversation.

#### 4.3 Keep the case current

After each node, write its result to `nodes/<node>.json`, record maintainer decisions in `decisions.json`, and rewrite `STATUS.md` with what is done, what is waiting, and the next step.

### 5. Configuration

The case keeps no configuration of its own. Every run resolves it again from these sources:

- **The probe**: `security-case-probe.sh <case> [repo]`, installed next to this guideline, prints the clone facts, the project's rule files, the environment variables and the directories they resolve to, the operator preferences and the case files in one read-only call, with an `ERROR` marker for anything it could not answer. With python3 it prints the node files as a digest of the fields the workflow routes on; the full records stay in `nodes/`. The workflow's loader starts from it; in manual mode, run it first.
- **Project rules** (the initialization steps): `project-info.md` for the repository and the issue tracker, `project-guidelines.md` for the fix branch and commit formats and any upgrade-note policy, `project-standards.md` for build and test commands.
- **`project-security.md`**, when present: the private reporting channel, the CNA and its tool, the advisory template and publication location, the signing step, the supported maintenance lines and end-of-life lines, the fix model (`public` or `ghsa`), and an optional public-text denylist. When it is missing, the CVE gate, the template, the fix model and the backport targets are asked from the maintainer (`template=`, `fix-model=`, `targets=`) instead of guessed.
- **git and gh**: the upstream remote, the fork remote (the one that points at the maintainer's login), the default branch, and whether the clone is shallow.
- **Environment variables**:

| Variable | Default | Purpose |
|---|---|---|
| `OSS_SECURITY_CASES_DIR` | `~/.oss-helper/security-cases` | Where case directories live. Keep it private and outside every repository. |
| `OSS_WORKTREE_ROOT` | the parent directory of the clone | Where worktrees for triage, fixes and backports are created |
| `OSS_PUSH_REMOTE` | the fork remote of the maintainer's login | The remote that branches are pushed to |
| `OSS_SECURITY_CASE_PREFS` | `~/.config/oss-helper/security-case.md` | The operator-preferences file |
| `OSS_SECURITY_NOTES_DIR` | _(none)_ | A directory of Markdown notes the triage searches for earlier reports and rulings |
| `OSS_CVE_RECORDS_DIR` | _(none)_ | Where to copy the drafted CVE5 JSON as well |
| `OSS_JIRA_USER` | the Jira user of `$JIRA_TOKEN` | Assignee for a Jira issue |
| `OSS_CVE_BACKUP_REPO` | _(none)_ | The private draft repository: the CVE drafts are archived there, after the CVE-draft guideline (`draft-cve.md`) verifies it is private. Unset, the drafts stay local in the case directory only. |

- **Operator preferences**: a free-text Markdown file, given verbatim to every node, for habits that belong to the maintainer rather than the project. It is also where a maintainer names a mail archive: an MCP server that reads the project's private security list, which the workflow then uses - for the threads named with `threads=` - to read the discussion, check for earlier replies and record the ruling. A report given only as a file is not tied to the archive. For example:

```text
- Sign every commit with git commit -S.
- Run ./build.sh --full before committing a fix.
- Mail archive: the "security-list" MCP server. It reads and searches threads,
  and records a triage state and notes on a thread.
- Sign replies to reporters "Jane Maintainer, for the Example security team".
- Advisory template: docs/security/ADVISORY-TEMPLATE.md in the website repository.
```

A case directory holds `report.txt`, `report-meta.json`, `triage.md`, the drafts, `nodes/<node>.json`, `decisions.json`, `STATUS.md`, `log.md`, `work/` for scratch files and `cve/` for the CVE draft. It is embargoed material: never commit it to a public repository.

### 6. Public text

Everything that leaves the case directory before disclosure is public: issue text, branch names, commit messages, code comments, test names, PR text. Before publishing, lint it case-insensitively for at least `vulnerab`, `exploit`, `CVE-`, `CVSS`, `CWE-`, `attacker`, `RCE`, `PoC`, `embargo`, `security@` and `reported by`. Lint it also for the project's denylist, the case's `denyTerms` (payload fragments, the reporter's wording), and the reporter's name, handle and address. Describe the change in functional terms only.

### 7. Constraints

You MUST:

- Keep the maintainer the decision maker: stop at every gate, and publish only what the maintainer approved after seeing it.
- Verify report claims statically against freshly fetched refs and the release tags, and compute the CVSS vector before choosing a severity.
- Keep every case file in the case directory, and keep the case directory private.
- Work in dedicated worktrees, never in the maintainer's checkout, and run one build at a time.
- Name only published CVEs in anything a reporter or the public reads.
- Push to the fork remote, and recount any PR-volume cap from the project's agent instructions right before opening each PR.
- Hold backports until the main PR is merged, and check for backport PRs opened by others before preparing one.
- Draft the CVE advisory only after every fixed version is released, keep the drafts in the case directory, and archive them only to a configured draft repository verified as private.

You MUST NOT:

- Send email, reserve or request CVE identifiers, merge PRs, sign advisories, or publish an advisory.
- Put exploit details, the reporter's identity, CVE identifiers or security wording into public text before disclosure.
- Tell the reporter about sibling findings, unpublished CVEs or other embargoed reports.
- Write report material to temporary directories, a session scratchpad, or a public repository.
- Draft the CVE advisory before every fixed version is released, push the drafts anywhere but a verified-private draft repository, or open a pull request with them.
- Retry or reshape an issue-tracker write, push or PR that the permission system refused. Hand the prepared script to the maintainer instead.
- Run reproducers that perform the reported attack, or stand up attacker-controlled endpoints.
- Guess configuration that the project rules do not give (supported lines, CNA, template, fix model). Ask the maintainer instead.

### 8. Acceptance Criteria

- The case directory holds the report, the triage, the drafts and a `STATUS.md` that names every open gate and the exact next command.
- The maintainer ruled the verdict before anything was published, and approved each publication after seeing it.
- For VALID: a reserved CVE is recorded, the reply names it, the fix and its backports went through neutral public text (or through the private advisory for `ghsa`), and the CVE draft exists in `cve/` with its checklist.
- For HARDENING and DEFENSE_IN_DEPTH: the reply explains why there is no CVE and cites the public issue.
- For INVALID and DUPLICATE: the reply explains the verdict without exposing anything private.
- Nothing embargoed reached a public place.
