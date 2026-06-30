#!/usr/bin/env bash
#
# Install script for AI Agent OSS Helper
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main/install.sh | bash
#   ./install.sh              # Install to all agents (claude, bob, gemini, opencode, codex)
#   ./install.sh claude       # Install to claude only
#   ./install.sh bob          # Install to bob only
#   ./install.sh gemini       # Install to gemini only
#   ./install.sh opencode     # Install to opencode only
#   ./install.sh codex        # Install to codex only
#

set -euo pipefail

# Configuration
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/Open-Harness-Engineering/ai-agents-oss-helper/main}"
AGENTS=("claude" "bob" "gemini" "opencode" "codex")

# Skill directory (relative path from repo root)
SKILL_DIR="skills/oss-helper"

# All skill files to install (relative paths from repo root)
SKILL_FILES=(
    "skills/oss-helper/SKILL.md"
    "skills/oss-helper/add-project.md"
    "skills/oss-helper/address-review.md"
    "skills/oss-helper/analyze-issue.md"
    "skills/oss-helper/analyze-third-party-cve.md"
    "skills/oss-helper/backport-pr.md"
    "skills/oss-helper/create-issue.md"
    "skills/oss-helper/create-security-advisory.md"
    "skills/oss-helper/draft-cve.md"
    "skills/oss-helper/find-task.md"
    "skills/oss-helper/fix-backlog-task.md"
    "skills/oss-helper/fix-ci-errors.md"
    "skills/oss-helper/fix-github-alert.md"
    "skills/oss-helper/fix-issue.md"
    "skills/oss-helper/fix-sonarcloud.md"
    "skills/oss-helper/install-info.md"
    "skills/oss-helper/list-issues.md"
    "skills/oss-helper/list-pr-status.md"
    "skills/oss-helper/list-prs.md"
    "skills/oss-helper/merge-pr.md"
    "skills/oss-helper/oss-create-multi-repo-issue.md"
    "skills/oss-helper/oss-create-rules.md"
    "skills/oss-helper/oss-fix-multi-repo-issue.md"
    "skills/oss-helper/oss-qe-create-test-plan.md"
    "skills/oss-helper/oss-qe-verify.md"
    "skills/oss-helper/oss-review-prs.md"
    "skills/oss-helper/oss-security-scan.md"
    "skills/oss-helper/oss-triage-issue.md"
    "skills/oss-helper/oss-workspace-init.md"
    "skills/oss-helper/oss-workspace-status.md"
    "skills/oss-helper/pr-status.md"
    "skills/oss-helper/quick-fix.md"
    "skills/oss-helper/review-pr.md"
    "skills/oss-helper/triage-security-report.md"
    "skills/oss-helper/update-knowledge.md"
)

