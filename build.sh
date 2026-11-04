#!/usr/bin/env bash
# Assemble local, relocatable OSS Helper artifacts. Never writes user configuration.
set -euo pipefail

AGENTS=("claude" "bob" "gemini" "opencode" "codex" "agy")

# Shared initialization file (copied into each skill directory during install)
SHARED_INIT="skills/_shared/init.md"
# Its script: init.md steps 1-3 in one read-only call (copied next to init.md)
SHARED_INIT_SCRIPT="skills/_shared/oss-init.sh"

# Shared fragments referenced by guidelines as `_fragments/<name>`
# (copied into each skill's _fragments/ directory during install)
SHARED_FRAGMENTS=(
    "commands/_fragments/_build-workflow.md"
    "commands/_fragments/_issue-ownership.md"
    "commands/_fragments/_operator-preferences.md"
    "commands/_fragments/_checkpoint.md"
)

# Skill definitions: "skill-dir|SKILL.md + guideline files..."
# Each skill is a directory under skills/ containing a SKILL.md and guideline files.
SKILL_DIRS=("oss-issues" "oss-review" "oss-ci" "oss-security" "oss-project" "oss-qe")

# Sub-agent definitions (installed for all tools in their native format)
AGENT_FILES=(
    "agents/oss-carbon-frontend-specialist.md"
    "agents/oss-code-reviewer.md"
    "agents/oss-marketing-specialist.md"
    "agents/oss-quarkus-backend-specialist.md"
    "agents/oss-software-architect.md"
    "agents/oss-technical-writer.md"
    "agents/oss-test-engineer-java.md"
    "agents/qa-test-strategist.md"
)

# Claude Code workflows: scripts run by the Workflow tool. They are installed for Claude only,
# into ~/.claude/workflows/; the other agents follow the matching guideline by hand.
WORKFLOW_FILES=(
    "workflows/oss-security-case.js"
)

# Files for each skill (relative paths from repo root).
# Keep this as a Bash 3-compatible lookup instead of an associative array:
# macOS still ships /bin/bash 3.2 on some machines.
SKILL_FILES_RESULT=""
get_skill_files() {
    case "$1" in
        oss-issues)
            SKILL_FILES_RESULT="
                skills/oss-issues/SKILL.md
                skills/oss-issues/fix-issue.md
                skills/oss-issues/analyze-issue.md
                skills/oss-issues/create-issue.md
                skills/oss-issues/list-issues.md
                skills/oss-issues/find-task.md
                skills/oss-issues/fix-backlog-task.md
                skills/oss-issues/oss-triage-issue.md
                skills/oss-issues/oss-create-multi-repo-issue.md
                skills/oss-issues/oss-fix-multi-repo-issue.md
            "
            ;;
        oss-review)
            SKILL_FILES_RESULT="
                skills/oss-review/SKILL.md
                skills/oss-review/review-pr.md
                skills/oss-review/address-review.md
                skills/oss-review/oss-review-prs.md
                skills/oss-review/pr-status.md
                skills/oss-review/list-pr-status.md
                skills/oss-review/list-prs.md
                skills/oss-review/merge-pr.md
                skills/oss-review/backport-pr.md
                skills/oss-review/pr-report.sh
            "
            ;;
        oss-ci)
            SKILL_FILES_RESULT="
                skills/oss-ci/SKILL.md
                skills/oss-ci/fix-ci-errors.md
                skills/oss-ci/fix-sonarcloud.md
                skills/oss-ci/fix-github-alert.md
                skills/oss-ci/quick-fix.md
            "
            ;;
        oss-security)
            SKILL_FILES_RESULT="
                skills/oss-security/SKILL.md
                skills/oss-security/triage-security-report.md
                skills/oss-security/security-case.md
                skills/oss-security/security-case-probe.sh
                skills/oss-security/skip-list.sh
                skills/oss-security/skip_cves_apache_unmappable.txt
                skills/oss-security/analyze-third-party-cve.md
                skills/oss-security/draft-cve.md
                skills/oss-security/create-security-advisory.md
                skills/oss-security/update-gh-advisory-db.md
                skills/oss-security/oss-security-scan.md
            "
            ;;
        oss-project)
            SKILL_FILES_RESULT="
                skills/oss-project/SKILL.md
                skills/oss-project/add-project.md
                skills/oss-project/install-info.md
                skills/oss-project/oss-create-rules.md
                skills/oss-project/update-knowledge.md
                skills/oss-project/oss-workspace-init.md
                skills/oss-project/oss-workspace-status.md
            "
            ;;
        oss-qe)
            SKILL_FILES_RESULT="
                skills/oss-qe/SKILL.md
                skills/oss-qe/oss-qe-create-test-plan.md
                skills/oss-qe/oss-qe-verify.md
                skills/oss-qe/oss-qe-module-audit.md
            "
            ;;
        *)
            SKILL_FILES_RESULT=""
            return 1
            ;;
    esac
}

