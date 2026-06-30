### Agent Delegation

If a **qa-test-strategist**, **QE**, **QA**, or **tester** agent is available, delegate the plan creation to it. The specialized agent should receive:

- The project context (project-info, project-standards, project-guidelines)
- The test plan name and any additional instructions
- The test plan format reference (step 5)
- Any existing common steps found in step 4

**MUST NOT** delegate to coding agents (backend-specialist, frontend-specialist, java-test-engineer, etc.) unless the user explicitly instructs otherwise. Coding agents optimize for implementation, not test strategy — they produce scripts, not verifiable test plans.

If no QE/QA agent is available, the main agent creates the plan directly.

### 1. Parse Input

Extract from the arguments:
- **Test plan name** — the short identifier (e.g., `operator-basic-tests`). This becomes the filename: `<name>.md`.
- **Additional instructions** — optional scope, environment, or focus guidance from the user.

### 2. Search for Existing Test Plans

Before creating a new plan, check if one already exists. Search in this order:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Search order
ls "${REPO_ROOT}/tests/plans/<name>.md" 2>/dev/null
ls "${REPO_ROOT}/test-plans/<name>.md" 2>/dev/null
ls "${REPO_ROOT}/.oss-ai-helper-rules/test-plans/<name>.md" 2>/dev/null
```

If a plan with this name is found:

- Present it to the user (overview, phase count, test count)
- Ask: **update the existing plan** or **create a fresh one**?
- If updating, read the existing plan fully and modify in place
- If creating fresh, proceed to step 3

### 3. Analyze the Project

Gather information to inform the test plan:

- **Project structure** — modules, entry points, APIs, CRDs, CLI commands, UI pages
- **Build and test tools** — from `project-standards.md` (build command, test command, required tools)
- **Existing tests** — scan for test directories, test frameworks, existing test suites
- **Risk areas** — recent changes (`git log --oneline -20`), complex modules, security-sensitive code
- **Existing documentation** — README, CONTRIBUTING, API docs, architecture docs
- **User instructions** — scope and focus from the additional instructions argument

### 4. Search for Reusable Common Steps

Check if the project already has reusable test procedures:

```bash
ls "${REPO_ROOT}/tests/plans/common/" 2>/dev/null
```

If common steps exist, read them. Reference them in the new plan instead of duplicating their content. If a procedure in the new plan would be useful across multiple plans (e.g., namespace setup, login, cleanup), extract it into a new common doc.

### 5. Generate the Test Plan

Produce a test plan following the format established by the project's existing plans. The plan must be executable by both humans following it step-by-step and AI agents running the commands.

#### Test Plan Structure

The generated plan MUST follow this structure. Use the sample plans in `sample-plans/plans/` (e.g., `operator-basic-functionality.md`, `mcp-cli-commands.md`, `basic-ui-test.md`) as format references.

**Required sections, in order:**

1. **H1 title** — `# Test Plan: <descriptive title>`
2. **Overview** — 1-3 sentences: what this plan tests and why. State whether every step is automatable or if any manual steps exist.
3. **Prerequisites** — three subsections:
   - **Required tools** — a table with columns: Tool, Minimum version, Verify command
   - **Prerequisite check script** — a shell script that checks all tools are installed and prints PASS/FAIL for each
   - **Environment variables** — shell export statements with defaults using `${VAR:-default}` syntax, followed by a table (Variable, Default, Description)
4. **Helper functions** (if needed) — reusable shell functions like `wait_for_deletion`, `get_token`, etc. Reference common docs when they exist.
5. **Phases** — numbered sequentially starting from 0:
   - Phase 0: Setup / prerequisites (login, namespace, dependencies)
   - Phase 1-N: Test scenarios (grouped by feature/area)
   - Final phase: Cleanup (idempotent teardown)
6. **Test Summary Matrix** — a table with columns: Phase, Test ID, Test Name, Priority

#### Format Rules

These rules encode the project's test plan conventions (from the contributing guide):

1. **Phases, not scripts** — organize tests into numbered phases that run sequentially. Each phase groups related assertions. This makes it easy to skip phases, resume after failure, or run a subset.

2. **Every step must be verifiable** — each step needs: a command, an expected outcome, and a PASS/FAIL assertion. Avoid steps that only run a command without checking the result.

3. **Prefer polling over sleeping** — use `oc wait`, `oc rollout status`, health check loops, or polling instead of fixed `sleep` calls. Clusters and environments vary in speed.

