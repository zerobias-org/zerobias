#!/bin/bash
#
# clone-all.sh — clone every public zerobias-org repo listed in
# scripts/repos.list into this meta-repo root.
#
# Reads the canonical list from scripts/repos.list (no live GitHub
# lookup), skips anything in .repoignore, and skips repos that are
# already cloned. Idempotent: re-running only clones what's missing.
#
# Usage:
#   ./scripts/clone-all.sh              # clone any missing repos
#   ./scripts/clone-all.sh --ssh        # use git@github.com:... URLs
#   ./scripts/clone-all.sh --help
#
# Requirements:
#   - git  (that's it — no gh, no curl)

set -u

ORG="zerobias-org"
USE_SSH=false

usage() {
    cat <<EOF
Usage: $0 [--ssh]

Clone every public $ORG repo listed in scripts/repos.list, skipping
anything already present or listed in .repoignore.

Options:
  --ssh        Clone with git@github.com:... (default is HTTPS)
  -h, --help   Show this help

To refresh the list when the org adds a new repo, maintainers run
./scripts/refresh-repos-list.sh (which uses gh).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ssh) USE_SSH=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

if ! command -v git >/dev/null 2>&1; then
    echo "❌ git not found. Install git first." >&2
    exit 1
fi

REPOS_FILE="scripts/repos.list"
if [ ! -f "$REPOS_FILE" ]; then
    echo "❌ Missing $REPOS_FILE. Run scripts/refresh-repos-list.sh (maintainer) to generate it." >&2
    exit 1
fi

# Load .repoignore (names only, ignore comments and blanks).
ignored=()
if [ -f .repoignore ]; then
    while IFS= read -r line; do
        name="${line%%#*}"
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        [ -n "$name" ] && ignored+=("$name")
    done < .repoignore
fi

is_ignored() {
    local target="$1"
    for n in "${ignored[@]}"; do
        [ "$n" = "$target" ] && return 0
    done
    return 1
}

# Read repos.list, stripping comments + blanks.
repos=()
while IFS= read -r line; do
    name="${line%%#*}"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [ -n "$name" ] && repos+=("$name")
done < "$REPOS_FILE"

if [ ${#repos[@]} -eq 0 ]; then
    echo "⚠️  $REPOS_FILE is empty." >&2
    exit 1
fi

echo "Cloning from $REPOS_FILE (${#repos[@]} entries before filtering)…"

cloned=0
skipped_present=0
skipped_ignored=0
failed=0

for repo in "${repos[@]}"; do
    if is_ignored "$repo"; then
        ((skipped_ignored++)) || true
        continue
    fi
    if [ -d "$repo/.git" ] || [ -d "$repo" ]; then
        ((skipped_present++)) || true
        continue
    fi

    if [ "$USE_SSH" = true ]; then
        url="git@github.com:$ORG/$repo.git"
    else
        url="https://github.com/$ORG/$repo.git"
    fi

    echo "  ↳ cloning $repo"
    if git clone --quiet "$url" "$repo"; then
        ((cloned++)) || true
    else
        echo "    ⚠️  failed to clone $repo"
        ((failed++)) || true
    fi
done

echo ""
echo "Summary:"
echo "  cloned:           $cloned"
echo "  already present:  $skipped_present"
echo "  ignored:          $skipped_ignored"
[ $failed -gt 0 ] && echo "  failed:           $failed"

if [ $failed -gt 0 ]; then
    exit 1
fi
