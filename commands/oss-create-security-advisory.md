# Report Security Vulnerability

Privately report a security vulnerability to a GitHub repository using GitHub's private vulnerability reporting feature. This command is intended for security researchers and contributors — it does NOT require admin access.

## Usage

```
/oss-create-security-advisory
```

**Arguments:**
- None (all information is gathered interactively)

## Instructions

### 1. Initialize Project Context

**MANDATORY:** First, read and process the `.oss-init.md` file to detect the current project and load its rules. All subsequent steps assume the project context (project-info, project-standards, project-guidelines) is loaded.

### 2. Verify Eligibility

Read the **Issue tracker** field from the project's `project-info.md`:
- If the issue tracker is **not** `GitHub`, stop and tell the user: "Private vulnerability reporting is a GitHub-specific feature. This project uses a different issue tracker."

Read the **GitHub repo** field. This will be used as `<OWNER>/<REPO>` for API calls.

### 3. Check Private Vulnerability Reporting

Verify that the repository has private vulnerability reporting enabled:

```bash
gh api repos/<OWNER>/<REPO> --jq '.security_and_analysis.secret_scanning.status // "disabled"'
```

Also check whether the repository is public (private vulnerability reporting requires a public repository or GitHub Advanced Security on private repos):

```bash
gh api repos/<OWNER>/<REPO> --jq '.private'
```

If the repository is private, warn the user: "This repository is private. Private vulnerability reporting may not be available unless GitHub Advanced Security is enabled."

**Note:** There is no reliable way to check whether private vulnerability reporting is enabled via the API before submitting. If the API call in step 7 fails with a 403 or 404, the feature is likely not enabled. Inform the user and suggest they contact the repository maintainers directly.

### 4. Gather Vulnerability Information

Collect the following from the user:

**Required:**
- **Summary** - A short, descriptive title for the vulnerability (e.g., "SQL injection in query parameter handling")
- **Description** - Detailed explanation including:
  - What the vulnerability is
  - How it can be exploited (proof of concept or attack scenario)
  - Impact (confidentiality, integrity, availability)
  - Affected versions (if known)
  - Suggested fix or workaround (if known)
- **Severity** - One of: `critical`, `high`, `medium`, `low`. Help the user choose by asking about the impact:
  - `critical` - Remote code execution, full system compromise, no authentication required
  - `high` - Significant data exposure, privilege escalation, authentication bypass
  - `medium` - Limited data exposure, requires specific conditions to exploit
  - `low` - Minor information disclosure, requires significant preconditions

**Affected Package(s):**

Ask the user for each affected package:
- **Ecosystem** - One of: `npm`, `pip`, `maven`, `nuget`, `composer`, `go`, `rust`, `rubygems`, `erlang`, `actions`, `pub`, `swift`, `other`
- **Package name** - The affected package identifier (e.g., `org.example:my-library` for Maven, `my-package` for npm)
- **Vulnerable version range** - Version constraint using operators (e.g., `< 1.2.0`, `>= 2.0.0, < 2.3.1`)
- **Patched versions** - Version(s) containing the fix, or leave empty if no fix is available yet
- **Vulnerable functions** (optional) - Specific functions affected

If the user is unsure about ecosystem or package name, help them by inspecting the project's build files (e.g., `pom.xml`, `package.json`, `go.mod`, `Cargo.toml`) loaded during project context initialization.

Ask the user if they want to add more affected packages. Repeat collection for each.

**Optional:**
- **CWE IDs** - Common Weakness Enumeration identifiers (e.g., `CWE-89` for SQL injection, `CWE-79` for XSS). Suggest relevant CWEs based on the vulnerability description if possible.

### 5. Format the Description

Structure the description in Markdown:

```markdown
## Summary

<concise summary of the vulnerability>

## Details

<technical details of the vulnerability, including root cause>

## Proof of Concept

<steps to reproduce or demonstrate the vulnerability>

## Impact

<who is affected and what an attacker could achieve>

## Suggested Fix

<recommended remediation, or "None — reporting for maintainer assessment">
```

