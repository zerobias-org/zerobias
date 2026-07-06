#!/usr/bin/env bash
#
# all_repos.sh — holistic status/checkout/push/remote-ssh helper for a folder of git repos
#
# Usage:
#   ./all_repos.sh status      /path/to/zerobias-repos   [--include-root]
#   ./all_repos.sh checkout    /path/to/zerobias-repos   <branch-name> [--include-root]
#   ./all_repos.sh push        /path/to/zerobias-repos   [commit message] [--include-root]
#   ./all_repos.sh remote-ssh  /path/to/zerobias-repos   [--include-root]
#
# Root-folder handling:
#   By default the ROOT folder itself is EXCLUDED even if it is a git repo
#   (e.g. the "zerobias" launcher repo) — only its immediate sub-repos are
#   processed. Pass --include-root to also treat ROOT as one of the repos.
#   --exclude-root is accepted too, as an explicit no-op, for clarity in
#   scripts/aliases.
#
# Repo detection:
#   A directory counts as a "repo" only if it has its own .git entry
#   (directory for a normal clone, or file for a submodule gitlink). Ordinary
#   subfolders that are just part of a parent repo's own tree (no .git of
#   their own) are never picked up — presence of .git is the only signal
#   used, not folder naming or nesting depth.
#
# "status" mode: walks every matching repo and prints branch, modified/
#   untracked files. Makes NO changes. Use this pass to spot files that
#   belong in .gitignore before you commit.
#
# "checkout" mode: for every repo, gets <branch-name> checked out using this
#   precedence (defensive, no destructive surprises):
#     1. local branch <branch-name> exists       -> git checkout <branch-name>
#     2. remote branch origin/<branch-name>       -> fetch + checkout tracking it
#     3. neither exists                           -> git checkout -b <branch-name>
#   Refuses to switch branches in a repo with uncommitted changes (prints a
#   warning and skips that repo) so nothing gets silently carried over or lost.
#
# "push" mode: for every repo with changes, ensures a local "dev" branch
#   exists (creating it from the current branch if needed), stages tracked
#   changes, commits, and pushes to origin/dev (creating the upstream if
#   needed). Skips repos with nothing to commit. Prompts once per repo
#   with uncommitted changes so you don't accidentally push something you
#   haven't reviewed.
#
# "remote-ssh" mode: for every repo whose "origin" remote uses an
#   https://HOST/OWNER/REPO(.git) URL, rewrites it to the equivalent
#   git@HOST:OWNER/REPO.git SSH form. Repos already on SSH (or using some
#   other scheme) are reported and left untouched. Prompts once per repo
#   before changing anything — this only edits local git config
#   (.git/config), it never touches GitHub/GitLab/etc. itself.

set -uo pipefail

# --- separate flags from positional args -----------------------------------
INCLUDE_ROOT=0
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --include-root) INCLUDE_ROOT=1 ;;
        --exclude-root) INCLUDE_ROOT=0 ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done
set -- "${POSITIONAL[@]}"

MODE="${1:-}"
ROOT="${2:-}"

if [[ -z "$MODE" || -z "$ROOT" ]]; then
    echo "Usage: $0 <status|checkout|push|remote-ssh> <repo-root-folder> [branch-name | commit message] [--include-root]"
    exit 1
fi

if [[ "$MODE" == "checkout" ]]; then
    TARGET_BRANCH="${3:-}"
    if [[ -z "$TARGET_BRANCH" ]]; then
        echo "Usage: $0 checkout <repo-root-folder> <branch-name> [--include-root]"
        exit 1
    fi
else
    MSG="${3:-Automated update via multi_repo_git.sh}"
fi

if [[ ! -d "$ROOT" ]]; then
    echo "Error: $ROOT is not a directory"
    exit 1
fi

ROOT="$(cd "$ROOT" && pwd)"   # normalize to absolute path for reliable comparison below

# Find repos: any directory at depth 1 (ROOT itself) or depth 2 (immediate
# children of ROOT) that has its own .git entry. -type d,f catches both
# normal clones (.git dir) and submodules (.git file with a gitdir: pointer).
mapfile -t REPOS < <(find "$ROOT" -mindepth 0 -maxdepth 2 \( -name ".git" \) \( -type d -o -type f \) -printf '%h\n' | sort -u)

