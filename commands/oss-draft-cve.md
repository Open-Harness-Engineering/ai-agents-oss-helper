# Draft CVE Advisory

Draft a project-specific CVE advisory page (e.g. Apache Camel-style `CVE-YYYY-NNNNN.html`) from a reserved CVE number, a reference advisory used as a format template, and optional context from a prior triage report and fix PR.

This command is drafting-only: it produces the advisory files locally for the maintainer to review, sign, and publish. It never pushes to a public security site, submits to MITRE, or reserves CVE identifiers.

## Usage

```
/oss-draft-cve <cve_id> template=<url_or_path> [triage_ref=<path_or_url>] [fix_pr=<pr_or_url>]
```

**Arguments:**
- `<cve_id>` - The **reserved** CVE ID (e.g. `CVE-2026-25747`). Required. The command does not reserve IDs — it only drafts against one already issued by the CNA.
- `template=<url_or_path>` - Required. URL to a reference advisory (e.g. `https://camel.apache.org/security/CVE-2026-25747.html`) **or** a local file (`.md` / `.pdf` / `.html`) whose layout the draft should match.
- `triage_ref=<path_or_url>` - Optional. Path or URL to the output of `/oss-triage-security-report`. Used to auto-populate description, affected code paths, and severity.
- `fix_pr=<pr_or_url>` - Optional. PR number or URL containing the fix. Used to extract fixed-version ranges, commit hashes, and issue references.

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Parse Input

Parse the argument string into four values:

- `cve_id` - first positional argument
- `template` - required key/value
- `triage_ref` - optional key/value
- `fix_pr` - optional key/value

If `cve_id` or `template` is missing, stop and print the usage block above.

### 3. Validate the Reserved CVE ID

Validate that `cve_id` matches the CVE naming convention: `CVE-<YYYY>-<NNNN or longer>`.

```
^CVE-\d{4}-\d{4,}$
```

If it does not match, stop and ask the user to provide the reserved ID in the correct format. Do NOT attempt to generate or guess an ID.

Remind the user:

> This command assumes `<cve_id>` has already been reserved by the CNA. If it has not, stop here and reserve it first. Drafting against an unreserved ID risks publishing with an ID that later gets assigned to someone else's vulnerability.

### 4. Acquire the Template

Determine the `template` source:

- **URL** (starts with `http://` or `https://`) - Ask the user to confirm the URL is safe to fetch. If confirmed, fetch with `WebFetch`. Extract the rendered text content.
- **Local file** - Detect the extension:
  - `.md` / `.html` / `.txt` - read with the `Read` tool.
  - `.pdf` - read with the `Read` tool (native PDF support).
  - `.docx` or other binary formats not directly supported - stop and ask the user to convert to `.md` or `.pdf` first. Do NOT attempt to parse the raw binary.

Store the template's raw text for parsing in the next step.

### 5. Extract the Template Skeleton

Parse the template to identify the section structure **used by this project**. Do NOT assume the Apache Camel layout — each project has its own house style. Look for headings, bolded labels, or field-value pairs such as:

- CVE ID
- Severity (or CVSS score, or risk rating)
- Summary (or title)
- Versions Affected
- Versions Fixed (or Patched Versions)
- Description
- Notes (or Technical Details)
- Mitigation (or Workaround, or Remediation)
- Credit (or Reporter, or Acknowledgements)
- References (or Links)
- Timeline / Disclosure dates (if present)
- CWE (if present)

Produce an ordered list of the template's sections with their exact labels. Present this skeleton to the user and ask them to confirm before populating — they may want to add, remove, or rename a section to match a newer house style.

### 6. Gather Content

Collect the content needed to fill each section. Use every available source before asking the user.

#### 6.1 Triage reference (if `triage_ref` provided)

If `triage_ref` is a URL, confirm with the user before fetching (same as step 4). Then parse the triage summary to extract:

- **Vulnerability class** - maps to `Severity` and informs the `Summary` line.
- **Root cause** - maps to `Description`.
- **Affected components and code paths** - maps to `Notes` and `Description`.
- **Versions affected** - maps to `Versions Affected`.
- **Severity assessment** - maps to `Severity`.
- **Prior CVE reference** - add to `References` / `Notes` if present.
- **Reporter credit** - maps to `Credit` if the triage retained reporter identity.

#### 6.2 Fix PR (if `fix_pr` provided)