4. **Parameterize everything configurable** — images, versions, hosts, IPs, ports, namespaces, branch names, labels go into environment variables with sensible defaults. Never hard-code:
   - Image tags → `export MY_IMAGE="${MY_IMAGE:-quay.io/org/component:latest}"`
   - Cluster URLs → `export CLUSTER_URL="${CLUSTER_URL:-http://localhost:8080}"`
   - Namespaces → `export NAMESPACE="${NAMESPACE:-test-ns}"`

5. **Extract reusable steps** — if a procedure appears in more than one plan (or is likely to), move it to `tests/plans/common/`. Reference it with a link and note which variables must be set before and after.

6. **Keep the main plan lean** — only logic unique to this test scenario belongs in the main plan. Replace duplicated procedures with references to common docs.

7. **Include negative tests** — verify that invalid inputs are rejected gracefully: missing required fields, references to non-existent resources, malformed data.

8. **Cleanup must be idempotent** — use `--ignore-not-found=true` on delete commands and `2>/dev/null || true` on wait commands. A cleanup phase that fails on missing resources makes re-runs painful.

9. **Shell compatibility** — use POSIX-compatible constructs. Avoid bash-only features like `${!VAR}` (indirect expansion). If bash is required, wrap the block in `bash -c '...'`.

10. **End with a test summary matrix** — every plan must include a summary table listing all phases, test IDs, test names, and priorities.

### 6. Credential and Infrastructure Safety

Before writing the plan, verify:

- **No hardcoded credentials** — passwords, tokens, secrets, API keys go into environment variables. Default values must be placeholders (e.g., `<your-token>`) or generic safe defaults (e.g., `admin` for local dev only).
- **No internal infrastructure** — cluster URLs, internal hostnames, IP addresses go into environment variables with generic defaults (e.g., `localhost`, `127.0.0.1`).
- **No leaked paths** — user home directories, organization-specific paths, internal tool locations are parameterized.

### 7. Write the Plan

Save the plan to the appropriate location based on the project's existing structure:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Use existing directory structure if present
if [ -d "${REPO_ROOT}/tests/plans" ]; then
  PLAN_DIR="${REPO_ROOT}/tests/plans"
elif [ -d "${REPO_ROOT}/test-plans" ]; then
  PLAN_DIR="${REPO_ROOT}/test-plans"
else
  PLAN_DIR="${REPO_ROOT}/tests/plans"
  # Create the directory
fi
```

Write `<name>.md` to `PLAN_DIR`. If new common procedures were extracted, write them to `${PLAN_DIR}/common/`.

### 8. Present Summary

After writing the plan, present:

- File path where the plan was saved
- Number of phases and test cases
- Whether any common steps were created or referenced
- Invite the user to review and adjust before executing with the QE Verify guideline (`oss-qe-verify.md`)

### 9. Constraints

You MUST:
- Delegate to QE/QA/tester agents when available, not coding agents.
- Follow the test plan format from step 5 — phases, PASS/FAIL assertions, env vars with defaults, summary matrix.
- Parameterize all infrastructure values (images, hosts, IPs, namespaces, credentials).
- Include a prerequisite check script and a test summary matrix in every plan.
- Include negative tests when testing APIs, CLIs, or CRDs.
- Make cleanup idempotent.
- Search for and reference existing common steps before duplicating procedures.
- Check for existing plans with the same name before creating.

You MUST NOT:

- Delegate plan creation to coding agents (backend-specialist, frontend-specialist, java-test-engineer, etc.) unless the user explicitly asks.
- Hardcode credentials, tokens, internal hostnames, IPs, or organization-specific paths.
- Write test steps without PASS/FAIL verification.
- Use fixed `sleep` calls where polling or wait commands are available.
- Use bash-only constructs without a compatibility wrapper.
- Skip the test summary matrix at the end of the plan.

### 10. Acceptance Criteria

- The plan follows the established format: overview, prerequisites (tool table + check script + env vars), numbered phases, PASS/FAIL assertions on every step, negative tests, idempotent cleanup, test summary matrix.
- All configurable values are environment variables with defaults.
- Common procedures reference shared docs, not inline copies.
- No credentials, internal hostnames, or organization-specific paths are hardcoded.
- The plan is saved to the correct location in the project.
- A summary is presented to the user with phase/test counts and an invitation to review.
