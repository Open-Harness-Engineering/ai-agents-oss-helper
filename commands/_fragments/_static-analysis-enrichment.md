# Static Analysis Enrichment Fragment

**DO NOT INVOKE THIS FRAGMENT DIRECTLY.** This fragment is referenced by review commands that want to enrich their evaluation with findings from static analysis tools run against the PR's modified files.

## Purpose

This fragment provides a lightweight, fast-path static analysis pass that:

- Detects which static analysis tools are available in the current environment
- Runs them against **only the files modified by the PR** (or the affected module for tools that cannot scope to individual files)
- Normalizes findings into a common structure
- Annotates each finding with whether it was **introduced by the PR** or is **pre-existing**
- Provides the normalized findings as additional context for the review evaluation

This is **not** a full security audit (use `/oss-security-scan` for that) and does **not** replace CI-integrated static analysis. It catches what it can with the tools at hand, and is transparent about coverage gaps.

## Time Budget

Spend no more than **30 seconds total** on scanner detection and execution. If a tool exceeds its time budget, kill it and note the timeout. The review must not be blocked by slow scanners.

## Instructions

### Step 1: Identify Modified Files and Ecosystem

From the PR diff already fetched, extract:

- The list of modified file paths
- The primary language(s) from file extensions
- For Maven projects: the affected module(s) by mapping file paths to module directories

```bash
# Extract modified file paths from PR metadata
gh pr view <PR_NUMBER> --repo <GITHUB_REPO> --json files --jq '.files[].path' > /tmp/pr-modified-files.txt

# Identify languages present
# .java → Java, .py → Python, .js/.ts/.tsx → JS/TS, .go → Go,
# .rb → Ruby, .sh → Shell, .kt → Kotlin, Dockerfile → Docker
```

### Step 2: Detect Available Scanners

Check which tools are installed using `command -v`. **Never install tools** -- only use what is already available. Check tools in this order, stopping at the first match per ecosystem:

#### Multi-Language (Always Check)

```bash
command -v semgrep    # Multi-language SAST
command -v gitleaks   # Secret detection (all languages)
```

#### AST-based Structural Analysis (Always Check)

```bash
command -v sg    # ast-grep — structural code pattern matching
```

If available, also check for rules:
```bash
# Check for project-local rules first, then oss-helper rules
for dir in ./.ast-grep-rules ./rules/java ~/.oss-helper/rules/java; do
  [[ -d "$dir" ]] && AST_GREP_RULES="$dir" && break
done
```

#### Java (Primary — Check All, Use Best Available)

For Java files, the fragment uses a **tiered detection strategy**. Most Java projects use Maven plugins rather than standalone CLIs, so Maven-based execution is the primary fallback:

**Tier 1 — Standalone CLI (preferred, file-scoped):**

```bash
command -v pmd          # PMD standalone CLI — best option: file-scoped, JSON output
# Also check for Checkstyle standalone JAR:
ls checkstyle*-all.jar /usr/local/lib/checkstyle*-all.jar 2>/dev/null
```

**Tier 2 — Maven plugin execution (fallback, module-scoped):**

If no standalone CLI is found, check whether the project has analysis plugins configured or custom rulesets available:

```bash
# Check for project-specific PMD ruleset
find . -name "*pmd*ruleset*.xml" -not -path "*/target/*" 2>/dev/null | head -1

# Check for project-specific Checkstyle config
find . -name "checkstyle*.xml" -not -path "*/target/*" 2>/dev/null | head -1

# Check if Maven is available (should always be true for Maven projects)
command -v mvn
```

#### Other Languages (Check If Files of That Language Are Modified)

```bash
# Python
command -v ruff         # Linting (replaces flake8/pylint)
command -v bandit       # Security

# JavaScript / TypeScript
command -v eslint       # Linting (needs project config)

# Go
command -v golangci-lint  # Meta-linter with --new-from-rev (best)
command -v staticcheck    # Standalone linter (fallback)
# go vet is always available with Go

# Shell
command -v shellcheck   # Shell script analysis

# Ruby
command -v rubocop      # Style and lint

# Kotlin
command -v detekt-cli   # Code analysis (use light mode)
command -v ktlint       # Style and formatting

# Dockerfile (only if PR touches Dockerfiles)
command -v hadolint     # Dockerfile linting

# C/C++ (only if no compilation database is required)
command -v cppcheck     # Static analysis (works without build)

# PHP
command -v phpstan      # Static analysis (needs project autoloader)
```

