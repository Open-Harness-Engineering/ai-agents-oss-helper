# Analyze Third-Party Dependency CVE

Analyze whether the current project is exposed to a specific CVE in a third-party dependency, by combining the advisory record (NVD / GHSA / OSV / vendor), any available exploitation details, and the project's actual usage of the dependency. Produce a structured exposure report and propose a follow-up action.

This command is the dependency-side counterpart of `/oss-triage-security-report`: that command triages an inbound report against the project's own code, while this one triages a publicly known CVE that lives in a dependency the project consumes. It does NOT publish anything to public trackers — it is a local investigative workflow.

## Usage

```
/oss-analyze-third-party-cve <CVE-ID> [dependency-coordinates]
```

**Arguments:**
- `<CVE-ID>` - CVE or GHSA identifier (e.g., `CVE-2024-12345`, `GHSA-abcd-efgh-1234`).
- `[dependency-coordinates]` - Optional. Disambiguates which artifact to focus on when the CVE record covers multiple packages (e.g., `org.apache.commons:commons-text`, `lodash`, `github.com/foo/bar`). If omitted, the command infers the affected dependency from the CVE record and walks each one.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Establish Boundaries

**Before proceeding, remind the user:**

> This analysis is local and investigative. No information from the CVE record, exploit details, or project findings will be sent to public issue trackers, PR descriptions, or chat channels unless you explicitly request it. The goal is to verify whether the project's specific usage triggers the vulnerable code paths and to choose the right follow-up.

Confirm with the user:
- Is the CVE **already public** (default for assigned CVE/GHSA identifiers)?
- Does any embargo or private advisory channel still apply (e.g., the user received the CVE detail under a coordinated-disclosure agreement before the public publication)? If yes, treat all specifics as confidential during analysis.

### 3. Fetch CVE Metadata

Fetch the advisory record from public sources, in this order. Stop at the first authoritative match and use later sources only to fill gaps.

1. **GHSA / GitHub Advisory Database** (rich technical detail, free):
   ```bash
   # By GHSA ID
   gh api graphql -f query='
     query($id:String!) {
       securityAdvisory(ghsaId:$id) {
         ghsaId summary description severity
         cvss { score vectorString }
         cwes(first:5) { nodes { cweId name } }
         identifiers { type value }
         references { url }
         vulnerabilities(first:20) {
           nodes {
             package { ecosystem name }
             vulnerableVersionRange
             firstPatchedVersion { identifier }
           }
         }
       }
     }' -F id=<GHSA-ID>

   # By CVE alias
   gh api graphql -f query='
     query($cve:String!) {
       securityAdvisories(identifier:{type:CVE, value:$cve}, first:5) {
         nodes { ghsaId summary description severity references { url } }
       }
     }' -F cve=<CVE-ID>
   ```
2. **NVD** (when GHSA does not have it): `https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=<CVE-ID>`
3. **OSV.dev** as a cross-check, especially for non-GitHub-tracked ecosystems: `https://api.osv.dev/v1/vulns/<CVE-or-GHSA>`
4. **Vendor advisory** linked from the record (often the only source with concrete vulnerable-API detail).

For URL fetches, ask the user to confirm the URL before fetching.

Record the following fields in a structured note:
- **Identifier(s):** CVE, GHSA, vendor IDs.
- **Severity / CVSS vector:** base score and vector string.
- **CWE class:** weakness category.
- **Affected package(s) / ecosystem(s):** e.g., Maven `org.apache.commons:commons-text`, npm `lodash`, Go `github.com/foo/bar`.
- **Vulnerable version range(s).**
- **First patched version(s).**
- **Vulnerable code paths / APIs / configurations** extracted from the description and references.
- **Public exploit / PoC details** when explicitly cited in the references. Use only to map vulnerable APIs — do NOT execute them.
- **Vendor-suggested workarounds.**

### 4. Locate the Dependency in the Project

Read the **Build tool** field from `project-standards.md` and use the matching method to find dependency coordinates and resolved versions:

| Build tool | How to locate |
|------------|---------------|
| Maven | `mvn dependency:tree -Dincludes=<group>:<artifact>` to find every place it appears. Cross-check resolved versions with `mvn help:effective-pom` or `mvn dependency:list`. |
| Gradle | `./gradlew :<module>:dependencies --configuration runtimeClasspath` (filter by package name). |
| npm/yarn | `npm ls <package>` or `yarn why <package>`. Inspect `package-lock.json` / `yarn.lock` for resolved versions. |
| Go modules | `go list -m all` and `go mod why <module>`. |
| Cargo | `cargo tree -p <crate>`. |

