Populate or correct entries in the [GitHub Advisory Database](https://github.com/github/advisory-database) for the project's own **published** CVEs. Unreviewed advisories are imported from NVD with no package/ecosystem mapping (`"affected": []`), so downstream tools (Dependabot, OSV scanners) cannot alert on them until someone contributes the affected-package data. This guideline formalizes that contribution: one pull request per advisory, with data taken verbatim from the project's official security advisories.

Upstream contribution rules (from `github/advisory-database` CONTRIBUTING.md) that this workflow MUST honor:

- One advisory per pull request.
- Fork-based PRs (`fork -> branch -> PR`).
- Only public, referenceable information — never pre-disclosure details.
- Changes must follow the [OSV schema](https://ossf.github.io/osv-schema/).

### 1. Parse Input

All arguments are optional:

- `year` - restrict the sweep to CVEs of one year (e.g. `2026`).
- `cve_ids` - explicit list of CVE ids to process (space or comma separated). Overrides `year`.
- `example_pr` - an existing advisory-database PR (URL or number) whose structure should be mirrored. If provided, fetch it with `gh pr view/diff` and treat its field layout as the canonical output shape.

If neither `year` nor `cve_ids` is given, ask the user to bound the scope before proceeding — a full-history sweep can mean dozens of PRs.

### 2. Locate the Authoritative Advisory Source

The generated data MUST come from the project's official security advisories, never from memory or NVD prose alone.

- If the optional `project-security.md` rule file exists, read the advisory page location / publishing conventions from it.
- Otherwise look for the project's security page (e.g. `https://<project>/security/`) or the website repository that sources it (e.g. Apache projects often keep `content/security/CVE-*.md` files with structured front matter in a `<project>-website` repository).
- If no authoritative source can be located, stop and ask the user.

The source must provide, per CVE: a one-line **summary**, the **affected version streams**, the **fixed versions**, and the **affected components/artifacts**. Front-matter-style sources (`summary:`, `affected:`, `fixed:` fields) are ideal because values can be copied verbatim.

### 3. Enumerate Published CVEs

List the project CVEs in scope from the authoritative source (e.g. enumerate `content/security/CVE-<year>-*.md` via `gh api repos/<org>/<website-repo>/contents/<path>`). Only **published** advisories qualify — anything embargoed, draft, or on a hold-merge branch is out of scope and MUST NOT be submitted.

### 4. Map CVEs to GitHub Advisories and Classify

For each CVE in scope:

```bash
gh api "/advisories?cve_id=<CVE-ID>" \
  --jq '.[] | [.cve_id, .ghsa_id, .type, (.vulnerabilities|length), .published_at] | @tsv'
```

Classify:

- `type == "reviewed"` - already curated by GitHub with package data. **Skip.**
- `type == "unreviewed"` with non-empty `vulnerabilities` - already populated. **Skip.**
- `type == "unreviewed"` with empty `vulnerabilities` - **candidate.**

Then de-duplicate against work already submitted: skip any candidate whose GHSA id already appears in an open advisory-database PR:

```bash
gh pr list --repo github/advisory-database --state open --search "<GHSA-ID> in:title" --json number
```

Present the resulting scope table (CVE, GHSA, verdict) to the user and get explicit confirmation before generating anything — the candidate count equals the number of PRs that will be opened.

### 5. Download the Current Advisory JSON Files

The repository path of an unreviewed advisory derives from its `published_at` timestamp:

```text
advisories/unreviewed/<YYYY>/<MM>/<GHSA-ID>/<GHSA-ID>.json
```

Fetch each candidate's file raw (`https://raw.githubusercontent.com/github/advisory-database/main/<path>`). If the computed path 404s, retry with the month before and after (records can straddle month boundaries). Keep these pristine copies — they are both the generation base and the later freshness check.

### 6. Extract Per-CVE Facts

From the official advisory (not from the NVD text) extract, per CVE:

- **Summary** - copied **verbatim** from the official summary field.
- **Version streams** - ordered `(introduced, fixed)` pairs, one per maintained release stream, exactly as the official `affected`/`fixed` statements say (e.g. "from 4.0.0 before 4.14.8, from 4.15.0 before 4.18.3, from 4.19.0 before 4.21.0" is three streams). Watch for irregular cases: single-stream fixes, streams fixed in a non-latest release, streams starting mid-history.
- **Affected artifacts** - only the artifacts the official description explicitly names as affected. Multi-artifact advisories are common (shared code, component families); never trim or extend the official list by judgement.
- **Ecosystem and package naming** - from the project's build tool (e.g. Maven -> `org.apache.camel:camel-<name>`, npm -> package name, Go -> module path).
- **Source location** - the artifact's directory in the project source tree, verified to exist (check the local checkout or the GitHub tree) before using it as a `PACKAGE` reference URL.

If any fact cannot be sourced from the official advisory, leave that advisory out of the batch and tell the user why. Do NOT guess.

### 7. Generate the Updated JSON

Write a small generator script (keep it in the session scratchpad) rather than hand-editing files. For each advisory:

1. **Round-trip fidelity check first**: re-serialize the pristine JSON with your serializer settings and require byte equality with the downloaded file. If it differs, your diff would contain formatting noise — fix the serializer, or skip the file. Reference settings that match the upstream repo: 2-space indent, UTF-8 without ASCII-escaping, **no trailing newline** (Python: `json.dumps(obj, indent=2, ensure_ascii=False)`).
2. Preserve the original key order. Insert `summary` immediately **after** `aliases` / before `details`. Update `modified` to the current UTC timestamp (`%Y-%m-%dT%H:%M:%SZ`).
3. Replace `"affected": []` with one entry **per artifact per stream**:

   ```json
   {
     "package": { "ecosystem": "<Ecosystem>", "name": "<package-name>" },
     "ranges": [ { "type": "ECOSYSTEM", "events": [ { "introduced": "<version-or-0>" } ] } ],
     "database_specific": { "last_known_affected_version_range": "< <fixed-version>" }
   }
   ```

   Use `"introduced": "0"` when the stream starts at the component's beginning of life; use the literal start version when the official statement says the stream begins later (this keeps late-introduced components from being flagged for versions that predate the flaw).

4. Append one `PACKAGE` reference to the `references` array, pointing at the verified source tree URL (e.g. `https://github.com/<org>/<repo>/tree/main/<component-path>`).
5. Leave every other field untouched, including `database_specific.github_reviewed`.
6. Validate the output: parses as JSON, the CVE id is in `aliases`, and `len(affected) == artifacts x streams`.

Diff every generated file against its pristine copy and confirm the diff contains **only** the intended changes (modified bump, summary, affected block, PACKAGE reference). Spot-review at least the simplest and the most complex advisory with the user if anything looks unusual.

### 8. Fork and Prepare Signed Commits

Contributions must carry the maintainer's normal commit signature and sign-off (`git commit -S -s`). The GitHub Contents API cannot produce either, so do NOT commit via `gh api PUT /contents` — use a local clone.

The advisory-database repository is huge; a partial clone keeps it tractable (~100 MB):

```bash
gh repo fork github/advisory-database --clone=false
git clone --depth 1 --filter=tree:0 --no-checkout https://github.com/<login>/advisory-database.git
cd advisory-database
git sparse-checkout init --cone
git sparse-checkout set <dir-of-each-candidate-advisory ...>
git checkout main
```

Then, per advisory:

```bash
git switch -C <login>-<GHSA-ID> main
cmp <repo-path> <pristine-copy>   # freshness check: abort this advisory if upstream changed since download
cp <generated-file> <repo-path>
git add -A
git commit -S -s -m "[<GHSA-ID>] <first line of details, truncated ~60 chars>..."
git push origin <login>-<GHSA-ID>
```

Branch naming `<login>-<GHSA-ID>` matches the convention used by GitHub's own "suggest improvements" flow and the upstream CONTRIBUTING suggestion.

### 9. Open the Pull Requests

Run one **pilot** PR end-to-end first; verify its rendered diff (`gh pr diff`) and the commit's `verified` status before batching the rest.

```bash
gh pr create --repo github/advisory-database --base main \
  --head "<login>:<login>-<GHSA-ID>" \
  --title "[<GHSA-ID>] <first line of details, truncated>..." \
  --body "<body>"
```

PR body template (mirrors the improvement-flow layout; adjust the update list to what actually changed):

```markdown
**Updates**
- Affected products
- Source code location
- Summary

**Comments**
Affected packages (<ecosystem>), version ranges, source code location and summary are taken from the official <project> security advisory: <official-advisory-URL>

_<AI attribution line per the project's rules of engagement>_
```

Space the creations 8-10 seconds apart. Log every created PR (CVE, GHSA, URL) to a running manifest file so the batch is resumable and idempotent.

### 10. Rate Limits and Draft Fallback

GitHub caps PR creation bursts (roughly 20-30 per rolling hour). The refusal is misleadingly worded:

```text
GraphQL: <login> does not have the correct permissions to execute `CreatePullRequest`
```

This is throttling, not a permissions problem. Handle it:

- Retry the failed creations with exponential backoff (minutes apart), skipping any branch that meanwhile got a PR.
- If the cap persists, create the remaining PRs as **drafts** (`gh pr create --draft ...`) — draft creation bypasses the cap. Record which PRs are drafts and mark them ready later (`gh pr ready <n> --repo github/advisory-database`) as earlier ones get merged or closed.
- Branches are pushed independently of PR creation, so no work is lost when a creation is throttled.

### 11. Verify and Report

After the batch:

- Every branch head is signed and signed-off: `gh api /repos/<login>/advisory-database/commits/<branch> --jq '.commit.verification.verified'` is `true` and the message contains the `Signed-off-by:` trailer.
- The open-PR count matches the candidate count (`gh pr list --repo github/advisory-database --author <login> --state open --limit 100` — mind the default list limit of 30).
- Print the final mapping table: CVE, GHSA, PR URL, draft-or-ready.
- List the follow-ups explicitly: drafts to flip ready, and a later pass to check whether the curation team merged, adjusted, or requested changes.

### 12. Constraints

You MUST:

- Process only **published** CVEs, with every field sourced from the project's official advisory.
- Present the scope (candidate list and PR count) and get user confirmation before opening PRs on the external repository.
- Open exactly one advisory per PR, from a fork, with `-S -s` commits.
- Run the round-trip fidelity check before generating, and the base-freshness `cmp` before committing.
- Verify artifact names and source-tree paths exist before writing them into `affected` / `PACKAGE` entries.
- De-duplicate against advisories that are reviewed, already populated, or already covered by an open PR.
- Include the AI attribution line in every PR body, per the rules of engagement.

You MUST NOT:

- Touch `github-reviewed` advisories or flip `github_reviewed` flags.
- Submit anything embargoed, unpublished, or known only from private channels.
- Guess version ranges, affected artifacts, ecosystems, or summaries.
- Commit through the GitHub Contents API (it cannot sign or sign off).
- Bundle multiple advisories into one PR or push branches to the upstream repository.

### 13. Acceptance Criteria

- Every candidate advisory has exactly one PR, or an explicit logged reason why it was skipped.
- Each PR diff contains only: `modified` bump, `summary`, populated `affected`, appended `PACKAGE` reference.
- `affected` entries equal artifacts x streams, matching the official advisory statements.
- All commits are verified-signed and carry the `Signed-off-by:` trailer.
- A final CVE -> GHSA -> PR mapping table is printed, with drafts and follow-ups called out.
