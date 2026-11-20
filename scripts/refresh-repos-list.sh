#!/bin/bash
#
# refresh-repos-list.sh — regenerate scripts/repos.list from the live
# zerobias-org org via the GitHub CLI.
#
# This is a **maintainer** script. Regular contributors don't run it —
# they only need git + the committed scripts/repos.list. Run this when
# the org adds (or removes) a public repo and the bootstrap list needs
# to catch up.
#
# Usage:
#   ./scripts/refresh-repos-list.sh
#   ./scripts/refresh-repos-list.sh --help
#
# Requirements:
#   - gh CLI installed and authenticated (`gh auth login`)
#
# The leading comment block of scripts/repos.list is kept as-is; only
# the repo-name list below it is rewritten. If the file doesn't exist
# yet, a default header is written.

set -u

ORG="zerobias-org"
REPOS_FILE="scripts/repos.list"

usage() {
    cat <<EOF
Usage: $0

Regenerate $REPOS_FILE from the public, non-archived repos in the
$ORG GitHub org. Shows a diff before writing; never commits.

Options:
  -h, --help   Show this help
EOF
}

default_header() {
    cat <<'EOF'
# Public zerobias-org repos to clone into this meta-repo workspace.
#
# This file is the source of truth for scripts/clone-all.sh — no live
# GitHub lookup happens at clone time. Maintainers regenerate it with:
#
#   ./scripts/refresh-repos-list.sh
#
# (which uses the gh CLI to enumerate the org). Regular contributors
# don't need gh, just git.
#
# Entries listed in .repoignore (such as .github and the meta-repo
# itself) are skipped even if they appear here, so the list can mirror
# the org 1:1 without manual filtering.
#
# Format: one repo name per line. Blank lines and lines starting with
# `#` are ignored.

EOF
}

# Print the existing file's header: every comment or blank line before
# the first repo entry. Falls back to the default for a missing file.
current_header() {
    if [ -f "$REPOS_FILE" ]; then
        awk '/^[[:space:]]*(#|$)/ { print; next } { exit }' "$REPOS_FILE"
    else
        default_header
    fi
}

# Print public, non-archived repo names in the org, sorted.
fetch_repos() {
    gh api "orgs/$ORG/repos" --paginate \
        --jq '.[] | select(.archived == false and .visibility == "public") | .name' |
        LC_ALL=C sort
    # Surface gh's exit status, not sort's.
    return "${PIPESTATUS[0]}"
}

die() { echo "❌ $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

command -v gh >/dev/null 2>&1 || die "gh CLI not found. Install: https://cli.github.com/"
gh auth status >/dev/null 2>&1 || die "gh CLI not authenticated. Run: gh auth login"

echo "Fetching public repos from ${ORG}…"
repo_names="$(fetch_repos)" || die "gh api failed — leaving $REPOS_FILE untouched."
[ -n "$repo_names" ] || die "gh returned 0 repos — refusing to overwrite $REPOS_FILE."
repo_count="$(printf '%s\n' "$repo_names" | wc -l | tr -d ' ')"

# Build the new file next to the target so the final mv is an atomic
# same-filesystem rename, and so it gets normal (non-0600) permissions.
TMP_FILE="$(mktemp "$REPOS_FILE.XXXXXX")" || die "could not create temp file."
trap 'rm -f "$TMP_FILE"' EXIT
chmod 644 "$TMP_FILE"

{
    current_header
    printf '%s\n' "$repo_names"
} > "$TMP_FILE"

if [ -f "$REPOS_FILE" ] && cmp -s "$REPOS_FILE" "$TMP_FILE"; then
    echo "✅ $REPOS_FILE already current ($repo_count repos)."
    exit 0
fi

echo ""
echo "Changes to $REPOS_FILE:"
if [ -f "$REPOS_FILE" ]; then
    diff "$REPOS_FILE" "$TMP_FILE"
else
    echo "  (new file)"
fi
echo ""

mv "$TMP_FILE" "$REPOS_FILE"
trap - EXIT
echo "✅ Wrote $REPOS_FILE ($repo_count repos). Review and commit when ready."
