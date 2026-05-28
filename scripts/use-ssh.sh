#!/bin/bash
#
# use-ssh.sh — rewrite every sub-repo's origin URL from HTTPS to SSH (or back).
#
# Sub-repos are cloned over HTTPS by default (zero-credential read access for
# any contributor). Maintainers who push back to the org want SSH locally;
# this script flips every cloned sub-repo's `origin` remote between the two.
#
# Usage:
#   ./scripts/use-ssh.sh             # HTTPS  -> SSH
#   ./scripts/use-ssh.sh --revert    # SSH    -> HTTPS

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$META_ROOT" || exit 1

REVERT=false
if [ "${1:-}" = "--revert" ] || [ "${1:-}" = "-r" ]; then
    REVERT=true
fi

META_OWN_DIRS=(.claude .github docs scripts)
is_meta_own() {
    local d="$1"
    for own in "${META_OWN_DIRS[@]}"; do
        [ "$d" = "$own" ] && return 0
    done
    return 1
}

count=0
for entry in */ .[!.]*/; do
    [ -d "$entry" ] || continue
    name="${entry%/}"
    is_meta_own "$name" && continue
    [ -e "$name/.git" ] || continue

    cd "$META_ROOT/$name" || continue
    old_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$old_url" ]; then
        cd "$META_ROOT"; continue
    fi

    if [ "$REVERT" = true ]; then
        new_url=$(echo "$old_url" | sed -E 's#git@github.com:#https://github.com/#')
    else
        new_url=$(echo "$old_url" | sed -E 's#https://github.com/#git@github.com:#')
    fi

    if [ "$old_url" != "$new_url" ]; then
        git remote set-url origin "$new_url"
        echo "  $name → $new_url"
        ((count++)) || true
    fi
    cd "$META_ROOT"
done

if [ "$REVERT" = true ]; then
    echo ""
    echo "✅ Reverted $count remote(s) to HTTPS"
else
    echo ""
    echo "✅ Switched $count remote(s) to SSH"
fi
