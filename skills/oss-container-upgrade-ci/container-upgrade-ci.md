---
name: container-upgrade-ci
description: >
  Container upgrade CI orchestrator. Discovers open container-image PRs
  without CI coverage and triggers /component-test for the affected components.
user-invocable: true
---

# Container Upgrade CI Loop

Automated loop that finds container-image upgrade PRs lacking CI test coverage
and triggers targeted component tests. Lightweight -- no sub-agents, no worktrees,
no code changes. Just discovery and CI triggering.

## Background

Container image upgrades are created weekly by the `check-container-versions.yml`
GitHub Actions workflow. These PRs change `container.properties` files under
`test-infra/` and are authored by `github-actions[bot]`. The `pull_request`-triggered
CI runs are blocked (`action_required`) because GitHub requires approval for
bot-authored PRs. The `/component-test` command bypasses this by dispatching
a `workflow_dispatch` run under the commenting user's identity.

## Execution Steps

### 0. Pre-flight

Detect the project and load config:

```bash
# Detect upstream repo
UPSTREAM_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
if [[ -z "$UPSTREAM_REPO" ]]; then
  UPSTREAM_REPO=$(git remote get-url upstream 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')
fi
echo "Upstream: $UPSTREAM_REPO"

# Detect operator
OPERATOR_NAME=$(gh api /user --template '{{.login}}' 2>/dev/null || echo "unknown")
echo "Operator: $OPERATOR_NAME"
```

Read project config if available:
- `.oss-ai-helper-rules/project-info.md` -- for repo name validation
- `.oss-ai-helper-rules/project-standards.md` -- for build commands (informational)

### 1. Discover Container Upgrade PRs

Find all open PRs with the `container-images` label:

```bash
gh pr list --repo "$UPSTREAM_REPO" --state open --label "container-images" \
  --json number,title,headRefName,author,createdAt \
  --template '{{range .}}{{.number}}|{{.title}}|{{.headRefName}}|{{.author.login}}{{"\n"}}{{end}}'
```

If no PRs found, output a brief summary and exit:
```
No open container-image PRs found. Nothing to do.
```

### 2. Check CI Status for Each PR

For each PR, check whether CI has already run successfully:

```bash
# Check for a successful "Build and test" workflow run on the PR branch
gh run list --repo "$UPSTREAM_REPO" \
  --branch "$HEAD_REF" \
  --workflow="pr-build-main.yml" \
  --limit 1 \
  --json status,conclusion \
  --template '{{range .}}{{.status}}/{{.conclusion}}{{end}}'
```

Classify each PR:

| CI Status | Action |
|-----------|--------|
| `completed/success` | Skip -- CI already passed |
| `completed/failure` | Skip -- CI ran but failed (needs human attention) |
| `in_progress/` | Skip -- CI is running |
| `completed/action_required` | **Needs trigger** -- bot PR was blocked |
| No runs found | **Needs trigger** -- CI never ran |

### 3. Map Test-Infra Module to Component(s)

For each PR that needs a CI trigger, extract the test-infra module from the
PR title and find consuming components:

```bash
# Extract test-infra module name from title pattern:
#   "chore(camel-test-infra-kafka): upgrade ..."
INFRA_MODULE=$(echo "$TITLE" | sed -n 's/chore(\(camel-test-infra-[^)]*\)).*/\1/p')

# Find components that depend on this test-infra module
COMPONENTS=$(grep -rl "$INFRA_MODULE" components/ --include=pom.xml 2>/dev/null \
  | sed 's|/pom.xml||' | sed 's|^components/||' | sort -u | tr '\n' ' ')
```

### 4. Trigger /component-test

For each PR with identified components:

1. **Check if we already posted a `/component-test` comment** on this PR
   (to avoid duplicates):

   ```bash
   gh api "repos/$UPSTREAM_REPO/issues/$PR_NUMBER/comments" --paginate \
     --template '{{range .}}{{.body}}{{"\n"}}{{end}}' \
     | grep -c "/component-test" || echo "0"
   ```

