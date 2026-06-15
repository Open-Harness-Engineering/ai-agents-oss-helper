# Scan Codebase for Vulnerabilities

Proactively scan the project's **own first-party code** for security vulnerabilities, anchored to the project's threat / security model. The scan combines any security scanners that are already installed (SAST/SCA) with reasoning-based static analysis and data-flow tracing, then produces a structured findings report and proposes a follow-up path for each finding.

This command is the proactive counterpart to the project's other security commands, which are all reactive: `/oss-triage-security-report` triages an inbound report, `/oss-analyze-third-party-cve` triages a known CVE in a dependency, and `/oss-fix-github-alert` works an alert that already exists. This command goes looking for *unknown* problems in the project's own code before anyone reports them.

Findings produced by this command are potential undisclosed vulnerabilities in the project. Treat them as confidential. This command does NOT publish anything to public trackers, PRs, or chat channels — it is a local investigative workflow, and every outward-facing action is an explicit, user-confirmed handoff to a dedicated command.

## Usage

```
/oss-security-scan [path-or-module] [severity=<min>] [scanners=<auto|off|tool1,tool2>]
```

**Arguments:**
- `[path-or-module]` - Optional. A path, module, or glob to scope the scan (e.g. `core/`, `src/main/java/com/acme/web`, `services/auth`). If omitted, the scan targets the whole first-party codebase, with scoping guidance applied (see step 4).
- `severity=<min>` - Optional. Minimum severity to include in the report: `critical`, `high`, `medium`, `low`, or `info`. Default: `low` (everything except purely informational notes). Findings below the threshold are still counted in the summary but not detailed.
- `scanners=<auto|off|tool1,tool2>` - Optional. `auto` (default) detects and runs whatever scanners are installed; `off` runs reasoning-based analysis only; a comma-separated list restricts to specific tools (e.g. `scanners=semgrep,gosec`).

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines, and `project-security.md` when present) is loaded.

If `project-security.md` is present, use it for:
- The **Private reporting channel** — used verbatim in the follow-up step (step 9) instead of guessing an address.
- The **threat model anchor** — its scope, supported release lines, and any documented security posture inform what counts as in-scope (step 3).

### 2. Establish Boundaries

**Before proceeding, remind the user:**

> This scan is local and investigative. It looks for vulnerabilities in this project's own code. Any finding is a *potential undisclosed vulnerability* and will be treated as confidential — nothing is sent to public issue trackers, PR descriptions, or chat channels unless you explicitly confirm a handoff, and exploit specifics are stripped from any text proposed for a public artifact.

Confirm with the user:
- Is there any **embargo or coordinated-disclosure** context already in flight for this area? If so, keep all specifics confidential and prefer the private follow-up paths.
- The scan runs scanners and analysis **statically**. It will not execute proof-of-concept exploits against any running system. Confirm the user is not asking for live exploitation (that is out of scope — see Constraints).

### 3. Establish the Threat / Security Model

The scan must be anchored to what the project actually defends against. Establish the model using the **first source found**, in this order:

1. **`project-security.md`** (rule file, if loaded in step 1) — use its scope, posture, and supported release lines.
2. **In-repo security docs** — check for a threat model or security policy in the repository:
   ```bash
   ls SECURITY.md .github/SECURITY.md docs/SECURITY.md THREATMODEL.md docs/threat-model*.md 2>/dev/null
   ```
   Read whatever exists. Extract: assets worth protecting, trust boundaries, entry points / attacker-reachable surfaces, and anything explicitly declared **out of scope** (a documented disclaimer means a related finding is *informational*, not a vulnerability).
3. **Generate a lightweight model (when none exists).** If neither of the above is present, derive a short threat model so the scan has an anchor:
   - If a dedicated threat-model skill/command is available in this environment (for example `threat-model-producer`), prefer it to produce the model.
   - Otherwise build a lightweight model inline, capturing:
     - **Assets** — what an attacker would want (data, credentials, compute, integrity of output).
     - **Trust boundaries** — where untrusted input crosses into the system (network handlers, message listeners, CLI args, file/config readers, deserialization points, plugin/SPI loading).
     - **Entry points** — concrete attacker-reachable surfaces in the code.
     - **Attacker model** — unauthenticated remote, authenticated user, local user, malicious dependency/config.
     - **In scope / out of scope** — what this project credibly claims to defend against vs. what it delegates to the deployer.

   **Propose the generated model as a PR.** The threat model is a public-safe document (it describes posture, not exploits). After the scan, offer to contribute it back: write it to a sensible location (`SECURITY.md` if absent, or `docs/threat-model.md`), then hand off to `/oss-quick-fix` so it goes through the normal branch + PR flow with user confirmation. Do **not** fabricate a `project-security.md` CVE-handling workflow — that file cannot be inferred from source (see `.oss-init.md`); point the user to `/oss-add-project` if they want one.

