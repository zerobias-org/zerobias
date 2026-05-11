#!/bin/bash

# update_all.sh - Update all submodules intelligently
#
# - If on main/master:    checkout and pull latest from origin
# - If on feature branch: fetch origin, update local main/master without
#                         clobbering your working branch
# - Tracks which submodules got updated so you know what to commit
#   in the meta-repo afterwards.

set -e

# Move to repo root (script may be invoked from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

echo "========================================="
echo "Updating all submodules..."
echo "========================================="
echo ""

UPDATED_MODULES=()

# Get list of all submodules
SUBMODULES=$(git submodule status | awk '{print $2}')

if [ -z "$SUBMODULES" ]; then
    echo "ℹ️  No submodules registered yet."
    echo "    Run: git submodule update --init --recursive"
    exit 0
fi

for submodule in $SUBMODULES; do
    if [ ! -d "$submodule" ]; then
        echo "⚠️  $submodule: Directory not found, skipping"
        continue
    fi

    cd "$submodule"

    # Get current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Determine the default branch (main or master)
    git fetch origin --quiet
    DEFAULT_BRANCH=""
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        DEFAULT_BRANCH="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        DEFAULT_BRANCH="master"
    else
        echo "⚠️  $submodule: No main/master branch found, skipping"
        cd - > /dev/null
        continue
    fi

    OLD_COMMIT=$(git rev-parse HEAD)

    if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
        echo "📦 $submodule: On $DEFAULT_BRANCH, pulling latest..."

        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "   ⚠️  Uncommitted changes detected, skipping pull"
            echo "   💡 Run 'cd $submodule && git status' to see changes"
        else
            git checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
            git pull origin "$DEFAULT_BRANCH" --quiet
            NEW_COMMIT=$(git rev-parse HEAD)

            if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
                UPDATED_MODULES+=("$submodule")
                echo "   ✅ Updated: $OLD_COMMIT -> $NEW_COMMIT"
            else
                echo "   ℹ️  Already up to date"
            fi
        fi
    else
        echo "🔧 $submodule: On branch '$CURRENT_BRANCH', updating $DEFAULT_BRANCH in background..."

        git fetch origin "$DEFAULT_BRANCH:$DEFAULT_BRANCH" --quiet 2>/dev/null || \
            git fetch origin "$DEFAULT_BRANCH" --quiet

        NEW_DEFAULT_COMMIT=$(git rev-parse "origin/$DEFAULT_BRANCH")
        OLD_DEFAULT_COMMIT=$(git rev-parse "$DEFAULT_BRANCH" 2>/dev/null || echo "unknown")

        if [ "$OLD_DEFAULT_COMMIT" != "$NEW_DEFAULT_COMMIT" ]; then
            echo "   ✅ $DEFAULT_BRANCH updated: $OLD_DEFAULT_COMMIT -> $NEW_DEFAULT_COMMIT"
        else
            echo "   ℹ️  $DEFAULT_BRANCH already up to date"
        fi

        echo "   💡 Still on branch '$CURRENT_BRANCH' (unchanged)"
    fi

    cd - > /dev/null
    echo ""
done

echo "========================================="
echo "Summary"
echo "========================================="

if [ ${#UPDATED_MODULES[@]} -eq 0 ]; then
    echo "✅ All submodules already up to date"
    echo "   No meta-repo commit needed"
else
    echo "📝 Updated ${#UPDATED_MODULES[@]} submodule(s):"
    for module in "${UPDATED_MODULES[@]}"; do
        echo "   - $module"
    done
    echo ""
    echo "Next steps:"
    echo "  git status                                    # Review changes"
    echo "  git add -A                                    # Stage submodule updates"
    echo "  git commit -m 'deps: update submodules'       # Commit"
    echo "  git push                                      # Push to remote"
fi

echo ""
echo "✅ Update complete!"