# Guideline files that become individual commands for all agents.
# Each entry: "skill-dir|guideline-filename|oss-command-name|description"
GUIDELINE_COMMANDS=(
    "oss-issues|fix-issue.md|oss-fix-issue|Fix an issue from the project's issue tracker"
    "oss-issues|analyze-issue.md|oss-analyze-issue|Analyze an issue to understand the problem"
    "oss-issues|create-issue.md|oss-create-issue|Create a new issue in the project's tracker"
    "oss-issues|list-issues.md|oss-list-issues|List issues assigned to you"
    "oss-issues|find-task.md|oss-find-task|Find an issue to contribute to"
    "oss-issues|fix-backlog-task.md|oss-fix-backlog-task|Fix a task from a Backlog.md file"
    "oss-issues|oss-triage-issue.md|oss-triage-issue|Triage a filed issue (maintainer-side)"
    "oss-issues|oss-create-multi-repo-issue.md|oss-create-multi-repo-issue|Create and link issues across multiple repositories"
    "oss-issues|oss-fix-multi-repo-issue.md|oss-fix-multi-repo-issue|Fix an issue spanning multiple repositories"
    "oss-review|review-pr.md|oss-review-pr|Review a pull request"
    "oss-review|address-review.md|oss-address-review|Address review feedback on a pull request"
    "oss-review|oss-review-prs.md|oss-review-prs|Review a batch of open PRs"
    "oss-review|pr-status.md|oss-pr-status|Check CI, review state, and merge readiness of a PR"
    "oss-review|list-pr-status.md|oss-list-pr-status|List all your open PRs with status summary"
    "oss-review|list-prs.md|oss-list-prs|List all open PRs in the repository"
    "oss-review|merge-pr.md|oss-merge-pr|Merge a PR after verifying requirements"
    "oss-review|backport-pr.md|oss-backport-pr|Cherry-pick a merged PR onto another branch"
    "oss-ci|fix-ci-errors.md|oss-fix-ci-errors|Download CI reports, identify errors, and fix them"
    "oss-ci|fix-sonarcloud.md|oss-fix-sonarcloud|Fix SonarCloud issues for a given rule"
    "oss-ci|fix-github-alert.md|oss-fix-github-alert|Fix a GitHub security or quality alert"
    "oss-ci|quick-fix.md|oss-quick-fix|Apply a quick fix without a tracked issue"
    "oss-security|triage-security-report.md|oss-triage-security-report|Triage an inbound security vulnerability report"
    "oss-security|security-case.md|oss-security-case|Drive a security report through triage, reply, CVE, issue, fix, backports and CVE draft"
    "oss-security|analyze-third-party-cve.md|oss-analyze-third-party-cve|Analyze exposure to a third-party CVE"
    "oss-security|draft-cve.md|oss-draft-cve|Draft a CVE advisory page and the matching CVE Record Format JSON"
    "oss-security|create-security-advisory.md|oss-create-security-advisory|Report a security vulnerability via GitHub"
    "oss-security|update-gh-advisory-db.md|oss-update-gh-advisory-db|Populate GitHub Advisory Database entries for the project's published CVEs"
    "oss-security|oss-security-scan.md|oss-security-scan|Scan codebase for security vulnerabilities"
    "oss-project|add-project.md|oss-add-project|Add a new project to the OSS Helper"
    "oss-project|install-info.md|oss-install-info|Install project rules from the known-projects repository"
    "oss-project|oss-create-rules.md|oss-create-rules|Generate project rule files by auto-inspecting a repository"
    "oss-project|update-knowledge.md|oss-update-knowledge|Update project rule files"
    "oss-project|oss-workspace-init.md|oss-workspace-init|Initialize a multi-repo workspace"
    "oss-project|oss-workspace-status.md|oss-workspace-status|Report status of all repos in a workspace"
    "oss-qe|oss-qe-create-test-plan.md|oss-qe-create-test-plan|Create a test plan for a project feature or component"
    "oss-qe|oss-qe-verify.md|oss-qe-verify|Execute an existing test plan and track results"
    "oss-qe|oss-qe-module-audit.md|oss-qe-module-audit|Deep-audit a module family for bugs, antipatterns, inconsistencies, missing features, and ideas"
)

