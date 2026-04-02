#!/usr/bin/env bash
#
# Install script for AI Agent OSS Helper commands
#
# Usage:
#   git clone https://github.com/orpiske/ai-agents-oss-helper.git ~/.oss-helper
#   ~/.oss-helper/install.sh              # Install to all agents (claude, bob, gemini, opencode, codex)
#   ~/.oss-helper/install.sh claude       # Install to claude only
#   ~/.oss-helper/install.sh bob          # Install to bob only
#   ~/.oss-helper/install.sh gemini       # Install to gemini only
#   ~/.oss-helper/install.sh opencode     # Install to opencode only
#   ~/.oss-helper/install.sh codex        # Install to codex only
#

set -euo pipefail

# Configuration
REPO_URL="${REPO_URL:-https://github.com/Open-Harness-Engineering/ai-agents-oss-helper.git}"
INSTALL_DIR="$HOME/.oss-helper"
AGENTS=("claude" "bob" "gemini" "opencode" "codex")

# Command files to install (relative paths from repo root)
COMMAND_FILES=(
    "commands/.oss-init.md"
    "commands/oss-add-project.md"
    "commands/oss-fix-issue.md"
    "commands/oss-review-pr.md"
    "commands/oss-find-task.md"
    "commands/oss-create-issue.md"
    "commands/oss-quick-fix.md"
    "commands/oss-analyze-issue.md"
    "commands/oss-fix-sonarcloud.md"
    "commands/oss-update-knowledge.md"
    "commands/oss-fix-ci-errors.md"
    "commands/oss-fix-backlog-task.md"
    "commands/oss-pr-status.md"
    "commands/oss-list-pr-status.md"
    "commands/oss-backport-pr.md"
    "commands/oss-self-update.md"
)

# Rule files to install (relative paths from repo root)
RULE_FILES=(
    "rules/wanaku/project-info.md"
    "rules/wanaku/project-standards.md"
    "rules/wanaku/project-guidelines.md"
    "rules/wanaku-capabilities-java-sdk/project-info.md"
    "rules/wanaku-capabilities-java-sdk/project-standards.md"
    "rules/wanaku-capabilities-java-sdk/project-guidelines.md"
    "rules/camel-integration-capability/project-info.md"
    "rules/camel-integration-capability/project-standards.md"
    "rules/camel-integration-capability/project-guidelines.md"
    "rules/camel-core/project-info.md"
    "rules/camel-core/project-standards.md"
    "rules/camel-core/project-guidelines.md"
    "rules/camel-quarkus/project-info.md"
    "rules/camel-quarkus/project-standards.md"
    "rules/camel-quarkus/project-guidelines.md"
    "rules/camel-spring-boot/project-info.md"
    "rules/camel-spring-boot/project-standards.md"
    "rules/camel-spring-boot/project-guidelines.md"
    "rules/camel-kafka-connector/project-info.md"
    "rules/camel-kafka-connector/project-standards.md"
    "rules/camel-kafka-connector/project-guidelines.md"
    "rules/camel-k/project-info.md"
    "rules/camel-k/project-standards.md"
    "rules/camel-k/project-guidelines.md"
    "rules/hawtio/project-info.md"
    "rules/hawtio/project-standards.md"
    "rules/hawtio/project-guidelines.md"
    "rules/kaoto/project-info.md"
    "rules/kaoto/project-standards.md"
    "rules/kaoto/project-guidelines.md"
    "rules/forage/project-info.md"
    "rules/forage/project-standards.md"
    "rules/forage/project-guidelines.md"
    "rules/ai-agents-oss-helper/project-info.md"
    "rules/ai-agents-oss-helper/project-standards.md"
    "rules/ai-agents-oss-helper/project-guidelines.md"
    "rules/generic-github/project-info.md"
    "rules/generic-github/project-standards.md"
    "rules/generic-github/project-guidelines.md"
)

# Old rule files to clean up (relative paths under rules/)
OLD_RULE_FILES=(
    "project-info.md"
    "project-standards.md"
    "project-guidelines.md"
)

