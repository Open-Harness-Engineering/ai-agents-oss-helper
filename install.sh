#!/usr/bin/env bash
#
# Install script for AI Agent OSS Helper
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
#   ./install.sh              # Install to all agents (claude, bob, gemini, opencode, codex, agy)
#   ./install.sh claude       # Install to claude only
#   ./install.sh bob          # Install to bob only
#   ./install.sh gemini       # Install to gemini only
#   ./install.sh opencode     # Install to opencode only
#   ./install.sh codex        # Install to codex only
#   ./install.sh agy          # Install to agy only
#
# Options:
#   --version <tag>           Install assets from a release tag instead of main.
#                             Remote installs only (curl | bash); or set
#                             OSS_HELPER_VERSION. Example:
#                             curl -fsSL .../main/install.sh | bash -s -- --version v1.0.0
#

set -euo pipefail

# Configuration
# Release ref to install assets from (used for remote installs, e.g. curl | bash).
# Precedence: --version flag > OSS_HELPER_VERSION env var > default "main".
OSS_HELPER_REF="${OSS_HELPER_VERSION:-main}"
# BASE_URL may be set explicitly to override the derived URL (e.g. tests, mirrors);
# an explicit value takes precedence over OSS_HELPER_REF / --version.
if [[ -n "${BASE_URL:-}" ]]; then
    BASE_URL_EXPLICIT=true
else
    BASE_URL_EXPLICIT=false
fi
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/$OSS_HELPER_REF}"
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Determine script location (for local installs)
get_script_dir() {
    if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
        cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
    else
        echo ""
    fi
}

# Download or copy a file
fetch_file() {
    local src="$1"
    local dest="$2"
    local script_dir
    script_dir="$(get_script_dir)"

    # If running locally and file exists, copy it
    if [[ -n "$script_dir" ]] && [[ -f "$script_dir/$src" ]]; then
        cp "$script_dir/$src" "$dest"
        return 0
    fi

    # Otherwise, download from remote
    if command -v curl &> /dev/null; then
        curl -fsSL "$BASE_URL/$src" -o "$dest"
    elif command -v wget &> /dev/null; then
        wget -q "$BASE_URL/$src" -O "$dest"
    else
        error "Neither curl nor wget found. Cannot download files."
        return 1
    fi
}

# Convert a guideline file to Gemini CLI .toml format
convert_guideline_to_toml() {
    local src="$1"
    local dest="$2"
    local description="$3"
    {
        printf 'description = "%s"\n' "$description"
        printf "prompt = '''\n"
        printf 'Note: This is an OSS Helper guideline. Before following these instructions, detect the current project via git remote and load project-specific rules from ~/.gemini/rules/<project-directory>/ (project-info.md, project-standards.md, project-guidelines.md).\n\n'
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
                    printf 'Read and follow the initialization steps in `~/.claude/skills/%s/init.md` to detect the current project and load its configuration. Then read and follow the guideline in `~/.claude/skills/%s/%s`.\n\n' \
                        "$skill_name" "$skill_name" "$guideline_file"
                    printf 'Arguments: $ARGUMENTS\n\n'
                    printf '%s\n' "$FORK_NOTE"
                else
                    printf 'Invoke the %s skill. Follow the initialization steps, then read and follow the `%s` guideline.\n' "$skill_name" "$guideline_file"
                fi
                ;;
            *)
                printf 'Read and follow the initialization steps in `~/.%s/skills/%s/init.md` to detect the current project and load its configuration. Then read and follow the guideline in `~/.%s/skills/%s/%s`.\n' \
                    "$agent" "$skill_name" "$agent" "$skill_name" "$guideline_file"
                ;;
        esac
    } > "$dest"
}