When `[dependency-coordinates]` is provided, restrict the search to that artifact. Otherwise, infer the dependency from the CVE record and walk through each affected coordinate.

For each coordinate found, record:
- **Resolved version.**
- **Direct or transitive** (and, if transitive, the path to the direct dependency that brings it in).
- **In-range verdict:** `in-range`, `out-of-range`, or `inconclusive` (when the version cannot be resolved cleanly).

If the dependency is **not present** at any coordinate, record this as the verdict and skip the code-mapping step.

### 5. Map Vulnerable APIs to Project Usage

For each in-range coordinate, locate the cited vulnerable APIs / classes / endpoints / config options in the dependency's documentation (from the references) and search the project for usage:

```bash
# Java/Kotlin imports
rg -n "import\s+<vulnerable.package.Class>" --glob '!**/target/**' --glob '!**/build/**'

# Direct method calls
rg -n "<vulnerableMethod>\s*\(" --glob '!**/target/**' --glob '!**/build/**'

# Configuration entries (XML, properties, YAML, TOML)
rg -n "<vulnerable-config-key>" --glob '!**/target/**' --glob '!**/build/**'
```

Use language-appropriate search patterns for non-JVM languages (e.g., `import` in Go, `require`/`from` in Node, `use` in Rust).

For each match, record:
- **File and line.**
- **Caller / surrounding context** — which feature in our project triggers it.
- **Reachability assessment** — is the code path reached at runtime, or only in a non-default branch / opt-in feature flag?
- **Configuration prerequisites** — does exploitation require a specific feature flag, protocol enabled, or input source?

Where the vulnerability requires a sink-style trigger (e.g., deserialization of attacker-controlled input, template evaluation of user input), trace the data flow from project entry points (HTTP handlers, message listeners, file readers, CLI args) to the sink. Note breaks in the chain (e.g., the project always wraps input through a validator before reaching the vulnerable API).

If feasible, write a **tiny standalone reproducer** that exercises the dependency API in isolation (a Java `main`, a Python snippet, a Go test) to confirm the *logic* matches the advisory description — **without** running the exploit against a live service.

### 6. Cross-check Prior Work

```bash
# Has anyone already filed an issue or PR mentioning this CVE/GHSA?
gh issue list --search "<CVE-ID> in:title,body" --state all
gh pr list --search "<CVE-ID> in:title,body" --state all

# Local commits referencing the identifier or the affected package
git log --all --oneline --grep="<CVE-ID>"
git log --all --oneline --grep="<GHSA-ID>"
git log --all --oneline -- '<manifest-path>'
```

If a recent dependency bump or related fix exists, cite it in the report and note whether the project is already on (or above) the patched version.

Also check whether GitHub already raised a Dependabot alert for this CVE on the repository:

```bash
gh api "repos/<OWNER>/<REPO>/dependabot/alerts?state=open" \
  --jq '.[] | select(.security_advisory.cve_id == "<CVE-ID>")'
```

If an alert exists, link to it; the user may prefer the `/oss-fix-github-alert dependabot alert=<NUMBER>` flow.

### 7. Produce the Exposure Report

Output a structured report. Include the robot disclaimer at the top.

```markdown
> :robot: **Note:** This exposure analysis was generated by a coding agent and requires manual verification. The findings below should be reviewed by a human maintainer before any action is taken.

## Third-Party CVE Exposure Analysis

### Identifier
- **CVE:** <CVE-ID>
- **GHSA / vendor IDs:** <list>
- **CVSS:** <score> (<vector string>)
- **CWE:** <CWE-ID> - <name>

### Vulnerability Summary
- **Class:** <RCE / SSRF / deserialization / path traversal / ...>
- **Vulnerable APIs / configurations:** <list>
- **Vulnerable version range:** <range>
- **First patched version:** <version>
- **Public exploit / PoC available:** <yes / no — reference URL if yes>
- **Vendor workarounds:** <summary or "none documented">

### Dependency Presence

| Coordinate | Resolved version | Direct / transitive | In vulnerable range? |
|------------|------------------|----------------------|----------------------|
| <group:artifact> | <version> | direct / transitive (via <parent>) | :white_check_mark: yes / :x: no / :warning: inconclusive |

### Project Usage of Vulnerable APIs

| File | Line | API / config | Reachable from project entry point? | Notes |
|------|------|--------------|-------------------------------------|-------|
| <file> | <n> | <api> | yes / no / unclear | <data-flow note> |

If no usage is found, state explicitly: "No project code reaches the vulnerable APIs cited by the advisory." and explain how the search was scoped (which patterns, which modules).

### Prior Work
<Any existing issue, PR, commit, or Dependabot alert referencing this advisory.>

### Exposure Verdict
- :large_blue_diamond: **Exposed** - dependency is in vulnerable range AND project reaches the vulnerable code path under realistic configuration.
- :large_blue_diamond: **Not exposed in current usage** - dependency is in range but the vulnerable code path is unreachable in the project's configuration / input model. Justify with the data-flow notes above.
- :large_blue_diamond: **Not affected** - dependency is absent or already on (or above) the patched version.
- :large_blue_diamond: **Inconclusive** - resolution could not be determined; list the missing information.

### Recommended Action
- :large_blue_diamond: **Upgrade** to <patched-version> (or later). For transitive dependencies, identify the direct dependency to bump.
- :large_blue_diamond: **Apply vendor workaround** - <summary of mitigation>.
- :large_blue_diamond: **Document "not affected" rationale** - record the analysis in the project's security notes or a tracking issue without exploit specifics.
- :large_blue_diamond: **No action** - dependency not present or already patched.

### Confidence
- **Level:** high / medium / low
- **Rationale:** <what would raise or lower confidence — e.g., "resolved versions verified via mvn dependency:tree, but reachability assessed by static search only">

### Open Questions
- <question 1>
- <question 2>
```

