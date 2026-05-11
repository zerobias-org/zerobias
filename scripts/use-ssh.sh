#!/bin/bash

# use-ssh.sh - Rewrite submodule URLs from HTTPS to SSH (local only).
#
# The meta-repo ships HTTPS URLs so any outside contributor can clone and
# fetch without GitHub credentials. If you push back to the org you'll
# want SSH locally. This script updates your local .git/config (it does
# NOT change .gitmodules), so it's safe to run on a personal clone.
#
# To revert:  ./scripts/use-ssh.sh --revert

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

REVERT=false
if [ "$1" = "--revert" ] || [ "$1" = "-r" ]; then
    REVERT=true
fi

SUBMODULES=$(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

if [ -z "$SUBMODULES" ]; then
    echo "No submodules found in .gitmodules"
    exit 0
fi

for sub in $SUBMODULES; do
    https_url=$(git config --file .gitmodules "submodule.$sub.url")
    if [ "$REVERT" = true ]; then
        # SSH -> HTTPS
        new_url=$(echo "$https_url" | sed -E 's#git@github.com:#https://github.com/#')
    else
        # HTTPS -> SSH
        new_url=$(echo "$https_url" | sed -E 's#https://github.com/#git@github.com:#')
    fi
    git config "submodule.$sub.url" "$new_url"
    echo "  $sub -> $new_url"
done

git submodule sync --recursive >/dev/null
echo ""
if [ "$REVERT" = true ]; then
    echo "✅ Reverted to HTTPS submodule URLs (local only)"
else
    echo "✅ Switched to SSH submodule URLs (local only)"
fi
