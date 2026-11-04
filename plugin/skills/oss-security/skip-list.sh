#!/usr/bin/env bash
# skip-list.sh: query and extend skip_cves_apache_unmappable.txt (update-gh-advisory-db.md) without
# reading the whole list into the conversation.
#
#   bash skip-list.sh filter < candidates   print the input lines whose CVE id is not on the list
#                                           (lines without a CVE id pass through), and on stderr
#                                           how many were dropped
#   bash skip-list.sh has <CVE-ID>          exit 0 and print the entry when the id is listed, else exit 1
#   bash skip-list.sh add <CVE-ID> <reason> append "<CVE-ID>  # <reason>" unless the id is listed
#
# The list is the one next to this script, or --list <file> / $OSS_SKIP_LIST. The installed copy is
# replaced on every install: commit new entries to skills/oss-security/skip_cves_apache_unmappable.txt
# in the helper's repository too (or point --list at that file in a checkout).
set -u

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0" >&2
    exit 2
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift
list="${OSS_SKIP_LIST:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skip_cves_apache_unmappable.txt}"
args=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) list="${2:-}"; shift 2 ;;
        *) args="$args
$1"; shift ;;
    esac
done
arg1="$(printf '%s\n' "$args" | sed -n 2p)"
arg2="$(printf '%s\n' "$args" | sed -n 3p)"

if [ ! -f "$list" ]; then
    echo "ERROR skip list not found: $list" >&2
    exit 1
fi

# normalize <id>: upper case, and it has to look like a CVE id.
normalize() {
    local id
    id="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
    case "$id" in
        CVE-[0-9][0-9][0-9][0-9]-[0-9]*) printf '%s' "$id" ;;
        *) echo "ERROR not a CVE id: $1" >&2; exit 2 ;;
    esac
}

case "$cmd" in
    filter)
        awk '
            NR == FNR { if (toupper($1) ~ /^CVE-[0-9]+-[0-9]+$/) skip[toupper($1)] = 1; next }
            {
                line = toupper($0)
                if (match(line, /CVE-[0-9]+-[0-9]+/) && (substr(line, RSTART, RLENGTH) in skip)) { dropped++; next }
                print
            }
            END { printf "skip-list: %d candidate(s) dropped\n", dropped > "/dev/stderr" }
        ' "$list" -
        ;;
    has)
        id="$(normalize "$arg1")" || exit 2
        awk -v id="$id" 'toupper($1) == id { print; found = 1; exit } END { exit !found }' "$list"
        ;;
    add)
        id="$(normalize "$arg1")" || exit 2
        reason="$(printf '%s' "$arg2" | tr '\n' ' ' | sed 's/ *$//')"
        [ -n "$reason" ] || { echo "ERROR add needs a reason" >&2; exit 2; }
        if awk -v id="$id" 'toupper($1) == id { found = 1; exit } END { exit !found }' "$list"; then
            echo "already listed: $(awk -v id="$id" 'toupper($1) == id { print; exit }' "$list")"
            exit 0
        fi
        # The file may lack a final newline; never glue the new entry to the last line.
        if [ -s "$list" ] && [ "$(tail -c 1 "$list" | od -An -c | tr -d ' ')" != '\n' ]; then
            printf '\n' >> "$list"
        fi
        printf '%s  # %s\n' "$id" "$reason" >> "$list"
        echo "added: $id  # $reason"
        ;;
    *) usage ;;
esac
