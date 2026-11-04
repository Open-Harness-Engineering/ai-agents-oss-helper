### Agent Delegation

This guideline is built around **parallel scan agents**: the audit fans out read-only scan agents across module groups, then verifies their claims centrally. If the environment can spawn sub-agents (read-only explore/search agents, or a **code-reviewer** agent), delegate the group scans (step 5) and the consistency matrix (step 6) to them — one agent per module group, launched concurrently.

Two hard rules when delegating:

- Scan agents are **read-only investigators**: they must not modify files, and their prompt must demand `file:line` plus a verbatim code quote for every claim (see the prompt contract in step 5).
- The main agent MUST perform the verification pass (step 7) itself. Never let a scan agent verify its own findings, and never republish a sub-agent claim you did not re-verify against the code.

If no sub-agents are available, run the same group-by-group scans sequentially yourself, honoring the same output contract.

### 1. Parse Input

Arguments: `[path-or-scope] [focus=all|bugs|consistency|features]`

- **path-or-scope** — a directory, Maven/Gradle module, or module-family root to audit (e.g. `components/camel-aws`, `core/`, `src/main/java/com/acme/storage`). If omitted, list the project's top-level modules and ask the user to pick a scope — auditing a large repository in one run produces a noisy, unverifiable report.
- **focus** — optional; default `all` (bugs + antipatterns + inconsistencies + missing features + ideas). A narrower focus drops the other report sections but never drops the verification pass.

### 2. Sync the Branch

The audit must run against current upstream state, or the findings will include already-fixed code:

```bash
git fetch origin && git rebase origin/<default-branch>
```

- If the working tree is dirty or the rebase conflicts, stop and ask the user how to proceed.
- Record the audit snapshot: `git rev-parse --short HEAD`. It goes in the report header — findings are only claims about this exact commit.

### 3. Resolve the Module Inventory

Enumerate what is actually in scope:

- For a Maven multi-module tree, read the `<modules>` list of the scope's `pom.xml` (or list subdirectories containing a `pom.xml`). For Gradle, read `settings.gradle(.kts)` includes. For a plain package tree, list top-level packages.
- **Exclude** generated sources (`src/generated`, `target/`, `build/`), vendored code, and build output. Respect `.gitignore`.
- Watch for **ghost directories** — local leftovers of removed modules (`git ls-files <dir>` returns nothing but the directory exists). Note them as cleanup candidates; do not scan them.

State the resolved inventory (module count and names) before scanning.

### 4. Build the De-duplication Baseline

A finding that is already tracked is noise, and re-filing it damages maintainer trust. Before scanning:

- **Query the issue tracker** (GitHub or Jira, per `project-info.md`) for open issues touching the scope — search by component field and by module-name keywords. Capture `ID | summary` for each.

  ```bash
  # GitHub example
  gh issue list --state open --search "<module-keyword>" --limit 100
  # Jira example (adjust JQL to the project key from project-info.md)
  curl -s --get "<jira-url>/rest/api/2/search" \
    --data-urlencode 'jql=project = <KEY> AND status in (Open, "In Progress") AND (summary ~ "<keyword>" OR component = "<component>")'
  ```

- **Mine recent history** for just-fixed items so they are not re-reported: `git log --oneline --since='6 months ago' -- <scope>`.
- If the operator maintains a private backlog or a prior audit exists, de-duplicate against those too (ask if unsure).

Distill the result into an **exclusion list** (one line per known item, with its tracker ID) and embed it verbatim in every scan prompt as "Known/tracked items to EXCLUDE".

### 5. Fan Out the Group Scans

Partition the inventory into functional groups of roughly 3–6 modules by affinity (messaging, storage, compute, AI, support/util — whatever the family suggests), so each agent holds a coherent slice. For each group, launch a scan agent with this prompt contract:

- Repository root, explicit module list, and where to look: main sources (entry classes, configuration, producers/consumers/services, helpers), module docs, and a skim of tests for coverage gaps. Generated sources excluded.
- Findings reported in fixed categories: `BUG`, `ANTIPATTERN`, `INCONSISTENCY`, `MISSING_FEATURE`, `IDEA`, `TEST_GAP` / `DOC_GAP`.
- **Every code claim MUST include the absolute file path, line number, and a verbatim 1–3 line code quote** — state in the prompt that claims without a quote will be discarded.
- Severity (HIGH/MEDIUM/LOW) and confidence per finding, ranked most-severe first.
- The step 4 exclusion list, embedded verbatim.
- A response line budget (~150 lines) so agents select rather than dump.