# Report commands that Claude Code runs in a forked context (context: fork): a fresh sub-agent does
# the reads and only its report comes back, so the command neither re-reads the history of the
# session it is started from nor grows it. Their guidelines ask nothing until the end. find-task
# stays inline because it starts by asking the user questions, which a fork cannot do.
FORKED_COMMANDS="oss-list-prs oss-list-pr-status oss-pr-status oss-list-issues oss-analyze-issue oss-workspace-status"
FORK_NOTE='You run in a forked context: a fresh sub-agent that sees none of the conversation that started you, and whose tool calls stay out of it. Your final message is all the user sees, so make it the complete report the guideline describes. You cannot ask questions while you work: where the guideline asks the user to choose or to answer, end the report with that question, and the conversation that started you takes the answer.'

# Claude commands that drive a Claude Code workflow. The workflow's loader resolves the project, its rules and
# its configuration itself, so in workflow mode the command reads the guideline directly instead of running the
# skill's initialization first; manual mode still runs it.
WORKFLOW_COMMANDS="oss-security-case"

# Old rule files to clean up (relative paths under rules/)
OLD_RULE_FILES=(
    "project-info.md"
    "project-standards.md"
    "project-guidelines.md"
)

# Old command files to clean up (basenames only, from previous versions)
OLD_COMMAND_FILES=(
    # Legacy v1 commands
    "camel-fix-sonarcloud.md"
    "camel-core-fix-jira-issue.md"
    "camel-core-find-task.md"
    "camel-core-quick-fix.md"
    "wanaku-analyze-issue.md"
    "wanaku-create-issue.md"
    "wanaku-find-task.md"
    "wanaku-fix-issue.md"
    "wanaku-quick-fix.md"
    "wanaku-capabilities-java-sdk-create-issue.md"
    "wanaku-capabilities-java-sdk-find-task.md"
    "wanaku-capabilities-java-sdk-fix-issue.md"
    "wanaku-capabilities-java-sdk-quick-fix.md"
    "camel-integration-capability-create-issue.md"
    "camel-integration-capability-find-task.md"
    "camel-integration-capability-fix-issue.md"
    "camel-integration-capability-quick-fix.md"
    "ai-agents-oss-helper-create-cmd.md"
    "ai-agents-oss-helper-create-issue.md"
    # v2 commands (migrated to skill in v3)
    ".oss-init.md"
    "oss-add-project.md"
    "oss-address-review.md"
    "oss-analyze-issue.md"
    "oss-analyze-third-party-cve.md"
    "oss-backport-pr.md"
    "oss-create-issue.md"
    "oss-create-security-advisory.md"
    "oss-draft-cve.md"
    "oss-find-task.md"
    "oss-fix-backlog-task.md"
    "oss-fix-ci-errors.md"
    "oss-fix-github-alert.md"
    "oss-fix-issue.md"
    "oss-fix-sonarcloud.md"
    "oss-install-info.md"
    "oss-list-issues.md"
    "oss-list-pr-status.md"
    "oss-list-prs.md"
    "oss-merge-pr.md"
    "oss-pr-status.md"
    "oss-quick-fix.md"
    "oss-review-pr.md"
    "oss-triage-security-report.md"
    "oss-update-knowledge.md"
    "oss-create-rules.md"
    "oss-triage-issue.md"
    "oss-review-prs.md"
    "oss-security-scan.md"
    "oss-workspace-init.md"
    "oss-workspace-status.md"
    "oss-create-multi-repo-issue.md"
    "oss-fix-multi-repo-issue.md"
    "oss-qe-create-test-plan.md"
    "oss-qe-verify.md"
)

