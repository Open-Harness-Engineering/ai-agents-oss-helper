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

**Detect ASF advisories by their references, not by their prose.** Many genuine ASF advisories never
contain the word "Apache" — they say "the Ambari Alert Definition feature", "CloudStack's host tags
listing", "the Spark History Server", "the Gravitino UI", "the FAB auth manager". Grepping the
description for `apache` silently drops them, and truncating the description before grepping drops
more. Every genuine ASF advisory, however, links to `lists.apache.org`, `cwiki.apache.org` or a
`<project>.apache.org` page, so filter on that:

```bash
gh api --paginate "/advisories?type=unreviewed&published=<YEAR>-01-01..<YEAR>-12-31&per_page=100" \
  --jq '.[] | select((.vulnerabilities|length)==0)
        | select([.references[]?|select(test("apache\\.org"))]|length > 0)
        | [.ghsa_id,(.cve_id//"-"),(.published_at[0:10]),
           ([.references[]?|select(test("apache\\.org"))]|join(" ")),
           (((.summary//"")+" || "+(.description//""))|gsub("[\n\t]";" ")|.[0:300])] | @tsv'
```

**Only the modern permalink counts.** A `lists.apache.org/thread/<id>` link, a
`<project>.apache.org/security/...` page or a `dist.apache.org/repos/dist/release/<p>/...CVE...` patch
is an ASF advisory reference. The **legacy** form
`lists.apache.org/thread.html/<hash>@%3C<list>.<project>.apache.org%3E` is a *discussion* link, which
NVD pastes onto advisories for other software that an ASF project merely discussed on its lists —
in 2022 that inflated the candidate set from 210 to 807 (OpenLDAP, libcurl, Python, Xorg, binutils,
even a LOGITEC router). Match on the strong forms only:

```
lists\.apache\.org/thread/[0-9a-z] | apache\.org/security | dist\.apache\.org/repos/dist/release/[a-z]+/.*CVE
```

Adding `github.com/apache/` as an extra signal was tested across five years and found **nothing** the
strong forms miss.

**The dataset floor is 2021.** `type=unreviewed` with `vulnerabilities==0` returns zero advisories
published in 2020 or earlier, so 2021-to-current is the whole territory; do not spend a sweep looking
further back.

As a cheap second probe, `?type=unreviewed&updated=<last few days>` catches records ingested late with
an older publish date. In practice it has never surfaced anything the full-year `published` sweep
missed, so treat it as a confirmation, not a substitute.

There is no server-side text filter, so the whole year downloads (~45-60k rows, under 10 minutes).
Run the **full year, every time** — not a rolling window, and not "I closed it last week". A rolling
window once hid a 385-advisory backlog, and a 61-advisory Apache Thrift release batch landed two days
after a reconciliation that reported nothing outstanding. Projects ship whole CVE families at once.
Reference matching also removes the opposite error — third-party advisories that merely mention an
ASF product (a Nagios or WordPress bug that happens to name Apache) stop showing up as candidates.



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

Then de-duplicate against work already submitted — **yours and other contributors'**. Other people
sweep this same backlog, so build one local index of every open PR rather than searching per GHSA
(one `--search` call per candidate is slow and easy to skip):

```bash
gh api --paginate "/repos/github/advisory-database/pulls?state=open&per_page=100" \
  --jq '.[]|"\(.number)\t\(.user.login)\t\(.title)"' > /tmp/allprs.tsv
# then match GHSA-....-....-.... out of the titles against your candidate list
```

**Match the GHSA id case-insensitively.** Most PR titles start with `[GHSA-...]`, but not all — a real
one reads *"Adding maven package and versions for ghsa-xw5h-cmh3-8j6j"*, and a case-sensitive regex
missed it, so a curator had to close my duplicate. Matching the PR's changed file path would be fully
authoritative, but that costs one API call per PR; the case-insensitive title match is the cheap fix. **Drop any candidate
that already has an open PR, whoever opened it.** Re-run the index after filing too: a collision can
appear in between, and a duplicate must then be closed with a comment pointing at the earlier PR.

Also drop any CVE listed in `skip_cves_apache_unmappable.txt` (next to this file) — those are
already-proven dead ends. **And when you judge a candidate unmappable, append it to that file with
its reason in the same session.** A verdict you keep only in your head is invisible to the next
sweep: parking ~150 "unmappable" items without recording them is what grew a 385-advisory backlog,
and the first sweep after that re-derived 182 of them from scratch.