# Installed project rules used to live in ~/.<agent>/rules/<project>/. Claude Code loads every file
# under ~/.claude/rules/ into every session and sub-agent, whichever repository is open, so they now
# live in ~/.<agent>/oss-helper/rules/<project>/, where only the OSS Helper initialization reads them.
# Move the OSS Helper rule sets (a project-info.md that declares a Remote pattern) and leave
# everything else in the old directory alone.
migrate_legacy_rules() {
    local legacy_dir="$1"
    local rules_dir="$2"
    local info_file project_dir project

    [[ -d "$legacy_dir" ]] || return 0
    for info_file in "$legacy_dir"/*/project-info.md; do
        [[ -f "$info_file" ]] || continue
        grep -Eq '\*\*Remote pattern:\*\*' "$info_file" || continue
        project_dir="$(dirname "$info_file")"
        project="$(basename "$project_dir")"
        if [[ -e "$rules_dir/$project" ]]; then
            warn "  Rules for $project are in both $project_dir and $rules_dir/$project. Kept the second; compare them and remove $project_dir."
            continue
        fi
        if mv "$project_dir" "$rules_dir/$project"; then
            info "  Moved project rules: $project_dir -> $rules_dir/$project"
        else
            error "  Failed to move $project_dir to $rules_dir/$project"
            return 1
        fi
    done
}

# Install for agents that support skills natively (Claude, Bob, agy)
install_skill_agent() {
    local agent="$1"
    local skills_root="$HOME/.$agent/skills"
    local commands_dir="$HOME/.$agent/commands"
    local rules_dir="$HOME/.$agent/oss-helper/rules"
    local legacy_rules_dir="$HOME/.$agent/rules"

    info "Installing for $agent..."

    if ! mkdir -p "$rules_dir"; then
        error "Failed to create directory: $rules_dir"
        return 1
    fi
    migrate_legacy_rules "$legacy_rules_dir" "$rules_dir" || return 1

    # Clean up old command files
    if [[ -d "$commands_dir" ]]; then
        info "  Cleaning up old commands..."
        for old_file in "${OLD_COMMAND_FILES[@]}"; do
            rm -f "$commands_dir/$old_file"
        done
    fi

    # Clean up old monolithic skill directory
    for old_skill in "${OLD_SKILL_DIRS[@]}"; do
        if [[ -d "$skills_root/$old_skill" ]]; then
            info "  Removing old skill: $old_skill"
            rm -rf "$skills_root/$old_skill"
        fi
    done

    # Install each skill
    for skill_dir in "${SKILL_DIRS[@]}"; do
        local target_dir="$skills_root/$skill_dir"

        if ! mkdir -p "$target_dir"; then
            error "Failed to create directory: $target_dir"
            return 1
        fi

        info "  Installing skill: $skill_dir"

        # Install skill files
        if ! get_skill_files "$skill_dir"; then
            error "Unknown skill: $skill_dir"
            return 1
        fi
        for file in $SKILL_FILES_RESULT; do
            local filename
            filename="$(basename "$file")"
            local dest="$target_dir/$filename"

            if fetch_file "$file" "$dest"; then
                info "    Installed: $filename"
            else
                error "    Failed to install: $filename"
                return 1
            fi
        done

        # Copy shared init.md into each skill directory
        local init_dest="$target_dir/init.md"
        if fetch_file "$SHARED_INIT" "$init_dest"; then
            info "    Installed: init.md (shared)"
        else
            error "    Failed to install: init.md"
            return 1
        fi
        if fetch_file "$SHARED_INIT_SCRIPT" "$target_dir/oss-init.sh"; then
            info "    Installed: oss-init.sh (shared)"
        else
            error "    Failed to install: oss-init.sh"
            return 1
        fi

        # Copy shared fragments into each skill's _fragments/ directory
        if ! mkdir -p "$target_dir/_fragments"; then
            error "Failed to create directory: $target_dir/_fragments"
            return 1
        fi
        for fragment in "${SHARED_FRAGMENTS[@]}"; do
            local fragment_name
            fragment_name="$(basename "$fragment")"
            if fetch_file "$fragment" "$target_dir/_fragments/$fragment_name"; then
                info "    Installed: _fragments/$fragment_name (shared)"
            else
                error "    Failed to install: _fragments/$fragment_name"
                return 1
            fi
        done
    done

    # Install individual commands (thin wrappers that invoke the skills)
    if ! mkdir -p "$commands_dir"; then
        error "Failed to create directory: $commands_dir"
        return 1
    fi

    info "  Installing commands..."
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        local skill_dir guideline_file cmd_name description
        IFS='|' read -r skill_dir guideline_file cmd_name description <<< "$entry"

        local dest="$commands_dir/${cmd_name}.md"
        generate_skill_agent_command "$agent" "$skill_dir" "$guideline_file" "$dest" "$description"
        info "    Installed: ${cmd_name}.md"
    done

    # Install sub-agents
    local agents_dir="$HOME/.$agent/agents"
    if ! mkdir -p "$agents_dir"; then
        error "Failed to create directory: $agents_dir"
        return 1
    fi

    info "  Installing sub-agents..."
    for agent_file in "${AGENT_FILES[@]}"; do
        local filename
        filename="$(basename "$agent_file")"
        local dest="$agents_dir/$filename"

        if fetch_file "$agent_file" "$dest"; then
            info "    Installed: $filename"
        else
            error "    Failed to install: $filename"
            return 1
        fi
    done

    # Install workflows (the Workflow tool is Claude Code only)
    if [[ "$agent" == "claude" ]]; then
        install_claude_workflows || return 1
    fi

    # Remove old monolithic rule files (legacy cleanup)
    info "  Cleaning up old rule files..."
    for old_file in "${OLD_RULE_FILES[@]}"; do
        rm -f "$legacy_rules_dir/$old_file"
    done

    info "  Skills installed to: $skills_root/{${SKILL_DIRS[*]}}"
    info "  Commands installed to: $commands_dir"
    info "  Sub-agents installed to: $agents_dir"
    info "  Rules directory: $rules_dir (project rules installed on demand)"
}

# Install Claude Code workflows into ~/.claude/workflows/. Claude Code reads that directory when a
# session starts, so a session that was already running sees a new workflow only by its path.
install_claude_workflows() {
    local workflows_dir="$HOME/.claude/workflows"

    if ! mkdir -p "$workflows_dir"; then
        error "Failed to create directory: $workflows_dir"
        return 1
    fi

    info "  Installing workflows..."
    for workflow_file in "${WORKFLOW_FILES[@]}"; do
        local filename
        filename="$(basename "$workflow_file")"

        if fetch_file "$workflow_file" "$workflows_dir/$filename"; then
            info "    Installed: $filename"
        else
            error "    Failed to install: $filename"
            return 1
        fi
    done

    info "  Workflows installed to: $workflows_dir (start a new Claude Code session to load them)"
}

# Install for Gemini CLI (individual TOML commands)
install_gemini() {
    local commands_dir="$HOME/.gemini/commands"
    local rules_dir="$HOME/.gemini/rules"

    info "Installing for gemini..."

    if ! mkdir -p "$commands_dir"; then
        error "Failed to create directory: $commands_dir"
        return 1
    fi

    if ! mkdir -p "$rules_dir"; then
        error "Failed to create directory: $rules_dir"
        return 1
    fi

    # Clean up old command files
    info "  Cleaning up old commands..."
    for old_file in "${OLD_COMMAND_FILES[@]}"; do
        rm -f "$commands_dir/$old_file"
        rm -f "$commands_dir/${old_file%.md}.toml"
    done

    # Install individual guideline commands as TOML
    info "  Installing commands..."
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        local skill_dir guideline_file cmd_name description
        IFS='|' read -r skill_dir guideline_file cmd_name description <<< "$entry"

        local src_path="skills/$skill_dir/$guideline_file"
        local toml_name="${cmd_name}.toml"
        local dest="$commands_dir/$toml_name"
        local tmp_md
        tmp_md="$(mktemp)"

        if fetch_file "$src_path" "$tmp_md"; then
            convert_guideline_to_toml "$tmp_md" "$dest" "$description"
            rm -f "$tmp_md"
            info "    Installed: $toml_name"
        else
            rm -f "$tmp_md"
            error "    Failed to install: $toml_name"
            return 1
        fi
    done

    # Remove old monolithic rule files (legacy cleanup)
    info "  Cleaning up old rule files..."
    for old_file in "${OLD_RULE_FILES[@]}"; do
        rm -f "$rules_dir/$old_file"
    done

    # Install sub-agents
    local agents_dir="$HOME/.gemini/agents"
    if ! mkdir -p "$agents_dir"; then
        error "Failed to create directory: $agents_dir"
        return 1
    fi

    info "  Installing sub-agents..."
    for agent_file in "${AGENT_FILES[@]}"; do
        local filename
        filename="$(basename "$agent_file")"
        local dest="$agents_dir/$filename"
        local tmp_md
        tmp_md="$(mktemp)"

        if fetch_file "$agent_file" "$tmp_md"; then
            convert_agent_to_gemini "$tmp_md" "$dest"
            rm -f "$tmp_md"
            info "    Installed: $filename"
        else
            rm -f "$tmp_md"
            error "    Failed to install: $filename"
            return 1
        fi
    done

    info "  Commands installed to: $commands_dir"
    info "  Sub-agents installed to: $agents_dir"
    info "  Rules directory: $rules_dir (project rules installed on demand)"
}

# Install for OpenCode (individual commands with frontmatter)
install_opencode() {
    local commands_dir="$HOME/.config/opencode/commands"
    local rules_dir="$HOME/.config/opencode/rules"

    info "Installing for opencode..."

    if ! mkdir -p "$commands_dir"; then
        error "Failed to create directory: $commands_dir"
        return 1
    fi

    if ! mkdir -p "$rules_dir"; then
        error "Failed to create directory: $rules_dir"
        return 1
    fi

    # Clean up old command files
    info "  Cleaning up old commands..."
    for old_file in "${OLD_COMMAND_FILES[@]}"; do
        rm -f "$commands_dir/$old_file"
    done

    # Install individual guideline commands with frontmatter
    info "  Installing commands..."
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        local skill_dir guideline_file cmd_name description
        IFS='|' read -r skill_dir guideline_file cmd_name description <<< "$entry"

        local src_path="skills/$skill_dir/$guideline_file"
        local dest="$commands_dir/${cmd_name}.md"
        local tmp_md
        tmp_md="$(mktemp)"

        if fetch_file "$src_path" "$tmp_md"; then
            convert_guideline_to_opencode_md "$tmp_md" "$dest" "$description"
            rm -f "$tmp_md"
            info "    Installed: ${cmd_name}.md"
        else
            rm -f "$tmp_md"
            error "    Failed to install: ${cmd_name}.md"
            return 1
        fi
    done

    # Remove old monolithic rule files (legacy cleanup)
    info "  Cleaning up old rule files..."
    for old_file in "${OLD_RULE_FILES[@]}"; do
        rm -f "$rules_dir/$old_file"
    done

    # Install sub-agents
    local agents_dir="$HOME/.config/opencode/agents"
    if ! mkdir -p "$agents_dir"; then
        error "Failed to create directory: $agents_dir"
        return 1
    fi

    info "  Installing sub-agents..."
    for agent_file in "${AGENT_FILES[@]}"; do
        local filename
        filename="$(basename "$agent_file")"
        local dest="$agents_dir/$filename"
        local tmp_md
        tmp_md="$(mktemp)"

        if fetch_file "$agent_file" "$tmp_md"; then
            convert_agent_to_opencode "$tmp_md" "$dest"
            rm -f "$tmp_md"
            info "    Installed: $filename"
        else
            rm -f "$tmp_md"
            error "    Failed to install: $filename"
            return 1
        fi
    done

    info "  Commands installed to: $commands_dir"
    info "  Sub-agents installed to: $agents_dir"
    info "  Rules directory: $rules_dir (project rules installed on demand)"
}

# Install for Codex (skill directories under ~/.agents/skills/)
install_codex() {
    local skills_root="$HOME/.agents/skills"
    local codex_rules_dir="$HOME/.codex/oss-helper/rules"

    info "Installing for codex..."

    if ! mkdir -p "$codex_rules_dir"; then
        error "Failed to create directory: $codex_rules_dir"
        return 1
    fi

    # Clean up old skill directories
    info "  Cleaning up old skills..."
    for old_skill in "${OLD_CODEX_SKILLS[@]}"; do
        rm -rf "$skills_root/$old_skill"
    done
    # Legacy installs exposed internal fragments as skills. Only remove them
    # when their init preamble identifies them as OSS Helper artifacts.
    for old_skill in README _common-init _build-workflow; do
        if [[ -f "$skills_root/$old_skill/SKILL.md" ]] &&
            grep -Fq 'Before you begin, read and follow the OSS Helper init file at ~/.codex/oss-helper/.oss-init.md.' "$skills_root/$old_skill/SKILL.md"; then
            rm -rf "$skills_root/$old_skill"
        fi
    done
    # Clean up old init file
    rm -f "$HOME/.codex/oss-helper/.oss-init.md"

    # Install each skill
    for skill_dir in "${SKILL_DIRS[@]}"; do
        local target_dir="$skills_root/$skill_dir"

        if ! mkdir -p "$target_dir"; then
            error "Failed to create directory: $target_dir"
            return 1
        fi

        info "  Installing skill: $skill_dir"

        # Install skill files
        if ! get_skill_files "$skill_dir"; then
            error "Unknown skill: $skill_dir"
            return 1
        fi
        for file in $SKILL_FILES_RESULT; do
            local filename
            filename="$(basename "$file")"
            local dest="$target_dir/$filename"

            if fetch_file "$file" "$dest"; then
                info "    Installed: $filename"
            else
                error "    Failed to install: $filename"
                return 1
            fi
        done

        # Copy shared init.md into each skill directory
        local init_dest="$target_dir/init.md"
        if fetch_file "$SHARED_INIT" "$init_dest"; then
            info "    Installed: init.md (shared)"
        else
            error "    Failed to install: init.md"
            return 1
        fi
        if fetch_file "$SHARED_INIT_SCRIPT" "$target_dir/oss-init.sh"; then
            info "    Installed: oss-init.sh (shared)"
        else
            error "    Failed to install: oss-init.sh"
            return 1
        fi

        # Copy shared fragments into each skill's _fragments/ directory
        if ! mkdir -p "$target_dir/_fragments"; then
            error "Failed to create directory: $target_dir/_fragments"
            return 1
        fi
        for fragment in "${SHARED_FRAGMENTS[@]}"; do
            local fragment_name
            fragment_name="$(basename "$fragment")"
            if fetch_file "$fragment" "$target_dir/_fragments/$fragment_name"; then
                info "    Installed: _fragments/$fragment_name (shared)"
            else
                error "    Failed to install: _fragments/$fragment_name"
                return 1
            fi
        done
    done

    # Install sub-agents
    local agents_dir="$HOME/.codex/agents"
    if ! mkdir -p "$agents_dir"; then
        error "Failed to create directory: $agents_dir"
        return 1
    fi

    info "  Installing sub-agents..."
    for agent_file in "${AGENT_FILES[@]}"; do
        local filename toml_name
        filename="$(basename "$agent_file")"
        toml_name="${filename%.md}.toml"
        local dest="$agents_dir/$toml_name"
        local tmp_md
        tmp_md="$(mktemp)"

        if fetch_file "$agent_file" "$tmp_md"; then
            convert_agent_to_codex_toml "$tmp_md" "$dest"
            rm -f "$tmp_md"
            info "    Installed: $toml_name"
        else
            rm -f "$tmp_md"
            error "    Failed to install: $toml_name"
            return 1
        fi
    done

    info "  Skills installed to: $skills_root/{${SKILL_DIRS[*]}}"
    info "  Sub-agents installed to: $agents_dir"
    info "  Rules directory: $codex_rules_dir (project rules installed on demand)"
}

# Install for a specific agent
install_for_agent() {
    local agent="$1"

    case "$agent" in
        claude|bob|agy)
            install_skill_agent "$agent"
            ;;
        gemini)
            install_gemini
            ;;
        opencode)
            install_opencode
            ;;
        codex)
            install_codex
            ;;
    esac
}

# Print usage/help.
usage() {
    cat <<USAGE
AI Agent OSS Helper - Installer

Usage: install.sh [--version <tag>] [agent]

Agents: ${AGENTS[*]}
  (omit the agent to install for all of them)

Options:
  --version <tag>   Install assets from a release tag instead of the latest
                    main. Applies to remote installs (curl | bash); can also
                    be set via the OSS_HELPER_VERSION environment variable.
  -h, --help        Show this help and exit.

Examples:
  curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash -s -- --version v1.0.0
  OSS_HELPER_VERSION=v1.0.0 ./install.sh claude
USAGE
}

# Main
main() {
    local agents_to_install=()
    local selected_agent=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                if [[ $# -lt 2 ]]; then
                    error "--version requires a tag argument (e.g. --version v1.0.0)"
                    exit 1
                fi
                OSS_HELPER_REF="$2"
                shift 2
                ;;
            --version=*)
                OSS_HELPER_REF="${1#*=}"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -n "$selected_agent" ]]; then
                    error "Unexpected argument: $1"
                    echo "Valid agents: ${AGENTS[*]}"
                    exit 1
                fi
                selected_agent="$1"
                shift
                ;;
        esac
    done

    # Derive BASE_URL from the chosen ref unless BASE_URL was set explicitly.
    if [[ "$BASE_URL_EXPLICIT" == "false" ]]; then
        BASE_URL="https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/$OSS_HELPER_REF"
    fi

    # Resolve which agents to install.
    if [[ -z "$selected_agent" ]]; then
        agents_to_install=("${AGENTS[@]}")
    else
        local valid=false
        for agent in "${AGENTS[@]}"; do
            if [[ "$selected_agent" == "$agent" ]]; then
                valid=true
                break
            fi
        done

        if [[ "$valid" == "false" ]]; then
            error "Unknown agent: $selected_agent"
            echo "Valid agents: ${AGENTS[*]}"
            exit 1
        fi

        agents_to_install=("$selected_agent")
    fi

    echo ""
    echo "AI Agent OSS Helper - Installer"
    echo "================================"
    echo ""

    for agent in "${agents_to_install[@]}"; do
        install_for_agent "$agent"
        echo ""
    done

    info "Installation complete!"
    echo ""
    echo "The OSS Helper skills are installed as 6 focused skill groups:"
    echo "  /oss-issues   - Issue management (fix, analyze, create, triage)"
    echo "  /oss-review   - PR management (review, merge, backport)"
    echo "  /oss-ci       - CI/CD and code quality (CI errors, SonarCloud)"
    echo "  /oss-security - Security (CVE triage, advisories, scanning)"
    echo "  /oss-project  - Project setup (rules, workspaces)"
    echo "  /oss-qe       - Quality engineering (test plans)"
    echo ""
    echo "You can also use individual commands (e.g., /oss-fix-issue, /oss-review-pr)"
    echo "or just describe what you want (e.g., 'fix issue #42', 'review PR 15')."
    echo ""
    echo "Sub-agents (all tools):"
    echo "  Specialized agents for backend, frontend, architecture, testing,"
    echo "  code review, technical writing, and marketing."
    echo ""
    echo "Workflows (Claude Code only):"
    echo "  /oss-security-case drives a security report through triage, reply, CVE,"
    echo "  issue, fix, backports and CVE draft; other agents follow the same"
    echo "  guideline by hand."
}

main "$@"