Present the established (or generated) model back to the user in a few bullets and confirm it before scanning. The model determines which vulnerability classes matter and which findings are in scope.

### 4. Determine Scan Scope

Decide what to scan:

- If `[path-or-module]` was given, restrict to it.
- Otherwise target the whole first-party codebase, but **scope deliberately** — a blanket scan of a large repo is noisy and slow:
  - **Prioritize** code reachable from the entry points / trust boundaries identified in step 3.
  - **Exclude** vendored, generated, and build output (`**/target/**`, `**/build/**`, `**/dist/**`, `**/node_modules/**`, `**/vendor/**`, generated sources). Respect `.gitignore`.
  - Treat **test code** as lower priority unless it reveals insecure helpers shipped in production paths.
  - For a large repo, propose scanning module-by-module (most security-relevant first) and confirm the order with the user rather than attempting everything at once.

State the resolved scope (paths, globs, exclusions) before running anything.

### 5. Run Available Scanners

Unless `scanners=off`, detect which security tools are installed and run the relevant ones **in read-only / analysis mode**. Detect with `command -v <tool>` (and, for build-plugin-based tools, check the build config). Only run tools that match the languages actually present in scope.

| Ecosystem | SAST (code) | SCA / deps | Secrets |
|-----------|-------------|------------|---------|
| Multi-language | `semgrep --config auto` (or `opengrep`); `codeql` only if a database can be built (heavy — opt-in) | `osv-scanner -r .`; `trivy fs .` | `gitleaks detect`; `trufflehog`; `detect-secrets` |
| Java / Kotlin / JVM | SpotBugs + Find Security Bugs (via the build plugin, if configured) | OWASP `dependency-check` | (multi-language secrets tools above) |
| JavaScript / TypeScript | ESLint security plugins (if configured); `semgrep` | `npm audit` / `yarn audit` / `pnpm audit` | (above) |
| Python | `bandit -r <scope>` | `pip-audit`; `safety check` | (above) |
| Go | `gosec ./...` | `govulncheck ./...` | (above) |
| Rust | `semgrep` | `cargo audit` | (above) |
| Ruby | `brakeman` (Rails) | `bundler-audit` | (above) |
| Containers / IaC | `checkov`; `tfsec` | `trivy config .` | (above) |

Guidance:
- **Record which scanners ran and which were skipped** (not installed / not applicable). The report must be honest about coverage — a clean report from "no scanners installed" is not the same as a clean report from a full SAST run.
- **Capture raw findings** (rule id, file, line, message, severity) but do **not** trust them yet — scanner output is triaged in step 7.
- **SCA / dependency findings overlap** with `/oss-analyze-third-party-cve` and `/oss-fix-github-alert dependabot`. Note them, but in the follow-up step defer dependency CVEs to those commands rather than duplicating that workflow here. This command's primary focus is **first-party code (SAST)**.
- If running a scanner would require a network fetch, a build, or downloading rules, **ask the user first**.

### 6. Reasoning-Based Static Analysis

Independently of the scanners, analyze the in-scope code for the vulnerability classes that the threat model makes relevant. Do not limit yourself to what the tools flagged — tools miss logic flaws and design-level issues.

Work from **trust boundaries inward**: for each entry point identified in step 3, trace data flow from the untrusted source to any sensitive sink, noting validators/sanitizers/encoders along the way and where the chain breaks.

Vulnerability classes to consider (select those the threat model makes relevant):
- **Injection** — SQL, OS command, LDAP, expression/EL, template (SSTI), XPath, header injection.
- **Deserialization** of untrusted data; unsafe object mapping; polymorphic type handling.
- **Path traversal** / arbitrary file read/write; unsafe archive extraction (zip-slip).
- **SSRF** and unvalidated outbound requests; open redirect.
- **XML/YAML/JSON parser** misconfiguration — XXE, entity expansion (billion laughs), unsafe YAML loaders.
- **AuthN / AuthZ** — missing access control, broken object-level authorization, privilege escalation, insecure session/token handling.
- **Cryptography** — weak/obsolete algorithms, ECB mode, static IVs, weak randomness for security decisions, hardcoded keys/secrets.
- **Secrets** — credentials, tokens, or keys committed to the repo or logged.
- **Unsafe reflection / classloading / plugin loading** from attacker-influenced input.
- **Improper input validation / output encoding** — XSS where the project renders to a browser.
- **Sensitive data exposure** — secrets in logs, errors, or responses; missing redaction.
- **Insecure defaults / dangerous configuration** — features that are unsafe unless the deployer changes a default.
- **Denial of service** — ReDoS, unbounded allocation, decompression bombs, missing limits on attacker-controlled sizes.
- **Concurrency** — TOCTOU / race conditions in security-relevant paths; predictable temp-file creation.