Embed a defect checklist tuned to the stack. For Java, have agents look for:

- **Thread safety** — shared mutable collections mutated from parallel streams or executors; `static` mutable state shared across consumer/endpoint instances (e.g. a static cursor field).
- **Silent no-op dispatch** — `if (payload instanceof X)` chains with no `else` (wrong-typed input passes through unchanged); public enum operations whose method bodies are empty stubs (phantom API); always-true validation such as `isNotEmpty(isNotEmpty(x))`.
- **Copy-paste defects between operation branches** — wrong header/constant read, wrong builder setter called, error message naming a different field (compare each `case` branch carefully; this family of bug is endemic in operation-switch producers).
- **Remote API misuse** — missing pagination on list/query calls (`nextToken`/`marker` never followed); batch APIs called without chunking to the service's batch-size limit; identical deduplication/partition keys assigned to every entry of a batch; required request fields never set on one input path.
- **Resource lifecycle** — clients/streams not closed, or closed while still shared by siblings; raw `new Thread(...)` outside the managed executor; schedulers/executors not shut down on stop.
- **Exception handling** — `catch (Throwable)`; exceptions swallowed without rethrow or without logging the exception object; checked exceptions wrapped in bare `RuntimeException` in methods that already declare them.
- **Dead configuration** — options declared/documented but never read anywhere outside their configuration class (grep the option name across the module); annotation `defaultValue` metadata disagreeing with the actual field default.
- **Interrupt handling** — `interrupted` flags read but never set; `InterruptedException` caught without re-interrupting.
- **Allocation in hot paths** — heavyweight objects (`ObjectMapper`, compiled patterns, clients) constructed per call or inside loops.
- **Unbounded in-memory state** — dedup sets or caches that only grow; time-window cursors that skip records (e.g. `lastTime.plusMillis(N)` or a newest-first page used as the resume cursor).
- **NPE risks** — `switch` on a nullable, non-required enum option; nullable SDK getters dereferenced without a guard.

For `MISSING_FEATURE`, instruct agents to compare the module's exposed operation surface against the current capabilities of the wrapped library or service (e.g. the producer's operation switch vs. the SDK client's method surface) and to list only impactful gaps.

### 6. Run the Cross-Cutting Consistency Scan

In parallel with the group scans, launch one additional agent over ALL modules in scope, grep-driven rather than file-reading, to build a **consistency matrix**: for each dimension, the list of modules that have vs. lack the trait, backed by the grep pattern used. Dimensions to adapt to the family:

- Configuration option parity (credentials, timeouts, TLS/proxy options present in most modules but missing in a few).
- Security-relevant flag annotation/marking parity (e.g. insecure options carrying the project's required metadata).
- Health-check / observability support tiers.
- Shared-helper or base-class adoption (including the smell of a common base class that exists but nothing extends).
- Naming conventions (scheme/prefix drift, class-name typos, constant casing).
- Error-message hygiene (copy-pasted messages naming the wrong field).
- Pagination and pass-through/POJO-mode support parity.

Require a ranked "top N inconsistencies worth fixing" list with `file:line` and a verbatim quote for at least the top 5.

### 7. Verification Pass (non-negotiable)

Sub-agent findings are candidate claims, not facts. For EVERY finding you intend to report:

- Open the cited file yourself and confirm the quoted code exists **and the defect logic actually holds** — presence of the line is not enough; trace the branch/data flow the claim depends on.
- Sub-agent line numbers can be wrong or stale — locate the code by content, not by trusting the number.
- Re-run the matrix greps yourself for cross-module claims.
- Drop what does not verify. Label anything that survives without your personal re-verification as **"agent-reported"** — never present it as confirmed.
- While verifying, look one level deeper: verified bugs cluster, and the sibling branch of a confirmed copy-paste defect often carries another one.
- **External facts** — any claim about third-party state (a service being deprecated or closed to new customers, an SDK capability, a version) must be verified against official sources (web search, release notes, Maven Central) and cited in the report. Never assert external state from training memory alone.

### 8. Route Security-Sensitive Findings

Some audit findings are potential vulnerabilities, and those must not travel the public path:

- A finding where **untrusted input crosses a trust boundary** (injection, unfiltered attacker-controlled maps copied into routing state, deserialization of untrusted data, missing auth checks) MUST NOT appear in the public report, issues, or PRs. Hand it off to the Triage Security Report guideline (`triage-security-report.md`) or the Create Security Advisory guideline (`create-security-advisory.md`), or to the private channel declared in `project-security.md`.
- Distinguish these from **hardening-grade** items (defense-in-depth on operator-controlled configuration, fixed field-set header mapping, missing conditions on self-provisioned resources). Hardening can be tracked publicly with sanitized wording — no attack scenario, no "vulnerability"/"exploit"/"CVE" vocabulary.
- When unsure which side a finding falls on, default to the private path and ask the user.

### 9. Produce the Audit Report

Output a structured report. Findings the user cannot verify are worthless — every item carries its `file:line`.

```markdown
> :robot: **Note:** This audit was generated by a coding agent. Verified items were re-checked
> against the source by the main agent; items marked *agent-reported* were not and need a human
> or follow-up check before filing.

## Module Audit — <scope> @ <short-sha>

### Scope & Method
- **Modules audited:** <count + names, exclusions applied>
- **Agents used:** <N group scans + consistency matrix / sequential solo>
- **De-dup baseline:** <tracker queried, N open issues excluded; prior audits considered>
- **Verification:** <all findings re-verified / N findings labeled agent-reported>

### 1. Bug fixes (ranked)
<severity-tiered list; one line to a short paragraph each; file:line; confidence.>

### 2. Antipatterns
### 3. Inconsistencies
<matrix summary: dimension → modules lacking the trait; ranked fix-worthy list.>

### 4. Missing features
<deduped; reference existing tracker IDs where an ask already exists.>

### 5. New ideas
<larger enhancements, new modules/components, structural refactors that kill finding classes.>

### 6. Test / doc gaps

### Already tracked (excluded)
<tracker IDs the scan deliberately did not re-report.>

### Coverage & limitations
<modules or aspects not scanned; claims not verified; external facts and their sources.>
```

### 10. Propose Follow-Ups

Based on the report, offer next actions — do **NOT** execute any without explicit confirmation:

1. **File issues** — hand off to the Create Issue guideline (`create-issue.md`). Group sensibly: one issue per module/theme, and an umbrella issue for a family-wide pattern (e.g. "silent no-op on wrong-typed POJO body across N modules"). Sanitize anything step 8 flagged.
2. **Fix the top items** — hand off to the Fix Issue guideline (`fix-issue.md`) or, for trivial safe cleanups, the Quick Fix guideline (`quick-fix.md`).
3. **Track in a backlog** — if the operator uses one, offer the findings as backlog entries instead of tracker issues.

Respect the project's PR-volume limits (`project-guidelines.md` or the project's agent rules) when planning fixes — a 40-finding report is not an invitation to open 40 PRs.

### 11. Constraints

You MUST:

- Rebase onto the upstream default branch before scanning and record the audit snapshot SHA.
- State the resolved scope and module inventory before scanning, with exclusions.
- Build the de-duplication baseline first and embed the exclusion list in every scan prompt.
- Require `file:line` plus a verbatim quote for every sub-agent code claim, and discard claims without one.
- Personally re-verify every finding before reporting it, and label anything not re-verified as *agent-reported*.
- Verify external-state claims (deprecations, SDK capabilities, versions) against official sources and cite them.
- Route potential trust-boundary findings through the private security path (step 8), and sanitize hardening items for public artifacts.
- Confirm with the user before any handoff that produces an issue, PR, or backlog entry.

You MUST NOT:

- Republish sub-agent output unverified, or let a scan agent verify its own findings.
- Re-report items in the exclusion baseline (open issues, recent fixes, prior-audit items).
- Include attack scenarios or "vulnerability"/"exploit"/"CVE" wording in any public artifact produced from this audit.
- Modify project code as part of the audit itself — this guideline is read-only; fixes go through the dedicated guidelines.
- File issues, commit, push, or open PRs without explicit user confirmation, or exceed the project's PR-volume limits.

### 12. Acceptance Criteria

- The branch is rebased and the audit snapshot SHA recorded and reported.
- The module inventory and exclusions are stated before scanning; ghost directories are flagged, not scanned.
- A de-duplication baseline exists (tracker query + recent history) and excluded items are listed in the report.
- Group scans and the consistency matrix ran under the prompt contract (categories, `file:line` + quote, severity/confidence, line budget).
- Every reported finding was re-verified by the main agent or is explicitly labeled *agent-reported*; external facts carry cited sources.
- Security-sensitive findings were separated from the public report and routed to the security guidelines.
- The report follows the step 9 template, findings ranked, each with `file:line`, and coverage/limitations stated honestly.
- Follow-up paths are offered per finding group with the appropriate downstream guideline named, and nothing was filed without confirmation.