### 8. Propose a Follow-up Path

Based on the verdict, offer one or more of the following actions. Do NOT execute any without explicit confirmation.

**If exposed:**

1. **Bump the dependency** - hand off to `/oss-quick-fix` with a short, sanitized description (e.g., `upgrade <dependency> to <patched-version>`). Do NOT include exploit specifics in the public commit/PR text. Reference the CVE only if the project's policy and the advisory's public status explicitly permit it.
2. **Open a tracking issue** for follow-up work that exceeds a one-shot bump (config refactor, API migration after the upgrade, etc.) - hand off to `/oss-create-issue` with sanitized text. The proposed text MUST:
   - Frame the change as a hardening / dependency-update / refactor task.
   - Omit attack scenarios, exploit payloads, and exploitability commentary.
   - Reference the CVE only if the policy allows it.
3. **Address an existing GitHub alert** - if Dependabot has already raised an alert for this advisory, hand off to `/oss-fix-github-alert dependabot alert=<NUMBER>` instead of opening a new flow.

**If not exposed in current usage:**

4. **Document the rationale** - propose a short, sanitized note for the project's security notes or a private tracking issue. Do NOT publish exploit specifics. The note should describe *why* the project's usage does not reach the vulnerable path, so future contributors do not re-derive the analysis.

**If not affected:**

5. **Record a brief "not affected" note** - especially useful when external auditors or downstream consumers may ask. No public artifact required.

**If inconclusive:**

6. **Stop and request the missing information** - list what blocks a verdict (e.g., "cannot resolve transitive version; need access to the lockfile", "advisory does not name the vulnerable class").

In all cases, ask the user to confirm the sanitized text before any handoff.

### 9. Constraints

You MUST:
- Include the :robot: disclaimer note at the top of the exposure report.
- Verify the dependency's resolved version using the project's actual build tool, not heuristics (manifest-only inspection misses BOM-managed and transitive overrides).
- Distinguish "in vulnerable range" from "vulnerable code path reached" — they are not equivalent.
- Cite file and line for every claim of project usage.
- Ask the user before fetching URLs or contacting external systems.
- Sanitize any text proposed for downstream public artifacts.

You MUST NOT:
- Run the exploit / PoC against a live system or test instance, even locally. Verification is static and reproducer-based at most.
- Submit any issue, PR, advisory, or comment as part of this command. Handoffs go through the dedicated commands only after user confirmation.
- Include exploit payloads, raw advisory excerpts, or severity / "RCE" / "exploit" wording in any text intended for a downstream public artifact, unless the user explicitly authorizes it.
- Mark the project as "not exposed" without showing the data-flow reasoning.
- Conclude exposure from the manifest version alone — confirm with the resolver (Maven / Gradle / npm / Cargo / Go) so transitive overrides and BOMs are accounted for.

### 10. Acceptance Criteria

- The CVE record is fetched from at least one authoritative source (GHSA, NVD, OSV, or vendor advisory) and key fields are recorded.
- For each affected coordinate, the resolved version is verified via the project's build tool.
- For each in-range coordinate, the project's usage of the cited vulnerable APIs is searched and reported with file/line citations.
- A structured exposure report is produced with the :robot: disclaimer and a clear verdict.
- A concrete follow-up path is proposed, with the appropriate downstream command named, and any sanitized text is confirmed with the user before handoff.
