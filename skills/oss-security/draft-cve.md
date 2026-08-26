### 1. Parse Input

Parse the argument string into four values:

- `cve_id` - first positional argument
- `template` - required key/value
- `triage_ref` - optional key/value
- `fix_pr` - optional key/value

If `cve_id` or `template` is missing, stop and print the usage block above.

### 2. Validate the Reserved CVE ID

Validate that `cve_id` matches the CVE naming convention: `CVE-<YYYY>-<NNNN or longer>`.

```text
^CVE-\d{4}-\d{4,}$
```

If it does not match, stop and ask the user to provide the reserved ID in the correct format. Do NOT attempt to generate or guess an ID.

Remind the user:

> This command assumes `<cve_id>` has already been reserved by the CNA. If it has not, stop here and reserve it first. Drafting against an unreserved ID risks publishing with an ID that later gets assigned to someone else's vulnerability.

### 3. Acquire the Template

Determine the `template` source:

- **URL** (starts with `http://` or `https://`) - Ask the user to confirm the URL is safe to fetch. If confirmed, fetch with `WebFetch`. Extract the rendered text content.
- **Local file** - Detect the extension:
  - `.md` / `.html` / `.txt` - read with the `Read` tool.
  - `.pdf` - read with the `Read` tool (native PDF support).
  - `.docx` or other binary formats not directly supported - stop and ask the user to convert to `.md` or `.pdf` first. Do NOT attempt to parse the raw binary.

Store the template's raw text for parsing in the next step.

### 4. Extract the Template Skeleton

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

### 5. Gather Content

Collect the content needed to fill each section. Use every available source before asking the user.

#### 5.1 Triage reference (if `triage_ref` provided)

If `triage_ref` is a URL, confirm with the user before fetching (same as step 3). Then parse the triage summary to extract:

- **Vulnerability class** - maps to `Severity` and informs the `Summary` line.
- **Root cause** - maps to `Description`.
- **Affected components and code paths** - maps to `Notes` and `Description`.
- **Versions affected** - maps to `Versions Affected`.
- **Severity assessment** - maps to `Severity`.
- **Prior CVE reference** - add to `References` / `Notes` if present.
- **Reporter credit** - maps to `Credit` if the triage retained reporter identity.

#### 5.2 Fix PR (if `fix_pr` provided)

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

#### 5.3 Missing data

For any section the template expects but neither source provides, insert an explicit placeholder:

```text
TODO: <what is missing and where it should come from>
```

Do NOT guess CVSS scores, CWE mappings, severity ratings, version ranges, or reporter names. A wrong CVE advisory is worse than an incomplete one.

JSON has no place to put a `TODO:` marker in a numeric or enumerated field. Step 7.3 defines how each unresolved section is carried into the machine-readable record.

### 6. Emit Artifacts

Produce two files side by side in the repository root (or the path the user specifies):

1. `<cve_id>.<ext>` - the advisory page in the template's format. Use the same extension the template used (`.html`, `.md`, `.txt`). Reproduce the template's heading style, field labels, and ordering exactly.
2. `<cve_id>.txt` - a plaintext body suitable for PGP signing into `<cve_id>.txt.asc`. This mirrors the advisory content in a `gpg --clearsign`-friendly plain format (no HTML tags, no markdown adornments, ASCII only where possible). Include a header block with the CVE ID, summary, and project name so the signed text is self-contained.

Do NOT run `gpg` or sign anything. The user signs the `.txt` file themselves after review.

Include a top banner in both files:

```text
:robot: Draft generated by an OSS Helper agent on <date>. Review every field before publishing. Do not publish without human maintainer sign-off.
```

The banner MUST be removed manually before signing and publishing.

### 7. Emit the CVE Record Format JSON

CVE Record Format 5.x is the structure the CVE Program defines for a record, and the ASF process tool at `https://cveprocess.apache.org/` serves its workflow from `/cve5`. That tool imports a record from a JSON file (step 9), so this file is not a byproduct - it is the artifact the whole command exists to produce. Getting it right means the maintainer loads one file instead of retyping a record into a form:

3. `<cve_id>.cve5.json` - the CVE Record Format JSON, carrying exactly the same facts as the advisory page and the plaintext body.

