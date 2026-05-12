#!/bin/bash

# add_repos.sh - Discover and add missing zerobias-org repositories as submodules
#
# Uses GitHub CLI to find public repos in the zerobias-org organization that
# aren't yet checked out as submodules in this meta-repo. Maintains a
# .repoignore file to track repos that should never be added (e.g. archived
# fixtures or repos not relevant to public contributors).
#
# Usage:
#   ./scripts/add_repos.sh              # Interactive mode (prompts for each repo)
#   ./scripts/add_repos.sh --auto-add   # Automatically add all missing repos
#   ./scripts/add_repos.sh --help       # Show this help

# Don't use set -e - we handle errors explicitly

ORG="zerobias-org"

# Parse command line arguments
AUTO_ADD=false
if [ "$1" = "--auto-add" ] || [ "$1" = "-a" ]; then
    AUTO_ADD=true
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--auto-add]"
    echo ""
    echo "Discover and add missing $ORG repositories as git submodules."
    echo ""
    echo "Options:"
    echo "  --auto-add, -a    Automatically add all missing repos as submodules"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Submodules are added with HTTPS URLs (clone-friendly for outside contributors)."
    echo "Maintainers who push back via SSH can use: ./scripts/use-ssh.sh"
    exit 0
fi

# Move to repo root (script may be invoked from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || exit 1

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed"
    echo ""
    echo "Install it with:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Windows: See https://github.com/cli/cli#windows"
    echo ""
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub CLI"
    echo ""
    echo "Run: gh auth login"
    echo ""
    exit 1
fi

echo "========================================="
echo "Repository Discovery Tool ($ORG)"
if [ "$AUTO_ADD" = true ]; then
    echo "Mode: 🤖 Auto-add (non-interactive)"
else
    echo "Mode: 💬 Interactive"
fi
echo "========================================="
echo ""

# Track statistics
TOTAL_FOUND=0
TOTAL_ADDED=0
TOTAL_IGNORED=0

REPOIGNORE_FILE=".repoignore"

# Function to load .repoignore file
load_repoignore() {
    if [ -f "$REPOIGNORE_FILE" ]; then
        mapfile -t ignored_repos < <(grep -v '^#' "$REPOIGNORE_FILE" | grep -v '^[[:space:]]*$' | sort)
    else
        ignored_repos=()
    fi
}

# Function to save .repoignore file
save_repoignore() {
    {
        echo "# Repositories in $ORG intentionally excluded from this meta-repo."
        echo "# Maintained by scripts/add_repos.sh."
        echo "# Format: one repo name per line. Comments start with #."
        echo ""
        printf '%s\n' "${ignored_repos[@]}" | sort -u
    } > "$REPOIGNORE_FILE"
}

# Function to check if repo is ignored
is_ignored() {
    local repo=$1
    for ignored in "${ignored_repos[@]}"; do
        if [ "$repo" = "$ignored" ]; then
            return 0
        fi
    done
    return 1
}

# Function to get existing submodules
get_existing_submodules() {
    git submodule status 2>/dev/null | awk '{print $2}' | sort
}