# Old skill directories to clean up (from v3 monolithic skill)
OLD_SKILL_DIRS=(
    "oss-helper"
)

# Old Codex individual skill directories to clean up
OLD_CODEX_SKILLS=(
    "oss-helper"
    "oss-add-project"
    "oss-address-review"
    "oss-analyze-issue"
    "oss-analyze-third-party-cve"
    "oss-backport-pr"
    "oss-create-issue"
    "oss-create-security-advisory"
    "oss-draft-cve"
    "oss-find-task"
    "oss-fix-backlog-task"
    "oss-fix-ci-errors"
    "oss-fix-github-alert"
    "oss-fix-issue"
    "oss-fix-sonarcloud"
    "oss-install-info"
    "oss-list-issues"
    "oss-list-pr-status"
    "oss-list-prs"
    "oss-merge-pr"
    "oss-pr-status"
    "oss-quick-fix"
    "oss-review-pr"
    "oss-triage-security-report"
    "oss-update-knowledge"
    "oss-create-rules"
    "oss-triage-issue"
    "oss-review-prs"
    "oss-security-scan"
    "oss-workspace-init"
    "oss-workspace-status"
    "oss-create-multi-repo-issue"
    "oss-fix-multi-repo-issue"
    "oss-qe-create-test-plan"
    "oss-qe-verify"
    "oss-qe-module-audit"
)


SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fetch_file() {
    cp "$SOURCE_ROOT/$1" "$2"
}

# Convert a guideline file to Gemini CLI .toml format
convert_guideline_to_toml() {
    local src="$1"
    local dest="$2"
    local description="$3" skill="${1%/*}"
    skill="${skill##*/}"
    {
        printf 'description = "%s"\n' "$description"
        printf "prompt = '''\n"
        printf 'When the %s skill is available, activate it, follow its init.md, then read and follow %s in that skill directory. Resolve supporting file references relative to that skill directory. Use the inline guideline below only when that skill is unavailable; first detect the current project via git remote and load project-specific rules from ~/.gemini/rules/<project-directory>/ (project-info.md, project-standards.md, project-guidelines.md).\n\n' "$skill" "${src##*/}"
        cat "$src"
        printf "\n'''\n"
    } > "$dest"
}

# Convert a guideline file to OpenCode markdown with frontmatter
convert_guideline_to_opencode_md() {
    local src="$1"
    local dest="$2"
    local description="$3"

    # Escape quotes and backslashes for YAML
    description="$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/\"/\\\"/g')"

    {
        printf -- "---\n"
        printf 'description: "%s"\n' "$description"
        printf -- "---\n\n"
        printf 'Note: This is an OSS Helper guideline. Before following these instructions, detect the current project via git remote and load project-specific rules from ~/.config/opencode/rules/<project-directory>/ (project-info.md, project-standards.md, project-guidelines.md).\n\n'
        cat "$src"
    } > "$dest"
}

# Extract the body of an agent file (everything after the closing --- of frontmatter)
extract_agent_body() {
    local file="$1"
    awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; if(c==2){found=1; next}} found{print}' "$file"
}