This file is a *draft record*, not a submission. Producing it does not change the rule in step 10: you never press the button that publishes.

#### 7.1 Shape the record against the real schema

Do NOT write the JSON from memory - the format has strict `oneOf` and `additionalProperties: false` constraints that are easy to violate. Fetch the published schema first and shape the record against it:

```bash
SCHEMA_DIR=/tmp/cve-schema
BASE=https://raw.githubusercontent.com/CVEProject/cve-schema/main/schema
mkdir -p "$SCHEMA_DIR/tags" "$SCHEMA_DIR/imports/cvss"
curl -sSL -o "$SCHEMA_DIR/CVE_Record_Format.json" "$BASE/CVE_Record_Format.json"
for f in reference-tags.json cna-tags.json adp-tags.json; do
  curl -sSL -o "$SCHEMA_DIR/tags/$f" "$BASE/tags/$f"
done
for f in cvss-v2.0.json cvss-v3.0.json cvss-v3.1.json cvss-v4.0.json; do
  curl -sSL -o "$SCHEMA_DIR/imports/cvss/$f" "$BASE/imports/cvss/$f"
done
```

The main schema `$ref`s the `tags/` and `imports/cvss/` files by relative path. Fetching `CVE_Record_Format.json` on its own is not enough - validation will abort on an unresolvable reference rather than report anything useful about the record.

Set `dataVersion` to the `default` declared by the schema you just fetched (read `definitions.dataVersion.default`). Do not hardcode a version from an older draft, and do not silently downgrade it.

Map the template's sections onto the record. The section labels differ per project - use the skeleton confirmed in step 4, not these exact names:

| Advisory section | CVE Record Format location |
|---|---|
| CVE ID | `cveMetadata.cveId` |
| Summary / Title | `containers.cna.title` |
| Description | `containers.cna.descriptions[]` |
| Versions Affected / Versions Fixed | `containers.cna.affected[].versions[]` |
| Severity / CVSS | `containers.cna.metrics[]` |
| CWE | `containers.cna.problemTypes[].descriptions[]` |
| Mitigation / Workaround | `containers.cna.workarounds[]` |
| Remediation / upgrade instructions | `containers.cna.solutions[]` |
| Credit / Reporter | `containers.cna.credits[]` |
| References | `containers.cna.references[]` |
| Timeline / Disclosure dates | `containers.cna.timeline[]` |

#### 7.2 Leave the CNA-controlled fields alone

The schema documents `cveMetadata` as *"controlled by the CVE Services"*. The CNA tool populates these on import, and a value you invent will either be silently overwritten or rejected:

- `cveMetadata.assignerOrgId`, `cveMetadata.assignerShortName`, `cveMetadata.requesterUserId`
- `cveMetadata.state`, `cveMetadata.serial`
- `cveMetadata.dateReserved`, `cveMetadata.datePublished`, `cveMetadata.dateUpdated`
- `containers.cna.providerMetadata.orgId`

Emit `cveMetadata` with `cveId` only, and omit `providerMetadata`, unless the assigning organization's UUID is known for certain.

For **ASF projects** it is known - a record in the ASF tool carries:

```json
"assignerOrgId": "f0158376-9dc2-43b6-827c-5f631a4d8d09",
"providerMetadata": { "orgId": "f0158376-9dc2-43b6-827c-5f631a4d8d09" }
```

Including it for an ASF project is safe and makes the file validate standalone; the tool re-asserts these on save either way. That UUID is the Apache Software Foundation's and no one else's - for any other CNA, ask the user or omit the fields. Do not carry it across projects.

Never set `cveMetadata.state`. Its only permitted value in the published-record schema is `PUBLISHED`, and a draft under review is not published. Its absence is what marks this file as a draft, since JSON cannot carry the `:robot:` banner the other two artifacts use.

State plainly to the user: **the draft will not pass strict standalone schema validation until the assigner UUID and state are filled in by the CNA tool.** That gap is expected and is not a defect in the draft.

#### 7.3 Omit rather than invent

Where a section carries a `TODO:` marker from step 5.3:

- **Optional blocks** - `problemTypes`, `metrics`, `workarounds`, `solutions`, `timeline`, `credits`, `tags`, `source` - omit the entire block. Never emit a placeholder `baseScore` of `0.0`, an invented `vectorString`, a `CWE-0`, or an empty-string credit. A record that omits the CVSS block is honest; a record scored `0.0` is wrong.
- **Required blocks** - `descriptions`, `affected`, `references` - emit them with whatever is known, and carry the `TODO:` text verbatim inside the relevant `value` or `description` string so review cannot miss it.

After writing the file, print the list of every block you omitted and why. The user must be able to see what the JSON does not yet say without diffing it against the advisory page.

#### 7.4 Constraints that fail validation most often

- `affected[]` entries need either `vendor` + `product` **or** `collectionURL` + `packageName`, and either `versions` **or** `defaultStatus`. `additionalProperties` is `false` - no extra keys.
- `affected[].versions[]` items are a strict `oneOf` with property-count caps. Use exactly one of these shapes:
  - `{version, status}` - a single version
  - `{version, status, versionType}` - a single version with explicit numbering semantics
  - `{version, status, versionType, lessThan}` - a range, upper bound exclusive
  - `{version, status, versionType, lessThanOrEqual}` - a range, upper bound inclusive

  Never add `lessThan` without `versionType`. Never set both `lessThan` and `lessThanOrEqual` on one entry.
- `versionType` is free text; the schema's examples are `custom`, `git`, `maven`, `python`, `rpm`, `semver`. Use `maven` for Maven-published projects and `semver` where the project genuinely follows semver - do not assume they are interchangeable.
- `status` is an enum: `affected`, `unaffected`, `unknown`. Nothing else.
- `descriptions[]` must contain at least one entry whose `lang` is an English code (`en`, `en_US`, ...), or the record is invalid.
- `problemTypes[].descriptions[]` entries require both `lang` and `description`; `cweId` must match `^CWE-[1-9][0-9]*$`, and `description` should be the CWE's official title.
- `metrics[]` entries must each carry one of `cvssV4_0`, `cvssV3_1`, `cvssV3_0`, `cvssV2_0`, or `other`.
- `references[].tags` come from a fixed enum: `broken-link`, `customer-entitlement`, `exploit`, `government-resource`, `issue-tracking`, `mailing-list`, `media-coverage`, `mitigation`, `not-applicable`, `patch`, `permissions-required`, `product`, `related`, `release-notes`, `signature`, `technical-description`, `third-party-advisory`, `vdb-entry`, `vendor-advisory`. Any other tag must be prefixed `x_`.
- `credits[].type` is an enum: `finder`, `reporter`, `analyst`, `coordinator`, `remediation developer`, `remediation reviewer`, `remediation verifier`, `tool`, `sponsor`, `other`.
- `tags` on the CNA container is an enum: `unsupported-when-assigned`, `exclusively-hosted-service`, `disputed`.
- Every timestamp (`timeline[].time`, `datePublic`) is RFC 3339: `yyyy-MM-ddTHH:mm:ss[+-]ZH:ZM`. A bare `yyyy-MM-dd` is rejected.

A minimal well-formed skeleton, with the CNA-controlled fields left out:

```json
{
  "dataType": "CVE_RECORD",
  "dataVersion": "<schema default>",
  "cveMetadata": {
    "cveId": "<cve_id>"
  },
  "containers": {
    "cna": {
      "title": "<summary line from the advisory>",
      "descriptions": [
        { "lang": "en", "value": "<description>" }
      ],
      "affected": [
        {
          "vendor": "<vendor>",
          "product": "<product>",
          "collectionURL": "https://repo.maven.apache.org/maven2",
          "packageName": "<groupId>:<artifactId>",
          "defaultStatus": "unaffected",
          "versions": [
            {
              "version": "<first affected>",
              "status": "affected",
              "versionType": "maven",
              "lessThan": "<first fixed>"
            }
          ]
        }
      ],
      "references": [
        { "url": "<advisory or PR url>", "name": "<title>", "tags": ["vendor-advisory"] }
      ]
    }
  }
}
```

#### 7.5 Check it before handing it over

Confirm the file is at least well-formed:

```bash
python3 -m json.tool <cve_id>.cve5.json > /dev/null && echo "well-formed"
```