Also run the project-specific checks the **prior security work** implies:
```bash
# Has this area been touched by past security fixes? Look for patterns to recheck.
git log --all --oneline --grep="CVE" --grep="security" --grep="vuln" -i | head -30
```
Where a past fix exists, check whether sibling components share the same defect pattern (scope drift is common).

For any candidate finding, confirm the data path by **reading the actual code** and, where it clarifies the logic, writing a tiny standalone reproducer that exercises the *logic in isolation* — never an exploit against a live service.

### 7. Triage & De-duplicate Findings

Merge scanner output (step 5) and reasoning findings (step 6) into a single triaged list. Do **not** pass raw scanner output through to the report.

For each candidate:
- **De-duplicate** — collapse the same defect reported by multiple tools/passes into one finding.
- **Confirm or drop** — read the cited code and verify the issue is real. Discard false positives (e.g., a `semgrep` taint hit where the input is actually constant, or already sanitized). Tools over-report; say so.
- **Assess reachability** — is the vulnerable code reachable from an entry point in the threat model under a realistic configuration, or only via a non-default branch / opt-in flag / internal-only call? Record the data-flow reasoning.
- **Map to the threat model** — a finding outside the project's declared scope (an explicitly disclaimed / deployer-owned concern) is **informational**, not a vulnerability. Note this rather than dropping it silently.
- **Severity** — assign critical / high / medium / low / info from impact × reachability (not the scanner's raw label).
- **Confidence** — high / medium / low, with a one-line rationale (e.g. "confirmed by reading the sink and tracing the caller" vs. "static match only, reachability unverified").

Distinguish clearly between **"scanner-flagged"** and **"confirmed reachable vulnerability."** Only the latter is a real finding.

### 8. Produce the Findings Report

Output a structured report. Include the robot disclaimer at the top. Apply the `severity=` threshold to what is detailed (everything is still counted in the summary).

```markdown
> :robot: **Note:** This security scan was generated by a coding agent and requires manual verification. The findings below are *potential* vulnerabilities, may include false positives, and must be reviewed by a human maintainer before any disclosure or fix. Keep this report confidential until findings are validated.

## Codebase Security Scan

### Scope & Coverage
- **Scope scanned:** <paths / modules / globs; exclusions applied>
- **Threat model source:** <project-security.md / SECURITY.md / generated>
- **Scanners run:** <tool list with versions, or "none installed">
- **Scanners skipped:** <tool: reason (not installed / not applicable)>
- **Analysis method:** <scanners + reasoning / reasoning only>

### Findings Summary
| Severity | Count |
|----------|-------|
| Critical | <n> |
| High     | <n> |
| Medium   | <n> |
| Low      | <n> |
| Info     | <n> |

### Findings
| # | Class | File:Line | Severity | Confidence | Reachable? | In threat-model scope? |
|---|-------|-----------|----------|------------|------------|------------------------|
| 1 | <class> | <file:line> | <sev> | <conf> | yes / no / unclear | yes / informational |

### Finding Detail (critical / high, and any the user requests)

#### Finding 1 — <short title>
- **Class / CWE:** <class> (<CWE-ID> - <name>)
- **Location:** <file:line> (and sibling locations with the same pattern)
- **Root cause:** <concise description of the defect, in code terms>
- **Data flow:** <untrusted source → … → sink>, and where validation is missing
- **Reachability:** <how an attacker reaches it; default vs. opt-in; auth required?>
- **Impact:** <confidentiality / integrity / availability, with rationale>
- **Severity rationale:** <impact × reachability>
- **Confidence:** <high/medium/low> — <why>
- **Suggested remediation:** <code-level fix direction — not an exploit>

### Prior Work
<Past commits, fixes, CVEs, or open alerts touching the affected areas.>

### Overall Verdict
- :large_blue_diamond: **Likely-real findings present** — <count critical/high>; private follow-up recommended.
- :large_blue_diamond: **Only hardening / informational items** — no confirmed exploitable vulnerability; safe to track publicly as hardening.
- :large_blue_diamond: **Clean within coverage** — no findings in the scanned scope; state coverage limits honestly.

### Confidence & Limitations
- **Overall confidence:** <level> — <what would raise/lower it: e.g. "SAST coverage partial, no semgrep installed; reachability assessed by static reading only">
- **Not covered:** <modules/languages/aspects out of this run's scope>

### Open Questions
- <question 1>
- <question 2>
```

### 9. Propose Follow-up Paths

Based on the verdict, offer one or more actions. Do **NOT** execute any without explicit confirmation. The split below mirrors the other security commands: confidential exploit detail goes through private channels; only sanitized, exploit-free text goes anywhere public.

**For a confirmed, exploitable, not-yet-public finding:**
1. **Triage it further** — hand off to `/oss-triage-security-report` (treating this report as the inbound source) for a deeper per-claim verification before disclosure.
2. **Report it privately** — hand off to `/oss-create-security-advisory`. If `project-security.md` declares a **Private reporting channel** other than GitHub private vulnerability reporting (e.g. an ASF `security@…` list), give the user that exact address and a private draft instead of the GitHub `/reports` flow.

**For a safe-to-track hardening item (no exploit detail, or already public):**
3. **File a sanitized issue** — hand off to `/oss-create-issue` with text that frames the change as hardening/consistency/refactor and **omits** the attack scenario, payloads, severity wording, and the words "vulnerability"/"exploit"/"RCE"/"CVE". Confirm the sanitized text first.
4. **Apply a trivial safe fix** — for a low-risk, obviously-correct hardening change, hand off to `/oss-quick-fix` with a sanitized description.

**For a dependency / SCA finding (not first-party code):**
5. **Defer to the dependency workflow** — hand off to `/oss-analyze-third-party-cve <CVE>` or, if Dependabot already raised it, `/oss-fix-github-alert dependabot alert=<NUMBER>`. Do not duplicate that analysis here.

**For the generated threat model (step 3, when one was produced):**
6. **Propose it as a PR** — this is a public-safe document. Offer to write it to `SECURITY.md` / `docs/threat-model.md` and hand off to `/oss-quick-fix`. Never include any finding detail in this document.

In all cases, present the sanitized text and the chosen handoff for explicit confirmation before anything leaves the local workflow.

### 10. Constraints

You MUST:
- Read and process `.oss-init.md` first.
- Include the :robot: disclaimer at the top of the report and treat all findings as confidential potential vulnerabilities.
- Anchor the scan to a threat / security model, and state which source was used.
- Run scanners **statically / read-only**, record which ran and which were skipped, and represent coverage honestly.
- Verify each finding by reading the actual code and assessing reachability, and cite `file:line` before classifying it as confirmed.
- Distinguish **"scanner-flagged"** from **"confirmed reachable vulnerability,"** and discard false positives.
- Keep exploit specifics (payloads, PoC, reproduction commands) out of any text proposed for a public artifact, and sanitize before any public handoff.
- Ask the user before any network fetch, build, or rule download a scanner would trigger.
- Confirm with the user before any handoff that produces an issue, PR, advisory, or comment.

You MUST NOT:
- Publish any finding to a public issue tracker, PR, comment, or chat channel as part of this command — handoffs go through the dedicated commands only after confirmation.
- Run exploits / proof-of-concept code against any live or test system, even locally. Verification is static and reproducer-based at most.
- Include exploit payloads or severity / "RCE" / "exploit" / "vulnerability" wording in any text intended for a public issue or PR.
- Mark a finding as confirmed without reading the code and tracing reachability, or pass raw scanner output through to the report unverified.
- Duplicate the dependency-CVE workflow — defer SCA/dependency findings to `/oss-analyze-third-party-cve` or `/oss-fix-github-alert`.
- Auto-generate a `project-security.md` CVE-handling workflow (it cannot be inferred from source); only the public-safe threat model document may be proposed as a PR.
- Commit, push, or open a PR for anything (findings *or* the threat model) without explicit user confirmation.

### 11. Acceptance Criteria

- The project context is loaded and a threat / security model is established (read from the repo or generated) and confirmed with the user.
- The scan scope is stated explicitly, with exclusions.
- Available scanners are detected and run (or `scanners=off` honored), and the report lists which ran and which were skipped.
- Reasoning-based analysis traces data flow from threat-model entry points to sinks, beyond what the scanners flagged.
- Findings are triaged (de-duplicated, false positives dropped, reachability assessed) and reported with `file:line` citations, severity, and confidence, under the :robot: disclaimer.
- A concrete follow-up path is proposed per finding, with the appropriate downstream command named, and any sanitized text confirmed before handoff.
- When a threat model was generated, it is offered as a public-safe PR — separate from, and containing none of, the confidential findings.