# Apply root-inclusion policy
FILTERED=()
for repo in "${REPOS[@]}"; do
    if [[ "$repo" == "$ROOT" && "$INCLUDE_ROOT" -eq 0 ]]; then
        continue
    fi
    FILTERED+=("$repo")
done
REPOS=("${FILTERED[@]}")

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "No git repos found under $ROOT"
    exit 0
fi

echo "Found ${#REPOS[@]} repos under $ROOT"
echo

# --- helpers used by push mode to report PR links after pushing ------------

# Parses a git remote URL (ssh, ssh://, or https, with or without embedded
# credentials) into "host|owner/repo" (no .git suffix). Echoes the result and
# returns 0, or returns 1 if the URL doesn't match a recognized form.
parse_host_path() {
    local url="$1" host path
    if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
        host="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"
    elif [[ "$url" =~ ^ssh://([^/]+)/(.+)$ ]]; then
        host="${BASH_REMATCH[1]}"
        host="${host##*@}"
        path="${BASH_REMATCH[2]}"
    elif [[ "$url" =~ ^https?://([^/]+)/(.+)$ ]]; then
        host="${BASH_REMATCH[1]}"
        host="${host##*@}"
        path="${BASH_REMATCH[2]}"
    else
        return 1
    fi
    path="${path%.git}"
    echo "${host}|${path}"
}

# Builds a browser-openable "start a PR/MR" URL from a host + owner/repo path.
build_pr_url() {
    local host="$1" path="$2"
    case "$host" in
        github.com)
            echo "https://github.com/${path}/pull/new/dev"
            ;;
        *gitlab*)
            echo "https://${host}/${path}/-/merge_requests/new?merge_request%5Bsource_branch%5D=dev"
            ;;
        *bitbucket*)
            echo "https://${host}/${path}/pull-requests/new?source=dev&t=1"
            ;;
        *)
            echo "https://${host}/${path}  (unrecognized host — open this repo and start a PR/MR from 'dev' manually)"
            ;;
    esac
}

PUSHED_REPOS=()  # populated in push mode: "name|pr_url" for repos actually pushed