Then validate the content against the schema. Validating the draft directly is close to useless: the record format is a top-level `oneOf` over the Published and Rejected shapes, so the missing CNA-controlled fields from step 7.2 collapse every error into a single root-level failure that echoes the whole document and hides real mistakes.

Validate a throwaway copy with those three fields stubbed in, against the `Published` branch of the top-level `oneOf` rather than the whole schema. Two details matter: the stub UUID must be shaped like a real version 4 UUID (the schema's `uuidType` pins the version and variant nibbles), and selecting the branch is what makes the validator report per-field paths instead of one root-level failure.

```bash
python3 -W ignore - <<'EOF'
import json, os
from jsonschema import Draft7Validator, RefResolver

SCHEMA_DIR = "/tmp/cve-schema"
STUB = "00000000-0000-4000-8000-000000000000"   # v4-shaped, or uuidType rejects it

schema = json.load(open(os.path.join(SCHEMA_DIR, "CVE_Record_Format.json")))
published = next(b for b in schema["oneOf"] if b.get("title") == "Published")
published = dict(published, definitions=schema["definitions"])
resolver = RefResolver(base_uri="file://" + SCHEMA_DIR + "/", referrer=schema)

rec = json.load(open("<cve_id>.cve5.json"))
rec["cveMetadata"]["assignerOrgId"] = STUB
rec["cveMetadata"]["state"] = "PUBLISHED"
rec["containers"]["cna"]["providerMetadata"] = {"orgId": STUB}

errors = sorted(Draft7Validator(published, resolver=resolver).iter_errors(rec),
                key=lambda e: list(e.path))
for e in errors:
    print("ERR", "/".join(str(p) for p in e.path) or "<root>", "->", e.message[:200])
print("VALID (content)" if not errors else f"{len(errors)} error(s)")
EOF
```

A clean draft prints `VALID (content)`. A defective one points at the exact path, for example:

```text
ERR containers/cna/affected/0/versions/0 -> {'version': '4.0.0', 'status': 'affected', 'lessThan': '4.4.0'} is not valid under any of the given schemas
ERR containers/cna/credits/0/type -> 'discoverer' is not one of ['finder', 'reporter', ...]
```

Every error this reports is a real defect in the draft - fix it. The stubbed values exist only for the check; they never go in the file. If `jsonschema` is not installed, say the record is unvalidated rather than implying it is valid, and do not install it without asking.

Finally, print the path to the file. It is the input to step 9 - do not POST it anywhere, and do not mistake a validated record for a published one.

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
- [ ] `<cve_id>.cve5.json` matches both (same versions, same severity, same references, same credit).
- [ ] Every block omitted from the JSON was omitted because the data is genuinely unknown, not because it was hard to map.
- [ ] `affected[].versions[]` entries use a permitted shape and the right `versionType` for how this project numbers releases.
- [ ] `cveMetadata.state` is still absent (the CNA tool sets it on publication).
- [ ] `:robot:` draft banner removed from both text files.
- [ ] Plaintext body clearsigned with the project release key (`gpg --clearsign <cve_id>.txt` → `<cve_id>.txt.asc`).
```

### 9. Hand the Record to the CNA Tool

The ASF process tool at `https://cveprocess.apache.org/` is [Vulnogram](https://github.com/Vulnogram/Vulnogram). Its record page has a **`CVE-JSON` tab that is read-only** (Copy / Download only), which makes it look like the record must be retyped. It does not: the toolbar `Open` control is backed by a hidden file input that imports a CVE record from disk.

```html
<input type="file" id="importJSON" accept="application/json" class="hid" onchange="loadFile(event,this);">
```

So `<cve_id>.cve5.json` from step 7 is loaded directly. Do not transcribe the record field by field, and do not automate the form - the import is a single action the maintainer performs:

1. Give the user the absolute path to `<cve_id>.cve5.json`.
2. They click **Open** in the tool's toolbar and select that file.
3. The editor populates from the record. The **Editor** tab shows a count of validation errors - they fix anything flagged.
4. They press **SAVE**.

**Gate:** do not hand over the file until the user confirms the step 8 checklist is done.

Two properties of the import worth stating when you hand the file over:

- **It replaces the editor's current contents.** If the record already holds work in progress, that work is overwritten on import. Where the tool already has content, offer to fold it into the JSON first rather than discarding it.
- **It does not save.** Nothing reaches the CNA until the maintainer presses SAVE, and nothing becomes public until the workflow below completes.

#### 9.1 Do not drive the tool yourself

Filling or submitting this tool programmatically is out of scope, whatever the mechanism - browser automation, a replayed session cookie, or a direct POST. The import above reduces the whole job to one file selection, so automation buys nothing and costs a great deal: the tool sits behind ASF SSO with MFA, and its toolbar carries `SAVE`, `Publish`, `Publish Selected`, `Reject All`, and `Transfer` controls next to each other.

If the user asks for automation anyway, point them at the `Open` control first. It is almost always what they actually wanted.

#### 9.2 The ASF workflow after SAVE

The maintainer does not submit to the CVE Program. Per the tool's own instructions, the record moves:

`DRAFT` → `REVIEW` (optional; notifies ASF Security to help with the entry) → `READY` (set when going public) → `PUBLIC`

The entry is visible only to the project's PMC and the ASF security team until it reaches `PUBLIC`. To finish: add a reference tagged `vendor-advisory` pointing at the public advisory post. **ASF Security is notified by that reference, submits the record to the CVE Program, and sets the state to `PUBLIC`.**

Never advise the user to submit to MITRE directly, and never describe a saved record as published.

### 10. Constraints

You MUST:

- Validate the CVE ID format before doing anything else.
- Learn the section structure from the template provided, not from a hardcoded layout.
- Produce the advisory page, the matching plaintext body, and the CVE Record Format JSON, and keep the facts in all three in sync.
- Fetch the published CVE schema before writing the JSON, and shape the record against it.
- Insert explicit `TODO:` markers for any section whose content cannot be derived from the provided sources.
- Omit optional JSON blocks whose data is unknown, and report every omission to the user.
- Confirm the step 8 checklist is done before handing the record to the CNA tool.
- Warn that importing replaces the tool's current editor contents, and offer to fold in existing work first.
- Stop after handing over the file. Do not sign, push, publish, or open a PR.
- Confirm URL fetches with the user before calling `WebFetch`.

You MUST NOT:

- Reserve, request, or generate CVE identifiers.
- Guess CVSS scores, CWE mappings, severity ratings, or release-line-to-version mappings.
- Invent placeholder values to satisfy the JSON schema - no `0.0` scores, no fabricated vector strings, no invented organization UUIDs.
- Populate the CNA-controlled `cveMetadata` fields or set `cveMetadata.state`.
- Include exploit payloads, PoC code, or reporter-private details in the draft.
- Run `gpg` or any signing command.
- Save, submit, or publish the record. Producing the file is the job; loading it and pressing SAVE is the maintainer's action, always. This applies to MITRE, a project security site, and any public tracker.
- Drive the CNA tool by any means - browser automation, a replayed session cookie, or a direct POST. The `Open` import makes it unnecessary (step 9.1).
- Automate a login or MFA flow, or ask for a password or one-time code.
- Advise submitting to the CVE Program directly, or describe a saved record as published (step 9.2).
- Overwrite an existing `<cve_id>.<ext>`, `<cve_id>.txt`, or `<cve_id>.cve5.json` without confirming with the user.

### 11. Acceptance Criteria

- The reserved `cve_id` is validated and carried through every artifact unchanged.
- The advisory layout matches the sections and labels of the provided template.
- Each template section is either populated from `triage_ref` / `fix_pr` / user input, or contains an explicit `TODO:` marker.
- Three files are produced: `<cve_id>.<ext>`, `<cve_id>.txt`, and `<cve_id>.cve5.json`, with matching content.
- The JSON is well-formed, uses only permitted enum values and version-entry shapes, and omits every block whose data is unknown.
- The list of omitted JSON blocks is printed alongside the review checklist.
- A `:robot:` draft banner is present on both text files.
- The user is handed the JSON path with the import steps, the warning that import replaces editor contents, and the reminder that SAVE is theirs to press.
- A review checklist is printed and nothing is signed, pushed, published, or submitted.