# Old command files to clean up (basenames only)
OLD_COMMAND_FILES=(
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

# Ensure the repository is available at INSTALL_DIR
ensure_repo() {
    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    if [[ -n "$script_dir" ]] && [[ -d "$script_dir/.git" ]]; then
        # Running from a local git clone
        local resolved_script resolved_install
        resolved_script="$(cd "$script_dir" && pwd -P)"
        resolved_install="$(cd "$INSTALL_DIR" 2>/dev/null && pwd -P 2>/dev/null || echo "")"

        if [[ "$resolved_script" != "$resolved_install" ]]; then
            # Script is not at INSTALL_DIR — link INSTALL_DIR to the clone
            if [[ -L "$INSTALL_DIR" ]]; then
                rm "$INSTALL_DIR"
            elif [[ -d "$INSTALL_DIR" ]]; then
                warn "$INSTALL_DIR already exists. Backing up to ${INSTALL_DIR}.bak"
                mv "$INSTALL_DIR" "${INSTALL_DIR}.bak"
            fi
            ln -s "$script_dir" "$INSTALL_DIR"
            info "Linked $INSTALL_DIR -> $script_dir"
        fi
    elif [[ -d "$INSTALL_DIR/.git" ]] || { [[ -L "$INSTALL_DIR" ]] && [[ -d "$(readlink -f "$INSTALL_DIR" 2>/dev/null)/.git" ]]; }; then
        # INSTALL_DIR already has a repo, pull updates
        info "Updating repository..."
        git -C "$INSTALL_DIR" pull --quiet
    else
        # First-time install: clone the repo
        info "Cloning repository to $INSTALL_DIR..."
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
}

# Copy a file from the install directory
fetch_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "$INSTALL_DIR/$src" ]]; then
        cp "$INSTALL_DIR/$src" "$dest"
        return 0
    fi

    error "Source file not found: $INSTALL_DIR/$src"
    return 1
}

# Create a symlink to a file in the install directory
link_file() {
    local src="$1"
    local dest="$2"

    # Resolve INSTALL_DIR to an absolute path (follow symlinks)
    local abs_install_dir
    abs_install_dir="$(cd "$INSTALL_DIR" && pwd -P)"

    if [[ -f "$abs_install_dir/$src" ]]; then
        ln -sf "$abs_install_dir/$src" "$dest"
        return 0
    fi

    error "Source file not found: $abs_install_dir/$src"
    return 1
}

# Create a symlink to a directory in the install directory
link_dir() {
    local src="$1"
    local dest="$2"

    # Resolve INSTALL_DIR to an absolute path (follow symlinks)
    local abs_install_dir
    abs_install_dir="$(cd "$INSTALL_DIR" && pwd -P)"

    if [[ -d "$abs_install_dir/$src" ]]; then
        # Remove existing target (file, symlink, or directory)
        if [[ -L "$dest" ]] || [[ -e "$dest" ]]; then
            rm -rf "$dest"
        fi
        ln -s "$abs_install_dir/$src" "$dest"
        return 0
    fi

    error "Source directory not found: $abs_install_dir/$src"
    return 1
}

# Convert a .md command file to Gemini CLI .toml format
convert_md_to_toml() {
    local src="$1"
    local dest="$2"
    local description
    description="$(sed -n '3p' "$src")"
    {
        printf 'description = "%s"\n' "$description"
        printf "prompt = '''\n"
        printf 'Note: Project rule files are installed at ~/.gemini/rules/<project-directory>/ with files: project-info.md, project-standards.md, project-guidelines.md. Read these files to get project-specific configuration after detecting the project.\n\n'
        cat "$src"
        printf "\n'''\n"
    } > "$dest"
}

# Convert a .md command file to OpenCode markdown with frontmatter
convert_md_to_opencode_md() {
    local src="$1"
    local dest="$2"
    local first_non_empty
    local description

    first_non_empty="$(awk 'NF { print; exit }' "$src")"
    if [[ "$first_non_empty" == "---" ]]; then
        cp "$src" "$dest"
        return 0
    fi

    description="$(awk '
        /^#/ { next }
        NF { print; exit }
    ' "$src")"

    if [[ -z "$description" ]]; then
        description="OSS Helper command"
    fi

    # Escape quotes and backslashes for YAML
    description="$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/\"/\\\"/g')"

    {
        printf -- "---\n"
        printf 'description: "%s"\n' "$description"
        printf -- "---\n\n"
        cat "$src"
    } > "$dest"
}