If the user provided a free-form description, restructure it into this format. Ask the user to confirm the formatted version.

### 6. Confirm with User

Before submitting, present a full summary:
- Summary (title)
- Severity
- Affected package(s) with ecosystem, name, and version range
- CWE IDs (if any)
- Full description

Remind the user:
- This report will be submitted **privately** to the repository maintainers
- Only the repository's security team and admins will see it
- The reporter (the user) will be credited and can participate in the discussion

Ask for explicit confirmation to proceed.

### 7. Build and Submit the Report

Construct the JSON payload:

```json
{
  "summary": "<summary>",
  "description": "<description>",
  "severity": "<severity>",
  "vulnerabilities": [
    {
      "package": {
        "ecosystem": "<ecosystem>",
        "name": "<package-name>"
      },
      "vulnerable_version_range": "<range>",
      "patched_versions": "<version>",
      "vulnerable_functions": ["<function>"]
    }
  ],
  "cwe_ids": ["<CWE-ID>"]
}
```

Omit optional fields that the user did not provide (do not send empty arrays for fields that were skipped). Omit `patched_versions` if no fix is known. Omit `vulnerable_functions` if not provided.

Submit using the GitHub private vulnerability reporting API:

```bash
gh api -X POST repos/<OWNER>/<REPO>/security-advisories/reports --input - <<'EOF'
<JSON_PAYLOAD>
EOF
```

**Important:** This uses the `/reports` endpoint, which is the private vulnerability reporting API for external reporters. It does NOT require admin access — any authenticated GitHub user can submit a report if the feature is enabled on the repository.

### 8. Report Result

After successful creation (HTTP 201), extract and display:
- **GHSA ID** - The GitHub Security Advisory identifier (e.g., `GHSA-xxxx-xxxx-xxxx`)
- **URL** - The advisory URL from the response
- **State** - Will be `triage` (the maintainers need to review it)

Tell the user:
- The vulnerability has been **privately reported** to the repository maintainers
- The advisory is in **triage** state — maintainers will review and respond
- The user will receive GitHub notifications about updates to the advisory
- The user is automatically credited as the reporter
- Do NOT disclose the vulnerability publicly until the maintainers have had a chance to address it (responsible disclosure)

### 9. Handle Errors

If the API call fails:
- **403 Forbidden** - Private vulnerability reporting is not enabled for this repository. Suggest the user:
  1. Check if the repository has a `SECURITY.md` file with alternative reporting instructions: `gh api repos/<OWNER>/<REPO>/contents/SECURITY.md --jq '.download_url'`
  2. Look for a security policy or contact email in the repository
  3. Contact the maintainers directly through other channels
- **404 Not Found** - The repository may not exist, or the endpoint is not available. Same fallback as 403.
- **422 Unprocessable Entity** - A field is invalid. Display the error message from the API response and help the user correct it.
- **Any other error** - Display the full error response.

### 10. Constraints

You MUST:
- Confirm all details with the user before submitting the report
- Validate the severity is one of the accepted values (`critical`, `high`, `medium`, `low`)
- Validate the ecosystem is one of the accepted values
- Format the description using the structured Markdown template
- Use the `/reports` endpoint (private vulnerability reporting), NOT the admin advisory creation endpoint
- Remind the user about responsible disclosure practices
- Provide fallback guidance if the feature is not enabled on the repository

You MUST NOT:
- Submit a report without user confirmation
- Use the admin endpoint (`POST /repos/{owner}/{repo}/security-advisories`) — that requires admin access
- Encourage public disclosure before maintainers have responded
- Provide inaccurate CWE suggestions (only suggest CWEs you are confident about)
- Include personally identifiable information beyond the user's GitHub username
- Send malformed JSON to the API

### 11. Acceptance Criteria

- A private vulnerability report is submitted to the repository via the GitHub API
- The report has a well-structured description, appropriate severity, and correct package information
- The user is provided with the GHSA ID and advisory URL
- The user is informed about the triage state and responsible disclosure expectations
- If private vulnerability reporting is not enabled, the user receives actionable fallback guidance (SECURITY.md, maintainer contact)