# Extract a frontmatter field value (handles quoted and unquoted values)
extract_fm_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        BEGIN{in_fm=0}
        /^---[[:space:]]*$/{in_fm++; next}
        in_fm==1 && $0 ~ "^"field":" {
            sub(/^[^:]+:[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$file"
}

# Convert a Claude/Bob agent file to Gemini CLI format
# Keeps name and description; drops unsupported fields; body unchanged
convert_agent_to_gemini() {
    local src="$1"
    local dest="$2"
    local name description
    name="$(extract_fm_field "$src" "name")"
    description="$(extract_fm_field "$src" "description")"

    {
        printf -- "---\n"
        printf 'name: "%s"\n' "$name"
        printf 'description: "%s"\n' "$description"
        printf -- "---\n"
        extract_agent_body "$src"
    } > "$dest"
}

# Convert a Claude/Bob agent file to OpenCode format
# Keeps description; adds mode: subagent; body unchanged
convert_agent_to_opencode() {
    local src="$1"
    local dest="$2"
    local description
    description="$(extract_fm_field "$src" "description")"

    {
        printf -- "---\n"
        printf 'description: "%s"\n' "$description"
        printf "mode: subagent\n"
        printf -- "---\n"
        extract_agent_body "$src"
    } > "$dest"
}

# Convert a Claude/Bob agent file to Codex TOML format
# Maps name, description, and body → developer_instructions
convert_agent_to_codex_toml() {
    local src="$1"
    local dest="$2"
    local name description body
    name="$(extract_fm_field "$src" "name")"
    description="$(extract_fm_field "$src" "description")"
    body="$(extract_agent_body "$src")"

    # Escape backslashes and single quotes for TOML multi-line literal strings
    {
        printf 'name = "%s"\n' "$name"
        printf 'description = "%s"\n' "$description"
        printf "developer_instructions = '''\n"
        printf '%s\n' "$body"
        printf "'''\n"
    } > "$dest"
}

# Generate a thin command file for skill agents (Claude, Bob, agy).
# Claude has a native skill framework that resolves references automatically;
# Bob and agy do not, so their commands include explicit file paths instead.
# Claude's wrappers are user-only (disable-model-invocation): Claude Code then keeps their
# descriptions out of every session's context, and the model reaches the same guidelines through
# the 6 skill groups. Typing /oss-<name> still works.
generate_skill_agent_command() {
    local agent="$1"
    local skill_name="$2"
    local guideline_file="$3"
    local dest="$4"
    local description="$5"
    local style="${6:-plugin}" skills_path='${CLAUDE_PLUGIN_ROOT}/skills' skill_prefix='oss-helper:'
    if [[ "$style" == legacy ]]; then skills_path='~/.claude/skills'; skill_prefix=''; fi

    # Escape quotes and backslashes for YAML
    description="$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/\"/\\\"/g')"

    local forked=false
    if [[ "$agent" == "claude" ]] && [[ " $FORKED_COMMANDS " == *" $(basename "$dest" .md) "* ]]; then
        forked=true
    fi

    {
        printf -- "---\n"
        if [[ "$agent" == "claude" ]]; then
            printf 'disable-model-invocation: true\n'
        fi
        printf 'description: "%s"\n' "$description"
        if [[ "$forked" == true ]]; then
            printf 'context: fork\n'
            printf 'background: false\n'
        fi
        printf -- "---\n\n"

        case "$agent" in
            claude)
                if [[ "$forked" == true ]]; then
                    # A fork starts without the conversation: name the files, and pass the arguments
                    # through $ARGUMENTS, which Claude Code substitutes (left unexpanded here on purpose).
                    printf 'Read and follow the initialization steps in `%s/%s/init.md` to detect the current project and load its configuration. Then read and follow the guideline in `%s/%s/%s`.\n\n' \
                        "$skills_path" "$skill_name" "$skills_path" "$skill_name" "$guideline_file"
                    printf 'Arguments: $ARGUMENTS\n\n'
                    printf '%s\n' "$FORK_NOTE"
                elif [[ " $WORKFLOW_COMMANDS " == *" $(basename "$dest" .md) "* ]]; then
                    printf 'Read and follow the guideline in `%s/%s/%s`. In workflow mode (its step 2), skip the skill'"'"'s initialization steps: the workflow'"'"'s loader resolves the project and its rules itself. In manual mode, first follow the initialization steps in `%s/%s/init.md`.\n' \
                        "$skills_path" "$skill_name" "$guideline_file" "$skills_path" "$skill_name"
                else
                    printf 'Invoke the %s%s skill. Follow the initialization steps, then read and follow the `%s` guideline.\n' "$skill_prefix" "$skill_name" "$guideline_file"
                fi
                ;;
            *)
                printf 'Read and follow the initialization steps in `~/.%s/skills/%s/init.md` to detect the current project and load its configuration. Then read and follow the guideline in `~/.%s/skills/%s/%s`.\n' \
                    "$agent" "$skill_name" "$agent" "$skill_name" "$guideline_file"
                ;;
        esac
    } > "$dest"
}