Record which scanners were detected, which were skipped (not installed), and which were not applicable (no files of that language modified). This information is included in the review output.

### Step 3: Run Scanners

Run each detected scanner against the modified files. Execute scanners **in parallel** where possible to stay within the 30-second budget.

#### Multi-Language Tools

**semgrep** (if available):

```bash
semgrep scan \
  --config auto \
  --json \
  --disable-version-check \
  --timeout 10 \
  --max-target-bytes 1000000 \
  $(cat /tmp/pr-modified-files.txt | tr '\n' ' ') \
  > /tmp/semgrep-results.json 2>/dev/null
```

Note: `--config auto` fetches rules from the Semgrep Registry (requires network, ~2–5s). The `--metrics=off` flag is **incompatible** with `--config auto` — do not combine them. If a local `.semgrep.yml` or `.semgrep/` directory exists in the project, prefer `--config .semgrep.yml` instead (which does work with `--metrics=off`).

**gitleaks** (if available):

```bash
# Copy modified files to a temp directory for single-invocation scan
mkdir -p /tmp/gitleaks-scan
while read f; do
  mkdir -p "/tmp/gitleaks-scan/$(dirname "$f")"
  cp "$f" "/tmp/gitleaks-scan/$f" 2>/dev/null
done < /tmp/pr-modified-files.txt

gitleaks detect \
  --no-git \
  -s /tmp/gitleaks-scan \
  --report-format json \
  --report-path /tmp/gitleaks-results.json \
  --no-banner 2>/dev/null

rm -rf /tmp/gitleaks-scan
```

#### AST-based Analysis

**ast-grep** (if available and rules found):

```bash
if [[ -n "${AST_GREP_RULES:-}" ]]; then
  sg scan --rule "$AST_GREP_RULES" --json \
    $(cat /tmp/pr-modified-files.txt | tr '\n' ' ') \
    > /tmp/ast-grep-results.json 2>/dev/null
fi
```

Note: ast-grep rules are structural pattern matches, not heuristic analysis. Findings from ast-grep are high-confidence for the patterns they cover (security vulnerabilities, code quality antipatterns). However, coverage is limited to the rules available.

#### Java Tools

**PMD standalone CLI** (if available — Tier 1):

```bash
# Use the project's own ruleset if found, otherwise use quickstart
RULESET=$(find . -name "*pmd*ruleset*.xml" -not -path "*/target/*" 2>/dev/null | head -1)
RULESET=${RULESET:-rulesets/java/quickstart.xml}

# Filter to only Java files
grep '\.java$' /tmp/pr-modified-files.txt > /tmp/pr-java-files.txt

pmd check \
  --file-list /tmp/pr-java-files.txt \
  -R "$RULESET" \
  -f json \
  --no-progress \
  > /tmp/pmd-results.json 2>/dev/null
```

**Checkstyle standalone** (if available — Tier 1):

```bash
# Use the project's config if found, otherwise use google_checks
CONFIG=$(find . -name "checkstyle*.xml" -not -path "*/target/*" 2>/dev/null | head -1)
CONFIG=${CONFIG:-/google_checks.xml}

java -jar <checkstyle-all.jar> \
  -c "$CONFIG" \
  -f sarif \
  $(grep '\.java$' /tmp/pr-modified-files.txt | tr '\n' ' ') \
  > /tmp/checkstyle-results.json 2>/dev/null
```

**Maven PMD plugin** (fallback — Tier 2, if no standalone CLI found):

