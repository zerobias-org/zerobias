#!/bin/bash
#
# update-all.sh — bring every sub-repo to the latest tip of its default branch.
#
# Works in three phases (no destructive action happens before the final confirm):
#
#   1. AUDIT    fetch + classify each sub-repo (read-only)
#   2. RESOLVE  prompt only for repos that need a decision (read-only)
#   3. CONFIRM  print the full plan, ask one y/n
#   4. EXECUTE  run the plan; report at the end
#
# Aborting before EXECUTE leaves everything untouched. Errors during EXECUTE
# are logged per-repo and don't stop the run.
#
# Usage:
#   ./scripts/update_all.sh             # interactive
#   ./scripts/update_all.sh --dry-run   # audit only; print state table and exit
#   ./scripts/update_all.sh --help

set -u

DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 [--dry-run]

Bring every sub-repo at the meta-repo root to the tip of its default branch.

Phases: audit (fetch + classify), resolve (prompt for ambiguous repos),
confirm (one y/n on the full plan), execute. Nothing is modified before the
confirm step.

Options:
  --dry-run    Print the audit table and exit. No prompts, no changes.
  -h, --help   Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$META_ROOT" || exit 1

# ─── Colors (only if stdout is a tty) ─────────────────────────────────────────
if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""
fi

# Meta-repo's own root dirs — never managed as sub-repos.
META_OWN_DIRS=(.claude .github docs scripts)

is_meta_own() {
    local d="$1"
    for own in "${META_OWN_DIRS[@]}"; do
        [ "$d" = "$own" ] && return 0
    done
    return 1
}

# ─── Discover sub-repos ───────────────────────────────────────────────────────
repos=()
for entry in */ .[!.]*/; do
    [ -d "$entry" ] || continue
    name="${entry%/}"
    is_meta_own "$name" && continue
    [ -e "$name/.git" ] || continue
    repos+=("$name")
done

if [ ${#repos[@]} -eq 0 ]; then
    echo "No sub-repos found at the meta-repo root."
    echo "Run ./scripts/clone-all.sh first."
    exit 0
fi

# ─── PHASE 1 — AUDIT ──────────────────────────────────────────────────────────
echo "${C_BOLD}Phase 1/4: auditing ${#repos[@]} sub-repo(s)…${C_RESET}"

# Parallel arrays, indexed by position in $repos.
states=()       # classification key (see below)
notes=()       # human-readable detail
branches=()    # current branch (or "DETACHED")
defaults=()    # default branch name
plans=()       # action chosen (filled in Phase 2; defaults filled here)

# Classification keys:
#   current      — already at origin/default, nothing to do
#   behind       — on default, clean, behind origin
#   feature      — on feature branch, clean
#   dirty        — uncommitted changes (any branch)
#   ahead        — on default, clean, has unpushed commits
#   diverged     — on default, clean, can't fast-forward
#   detached     — detached HEAD
#   no-default   — neither main nor master found
#   broken       — fetch failed or other error

for repo in "${repos[@]}"; do
    cd "$META_ROOT/$repo" || { states+=("broken"); notes+=("cannot cd"); branches+=("?"); defaults+=("?"); plans+=("skip"); cd "$META_ROOT"; continue; }

    # Default branch
    default=""
    git fetch origin --quiet 2>/dev/null || { states+=("broken"); notes+=("fetch failed"); branches+=("?"); defaults+=("?"); plans+=("skip"); cd "$META_ROOT"; continue; }
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        default="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        default="master"
    else
        states+=("no-default"); notes+=("no main/master at origin"); branches+=("?"); defaults+=("?"); plans+=("skip"); cd "$META_ROOT"; continue
    fi

    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ "$branch" = "HEAD" ] && branch="DETACHED"

    # Dirty?
    dirty_count=0
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    fi
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    total_dirty=$((dirty_count + untracked))

    if [ "$total_dirty" -gt 0 ]; then
        states+=("dirty"); notes+=("$total_dirty change(s) on $branch"); plans+=("")
    elif [ "$branch" = "DETACHED" ]; then
        states+=("detached"); notes+=("at $(git rev-parse --short HEAD)"); plans+=("")
    elif [ "$branch" != "$default" ]; then
        states+=("feature"); notes+=("on '$branch'"); plans+=("switch-ff")
    else
        local_sha=$(git rev-parse HEAD)
        remote_sha=$(git rev-parse "origin/$default")
        base_sha=$(git merge-base HEAD "origin/$default" 2>/dev/null || echo "")

        if [ "$local_sha" = "$remote_sha" ]; then
            states+=("current"); notes+=("up to date"); plans+=("noop")
        elif [ "$base_sha" = "$local_sha" ]; then
            ahead=$(git rev-list --count HEAD.."origin/$default")
            states+=("behind"); notes+=("$ahead commit(s) behind"); plans+=("ff")
        elif [ "$base_sha" = "$remote_sha" ]; then
            ahead=$(git rev-list --count "origin/$default"..HEAD)
            states+=("ahead"); notes+=("$ahead unpushed commit(s) on $default"); plans+=("")
        else
            states+=("diverged"); notes+=("local $default has diverged"); plans+=("")
        fi
    fi

    branches+=("$branch")
    defaults+=("$default")
    cd "$META_ROOT"
done

# ─── Print audit table ────────────────────────────────────────────────────────
printf "\n%-24s %-14s %-10s %s\n" "REPO" "BRANCH" "STATE" "NOTE"
printf '%s\n' "────────────────────────────────────────────────────────────────────────"
for i in "${!repos[@]}"; do
    case "${states[$i]}" in
        current)    color="$C_DIM" ;;
        behind|feature) color="$C_CYAN" ;;
        dirty|ahead|diverged|detached) color="$C_YELLOW" ;;
        no-default|broken) color="$C_RED" ;;
        *)          color="" ;;
    esac
    printf "${color}%-24s %-14s %-10s %s${C_RESET}\n" "${repos[$i]}" "${branches[$i]}" "${states[$i]}" "${notes[$i]}"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "${C_DIM}(dry-run: no further action)${C_RESET}"
    exit 0
