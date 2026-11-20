# shellcheck shell=bash
#
# Shared parsing for the meta-repo's name-list files (scripts/repos.list,
# .repoignore). Source this file; don't execute it.
#
# Format: one name per line. `#` starts a comment (whole-line or trailing),
# surrounding whitespace is trimmed, and blank lines are skipped.

# read_name_list FILE — print each name in FILE on its own line.
# A missing FILE prints nothing.
read_name_list() {
    local file="$1" line
    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -n "$line" ] && printf '%s\n' "$line"
    done < "$file"
}

# read_list_header FILE — print FILE's leading block of comment and blank
# lines, stopping before the first entry.
read_list_header() {
    awk '/^[[:space:]]*(#|$)/ { print; next } { exit }' "$1"
}