2. **If no prior `/component-test` comment**, post one:

   ```bash
   # Build the component list for /component-test
   # The command expects component names (e.g., "camel-kafka" not full paths)
   # For nested components (camel-aws/camel-aws2-s3), use the leaf module name
   COMPONENT_NAMES=$(echo "$COMPONENTS" | tr ' ' '\n' | xargs -I{} basename {} | tr '\n' ' ')

   gh pr comment "$PR_NUMBER" --repo "$UPSTREAM_REPO" \
     --body "/component-test $COMPONENT_NAMES"
   ```

3. **If the test-infra module has no component consumers** (e.g., observability,
   jaeger, clickhouse), post an informational comment instead:

   ```bash
   gh pr comment "$PR_NUMBER" --repo "$UPSTREAM_REPO" \
     --body "$(cat <<'EOF'
   > **Container Upgrade CI**: This test-infra module (`$INFRA_MODULE`) has no
   > direct component consumers in `components/`. CI coverage is limited to the
   > compilation check from the regular PR build. Manual verification may be needed.
   >
   > _Automated by container-upgrade-ci loop on behalf of @$OPERATOR_NAME_
   EOF
   )"
   ```

### 5. Handle Special Cases

#### Ollama PRs (tests disabled on CI)

If the test-infra module is `camel-test-infra-ollama`, the component tests
(langchain4j-*, openai, spring-ai-*) are disabled on CI via
`@DisabledIfSystemProperty(named = "ci.env.name")` because they download
3-5GB AI models. Post `/component-test` anyway (it still runs non-disabled
tests like compilation and unit tests), but add a note:

```bash
gh pr comment "$PR_NUMBER" --repo "$UPSTREAM_REPO" \
  --body "$(cat <<EOF
/component-test camel-langchain4j-chat

> **Note**: Most integration tests for Ollama-based components are disabled
> on CI due to large model downloads (~3-5GB). This will verify compilation
> and non-container tests. Full integration testing requires a local environment
> with cached models.
>
> _Automated by container-upgrade-ci loop on behalf of @$OPERATOR_NAME_
EOF
)"
```

#### AWS PRs (many components)

If the test-infra module is `camel-test-infra-aws-v2`, it fans out to 30+
components. Pick a representative subset to avoid overwhelming CI:

```bash
# Test a representative sample: S3, SQS, DDB, Lambda (most used)
gh pr comment "$PR_NUMBER" --repo "$UPSTREAM_REPO" \
  --body "/component-test camel-aws2-s3 camel-aws2-sqs camel-aws2-ddb camel-aws2-lambda"
```

### 6. Summary

Output a summary of actions taken:

```
## Container Upgrade CI Summary

- Open container-image PRs: <N>
- Already have CI: <M> (skipped)
- CI triggered: <T> PRs
  - <PR#>: /component-test <components>
  - ...
- No component consumers: <C> PRs (informational comment posted)
- Ollama (limited CI): <O> PRs
```

## Invocation

### One-shot
```
/oss-container-upgrade-ci
```

### As a recurring loop (recommended: weekly, after Monday container-check workflow)
```
/loop 1d --script "gh pr list --repo apache/camel --state open --label container-images --json number | python3 -c 'import sys,json; d=json.load(sys.stdin); exit(0 if d else 1)'" /oss-container-upgrade-ci
```

The precondition script exits 0 (fire) only when there are open container-image PRs.

## Constraints

You MUST:
- Check for existing `/component-test` comments before posting (avoid duplicates)
- Include AI attribution in all comments (`on behalf of @$OPERATOR_NAME`)
- Handle the no-consumers case gracefully (informational comment)
- Handle the Ollama case (note about disabled tests)
- Handle the AWS fan-out case (representative subset)
- Report what you did in the summary

You MUST NOT:
- Merge, close, approve, or label any PR
- Push to any branch
- Modify any code
- Post more than one `/component-test` comment per PR per loop invocation
- Post `/component-test` if one already exists AND the PR branch hasn't been
  updated since the last comment (check commit dates vs comment dates)