Skip categories worth recognising, beyond "the project is C/C++/Lua with no registry":

- **The advisory rules the artifacts out itself** — e.g. "present only in the distribution package
  (SpringBoot platform) and does not involve Maven artifacts". Take it at its word.
- **Java project, native component.** Guacamole's terminal-emulator flaw is in `guacd`
  (guacamole-server, C); ORC's LZO flaw is C++ only. The Maven artifacts are unaffected.
- **A vendor CVE about a bundled ASF library belongs to the vendor**, not the ASF artifact: the
  product is the affected package, and it is usually not on a registry. Tell-tale signs are a
  vendor-only reference and a fix expressed as *the vendor's* version.
- **Released but not on a registry**: some ASF projects ship only source/binary distributions
  (Roller, OFBiz, Fineract, HertzBeat, OpenOffice, VCL, and UI distributions whose library modules
  are published while the UI is not).
- **`Apache::*` Perl distributions are CPAN, not ASF**, and GitHub has no CPAN ecosystem. An Arrow
  **R** package advisory is CRAN, which GitHub has no ecosystem for either.
- **A Java project can still have a native or unpublished component.** Guacamole's REST layer lives in
  the webapp (`guacamole-client` is a pom-only aggregator) and `guacamole-auth-saml` is unpublished;
  ZooKeeper's C cli shell, Commons Daemon's `jsvc`, NiFi MiNiFi C++, Tomcat Connectors (`mod_jk`),
  Santuario C++ and Xerces-C++ are all native. Check which module holds the vulnerable code before
  assuming the project's Maven artifacts are affected.
- **Web consoles ship separately from the server.** `iotdb-web-workbench` and
  `streampark-console` are not on Maven Central even though `iotdb-server` and the StreamPark
  connector libraries are.
- **No fix version AND published artifacts that postdate the affected range = unmappable.**
  ManifoldCF CVE-2022-45910 says "2.23 and prior" with no fix, and `mcf-*-connector` on Central starts
  at 2.26, so no published version falls inside the range.
- **Old `published` dates are often NVD backfill.** Advisories published 2022 can describe 2002-2016
  CVEs (Tomcat 6, Archiva 1.x, Maven 3.0.4). Rather than arguing about whether an old CVE is worth
  filing, apply a decidable test: **does the affected artifact exist on Maven Central across the range
  the advisory states?** On one batch of 22 that test filed 3 (Tomcat 7.x, whose artifacts start at
  7.0.0) and closed 19 — Archiva's artifacts start at 2.2.0 while the advisories name 1.0-1.3.x,
  Tomcat has nothing below 7.0.0, and `openejb-core`'s numbering does not map 1:1 onto the TomEE
  versions its advisory states. When only part of the range is reachable, encode the reachable stream
  and say in the PR which stream you left out and why.

- **A multi-language project needs a per-binding registry map, built once and verified.** Apache
  Thrift ships one release across ~20 bindings; only Java (`maven:org.apache.thrift:libthrift`),
  Python (`pip:thrift`), Go (`go:github.com/apache/thrift`), Node.js (`npm:thrift`), PHP
  (`composer:apache/thrift`), Ruby (`gem:thrift`), Rust (`cargo:thrift`) and .NET
  (`nuget:ApacheThrift`) are published. **Verify the registry entry is actually the ASF one** — the
  Hex package named `thrift` is Pinterest's elixir-thrift, and pub.dev's `thrift` stops at 0.13.0.
  Match binding names **case-insensitively**: ASF advisories write "py bindings", "java bindings",
  "nodejs bindings", "c++ bindings", and a case-sensitive regex silently drops them. Then re-read
  every multi-binding advisory in full before filing, to confirm each binding you extracted is listed
  as affected rather than mentioned in passing.

A project-name extractor is triage, never a verdict — read every bucket before skip-listing it.
Three regex misses once hid 41 filable advisories in buckets labelled "not ASF" and "unmappable".

Present the resulting scope table (CVE, GHSA, verdict) to the user and get explicit confirmation before generating anything — the candidate count equals the number of PRs that will be opened.

### 5. Download the Current Advisory JSON Files

The repository path of an unreviewed advisory derives from its `published_at` timestamp:

```text
advisories/unreviewed/<YYYY>/<MM>/<GHSA-ID>/<GHSA-ID>.json
```

Fetch each candidate's file raw (`https://raw.githubusercontent.com/github/advisory-database/main/<path>`). If the computed path 404s, retry with the month before and after (records can straddle month boundaries). Keep these pristine copies — they are both the generation base and the later freshness check.