```bash
# Determine affected modules from changed file paths
# e.g., components/camel-http/src/... → components/camel-http
MODULES=$(grep '\.java$' /tmp/pr-modified-files.txt \
  | sed 's|/src/.*||' \
  | sort -u \
  | paste -sd',' -)

# Locate the project's PMD ruleset
RULESET=$(find . -name "*pmd*ruleset*.xml" -not -path "*/target/*" 2>/dev/null | head -1)

if [ -n "$RULESET" ]; then
  mvn org.apache.maven.plugins:maven-pmd-plugin:3.26.0:pmd \
    -pl "$MODULES" \
    -Dpmd.rulesetfiles="$(pwd)/$RULESET" \
    -Dformat=xml \
    -q 2>/dev/null
  # Results are in each module's target/pmd.xml
else
  mvn org.apache.maven.plugins:maven-pmd-plugin:3.26.0:pmd \
    -pl "$MODULES" \
    -Dformat=xml \
    -q 2>/dev/null
fi
```

**Maven Checkstyle plugin** (fallback — Tier 2, if no standalone CLI found):

```bash
CONFIG=$(find . -name "checkstyle*.xml" -not -path "*/target/*" 2>/dev/null | head -1)

if [ -n "$CONFIG" ]; then
  mvn org.apache.maven.plugins:maven-checkstyle-plugin:3.6.0:check \
    -pl "$MODULES" \
    -Dcheckstyle.config.location="$(pwd)/$CONFIG" \
    -Dcheckstyle.consoleOutput=true \
    -fn -q 2>/dev/null
fi
```

Note: Maven plugin execution adds ~10-15s overhead (JVM startup + plugin resolution). On first run the plugin itself may be downloaded (~5s, cached afterward). Use `-fn` (fail-never) to collect all findings without stopping on the first violation. Limit to **at most 3 modules** to stay within the time budget; if more modules are affected, pick the 3 with the most changed files and note the rest were skipped.

#### Python Tools

**ruff** (if available):

```bash
grep -E '\.py$' /tmp/pr-modified-files.txt | xargs ruff check \
  --output-format json \
  > /tmp/ruff-results.json 2>/dev/null
```

**bandit** (if available):

```bash
grep -E '\.py$' /tmp/pr-modified-files.txt | xargs bandit \
  -f json \
  > /tmp/bandit-results.json 2>/dev/null
```

#### JavaScript / TypeScript Tools

**eslint** (if available):

```bash
grep -E '\.(js|jsx|ts|tsx|mjs|cjs)$' /tmp/pr-modified-files.txt | xargs eslint \
  -f json \
  > /tmp/eslint-results.json 2>/dev/null
```

Note: ESLint needs the project's configuration (`eslint.config.*` or `.eslintrc.*`) to produce meaningful results. If no config is found in the project, skip ESLint and note that it was skipped due to missing configuration.

#### Go Tools

**golangci-lint** (if available — preferred):

```bash
# Use --new-from-rev to scope to changes since the PR's merge base
MERGE_BASE=$(git merge-base HEAD <base-branch>)
golangci-lint run \
  --new-from-rev="$MERGE_BASE" \
  --out-format json \
  > /tmp/golangci-results.json 2>/dev/null
```

**staticcheck** (fallback):

```bash
# Map changed Go files to packages
PACKAGES=$(grep '\.go$' /tmp/pr-modified-files.txt \
  | xargs -I{} dirname {} \
  | sort -u \
  | sed 's|^|./|')
staticcheck -f json $PACKAGES > /tmp/staticcheck-results.json 2>/dev/null
```

**go vet** (always available with Go):

```bash
go vet $PACKAGES 2> /tmp/govet-results.txt
```

#### Shell Tools

**shellcheck** (if available):

```bash
grep -E '\.(sh|bash|zsh|ksh)$' /tmp/pr-modified-files.txt | xargs shellcheck \
  -f json1 \
  > /tmp/shellcheck-results.json 2>/dev/null
```

#### Ruby Tools

**rubocop** (if available):

```bash
grep -E '\.rb$' /tmp/pr-modified-files.txt | xargs rubocop \
  -f json \
  > /tmp/rubocop-results.json 2>/dev/null
```

#### Kotlin Tools

**detekt** (if available, light mode):

```bash
KOTLIN_FILES=$(grep -E '\.kt$' /tmp/pr-modified-files.txt | paste -sd':' -)
detekt-cli \
  -i "$KOTLIN_FILES" \
  --report sarif:/tmp/detekt-results.sarif \
  2>/dev/null
```

**ktlint** (if available):