build_skills() {
    local output="$1" skill file fragment
    for skill in "${SKILL_DIRS[@]}"; do
        mkdir -p "$output/skills/$skill/_fragments"
        get_skill_files "$skill"
        for file in $SKILL_FILES_RESULT; do
            fetch_file "$file" "$output/skills/$skill/$(basename "$file")"
        done
        fetch_file "$SHARED_INIT" "$output/skills/$skill/init.md"
        fetch_file "$SHARED_INIT_SCRIPT" "$output/skills/$skill/oss-init.sh"
        for fragment in "${SHARED_FRAGMENTS[@]}"; do
            fetch_file "$fragment" "$output/skills/$skill/_fragments/$(basename "$fragment")"
        done
    done
}

build_commands() {
    local agent="$1" output="$2" entry skill guideline command description
    [[ "$agent" != codex ]] || return 0
    mkdir -p "$output/commands"
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        IFS='|' read -r skill guideline command description <<< "$entry"
        case "$agent" in
            gemini) convert_guideline_to_toml "$SOURCE_ROOT/skills/$skill/$guideline" "$output/commands/$command.toml" "$description" ;;
            opencode) convert_guideline_to_opencode_md "$SOURCE_ROOT/skills/$skill/$guideline" "$output/commands/$command.md" "$description" ;;
            *) generate_skill_agent_command "$agent" "$skill" "$guideline" "$output/commands/$command.md" "$description" ;;
        esac
    done
}

build_agents() {
    local agent="$1" output="$2" file filename
    mkdir -p "$output/agents"
    for file in "${AGENT_FILES[@]}"; do
        filename="$(basename "$file")"
        case "$agent" in
            gemini) convert_agent_to_gemini "$SOURCE_ROOT/$file" "$output/agents/$filename" ;;
            opencode) convert_agent_to_opencode "$SOURCE_ROOT/$file" "$output/agents/$filename" ;;
            codex) convert_agent_to_codex_toml "$SOURCE_ROOT/$file" "$output/agents/${filename%.md}.toml" ;;
            *) fetch_file "$file" "$output/agents/$filename" ;;
        esac
    done
}

build_target() {
    local agent="$1" destination="$2" staging file
    while [[ "$destination" == */ ]]; do destination="${destination%/}"; done
    case "${destination##*/}" in
        ''|.|..) echo "Invalid output directory: $2" >&2; return 1 ;;
    esac
    # Only replace an output previously generated by this builder.
    if [[ -L "$destination" ]] || { [[ -e "$destination" ]] && [[ ! -f "$destination/.oss-helper-build" ]]; }; then
        echo "Refusing to replace unmarked output: $destination" >&2
        return 1
    fi
    mkdir -p "$(dirname "$destination")"
    destination="$(cd "$(dirname "$destination")" && pwd)/$(basename "$destination")"
    staging="$(mktemp -d "${destination}.tmp.XXXXXX")"
    # Build in a subshell so failures preserve the previous complete output.
    if bash -c 'source "$1"; assemble_target "$2" "$3"' bash "$SOURCE_ROOT/build.sh" "$agent" "$staging"; then
        :
    else
        rm -rf "$staging"
        return 1
    fi
    rm -rf "$destination"
    mv "$staging" "$destination"
    printf 'Built %s: %s\n' "$agent" "$destination"
}