### 6. Extract Per-CVE Facts

**Start from the ASF announcement's `Affected versions:` header.** Nearly every ASF oss-security mail
carries a block like `- Apache Storm Nimbus (org.apache.storm:storm-server) 3.0.0 before 3.1.0`, which
states the **Maven coordinate and the exact bounds** even when the GHSA prose states neither. Where
the header and the prose disagree, the header is usually right and is always the thing to cite — for
Gravitino CVE-2025-53648 the prose said "the Gravitino UI, in versions 1.0.0 and below ... upgrade to
version 1.0.0" (self-contradictory) while the header said
`org.apache.gravitino:catalog-jdbc-common 0.5.0 before 1.0.0`, a different artifact entirely. The
openwall mirror (`https://www.openwall.com/lists/oss-security/<YYYY>/<MM>/<DD>/<n>`) serves these as
plain text; `lists.apache.org` needs JavaScript.

From the official advisory (not from the NVD text) extract, per CVE:

- **Summary** - copied **verbatim** from the official summary field.
- **Version streams** - ordered `(introduced, fixed)` pairs, one per maintained release stream, exactly as the official `affected`/`fixed` statements say (e.g. "from 4.0.0 before 4.14.8, from 4.15.0 before 4.18.3, from 4.19.0 before 4.21.0" is three streams). Watch for irregular cases: single-stream fixes, streams fixed in a non-latest release, streams starting mid-history.
- **Affected artifacts** - only the artifacts the official description explicitly names as affected. Multi-artifact advisories are common (shared code, component families); never trim or extend the official list by judgement.
- **Ecosystem and package naming** - from the project's build tool (e.g. Maven -> `org.apache.camel:camel-<name>`, npm -> package name, Go -> module path).
- **Source location** - the artifact's directory in the project source tree, verified to exist (check the local checkout or the GitHub tree) before using it as a `PACKAGE` reference URL.

If any fact cannot be sourced from the official advisory, leave that advisory out of the batch and tell the user why. Do NOT guess.

**The official advisory can contradict itself.** ASF announcements carry a structured
`Affected versions:` header and a prose `This issue affects ...` clause, and they disagree often
enough to check both:

- prose typo, header right — Tomcat CVE-2026-55955 ("9.0.18" vs header "9.0.118");
- prose template left unfilled — Ranger CVE-2026-32227 ("This issue affects ." with the header
  carrying "org.apache.ranger.services 2.0.0 through 2.8.0");
- header right for one line and prose right for another — OpenNLP CVE-2026-63317.

When the two disagree and neither is obviously a typo, **read the released source**: find the symbol
the fix introduces at its real call site and check which tag first contains it.

```bash
gh api "/repos/<org>/<repo>/contents/<path>?ref=<tag>" --jq .content | base64 -d | grep -c '<symbol>'
```

Grep the **call site**, not a helper the fix merely reuses — a shared guard may predate this CVE
because an earlier CVE added it. Record whichever source you used in the PR body, and skip the
advisory if the conflict stays unresolved.

**Component scoping.** When the advisory names a component rather than the whole product, map to
that component's artifact: Struts JSON-plugin bulletins -> `struts2-json-plugin` (not
`struts2-core`), Tomcat cluster issues -> `tomcat-tribes`, Tomcat examples-webapp issues -> the
`org.apache.tomcat:tomcat` distribution alone. Plugin-level artifacts have curated precedent
(`struts2-rest-plugin`, `struts2-convention-plugin`, `tomcat-coyote-ffm`). When the advisory links
its own fix PR (InLong does), the modules that PR touches are the authoritative artifact list.