# Guideline files that become individual commands for agents without skill support.
# Each entry: "guideline-filename|oss-command-name|description"
GUIDELINE_COMMANDS=(
    "add-project.md|oss-add-project|Add a new project to the OSS Helper"
    "address-review.md|oss-address-review|Address review feedback on a pull request"
    "analyze-issue.md|oss-analyze-issue|Analyze an issue to understand the problem"
    "analyze-third-party-cve.md|oss-analyze-third-party-cve|Analyze exposure to a third-party CVE"
    "backport-pr.md|oss-backport-pr|Cherry-pick a merged PR onto another branch"
    "create-issue.md|oss-create-issue|Create a new issue in the project's tracker"
    "create-security-advisory.md|oss-create-security-advisory|Report a security vulnerability via GitHub"
    "draft-cve.md|oss-draft-cve|Draft a CVE advisory page"
    "find-task.md|oss-find-task|Find an issue to contribute to"
    "fix-backlog-task.md|oss-fix-backlog-task|Fix a task from a Backlog.md file"
    "fix-ci-errors.md|oss-fix-ci-errors|Download CI reports, identify errors, and fix them"
    "fix-github-alert.md|oss-fix-github-alert|Fix a GitHub security or quality alert"
    "fix-issue.md|oss-fix-issue|Fix an issue from the project's issue tracker"
    "fix-sonarcloud.md|oss-fix-sonarcloud|Fix SonarCloud issues for a given rule"
    "install-info.md|oss-install-info|Install project rules from the known-projects repository"
    "list-issues.md|oss-list-issues|List issues assigned to you"
    "oss-create-rules.md|oss-create-rules|Generate project rule files by auto-inspecting a repository"
    "list-pr-status.md|oss-list-pr-status|List all your open PRs with status summary"
    "list-prs.md|oss-list-prs|List all open PRs in the repository"
    "merge-pr.md|oss-merge-pr|Merge a PR after verifying requirements"
    "pr-status.md|oss-pr-status|Check CI, review state, and merge readiness of a PR"
    "quick-fix.md|oss-quick-fix|Apply a quick fix without a tracked issue"
    "review-pr.md|oss-review-pr|Review a pull request"
    "triage-security-report.md|oss-triage-security-report|Triage an inbound security vulnerability report"
    "update-knowledge.md|oss-update-knowledge|Update project rule files"
    "oss-create-multi-repo-issue.md|oss-create-multi-repo-issue|Create and link issues across multiple repositories"
    "oss-fix-multi-repo-issue.md|oss-fix-multi-repo-issue|Fix an issue spanning multiple repositories"
    "oss-qe-create-test-plan.md|oss-qe-create-test-plan|Create a test plan for a project feature or component"
    "oss-qe-verify.md|oss-qe-verify|Execute an existing test plan and track results"
    "oss-review-prs.md|oss-review-prs|Review a batch of open PRs"
    "oss-security-scan.md|oss-security-scan|Scan codebase for security vulnerabilities"
    "oss-triage-issue.md|oss-triage-issue|Triage a filed issue (maintainer-side)"
    "oss-workspace-init.md|oss-workspace-init|Initialize a multi-repo workspace"
    "oss-workspace-status.md|oss-workspace-status|Report status of all repos in a workspace"
)

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

# Old Codex individual skill directories to clean up
OLD_CODEX_SKILLS=(
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

# Generate a thin command file for skill agents (Claude, Bob).
# The background skill provides all initialization and guideline content;
# the command just triggers the right guideline.
generate_skill_agent_command() {
    local guideline_file="$1"
    local dest="$2"
    local description="$3"

    # Escape quotes and backslashes for YAML
    description="$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/\"/\\\"/g')"

    {
        printf -- "---\n"
        printf 'description: "%s"\n' "$description"
        printf -- "---\n\n"
        printf 'Invoke the oss-helper skill. Follow the initialization steps, then read and follow the `%s` guideline.\n' "$guideline_file"
    } > "$dest"
}

# Install for agents that support skills natively (Claude, Bob)
install_skill_agent() {
    local agent="$1"
    local skills_dir="$HOME/.$agent/skills/oss-helper"
    local commands_dir="$HOME/.$agent/commands"
    local rules_dir="$HOME/.$agent/rules"

    info "Installing for $agent..."

    # Create target directories
    if ! mkdir -p "$skills_dir"; then
        error "Failed to create directory: $skills_dir"
        return 1
    fi

    if ! mkdir -p "$rules_dir"; then
        error "Failed to create directory: $rules_dir"
        return 1
    fi

    # Clean up old command files
    if [[ -d "$commands_dir" ]]; then
        info "  Cleaning up old commands..."
        for old_file in "${OLD_COMMAND_FILES[@]}"; do
            rm -f "$commands_dir/$old_file"
        done
    fi

    # Install skill files
    info "  Installing skill..."
    for file in "${SKILL_FILES[@]}"; do
        local filename
        filename="$(basename "$file")"
        local dest="$skills_dir/$filename"

        if fetch_file "$file" "$dest"; then
            info "    Installed: $filename"
        else
            error "    Failed to install: $filename"
            return 1
        fi
    done

    # Install individual commands (thin wrappers that invoke the skill)
    if ! mkdir -p "$commands_dir"; then
        error "Failed to create directory: $commands_dir"
        return 1
    fi

    info "  Installing commands..."
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        local guideline_file cmd_name description
        IFS='|' read -r guideline_file cmd_name description <<< "$entry"

        local dest="$commands_dir/${cmd_name}.md"
        generate_skill_agent_command "$guideline_file" "$dest" "$description"
        info "    Installed: ${cmd_name}.md"
    done

    # Remove old monolithic rule files (legacy cleanup)
    info "  Cleaning up old rule files..."
    for old_file in "${OLD_RULE_FILES[@]}"; do
        rm -f "$rules_dir/$old_file"
    done

    info "  Skill installed to: $skills_dir"
    info "  Commands installed to: $commands_dir"
    info "  Rules directory: $rules_dir (project rules installed on demand)"
}

# Install for Gemini CLI (individual TOML commands + SKILL.md as rule)
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
        local guideline_file cmd_name description
        IFS='|' read -r guideline_file cmd_name description <<< "$entry"

        local src_path="$SKILL_DIR/$guideline_file"
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

    info "  Commands installed to: $commands_dir"
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
        local guideline_file cmd_name description
        IFS='|' read -r guideline_file cmd_name description <<< "$entry"

        local src_path="$SKILL_DIR/$guideline_file"
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

    info "  Commands installed to: $commands_dir"
    info "  Rules directory: $rules_dir (project rules installed on demand)"
}

