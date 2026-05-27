#!/bin/bash
#
# clone-all.sh — clone every public zerobias-org repo into this meta-repo.
#
# Discovers repos via the GitHub CLI, skips anything listed in .repoignore,
# and skips anything already cloned. Idempotent: re-running only clones repos
# that aren't already present.
#
# Usage:
#   ./scripts/clone-all.sh              # clone any missing repos
#   ./scripts/clone-all.sh --ssh        # use git@github.com:... URLs (for maintainers)
#   ./scripts/clone-all.sh --help
#
# Requirements:
#   - gh CLI installed and authenticated (`gh auth login`)
#   - git

set -u

ORG="zerobias-org"
USE_SSH=false

usage() {
    cat <<EOF
Usage: $0 [--ssh]

Clone every public $ORG repo that isn't already present in the meta-repo root.
Respects .repoignore (one repo name per line, # for comments).

Options:
  --ssh        Clone with git@github.com:... (default is HTTPS)
  -h, --help   Show this help
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

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ gh CLI not found. Install: https://cli.github.com/" >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ gh CLI not authenticated. Run: gh auth login" >&2
    exit 1
fi

# Load .repoignore (names only, ignore comments and blanks).
ignored=()
if [ -f .repoignore ]; then
    while IFS= read -r line; do
        # Strip comments and surrounding whitespace
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

echo "Discovering public repos in $ORG..."
mapfile -t all_repos < <(gh api "orgs/$ORG/repos" --paginate \
    --jq '.[] | select(.archived == false and .visibility == "public") | .name' \
    | sort)

if [ ${#all_repos[@]} -eq 0 ]; then
    echo "⚠️  No repos found (or no access)." >&2
    exit 1
fi

cloned=0
skipped_present=0
skipped_ignored=0
failed=0

for repo in "${all_repos[@]}"; do
    if is_ignored "$repo"; then
        ((skipped_ignored++))
        continue
    fi
    if [ -d "$repo/.git" ] || [ -d "$repo" ]; then
        ((skipped_present++))
        continue
    fi

    if [ "$USE_SSH" = true ]; then
        url="git@github.com:$ORG/$repo.git"
    else
        url="https://github.com/$ORG/$repo.git"
    fi

    echo "  ↳ cloning $repo"
    if git clone --quiet "$url" "$repo"; then
        ((cloned++))
    else
        echo "    ⚠️  failed to clone $repo"
        ((failed++))
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
