#!/usr/bin/env bash
# Remove known legacy OSS Helper assets, preserving project rules and case data.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build.sh"

remove_asset() {
    local path="$1" seen
    for seen in "${listed_assets[@]+"${listed_assets[@]}"}"; do [[ "$seen" != "$path" ]] || return 0; done
    [[ -e "$path" || -L "$path" ]] || return 0
    listed_assets+=("$path")
    printf '%s %s\n' "$action" "$path"
    if [[ "$apply" == true ]]; then rm -rf -- "$path"; fi
}

uninstall_agent() {
    local agent="$1" root skills entry skill guideline command description file
    case "$agent" in
        opencode) root="$HOME/.config/opencode" ;;
        *) root="$HOME/.$agent" ;;
    esac
    skills="$root/skills"
    [[ "$agent" != codex ]] || skills="$HOME/.agents/skills"
    # Never traverse a symlinked installation root or component directory.
    if [[ -L "$HOME/.config" && "$agent" == opencode ]] || [[ -L "$HOME/.agents" && "$agent" == codex ]] || [[ -L "$root" || -L "$skills" || -L "$root/commands" || -L "$root/agents" || -L "$root/workflows" || -L "$root/oss-helper" ]]; then
        echo "Refusing symlinked installation directories for $agent" >&2
        return 1
    fi
    for skill in "${SKILL_DIRS[@]}" "${OLD_SKILL_DIRS[@]}"; do remove_asset "$skills/$skill"; done
    if [[ "$agent" == codex ]]; then
        for skill in "${OLD_CODEX_SKILLS[@]}"; do remove_asset "$skills/$skill"; done
        for skill in README _common-init _build-workflow; do
            if [[ -f "$skills/$skill/SKILL.md" ]] && grep -Fq 'Before you begin, read and follow the OSS Helper init file at ~/.codex/oss-helper/.oss-init.md.' "$skills/$skill/SKILL.md"; then
                remove_asset "$skills/$skill"
            fi
        done
    fi
    for file in "${OLD_COMMAND_FILES[@]}"; do
        remove_asset "$root/commands/$file"
        [[ "$agent" != gemini ]] || remove_asset "$root/commands/${file%.md}.toml"
    done
    for entry in "${GUIDELINE_COMMANDS[@]}"; do
        IFS='|' read -r skill guideline command description <<< "$entry"
        remove_asset "$root/commands/$command.md"
        [[ "$agent" != gemini ]] || remove_asset "$root/commands/$command.toml"
    done
    for file in "${AGENT_FILES[@]}"; do
        file="$(basename "$file")"
        [[ "$agent" != codex ]] || file="${file%.md}.toml"
        remove_asset "$root/agents/$file"
    done
    if [[ "$agent" == claude ]]; then
        for file in "${WORKFLOW_FILES[@]}"; do remove_asset "$root/$file"; done
    fi
    remove_asset "$root/oss-helper/.oss-init.md"
    remove_asset "$root/commands/.oss-init.md"
}

main() {
    local apply=false action='Would remove' selected='' agent valid=false
    local targets=("${AGENTS[@]}")
    local listed_assets=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes) apply=true; action='Removing'; shift ;;
            --dry-run) apply=false; action='Would remove'; shift ;;
            -h|--help)
                echo 'Usage: ./uninstall.sh [--yes|--dry-run] [agent]'
                echo 'Default: preview legacy OSS Helper removal for all agents.'
                echo 'Preserves project rules, case data, unrelated assets and marketplace plugins.'
                return 0 ;;
            -*) echo "Unknown option: $1" >&2; return 1 ;;
            *) [[ -z "$selected" ]] || { echo 'Expected one agent' >&2; return 1; }; selected="$1"; shift ;;
        esac
    done
    if [[ -n "$selected" ]]; then
        for agent in "${AGENTS[@]}"; do
            if [[ "$selected" == "$agent" ]]; then valid=true; break; fi
        done
        [[ "$valid" == true ]] || { echo "Unknown agent: $selected" >&2; return 1; }
        targets=("$selected")
    fi
    for agent in "${targets[@]}"; do uninstall_agent "$agent"; done
}
main "$@"
