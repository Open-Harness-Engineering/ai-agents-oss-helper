---
name: minimal-fix
description: >
  Produce the smallest possible code change that fixes a specific, well-scoped
  CI failure. Use only when the fix target is explicit. Never refactor unrelated code.
  Reads build/test commands from project-standards.md.
user-invocable: true
---

# Minimal Fix Skill

You fix **one specific CI failure** with the **smallest diff** that could work.

## Inputs

- Exact failure message and stack trace
- Failing test class and method (if test failure)
- Culprit commit SHA (if identified by triage)
- Module path
- Path denylist (from loop-constraints.md)
- **BUILD_CMD**, **TEST_CMD**, **FORMAT_CMD** (from project-standards.md via init)

## Process

1. **Understand the failure**: Read the error, the failing test, and the code it exercises.
2. **Read the culprit commit**: `git show <sha>` -- understand what changed and why.
3. **Check git history**: `git log --oneline -10 <failing-file>` and `git blame` for context.
4. **Identify the minimal root cause**: Not symptoms in distant files, but the actual bug.
5. **Apply the fix**: Change only what is required. No drive-by refactors.
6. **Format the code**:
   Run `$FORMAT_CMD` scoped to the module. If the project uses Maven:
   ```bash
   cd <module> && mvn formatter:format impsort:sort -B
   ```
   For other build tools, use the format command from project-standards.md.
7. **Run tests**:
   Run `$TEST_CMD` scoped to the module. If the project uses Maven:
   ```bash
   mvn clean install -B -pl <module> -am
   ```
   Or if the specific test is known:
   ```bash
   mvn test -B -pl <module> -Dtest=<TestClass>#<method>
   ```
   For other build tools, use the test command from project-standards.md.
8. **Summarize**: What changed, why, what you ran.

## Output

```markdown
## Minimal Fix Proposal

- **Target:** <CI failure / test name / error>
- **Root cause:** <one-sentence explanation>
- **Files changed:**
  - <path/to/file> -- <what changed>
- **Diff summary:** <1-3 bullets>
- **Tests run:** <command + result>
- **Risk:** low | medium
  - If medium, explain why and recommend human review
```

## Rules

- If fix requires > 5 files -> **stop and escalate**. Report:
  ```
  STATUS: needs-escalation
  REASON: Fix scope exceeds 5 files (<N> files affected). Needs human design decision.
  ```
- If path is on denylist (from loop-constraints.md) -> **stop and escalate**
- If fix would revert a prior intentional commit -> **stop and explain**
  (check with `git log` and linked issue/PR)
- Do NOT disable tests or weaken assertions to go green
- Do NOT add `@Disabled`, `@Ignore`, or `assumeTrue(false)` to make tests pass
- Do NOT mark yourself "done" -- the verifier decides
- Do NOT change unrelated code, even if you notice issues
- Do NOT bump dependency versions without explicit approval
- Always follow the project's code conventions (from .oss-ai-helper-rules/)
- Always use Awaitility instead of Thread.sleep() in test code (Java projects)