fi

# ─── PHASE 2 — RESOLVE ────────────────────────────────────────────────────────
needs_decision=()
for i in "${!repos[@]}"; do
    [ -z "${plans[$i]}" ] && needs_decision+=("$i")
done

if [ ${#needs_decision[@]} -gt 0 ]; then
    echo "${C_BOLD}Phase 2/4: ${#needs_decision[@]} repo(s) need a decision.${C_RESET}"
    echo ""

    for idx in "${needs_decision[@]}"; do
        repo="${repos[$idx]}"
        state="${states[$idx]}"
        branch="${branches[$idx]}"
        default="${defaults[$idx]}"
        note="${notes[$idx]}"

        echo "${C_BOLD}$repo${C_RESET} — $state ($note)"

        case "$state" in
            dirty)
                echo "  [s] stash uncommitted, switch to $default, fast-forward"
                echo "  [k] keep as is, skip this repo"
                echo "  [d] discard uncommitted, switch to $default, fast-forward ${C_RED}(destructive)${C_RESET}"
                echo "  [a] abort entire run"
                valid="s k d a"
                ;;
            ahead)
                echo "  [k] keep local commits, skip this repo"
                echo "  [r] reset local $default to origin/$default ${C_RED}(destructive — drops local commits)${C_RESET}"
                echo "  [a] abort entire run"
                valid="k r a"
                ;;
            diverged)
                echo "  [k] keep diverged state, skip this repo"
                echo "  [r] reset local $default to origin/$default ${C_RED}(destructive — drops local commits)${C_RESET}"
                echo "  [a] abort entire run"
                valid="k r a"
                ;;
            detached)
                echo "  [s] switch to $default, fast-forward (leaves detached commits unreferenced)"
                echo "  [k] keep detached, skip this repo"
                echo "  [a] abort entire run"
                valid="s k a"
                ;;
            *)
                echo "  [k] skip"
                echo "  [a] abort"
                valid="k a"
                ;;
        esac

        while :; do
            read -r -p "  choice: " choice </dev/tty || { echo ""; echo "no tty — aborting"; exit 130; }
            choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
            case " $valid " in *" $choice "*) break ;; esac
            echo "  invalid; expected one of: $valid"
        done

        case "$choice" in
            a) echo ""; echo "${C_YELLOW}Aborted. No repos were modified.${C_RESET}"; exit 0 ;;
            k) plans[$idx]="skip" ;;
            s) case "$state" in
                dirty)    plans[$idx]="stash-switch-ff" ;;
                detached) plans[$idx]="switch-ff" ;;
               esac ;;
            d) plans[$idx]="discard-switch-ff" ;;
            r) plans[$idx]="reset-default" ;;
        esac
        echo ""
    done