**No mappable package is a valid outcome.** Skip, and add the CVE to
`skip_cves_apache_unmappable.txt` with the reason, when the affected code is a C/C++/c_glib/Swift
binding with no package-manager distribution, the project publishes nothing to a package registry
(OFBiz, Fineract), the vulnerable module is unpublished (OpenMeetings' web module), the project is
retired with no fix (Shindig), the "fix" is documentation only (Kafka CVE-2026-41115), or the
product is not ASF at all despite the name (Azure Managed Instance for Apache Cassandra).

### 7. Generate the Updated JSON

Write a small generator script (keep it in the session scratchpad) rather than hand-editing files. For each advisory:

1. **Round-trip fidelity check first**: re-serialize the pristine JSON with your serializer settings and require byte equality with the downloaded file. If it differs, your diff would contain formatting noise — fix the serializer, or skip the file. Reference settings that match the upstream repo: 2-space indent, UTF-8 without ASCII-escaping, **no trailing newline** (Python: `json.dumps(obj, indent=2, ensure_ascii=False)`).
2. Preserve the original key order. Insert `summary` immediately **after** `aliases` / before `details`. Update `modified` to the current UTC timestamp (`%Y-%m-%dT%H:%M:%SZ`).
3. Replace `"affected": []` with one entry **per artifact per stream** — one entry holding exactly
   ONE range, never one entry with several ranges. That is the convention in the curated export
   (e.g. `GHSA-wm9w-rjj3-j356` = 8 entries; `GHSA-hf52-78x8-6w3w` = 3 packages x 2 streams = 6):

   ```json
   {
     "package": { "ecosystem": "<Ecosystem>", "name": "<package-name>" },
     "ranges": [ { "type": "ECOSYSTEM", "events": [
       { "introduced": "<version-or-0>" },
       { "fixed": "<fixed-version>" }
     ] } ]
   }
   ```

   - Use `"introduced": "0"` when the stream starts at the component's beginning of life; use the
     literal start version when the official statement says the stream begins later (this keeps
     late-introduced components from being flagged for versions that predate the flaw).
   - Use `{ "last_affected": "<last-version>" }` in place of `fixed` when the advisory names **no**
     fix for that stream — end-of-support lines are the common case (Tomcat 8.5.x/7.0.x, Struts 2.x).
   - Emit **no** `database_specific` block when a `fixed` event is present. Reserve
     `database_specific.last_known_affected_version_range` for advisories with no fix at all; the
     curated multi-stream advisories carry no `database_specific` whatsoever.
   - **Never synthesise a `fixed` version.** `fixed` asserts "this release exists and contains the
     fix". If the advisory states affected ranges but names **no** fix, use `last_affected` at the
     bound it states — do not compute "upper bound + 1". Inventing `3.3.17` / `2.9.15` / `2.8.13` for
     spring-kafka (whose lines stop at 3.3.16 / 2.9.13 / 2.8.11) was a real defect that had to be
     corrected after filing.
   - The one case where an **unpublished** `fixed` is correct is when *upstream itself* names that
     version — Tomcat 10.1.37/9.0.101, IoTDB 1.3.8/2.0.9, Atlas 2.6.0, Sling security 1.3.12. Keep the
     advisory's value and say in the PR body that it is not on the registry and which version is the
     first published unaffected one.
   - **Audit after every large batch**: extract every `(ecosystem, package, fixed)` triple from your
     open PRs and check each against its registry. Over 293 distinct pairs this surfaced exactly one
     defect. Beware two checker traps: query RubyGems/crates/Packagist by parsing their JSON (an HTTP
     code is not enough), and a Go module version can 404 on `proxy.golang.org` purely because the
     proxy has not cached the tag yet — confirm against the repo's git tags before calling it missing.

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

**Batch-loop hazards that silently truncate a run** (each of these cost a re-run in the 2026-10-01
sweep of 131 advisories):

- `gh pr create` and `git` read stdin, so inside `while read -r line; do ... done < file` they eat
  the loop's remaining input: the loop stops a few iterations in and exits 0. Drive the loop on a
  dedicated descriptor and starve every child of stdin:

  ```bash
  while read -r line <&3; do
    git -C "$R" checkout -q -B "$br" base </dev/null || continue
    out=$(gh pr create ... </dev/null 2>&1)
  done 3< batch.jsonl
  ```

- **Audit `ecosystem` per generated entry whenever a batch mixes registries.** A PyPI package built
  with the Maven helper serialises as `{"ecosystem": "Maven", "name": "apache-airflow-providers-fab"}`
  and nothing downstream complains. One line over the generated files catches it.
- Detect success by grepping the whole `gh pr create` output for the PR URL, not by exit status or
  `| tail -1`; append each success to a `done.tsv` and skip anything already listed, so a re-run is
  idempotent. Reconcile `done.tsv` against the live PR list afterwards.
- Never edit a shell script while it is running — bash re-reads it incrementally. Copy it to a new
  filename for the re-run.
- `nohup ./x.sh &` makes the harness report "completed" for the **wrapper**, not the script. Confirm
  with `ps -eo args | grep -F x.sh | grep -v grep` before starting a second copy; two copies sharing
  one clone collide on `.git/index.lock` and cascade bogus "FAIL checkout" for the whole remainder.

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