# Convert a .md command file to Codex skill format
convert_md_to_codex_skill() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local description

    description="$(awk '
        /^#/ { next }
        NF { print; exit }
    ' "$src")"

    if [[ -z "$description" ]]; then
        description="OSS Helper command"
    fi

    # Escape quotes and backslashes for YAML
    description="$(printf '%s' "$description" | sed 's/\\/\\\\/g; s/\"/\\\"/g')"

    {
        printf -- "---\n"
        printf 'name: %s\n' "$name"
        printf 'description: "%s"\n' "$description"
        printf -- "---\n\n"
        printf 'Before you begin, read and follow the OSS Helper init file at ~/.codex/oss-helper/.oss-init.md.\n\n'
        printf 'Invoke this skill by typing `$%s`.\n\n' "$name"
        cat "$src"
    } > "$dest"
}

# Install commands for a specific agent
install_for_agent() {
    local agent="$1"
    local commands_dir="$HOME/.$agent/commands"
    local rules_dir="$HOME/.$agent/rules"
    local use_symlinks=false

    if [[ "$agent" == "claude" || "$agent" == "bob" ]]; then
        use_symlinks=true
    fi

    if [[ "$agent" == "opencode" ]]; then
        commands_dir="$HOME/.config/opencode/commands"
        rules_dir="$HOME/.config/opencode/rules"
    fi

    if [[ "$agent" == "codex" ]]; then
        local skills_root="$HOME/.agents/skills"
        local codex_base="$HOME/.codex/oss-helper"
        local codex_rules_dir="$codex_base/rules"

        info "Installing for codex..."

        if ! mkdir -p "$skills_root"; then
            error "Failed to create directory: $skills_root"
            return 1
        fi

        if ! mkdir -p "$codex_rules_dir"; then
            error "Failed to create directory: $codex_rules_dir"
            return 1
        fi

        # Install shared init file
        if ! fetch_file "commands/.oss-init.md" "$codex_base/.oss-init.md"; then
            error "Failed to install: .oss-init.md"
            return 1
        fi

        # Install skills
        info "  Installing skills..."
        for file in "${COMMAND_FILES[@]}"; do
            local filename
            filename="$(basename "$file")"

            # Skip the shared init file (installed separately)
            if [[ "$filename" == ".oss-init.md" ]]; then
                continue
            fi

            local skill_name="${filename%.md}"
            local skill_dir="$skills_root/$skill_name"
            local skill_dest="$skill_dir/SKILL.md"
            local tmp_md

            rm -rf "$skill_dir"
            mkdir -p "$skill_dir"
            tmp_md="$(mktemp)"

            if fetch_file "$file" "$tmp_md"; then
                convert_md_to_codex_skill "$tmp_md" "$skill_dest" "$skill_name"
                rm -f "$tmp_md"
                info "    Installed skill: $skill_name"
            else
                rm -f "$tmp_md"
                error "    Failed to install skill: $skill_name"
                return 1
            fi
        done

        # Install rule files (with subdirectories)
        info "  Installing rules..."
        for file in "${RULE_FILES[@]}"; do
            local rel_path="${file#rules/}"
            local dest="$codex_rules_dir/$rel_path"
            local dest_dir
            dest_dir="$(dirname "$dest")"

            mkdir -p "$dest_dir"

            if fetch_file "$file" "$dest"; then
                info "    Installed: $rel_path"
            else
                error "    Failed to install: $rel_path"
                return 1
            fi
        done

        info "  Skills installed to: $skills_root"
        info "  Rules installed to: $codex_rules_dir"
        info "  Init file installed to: $codex_base/.oss-init.md"
        return 0
    fi

    info "Installing for $agent..."

    # Create target directories
    if ! mkdir -p "$commands_dir"; then
        error "Failed to create directory: $commands_dir"
        return 1
    fi

    if ! mkdir -p "$rules_dir"; then
        error "Failed to create directory: $rules_dir"
        return 1
    fi

    # Remove old command files
    info "  Cleaning up old commands..."
    for old_file in "${OLD_COMMAND_FILES[@]}"; do
        rm -f "$commands_dir/$old_file"
        # For gemini, also clean up .toml variants of old commands
        if [[ "$agent" == "gemini" ]]; then
            rm -f "$commands_dir/${old_file%.md}.toml"
        fi
    done

    # Install new command files
    info "  Installing commands..."
    for file in "${COMMAND_FILES[@]}"; do
        local filename
        filename="$(basename "$file")"

        if [[ "$agent" == "gemini" ]]; then
            # Gemini uses TOML commands: fetch .md to temp, convert to .toml
            local toml_name="${filename%.md}.toml"
            local dest="$commands_dir/$toml_name"
            local tmp_md
            tmp_md="$(mktemp)"

            if fetch_file "$file" "$tmp_md"; then
                convert_md_to_toml "$tmp_md" "$dest"
                rm -f "$tmp_md"
                # Remove any stale .md copy in gemini commands dir
                rm -f "$commands_dir/$filename"
                info "    Installed: $toml_name"
            else
                rm -f "$tmp_md"
                error "    Failed to install: $toml_name"
                return 1
            fi
        elif [[ "$agent" == "opencode" ]]; then
            # OpenCode uses markdown with frontmatter in ~/.config/opencode/commands
            local dest="$commands_dir/$filename"
            local tmp_md
            tmp_md="$(mktemp)"

            if fetch_file "$file" "$tmp_md"; then
                convert_md_to_opencode_md "$tmp_md" "$dest"
                rm -f "$tmp_md"
                info "    Installed: $filename"
            else
                rm -f "$tmp_md"
                error "    Failed to install: $filename"
                return 1
            fi
        elif [[ "$use_symlinks" == "true" ]]; then
            # Claude/Bob: create symlinks for instant updates
            local dest="$commands_dir/$filename"
            if link_file "$file" "$dest"; then
                info "    Linked: $filename"
            else
                error "    Failed to link: $filename"
                return 1
            fi
        else
            local dest="$commands_dir/$filename"
            if fetch_file "$file" "$dest"; then
                info "    Installed: $filename"
            else
                error "    Failed to install: $filename"
                return 1
            fi
        fi
    done

    # Remove old monolithic rule files
    info "  Cleaning up old rule files..."
    for old_file in "${OLD_RULE_FILES[@]}"; do
        rm -f "$rules_dir/$old_file"
    done

    # Install rule files
    info "  Installing rules..."
    if [[ "$use_symlinks" == "true" ]]; then
        # Claude/Bob: symlink entire project directories for instant updates
        local -A linked_projects
        for file in "${RULE_FILES[@]}"; do
            local project
            project="$(echo "${file#rules/}" | cut -d'/' -f1)"
            if [[ -z "${linked_projects[$project]:-}" ]]; then
                if link_dir "rules/$project" "$rules_dir/$project"; then
                    info "    Linked: $project/"
                else
                    error "    Failed to link: $project/"
                    return 1
                fi
                linked_projects[$project]=1
            fi
        done
    else
        for file in "${RULE_FILES[@]}"; do
            local rel_path="${file#rules/}"
            local dest="$rules_dir/$rel_path"
            local dest_dir
            dest_dir="$(dirname "$dest")"

            mkdir -p "$dest_dir"

            if fetch_file "$file" "$dest"; then
                info "    Installed: $rel_path"
            else
                error "    Failed to install: $rel_path"
                return 1
            fi
        done
    fi

    if [[ "$use_symlinks" == "true" ]]; then
        info "  Commands linked to: $commands_dir (symlinks -> $INSTALL_DIR)"
        info "  Rules linked to: $rules_dir (symlinks -> $INSTALL_DIR)"
    else
        info "  Commands installed to: $commands_dir"
        info "  Rules installed to: $rules_dir"
    fi
}

# Main
main() {
    local agents_to_install=()

    # Parse arguments
    if [[ $# -eq 0 ]]; then
        # No arguments: install for all agents
        agents_to_install=("${AGENTS[@]}")
    else
        # Validate agent argument
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

    # Ensure the git repository is available
    ensure_repo

    # Install for each agent
    for agent in "${agents_to_install[@]}"; do
        install_for_agent "$agent"
        echo ""
    done

    info "Installation complete!"
    echo ""
    echo "Available commands:"
    for file in "${COMMAND_FILES[@]}"; do
        local filename
        filename="$(basename "$file" .md)"
        # Skip hidden preamble files (not user-invocable)
        [[ "$filename" == .* ]] && continue
        echo "  /$filename"
    done
}

main "$@"