for repo in "${REPOS[@]}"; do
    name=$(basename "$repo")
    echo "==================================================================="
    echo " $name"
    echo "==================================================================="
    pushd "$repo" >/dev/null

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "  current branch: $branch"

    # Untracked files not covered by .gitignore — the ones worth eyeballing
    untracked=$(git ls-files --others --exclude-standard)
    if [[ -n "$untracked" ]]; then
        echo "  --- untracked (not yet gitignored) ---"
        echo "$untracked" | sed 's/^/    /'
    fi

    # Modified tracked files
    modified=$(git diff --name-only; git diff --cached --name-only)
    modified=$(echo "$modified" | sort -u | sed '/^$/d')
    if [[ -n "$modified" ]]; then
        echo "  --- modified (tracked) ---"
        echo "$modified" | sed 's/^/    /'
    fi

    if [[ -z "$untracked" && -z "$modified" ]]; then
        echo "  clean — nothing to do"
    fi

    if [[ "$MODE" == "remote-ssh" ]]; then
        origin_url=$(git remote get-url origin 2>/dev/null)
        if [[ -z "$origin_url" ]]; then
            echo "  no 'origin' remote configured — skipping"
            popd >/dev/null
            echo
            continue
        fi

        if [[ "$origin_url" =~ ^git@ || "$origin_url" =~ ^ssh:// ]]; then
            echo "  origin already uses SSH: $origin_url"
            popd >/dev/null
            echo
            continue
        fi

        if [[ ! "$origin_url" =~ ^https?:// ]]; then
            echo "  origin uses an unrecognized scheme, leaving as-is: $origin_url"
            popd >/dev/null
            echo
            continue
        fi

        # Strip scheme, split host from path, drop any trailing .git before re-adding it
        host_and_path="${origin_url#http://}"
        host_and_path="${host_and_path#https://}"
        host="${host_and_path%%/*}"
        # strip optional userinfo (user@ or user:token@) some HTTPS URLs embed
        host="${host##*@}"
        path="${host_and_path#*/}"
        path="${path%.git}"
        new_url="git@${host}:${path}.git"

        echo "  origin (HTTPS): $origin_url"
        echo "  would become  : $new_url"
        read -rp "  Update this repo's origin to SSH? [y/N] " ans
        case "$ans" in
            y|Y)
                git remote set-url origin "$new_url"
                echo "  updated. New origin: $(git remote get-url origin)"
                echo "  (verify SSH access works, e.g.: ssh -T git@${host})"
                ;;
            *)
                echo "  skipped"
                ;;
        esac

        popd >/dev/null
        echo
        continue
    fi

    if [[ "$MODE" == "checkout" ]]; then
        if [[ -n "$untracked" || -n "$modified" ]]; then
            echo "  WARNING: uncommitted changes present — skipping checkout to avoid"
            echo "           carrying them onto '$TARGET_BRANCH' unintentionally."
            popd >/dev/null
            echo
            continue
        fi

        git fetch origin --quiet 2>/dev/null

        if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
            echo "  local branch '$TARGET_BRANCH' exists -> checking it out"
            git checkout "$TARGET_BRANCH"
        elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
            echo "  remote branch 'origin/$TARGET_BRANCH' exists -> fetching + tracking it"
            git checkout -b "$TARGET_BRANCH" --track "origin/$TARGET_BRANCH"
        else
            echo "  no local or remote '$TARGET_BRANCH' -> creating new branch"
            git checkout -b "$TARGET_BRANCH"
        fi

        popd >/dev/null
        echo
        continue
    fi

    if [[ "$MODE" == "push" ]]; then
        if [[ -z "$untracked" && -z "$modified" ]]; then
            popd >/dev/null
            echo
            continue
        fi

        echo
        read -rp "  Stage tracked changes and push '$name' to dev? [y/N/s(kip+open shell)] " ans
        case "$ans" in
            y|Y)
                if ! git show-ref --verify --quiet refs/heads/dev; then
                    echo "  creating local dev branch from $branch"
                    git checkout -b dev
                else
                    git checkout dev
                    # bring in any commits made on the working branch, if different
                    if [[ "$branch" != "dev" ]]; then
                        git merge --no-edit "$branch" || {
                            echo "  merge conflict — resolve manually in $repo, then re-run"
                            popd >/dev/null
                            continue
                        }
                    fi
                fi
                git add -A
                if git diff --cached --quiet; then
                    echo "  nothing staged after add (likely all gitignored) — skipping commit"
                else
                    git commit -m "$MSG"
                    if git push -u origin dev; then
                        origin_url=$(git remote get-url origin 2>/dev/null)
                        if host_path=$(parse_host_path "$origin_url"); then
                            host="${host_path%%|*}"
                            path="${host_path#*|}"
                            pr_url=$(build_pr_url "$host" "$path")
                            PUSHED_REPOS+=("${name}|${pr_url}")
                        else
                            PUSHED_REPOS+=("${name}|(could not parse origin URL: $origin_url — open the repo manually)")
                        fi
                    else
                        echo "  push failed — see git output above; not added to the PR list"
                    fi
                fi
                ;;
            s|S)
                echo "  dropping you into a subshell in $repo — 'exit' to continue the loop"
                bash
                ;;
            *)
                echo "  skipped"
                ;;
        esac
    fi

    popd >/dev/null
    echo
done

if [[ "$MODE" == "push" ]]; then
    echo "==================================================================="
    echo " PR / MR links (only repos with something actually pushed)"
    echo "==================================================================="
    if [[ ${#PUSHED_REPOS[@]} -eq 0 ]]; then
        echo "  (nothing was pushed this run)"
    else
        for entry in "${PUSHED_REPOS[@]}"; do
            repo_name="${entry%%|*}"
            url="${entry#*|}"
            printf "  %-30s %s\n" "$repo_name" "$url"
        done
    fi
    echo
fi

echo "Done."