# Function to prompt user for action
prompt_add_or_ignore() {
    local repo=$1

    # Fetch repo metadata (handle errors gracefully)
    local repo_info
    repo_info=$(gh repo view "$ORG/$repo" --json description,updatedAt,isPrivate,isArchived,visibility 2>/dev/null || echo '{}')
    local description
    description=$(echo "$repo_info" | jq -r '.description // "No description"' 2>/dev/null || echo "No description")
    local updated_at
    updated_at=$(echo "$repo_info" | jq -r '.updatedAt // "Unknown"' 2>/dev/null | cut -d'T' -f1 || echo "Unknown")
    local visibility
    visibility=$(echo "$repo_info" | jq -r '.visibility // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
    local is_archived
    is_archived=$(echo "$repo_info" | jq -r '.isArchived // false' 2>/dev/null || echo "false")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 New repository found: $repo"
    echo "   URL: https://github.com/$ORG/$repo"
    echo "   Description: $description"
    echo "   Visibility: $visibility"
    echo "   Last updated: $updated_at"
    [ "$is_archived" = "true" ] && echo "   📦 ARCHIVED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$AUTO_ADD" = true ]; then
        echo "🤖 Auto-add mode: Adding as submodule..."
        if git submodule add "https://github.com/$ORG/$repo.git" "$repo"; then
            git submodule update --init "$repo"
            echo "✅ Added $repo"
            ((TOTAL_ADDED++))
        else
            echo "⚠️  Failed to add $repo, skipping"
        fi
        return 0
    fi

    echo "What should I do?"
    echo "  [a] Add as submodule"
    echo "  [i] Ignore (add to .repoignore)"
    echo "  [s] Skip for now (ask again next time)"
    echo "  [q] Quit"
    echo ""

    while true; do
        read -p "Choice [a/i/s/q]: " -r choice || {
            echo ""
            echo "⚠️  No input (EOF). Exiting..."
            return 1
        }
        echo ""

        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        case $choice in
            a)
                echo "Adding $repo as submodule..."
                if git submodule add "https://github.com/$ORG/$repo.git" "$repo"; then
                    git submodule update --init "$repo"
                    echo "✅ Added $repo"
                    ((TOTAL_ADDED++))
                else
                    echo "⚠️  Failed to add $repo, skipping"
                fi
                return 0
                ;;
            i)
                echo "Adding $repo to .repoignore..."
                ignored_repos+=("$repo")
                save_repoignore
                echo "✅ Ignored $repo"
                ((TOTAL_IGNORED++))
                return 0
                ;;
            s)
                echo "⏭️  Skipped $repo (will ask again next time)"
                return 0
                ;;
            q)
                echo "👋 Quitting..."
                return 1
                ;;
            "")
                echo "⚠️  No input received. Please enter a, i, s, or q."
                ;;
            *)
                echo "⚠️  Invalid choice: '$choice'. Please enter a, i, s, or q."
                ;;
        esac
    done
}

echo "Processing organization: $ORG"
echo ""

# Load .repoignore
load_repoignore
echo "Loaded ${#ignored_repos[@]} ignored repo(s) from $REPOIGNORE_FILE"

# Get existing submodules
mapfile -t existing_submodules < <(get_existing_submodules)
echo "Found ${#existing_submodules[@]} existing submodule(s)"

# Get all public, non-archived repos from GitHub org
echo "Fetching public repositories from GitHub org: $ORG..."
mapfile -t all_repos < <(gh api "orgs/$ORG/repos" --paginate \
    --jq '.[] | select(.archived == false and .visibility == "public") | .name' | sort)

if [ ${#all_repos[@]} -eq 0 ]; then
    echo "⚠️  No repositories found in $ORG (or no access)"
    exit 0
fi

echo "Found ${#all_repos[@]} total public repo(s) in GitHub org"

# Find missing repos
missing_repos=()
for repo in "${all_repos[@]}"; do
    is_submodule=false
    for existing in "${existing_submodules[@]}"; do
        if [ "$repo" = "$existing" ]; then
            is_submodule=true
            break
        fi
    done
    if [ "$is_submodule" = false ] && ! is_ignored "$repo"; then
        missing_repos+=("$repo")
    fi
done

if [ ${#missing_repos[@]} -eq 0 ]; then
    echo "✅ No missing repositories"
    exit 0
fi

echo ""
echo "Found ${#missing_repos[@]} missing repo(s):"
printf '  - %s\n' "${missing_repos[@]}"
echo ""

if [ "$AUTO_ADD" = false ]; then
    read -p "Review these repositories? [y/N]: " -r review_choice || {
        echo ""
        echo "⚠️  No input (EOF). Exiting."
        exit 0
    }
    echo ""

    if [[ ! $review_choice =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipped review - run script again to retry"
        exit 0
    fi
fi

for repo in "${missing_repos[@]}"; do
    ((TOTAL_FOUND++)) || true
    if ! prompt_add_or_ignore "$repo"; then
        break
    fi
done

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "Total new repositories found: $TOTAL_FOUND"
echo "Added as submodules: $TOTAL_ADDED"
echo "Added to .repoignore: $TOTAL_IGNORED"
echo ""

if [ $TOTAL_ADDED -gt 0 ]; then
    echo "Next steps:"
    echo "  git status                                    # Review new submodules"
    echo "  git add .gitmodules .repoignore               # Stage changes"
    echo "  git commit -m 'deps: add new submodules'      # Commit"
    echo "  git push                                      # Push to remote"
fi

echo ""
echo "✅ Repository discovery complete!"