Extract the PR number from the argument. If a full URL, take the trailing number.

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json number,title,body,headRefName,baseRefName,mergedAt,mergeCommit,commits,files,labels
```

From the response, derive:

- **Fix commit hashes** - from `commits[].oid` and `mergeCommit.oid` for the `Notes` section.
- **Issue/ticket references** - scan the PR title and body for `CAMEL-NNNNN`, `#NNN`, or `Fix #NNN` patterns; add to `Notes`.
- **Files touched** - from `files[].path`, useful for confirming the affected code path.
- **Target branch** - from `baseRefName`. Combine with `git tag --contains <merge_commit>` to determine which release versions contain the fix:

  ```bash
  git tag --contains <merge_commit_sha> | sort -V
  ```

  The smallest tag per release line is a candidate `Versions Fixed` entry. Present the raw tag list to the user — do NOT guess release-line mappings silently.

#### 6.3 Missing data

For any section the template expects but neither source provides, insert an explicit placeholder:

```
TODO: <what is missing and where it should come from>
```

Do NOT guess CVSS scores, CWE mappings, severity ratings, version ranges, or reporter names. A wrong CVE advisory is worse than an incomplete one.

### 7. Emit Artifacts

Produce two files side by side in the repository root (or the path the user specifies):

1. `<cve_id>.<ext>` - the advisory page in the template's format. Use the same extension the template used (`.html`, `.md`, `.txt`). Reproduce the template's heading style, field labels, and ordering exactly.
2. `<cve_id>.txt` - a plaintext body suitable for PGP signing into `<cve_id>.txt.asc`. This mirrors the advisory content in a `gpg --clearsign`-friendly plain format (no HTML tags, no markdown adornments, ASCII only where possible). Include a header block with the CVE ID, summary, and project name so the signed text is self-contained.

Do NOT run `gpg` or sign anything. The user signs the `.txt` file themselves after review.

Include a top banner in both files:

```
:robot: Draft generated by an OSS Helper agent on <date>. Review every field before publishing. Do not publish without human maintainer sign-off.
```

The banner MUST be removed manually before signing and publishing.

### 8. Review Checklist

After writing the files, print a checklist for the maintainer to run through before publication. Do NOT mark any item as done for them.

```markdown
## Review Checklist for <cve_id>

- [ ] CVE ID `<cve_id>` matches the one reserved with the CNA (not a typo, not a different year).
- [ ] Severity / CVSS score reviewed against the triage assessment.
- [ ] CWE mapping (if present) is correct.
- [ ] Versions Affected ranges verified against `git tag` and release history.
- [ ] Versions Fixed matches the tags that contain the fix commit(s).
- [ ] Description contains no exploit payloads, PoC code, or reporter-private details.
- [ ] Credit line matches what the reporter agreed to (coordinate with them if unclear).
- [ ] References resolve (PR URL, commit URL, JIRA/GitHub issue, prior CVE).
- [ ] `<cve_id>.txt` matches `<cve_id>.<ext>` (same facts, no drift between HTML and signed plaintext).
- [ ] `:robot:` draft banner removed from both files.
- [ ] Plaintext body clearsigned with the project release key (`gpg --clearsign <cve_id>.txt` → `<cve_id>.txt.asc`).
```

### 9. Constraints

You MUST:
- Validate the CVE ID format before doing anything else.
- Learn the section structure from the template provided, not from a hardcoded layout.
- Produce both the advisory page and the matching plaintext body, and keep their content in sync.
- Insert explicit `TODO:` markers for any section whose content cannot be derived from the provided sources.
- Stop after emitting the files. Do not sign, push, publish, or open a PR.
- Confirm URL fetches with the user before calling `WebFetch`.

You MUST NOT:
- Reserve, request, or generate CVE identifiers.
- Guess CVSS scores, CWE mappings, severity ratings, or release-line-to-version mappings.
- Include exploit payloads, PoC code, or reporter-private details in the draft.
- Run `gpg` or any signing command.
- Submit the draft to MITRE, a project security site, or a public tracker.
- Overwrite an existing `<cve_id>.<ext>` or `<cve_id>.txt` without confirming with the user.

### 10. Acceptance Criteria

- The reserved `cve_id` is validated and carried through both artifacts unchanged.
- The advisory layout matches the sections and labels of the provided template.
- Each template section is either populated from `triage_ref` / `fix_pr` / user input, or contains an explicit `TODO:` marker.
- Two files are produced: `<cve_id>.<ext>` and `<cve_id>.txt`, with matching content.
- A `:robot:` draft banner is present on both files.
- A review checklist is printed and nothing is signed, pushed, or published.
