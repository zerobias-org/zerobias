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
#
# Requirements:
#   - gh CLI installed and authenticated (`gh auth login`)
#
# The script preserves the header comments in scripts/repos.list and
# rewrites only the repo-name list below them.

set -u

ORG="zerobias-org"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$META_ROOT" || exit 1

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ gh CLI not found. Install: https://cli.github.com/" >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ gh CLI not authenticated. Run: gh auth login" >&2
    exit 1
fi

REPOS_FILE="scripts/repos.list"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "Fetching public repos from ${ORG}…"
repos=()
while IFS= read -r name; do
    [ -n "$name" ] && repos+=("$name")
done < <(gh api "orgs/$ORG/repos" --paginate \
    --jq '.[] | select(.archived == false and .visibility == "public") | .name' | sort)

if [ ${#repos[@]} -eq 0 ]; then
    echo "⚠️  gh returned 0 repos — refusing to overwrite $REPOS_FILE." >&2
    exit 1
fi

# Preserve the file's header (everything up to and including the last
# comment-only / blank line before the first repo entry).
{
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
    printf '%s\n' "${repos[@]}"
} > "$TMP_FILE"

# Diff before clobbering, so the maintainer sees what changed.
if [ -f "$REPOS_FILE" ] && diff -q "$REPOS_FILE" "$TMP_FILE" >/dev/null; then
    echo "✅ $REPOS_FILE already current (${#repos[@]} repos)."
    exit 0
fi

echo ""
echo "Changes to $REPOS_FILE:"
if [ -f "$REPOS_FILE" ]; then
    diff "$REPOS_FILE" "$TMP_FILE" || true
else
    echo "  (new file)"
fi
echo ""

mv "$TMP_FILE" "$REPOS_FILE"
trap - EXIT
echo "✅ Wrote $REPOS_FILE (${#repos[@]} repos). Review and commit when ready."
