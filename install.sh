#!/usr/bin/env bash
# Compatibility installer for existing automation. Prefer the Claude marketplace.
set -euo pipefail

installer_usage() {
    echo 'Usage: ./install.sh [--version TAG|--version=TAG] [agent]'
    echo 'Agents: claude bob gemini opencode codex agy (default: all)'
    echo 'Local checkout: build and copy assets. Remote: download the chosen ref (default: main).'
    echo 'OSS_HELPER_VERSION sets the ref; OSS_HELPER_ARCHIVE_URL overrides the archive URL.'
    echo 'No automatic removal: use uninstall.sh to preview legacy cleanup.'
}

# Keep dotfile-managed component roots usable, but do not overwrite linked assets.
check_install_path() {
    local path="$1" component_root="$2"
    while [[ "$path" != "$component_root" ]]; do
        [[ ! -L "$path" ]] || { echo "Refusing symlinked installation asset: $path" >&2; return 1; }
        path="${path%/*}"
    done
}

install_component() {
    local source="$1" destination="$2"
    [[ -d "$source" ]] || return 0
    mkdir -p "$destination"
    cp -R "$source/." "$destination/"
}

installer_main() {
    local selected='' ref="${OSS_HELPER_VERSION:-main}" remote=false arg agent valid=false
    local local_root='' archive_url staging source_dir output base skills component path destination
    local targets=(claude bob gemini opencode codex agy)
    [[ -z "${OSS_HELPER_VERSION:-}" && -z "${OSS_HELPER_ARCHIVE_URL:-}" ]] || remote=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) installer_usage; return 0 ;;
            --version)
                [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || { echo '--version requires a ref' >&2; return 1; }
                ref="$2"; remote=true; shift 2 ;;
            --version=*) ref="${1#*=}"; [[ -n "$ref" ]] || { echo '--version requires a ref' >&2; return 1; }; remote=true; shift ;;
            -*) installer_usage >&2; return 1 ;;
            *) [[ -z "$selected" && -n "$1" ]] || { installer_usage >&2; return 1; }; selected="$1"; shift ;;
        esac
    done
    if [[ -n "$selected" ]]; then
        for agent in "${targets[@]}"; do [[ "$agent" != "$selected" ]] || valid=true; done
        [[ "$valid" == true ]] || { echo "Unknown agent: $selected" >&2; return 1; }
        targets=("$selected")
    fi
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        local_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    staging="$(mktemp -d)"
    installer_staging="$staging"
    trap 'rm -rf -- "$installer_staging"' EXIT
    if [[ "$remote" == true || -z "$local_root" || ! -f "$local_root/build.sh" || ! -f "$local_root/skills/oss-issues/SKILL.md" || ! -f "$local_root/packaging/claude-plugin.json" ]]; then
        archive_url="${OSS_HELPER_ARCHIVE_URL:-https://codeload.github.com/Open-Harness-Engineering/ai-agents-oss-helper/tar.gz/$ref}"
        if command -v curl > /dev/null 2>&1; then
            curl -fsSL "$archive_url" -o "$staging/source.tar.gz"
        elif command -v wget > /dev/null 2>&1; then
            wget -q "$archive_url" -O "$staging/source.tar.gz"
        else
            echo 'curl or wget is required to download OSS Helper' >&2; return 1
        fi
        source_dir="$staging/source"
        mkdir -p "$source_dir"
        tar -xzf "$staging/source.tar.gz" -C "$source_dir" --strip-components=1
        [[ -f "$source_dir/install.sh" ]] || { echo 'Archive has no install.sh' >&2; return 1; }
        if [[ ! -f "$source_dir/build.sh" ]]; then
            # Old tags retain their original installer and its ref semantics.
            if [[ -n "$selected" ]]; then
                OSS_HELPER_VERSION="$ref" OSS_HELPER_ARCHIVE_URL='' bash "$source_dir/install.sh" "$selected"
            else
                OSS_HELPER_VERSION="$ref" OSS_HELPER_ARCHIVE_URL='' bash "$source_dir/install.sh"
            fi
        elif [[ -n "$selected" ]]; then
            OSS_HELPER_VERSION='' OSS_HELPER_ARCHIVE_URL='' bash "$source_dir/install.sh" "$selected"
        else
            OSS_HELPER_VERSION='' OSS_HELPER_ARCHIVE_URL='' bash "$source_dir/install.sh"
        fi
        return
    fi
    source "$local_root/build.sh"
    # Assemble every requested target before changing any agent installation.
    for agent in "${targets[@]}"; do
        output="$staging/$agent"
        bash "$local_root/build.sh" --output-dir "$output" "$agent"
        if [[ "$agent" == claude ]]; then
            for arg in "${GUIDELINE_COMMANDS[@]}"; do
                local skill guideline command description
                IFS='|' read -r skill guideline command description <<< "$arg"
                generate_skill_agent_command claude "$skill" "$guideline" "$output/commands/$command.md" "$description" legacy
            done
            for arg in "${WORKFLOW_FILES[@]}"; do cp "$local_root/$arg" "$output/$arg"; done
        fi
    done
    # Preflight every destination before copying any target.
    for agent in "${targets[@]}"; do
        output="$staging/$agent"
        if [[ "$agent" == opencode ]]; then base="$HOME/.config/opencode"; else base="$HOME/.$agent"; fi
        for component in skills commands agents workflows; do
            [[ -d "$output/$component" ]] || continue
            destination="$base/$component"
            [[ "$agent:$component" != codex:skills ]] || destination="$HOME/.agents/skills"
            while IFS= read -r -d '' path; do
                check_install_path "$destination${path#"$output/$component"}" "$destination"
            done < <(find "$output/$component" -print0)
        done
    done
    for agent in "${targets[@]}"; do
        output="$staging/$agent"
        if [[ "$agent" == opencode ]]; then base="$HOME/.config/opencode"; else base="$HOME/.$agent"; fi
        skills="$base/skills"
        [[ "$agent" != codex ]] || skills="$HOME/.agents/skills"
        install_component "$output/skills" "$skills"
        for component in commands agents workflows; do install_component "$output/$component" "$base/$component"; done
        printf 'Installed OSS Helper for %s\n' "$agent"
    done
}
installer_main "$@"