# Install for Codex (single skill directory)
install_codex() {
    local skills_root="$HOME/.agents/skills"
    local skill_dir="$skills_root/oss-helper"
    local codex_rules_dir="$HOME/.codex/oss-helper/rules"

    info "Installing for codex..."

    if ! mkdir -p "$skill_dir"; then
        error "Failed to create directory: $skill_dir"
        return 1
    fi

    if ! mkdir -p "$codex_rules_dir"; then
        error "Failed to create directory: $codex_rules_dir"
        return 1
    fi

    # Clean up old individual skill directories
    info "  Cleaning up old skills..."
    for old_skill in "${OLD_CODEX_SKILLS[@]}"; do
        rm -rf "$skills_root/$old_skill"
    done
    # Clean up old init file
    rm -f "$HOME/.codex/oss-helper/.oss-init.md"

    # Install skill files
    info "  Installing skill..."
    for file in "${SKILL_FILES[@]}"; do
        local filename
        filename="$(basename "$file")"
        local dest="$skill_dir/$filename"

        if fetch_file "$file" "$dest"; then
            info "    Installed: $filename"
        else
            error "    Failed to install: $filename"
            return 1
        fi
    done

    info "  Skill installed to: $skill_dir"
    info "  Rules directory: $codex_rules_dir (project rules installed on demand)"
}

# Install for a specific agent
install_for_agent() {
    local agent="$1"

    case "$agent" in
        claude|bob)
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

# Main
main() {
    local agents_to_install=()

    # Parse arguments
    if [[ $# -eq 0 ]]; then
        agents_to_install=("${AGENTS[@]}")
    else
        local valid=false
        for agent in "${AGENTS[@]}"; do
            if [[ "$1" == "$agent" ]]; then
                valid=true
                break
            fi
        done

        if [[ "$valid" == "false" ]]; then
            error "Unknown agent: $1"
            echo "Valid agents: ${AGENTS[*]}"
            exit 1
        fi

        agents_to_install=("$1")
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
    echo "The OSS Helper skill is installed as background knowledge."
    echo "Just describe what you want to do (e.g., 'fix issue #42', 'review PR 15')"
    echo "and the agent will follow the appropriate guidelines automatically."
}

main "$@"