# Native clients use this content-derived identity without claiming a release tag.
build_native_metadata() {
    local staging="$1" agent="$2" digest version template filename
    local templates=(agent-plugin bob-extension)
    case "$agent" in
        claude) sed 's|@SKILLS_PATH@|skills|g' "$SOURCE_ROOT/packaging/BOB.md" > "$staging/BOB.md" ;;
        gemini)
            templates=(gemini-extension)
            sed 's|@SKILLS_PATH@|skills|g' "$SOURCE_ROOT/packaging/GEMINI.md" > "$staging/GEMINI.md"
            ;;
    esac
    local checksum=(sha256sum)
    if command -v shasum > /dev/null 2>&1; then checksum=(shasum -a 256); fi
    digest="$(
        (
            cd "$staging"
            find . -type f -exec "${checksum[@]}" {} +
            cd "$SOURCE_ROOT"
            find packaging -type f -exec "${checksum[@]}" {} +
        ) | LC_ALL=C sort | "${checksum[@]}"
    )"
    version="0.0.0-dev.sha${digest%% *}"
    for template in "${templates[@]}"; do
        filename="$template.json"
        [[ "$template" != agent-plugin ]] || filename=plugin.json
        sed "s/@VERSION@/$version/g" "$SOURCE_ROOT/packaging/$template.json" > "$staging/$filename"
    done
}

assemble_target() {
    local agent="$1" staging="$2" file
    case "$agent" in claude|bob|agy|codex|gemini) build_skills "$staging" ;; esac
    build_commands "$agent" "$staging"
    build_agents "$agent" "$staging"
    if [[ "$agent" == claude ]]; then
        mkdir -p "$staging/workflows" "$staging/.claude-plugin"
        for file in "${WORKFLOW_FILES[@]}"; do
            sed 's@/oss-security-case@/oss-helper:oss-security-case@g' "$SOURCE_ROOT/$file" > "$staging/$file"
        done
        fetch_file 'packaging/claude-plugin.json' "$staging/.claude-plugin/plugin.json"
    fi
    fetch_file LICENSE "$staging/LICENSE"
    case "$agent" in claude|gemini) build_native_metadata "$staging" "$agent" ;; esac
    printf 'OSS Helper generated output: %s\n' "$agent" > "$staging/.oss-helper-build"
}

usage() {
    echo 'Usage: ./build.sh [--output-dir DIR] [agent]'
    echo "Agents: ${AGENTS[*]} (default: all)"
    echo 'Default outputs: plugin/ (Claude), build/<agent>/ (others).'
    echo '--output-dir requires one agent and replaces only marked generated output.'
}

main() {
    local selected="" output="" agent destination valid=false
    local targets=("${AGENTS[@]}")
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; return 0 ;;
            --output-dir) [[ $# -ge 2 && -n "$2" ]] || { usage >&2; return 1; }; output="$2"; shift 2 ;;
            -*) usage >&2; return 1 ;;
            *) [[ -z "$selected" ]] || { usage >&2; return 1; }; selected="$1"; shift ;;
        esac
    done
    if [[ -n "$selected" ]]; then
        for agent in "${AGENTS[@]}"; do
            if [[ "$selected" == "$agent" ]]; then valid=true; break; fi
        done
        [[ "$valid" == true ]] || { usage >&2; return 1; }
        targets=("$selected")
    elif [[ -n "$output" ]]; then
        echo '--output-dir requires an agent' >&2; return 1
    fi
    for agent in "${targets[@]}"; do
        destination="$output"
        if [[ -z "$destination" ]]; then
            if [[ "$agent" == claude ]]; then destination="$SOURCE_ROOT/plugin"; else destination="$SOURCE_ROOT/build/$agent"; fi
        fi
        build_target "$agent" "$destination"
        case "$agent:$output" in
            claude:)
                cp "$destination/bob-extension.json" "$SOURCE_ROOT/bob-extension.json"
                sed 's|@SKILLS_PATH@|plugin/skills|g' "$SOURCE_ROOT/packaging/BOB.md" > "$SOURCE_ROOT/BOB.md"
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