```bash
grep -E '\.kt$' /tmp/pr-modified-files.txt | xargs ktlint \
  --reporter=json \
  > /tmp/ktlint-results.json 2>/dev/null
```

#### Dockerfile Tools

**hadolint** (if Dockerfiles are modified):

```bash
grep -iE '(Dockerfile|\.dockerfile)' /tmp/pr-modified-files.txt | xargs hadolint \
  --format json \
  > /tmp/hadolint-results.json 2>/dev/null
```

#### C/C++ Tools

**cppcheck** (if available):

```bash
grep -E '\.(c|cpp|cc|cxx|h|hpp|hxx)$' /tmp/pr-modified-files.txt | xargs cppcheck \
  --xml --xml-version=2 \
  2> /tmp/cppcheck-results.xml
```

### Step 4: Normalize Findings

Parse each scanner's output into a common structure. For each finding, extract:

| Field | Description |
|-------|-------------|
| `scanner` | Tool name (e.g., `pmd`, `semgrep`, `eslint`) |
| `file` | File path relative to repo root |
| `line` | Line number |
| `rule` | Rule ID (e.g., `java:S1192`, `no-unused-vars`, `SC2086`) |
| `severity` | Normalized: `error`, `warning`, `info` |
| `message` | Human-readable description |

**Scanner-specific parsing notes:**

**ast-grep:** JSON output has `{matches: [{ruleId, message, severity, labels: [{source, start, end}]}]}`. Map:
- `scanner`: `ast-grep`
- `file`: from `labels[0].source`
- `line`: from `labels[0].start.line`
- `rule`: `ruleId`
- `severity`: map `severity` field
- `message`: `message` field

**Severity normalization:**

| Scanner term | Normalized |
|-------------|------------|
| `error`, `critical`, `high`, `blocker` | `error` |
| `warning`, `medium`, `major`, `codesmell` | `warning` |
| `info`, `low`, `minor`, `style`, `convention` | `info` |

### Step 5: Annotate with Diff Context

For each normalized finding, determine whether the flagged line is **new in this PR** or **pre-existing**:

1. Parse the PR diff to identify which lines are additions (lines starting with `+` in the diff, excluding the `+++` header)
2. For each finding, check whether its `file:line` falls within an added or modified range
3. Tag each finding:
   - **`introduced`** — the line was added or modified by this PR. Higher priority.
   - **`pre-existing`** — the line was already present before this PR. Lower priority; mention only if directly relevant to the change's context (e.g., the PR modifies a method that already has a pre-existing issue).

### Step 6: Produce Scanner Summary

Format the results as a structured summary to feed into the review evaluation. This summary is **not** presented to the user directly — it is context for the reviewer.

```markdown
## Static Analysis Results

### Coverage
- **Scanners run:** semgrep (auto config), PMD (via Maven, project ruleset)
- **Scanners skipped:** Checkstyle (not installed), ESLint (no Java files)
- **Scanners not applicable:** shellcheck (no .sh files modified)
- **Time spent:** 18s

### Findings (introduced by this PR)
| Scanner | File | Line | Rule | Severity | Message |
|---------|------|------|------|----------|---------|
| pmd | src/main/.../Handler.java | 42 | UnusedLocalVariable | warning | Variable 'tmp' is declared but never used |
| semgrep | src/main/.../Query.java | 78 | java.lang.security.audit.tainted-sql | error | User input in SQL query |

### Findings (pre-existing, context only)
| Scanner | File | Line | Rule | Severity | Message |
|---------|------|------|------|----------|---------|
| pmd | src/main/.../Handler.java | 15 | CyclomaticComplexity | warning | Method has cyclomatic complexity of 12 |

### Coverage Gaps
- No SpotBugs or ErrorProne analysis (require compilation; use CI results for bytecode-level analysis)
- semgrep community rules only (cross-file taint analysis requires semgrep Pro)
```

## How the Reviewer Uses These Results

The review evaluation step (step 5 of `/oss-review-pr`) incorporates scanner findings as follows:

