### Agent Delegation

If a **qa-test-strategist**, **QE**, **QA**, or **tester** agent is available, delegate plan execution to it. The specialized agent should receive:

- The project context (project-info, project-standards, project-guidelines)
- The full test plan content
- Any user guidance (phases to run/skip, overrides)
- The results table format requirement (step 7)

**MUST NOT** delegate to coding agents (backend-specialist, frontend-specialist, java-test-engineer, etc.) unless the user explicitly instructs otherwise.

If no QE/QA agent is available, the main agent executes the plan directly.

### 1. Parse Input

Extract from the arguments:
- **Test plan identifier** — either a short name (e.g., `operator-basic-tests`) or a file path
- **Guidance** — optional: which phases to run/skip, environment overrides, specific focus areas

### 2. Locate Test Plan

If the input is a file path, read it directly. Otherwise, search by name in this order:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

ls "${REPO_ROOT}/tests/plans/<name>.md" 2>/dev/null
ls "${REPO_ROOT}/test-plans/<name>.md" 2>/dev/null
ls "${REPO_ROOT}/.oss-ai-helper-rules/test-plans/<name>.md" 2>/dev/null
```

If no plan is found, ask the user to provide the path or run the QE Create Test Plan guideline (`oss-qe-create-test-plan.md`) first.

### 3. Load and Present the Plan

Read the full plan. Present a summary to the user before execution:

```markdown
## Test Plan: <title>

- **Phases:** <count>
- **Test cases:** <count>
- **Prerequisites:** <tool list>
- **Environment variables required:** <list>
- **Scope:** <what this plan covers>
```

If the user provided guidance to skip or focus on specific phases, confirm the adjusted scope. Wait for user confirmation before proceeding to execution.

### 4. Verify Prerequisites

Run the prerequisite check from the plan:

- **Tools** — verify each required tool is installed using the plan's verify commands
- **Environment variables** — check that required variables are set (or have defaults)
- **Connectivity** — if the plan requires external access (cluster, API, service), verify connectivity

Report missing prerequisites clearly before starting. If critical prerequisites are missing, stop and present what needs to be resolved.

### 5. Execute Phases Sequentially

Work through the plan phase by phase, test by test:

For each test step:

1. **Run the command(s)** from the plan
2. **Evaluate the assertion** — check the expected outcome against the actual result
3. **Record the result:**
   - **PASS** — assertion met, expected outcome observed
   - **FAIL** — assertion not met, unexpected outcome. Capture: actual output, error messages, logs
   - **SKIP** — test skipped per user guidance or because a prerequisite for this specific test is not met (not a plan-wide prerequisite failure)
   - **BLOCKED** — a prior failure prevents this test from running
4. **On FAIL:** collect evidence — error output, relevant logs, observed vs expected behavior. Continue to the next test unless the failure blocks subsequent tests.
5. **On BLOCKED:** if a failure prevents the rest of a phase (or the entire plan) from continuing, stop execution and proceed directly to step 7 (results table). Present findings so far.

**Progress updates:** provide brief updates between phases — phase name, pass/fail count so far.

### 6. Bug Collection

For each FAIL result, record:

- **Test ID** — the phase and test number (e.g., `3.2`)
- **Test name** — the test description from the plan
- **Observed behavior** — what actually happened
- **Expected behavior** — what the plan expected
- **Evidence** — error output, log snippets, HTTP status codes, command output
- **Severity** — Critical (blocks other tests or core functionality), High (significant but non-blocking), Medium (minor functional issue), Low (cosmetic or edge case)

### 7. Produce Results Table (MANDATORY)

**This step is NOT optional.** A results table MUST ALWAYS be presented after execution — whether the run completed fully, was partially executed, or terminated early due to a blocking failure.

#### Results Format

```markdown
> :robot: **Note:** This verification was executed by a coding agent. Results should be reviewed by a human before acting on them. Test assertions are mechanical checks — they may miss context that a human would catch.

## Verification Results — <test plan name>

### Summary

| Metric | Count |
|--------|-------|
| Total tests | <n> |
| Passed | <n> |
| Failed | <n> |
| Skipped | <n> |
| Blocked | <n> |

### Overall Verdict: <PASS / PARTIAL PASS / FAIL>

<!-- PASS: all tests passed -->
<!-- PARTIAL PASS: some tests failed but core functionality works -->
<!-- FAIL: critical tests failed or execution was blocked -->

### Detailed Results

| Phase | Test ID | Test Name | Result | Notes |
|-------|---------|-----------|--------|-------|
| 0 | 0.1 | <name> | PASS | |
| 1 | 1.1 | <name> | FAIL | <brief reason> |
| 1 | 1.2 | <name> | BLOCKED | Blocked by 1.1 |
| ... | ... | ... | ... | ... |

### Bugs Found

<!-- Omit this section if no bugs were found -->

| # | Test ID | Severity | Description |
|---|---------|----------|-------------|
| 1 | 1.1 | Critical | <what failed and why> |

#### Bug 1 — <short title>
- **Test:** <test ID> — <test name>
- **Severity:** <Critical/High/Medium/Low>
- **Observed:** <what happened>
- **Expected:** <what should have happened>
- **Evidence:** <error output, logs, commands>

### Open Questions
- <question 1>
```

### 8. Propose Follow-up

Based on the results, offer one or more actions. Do NOT execute any without explicit confirmation.

- **File bugs** — for each FAIL with a confirmed bug, offer to hand off to the Create Issue guideline (`create-issue.md`) with a sanitized description.
- **Fix issues** — for clear, reproducible bugs with an obvious fix path, offer to hand off to the Fix Issue guideline (`fix-issue.md`).
- **Update the plan** — if the plan has stale assertions, missing steps, or needs adjustment, offer to hand off to the QE Create Test Plan guideline (`oss-qe-create-test-plan.md`) for an update.
- **Re-run** — if failures were caused by environment issues (flaky network, timing), offer to re-run the affected phases.

### 9. Constraints

You MUST:
- Delegate to QE/QA/tester agents when available, not coding agents.
- Present the plan summary and get user confirmation before execution.
- Verify prerequisites before starting test execution.
- Record every test as PASS, FAIL, SKIP, or BLOCKED — no unrecorded tests.
- Capture evidence for every FAIL (error output, logs, observed vs expected).
- **ALWAYS present the results table (step 7)** — even on partial runs, early termination, or blocking failures.
- Include the :robot: disclaimer in the results.
- Stop execution if a failure blocks subsequent tests, and present findings so far.

You MUST NOT:

- Delegate execution to coding agents (backend-specialist, frontend-specialist, java-test-engineer, etc.) unless the user explicitly asks.
- Skip the results table under any circumstances.
- Mark a test as PASS when the assertion was not met.
- Continue past a blocking failure without noting BLOCKED on subsequent tests.
- Modify application source code — verification is read-only with respect to the codebase. Fixing is the job of the Fix Issue guideline (`fix-issue.md`).
- Silently drop test results — every test in the executed scope must appear in the results table.
- Leak credentials, tokens, or internal infrastructure details in the results output.

### 10. Acceptance Criteria

- The test plan is located and presented to the user before execution.
- Prerequisites are verified before starting.
- Each test step is executed and recorded with a clear result (PASS/FAIL/SKIP/BLOCKED).
- Evidence is captured for every failure.
- A results table is presented with summary counts, detailed per-test results, and an overall verdict.
- Bugs are listed with severity, observed/expected behavior, and evidence.
- Follow-up actions are proposed with the appropriate downstream guidelines named.