fi

# ─── PHASE 3 — CONFIRM ────────────────────────────────────────────────────────
to_act=0
for i in "${!repos[@]}"; do
    [ "${plans[$i]}" = "noop" ] && continue
    [ "${plans[$i]}" = "skip" ] && continue
    ((to_act++)) || true
done

if [ "$to_act" -eq 0 ]; then
    echo "${C_GREEN}Nothing to do — every repo is already up to date or being skipped.${C_RESET}"
    exit 0
fi

echo "${C_BOLD}Phase 3/4: plan${C_RESET}"
echo ""
for i in "${!repos[@]}"; do
    plan="${plans[$i]}"
    [ "$plan" = "noop" ] && continue
    case "$plan" in
        skip)              label="skip" ;;
        ff)                label="fast-forward" ;;
        switch-ff)         label="switch to ${defaults[$i]} + fast-forward" ;;
        stash-switch-ff)   label="${C_YELLOW}stash${C_RESET} + switch to ${defaults[$i]} + fast-forward" ;;
        discard-switch-ff) label="${C_RED}discard changes${C_RESET} + switch to ${defaults[$i]} + fast-forward" ;;
        reset-default)     label="${C_RED}hard reset${C_RESET} ${defaults[$i]} to origin/${defaults[$i]}" ;;
        *)                 label="$plan" ;;
    esac
    printf "  %-24s %s\n" "${repos[$i]}" "$label"
done
echo ""

read -r -p "Proceed? [y/N] " ok </dev/tty || { echo ""; echo "no tty — aborting"; exit 130; }
case "$ok" in
    y|Y|yes|YES) ;;
    *) echo "${C_YELLOW}Aborted. No repos were modified.${C_RESET}"; exit 0 ;;
esac

# ─── PHASE 4 — EXECUTE ────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}Phase 4/4: executing…${C_RESET}"
echo ""

succeeded=0; failed=0; skipped=0
failed_repos=()

for i in "${!repos[@]}"; do
    repo="${repos[$i]}"
    plan="${plans[$i]}"
    default="${defaults[$i]}"

    case "$plan" in
        noop)
            ((skipped++)) || true
            continue
            ;;
        skip)
            echo "  ↳ $repo: skipped"
            ((skipped++)) || true
            continue
            ;;
    esac

    cd "$META_ROOT/$repo" || { echo "  ${C_RED}✗${C_RESET} $repo: cannot cd"; ((failed++)) || true; failed_repos+=("$repo"); continue; }

    rc=0
    case "$plan" in
        ff)
            git pull --ff-only origin "$default" --quiet || rc=$?
            ;;
        switch-ff)
            git switch "$default" --quiet 2>/dev/null && git pull --ff-only origin "$default" --quiet || rc=$?
            ;;
        stash-switch-ff)
            git stash push -u -m "update-all.sh auto-stash $(date -u +%Y-%m-%dT%H:%M:%SZ)" --quiet \
              && git switch "$default" --quiet \
              && git pull --ff-only origin "$default" --quiet || rc=$?
            ;;
        discard-switch-ff)
            git reset --hard HEAD --quiet \
              && git clean -fd --quiet \
              && git switch "$default" --quiet \
              && git pull --ff-only origin "$default" --quiet || rc=$?
            ;;
        reset-default)
            git switch "$default" --quiet \
              && git reset --hard "origin/$default" --quiet || rc=$?
            ;;
    esac

    if [ "$rc" -eq 0 ]; then
        echo "  ${C_GREEN}✓${C_RESET} $repo"
        ((succeeded++)) || true
    else
        echo "  ${C_RED}✗${C_RESET} $repo (exit $rc)"
        ((failed++)) || true
        failed_repos+=("$repo")
    fi

    cd "$META_ROOT"
done

# Refresh root-level copies of sub-repo skills (see scripts/sync-skills.sh).
"$SCRIPT_DIR/sync-skills.sh" --quiet || echo "⚠️  skill sync failed — run ./scripts/sync-skills.sh manually"

echo ""
echo "${C_BOLD}Done.${C_RESET} $succeeded updated, $skipped skipped, $failed failed."
if [ ${#failed_repos[@]} -gt 0 ]; then
    printf '  failed: %s\n' "${failed_repos[@]}"
    exit 1
fi