1. **Correlate** — check whether a scanner finding aligns with something the reviewer already noticed from reading the diff. A scanner finding that confirms a reviewer concern elevates its confidence.
2. **Suppress** — discard scanner findings that contradict project rules. For example, if `project-standards.md` explicitly allows a pattern that a scanner flags, note it was suppressed and why.
3. **Elevate** — if a scanner flags one instance of a problem and the reviewer sees the same pattern repeated elsewhere in the diff, call out the broader pattern.
4. **Attribute** — when citing a scanner finding in the review, clearly state which tool produced it (e.g., "PMD flags `UnusedLocalVariable` on line 42"). Do not present tool findings as the reviewer's own reasoning.
5. **Prioritize introduced over pre-existing** — findings on lines added by the PR are actionable. Pre-existing findings are mentioned only as context (e.g., "this method already has high complexity; this PR increases it further").
6. **State coverage honestly** — the review must note which tools ran, which were unavailable, and what categories of issues are therefore not covered.

## Scanner Reference

### Supported Tools

| Tool | Ecosystem | Output Format | Scoping | Notes |
|------|-----------|---------------|---------|-------|
| semgrep | Multi-language | JSON | File-scoped | `--config auto` fetches rules from registry |
| gitleaks | Multi-language | JSON | File-scoped | Secret detection |
| ast-grep | Multi-language | JSON | File-scoped | Structural pattern matching via custom rules; high-confidence findings limited to available rule coverage |
| PMD | Java | JSON / XML | File-scoped (CLI) or module-scoped (Maven) | Standalone CLI preferred |
| Checkstyle | Java | SARIF | File-scoped (CLI) or module-scoped (Maven) | Standalone JAR preferred |
| ruff | Python | JSON | File-scoped | Replaces flake8/pylint |
| bandit | Python | JSON | File-scoped | Security-focused |
| eslint | JavaScript/TypeScript | JSON | File-scoped | Requires project config |
| golangci-lint | Go | JSON | `--new-from-rev` | Meta-linter, preferred |
| staticcheck | Go | JSON | Package-scoped | Fallback |
| shellcheck | Shell | JSON | File-scoped | — |
| rubocop | Ruby | JSON | File-scoped | — |
| detekt | Kotlin | SARIF | File-scoped | Light mode |
| ktlint | Kotlin | JSON | File-scoped | Style/formatting |
| hadolint | Dockerfile | JSON | File-scoped | — |
| cppcheck | C/C++ | XML | File-scoped | Works without build |

### Tools That Cannot Work in This Model

The following tools were evaluated and **cannot** be used in this fragment because they require compilation, a full project scan, or are too slow:

| Tool | Ecosystem | Reason |
|------|-----------|--------|
| SpotBugs | Java | Requires compiled bytecode |
| ErrorProne | Java | Runs during compilation (IS the compiler plugin) |
| CodeQL | Any | Requires building a database (minutes, ~800MB) |
| mypy | Python | Needs full project type context, often >30s |
| tsc --noEmit | TypeScript | Cannot scope to individual files |
| cargo clippy | Rust | Requires compilation, crate-scoped |
| brakeman | Ruby | Whole-project only |
| scalafix | Scala | Semantic rules require SemanticDB (compilation artifact) |
| clang-tidy | C/C++ | Effectively requires compile_commands.json |
| trivy | Any | SCA/dependency scanner, not source code analysis |

For these tools, the review should note the gap and direct the reader to CI results.

## Error Handling

### Scanner Failures

- If a scanner fails (non-zero exit code that is not "findings found"), note the failure and continue with other scanners. Do not let one scanner failure block the review.
- If a scanner times out (exceeds its share of the 30s budget), kill it and note the timeout.
- If no scanners are available at all, note this fact and proceed with the rules-only review. This is the pre-existing behavior and is perfectly valid.

### Maven Plugin Failures

- If Maven plugin execution fails due to missing plugin or network issues, skip it and note the failure.
- Use `-fn` (fail-never) to prevent Maven from stopping at the first violation.
- If Maven startup alone exceeds 15s, skip the Maven-based analysis and note the timeout.

### Empty Results

- If all scanners run successfully but produce zero findings, state this explicitly: "Static analysis produced no findings on the modified files."
- This is a positive signal but should be presented with appropriate caveats about coverage gaps.

## Version

1.0.0
