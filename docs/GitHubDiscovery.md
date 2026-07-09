# Finding & reusing work on GitHub (`gh` CLI)

Claude-facing recipe catalog for digging through the ZeroBias GitHub orgs with
the `gh` CLI — finding **PRs**, **branches**, and **code**, and **reusing data
from past work** without disturbing the user's checkout.

This complements, not replaces, the [`zb-knowledge`](MCPs.md) MCP: use
`zb-knowledge` for *semantic code search* across indexed repos ("how is X done?"),
and `gh` for everything GitHub knows that an index doesn't — **PRs, branches,
review state, diffs, and files at an arbitrary ref**.

> **Design intent:** prefer doing this yourself over handing the user commands.
> The only step that needs the user is the one-time authentication below —
> everything else you run on their behalf. Proactively offer to search when a
> user says things like "I had a PR for that", "there's a branch somewhere", or
> "did we ever try Y?" — old PRs and branches are often worth reusing.

---

## 0. Prerequisite (the one manual step)

`gh` must be installed and authenticated. This is the only piece you can't do
for the user (interactive login):

```bash
gh auth status                 # already logged in? (shows the account + scopes)
```

If not authenticated, ask the user to run it themselves in this session:

```
! gh auth login                # interactive — pick GitHub.com, HTTPS, browser/token
```

Notes:
- Reuse across API + git: `gh auth setup-git` lets git push/pull use the `gh`
  token (useful for the private org).
- Some `gh search` / `gh api` calls over private repos need the token to carry
  `repo` scope — if a call 404s on a repo you know exists, it's usually a scope
  or membership gap, not a missing repo.

## Orgs

- **`zerobias-org`** — the public/open-source org (this meta-repo's subject).
- **`zerobias-com`** — the **private** org where most integration code lives
  (Hub server, modules, platform). Every command below works there too by
  swapping `--owner zerobias-com` / `--repo zerobias-com/<repo>`, **if the user
  has access**. If unsure which org a repo is in, search both.

---

## 1. Find PRs

```bash
# The user's own open PRs across the whole org (the common "where did I leave off?")
gh search prs --owner zerobias-org --author @me --state open

# Their merged/closed history (reuse past work)
gh search prs --owner zerobias-org --author @me --state closed --limit 50

# Anyone's PRs by keyword/topic across the org
gh search prs --owner zerobias-org "okta connector"

# Every open PR in one repo, richest view
gh pr list --repo zerobias-org/<repo> --state all --limit 100 \
  --json number,title,author,headRefName,state,updatedAt,url

# Filter by author / label / base branch in a single repo
gh pr list --repo zerobias-org/<repo> --author <user> --base dev --state all
```

Useful `gh search prs` filters: `--author`, `--assignee`, `--label`,
`--draft`, `--merged`, `--created 2025-01-01..2025-06-30`, `--limit`.
Add `--json number,title,repository,url,updatedAt` to get structured output.

## 2. Inspect & reuse a specific PR

```bash
gh pr view <n>  --repo <repo>                         # summary + description + checks
gh pr diff <n>  --repo <repo>                         # the full diff (read, don't checkout)
gh pr view <n>  --repo <repo> --json files,commits,headRefName,baseRefName
gh pr view <n>  --repo <repo> --json comments,reviews  # discussion / review feedback to reuse
```

**Reuse the data without touching the user's working tree** (the don't-disturb
rule in [`CLAUDE.md`](../CLAUDE.md) — use the GitHub API or a `git worktree`,
never switch their branch):

```bash
# Read ONE file exactly as it is on the PR's branch — no clone, no checkout
gh api repos/<repo>/contents/<path>?ref=<headRefName> --jq '.content' | base64 -d

# Or bring the PR's whole tree into an isolated worktree to build/test against
git -C <local-clone> fetch origin
git -C <local-clone> worktree add /tmp/reuse-pr-<n> origin/<headRefName>
# ... read / cherry-pick / copy what you need ...
git -C <local-clone> worktree remove /tmp/reuse-pr-<n> --force
```

Cherry-pick a single commit out of an old PR into current work:

```bash
git -C <local-clone> fetch origin <headRefName>
git -C <local-clone> cherry-pick <sha>        # do this on a branch/worktree, not their checkout
```

`gh pr checkout <n> --repo <repo>` also works, but it **switches the current
checkout** — avoid it if the user has uncommitted work; use a worktree instead.

## 3. Find branches ahead of `main`

The "dev branches ahead of main" sweep — what's unmerged and might need
promoting or salvaging:

```bash
# List all branches in a repo
gh api repos/zerobias-org/<repo>/branches --paginate --jq '.[].name'

# How far a branch is ahead/behind main (and whether it still merges cleanly)
gh api repos/zerobias-org/<repo>/compare/main...<branch> \
  --jq '{ahead: .ahead_by, behind: .behind_by, status, commits: [.commits[].commit.message]}'
```

Sweep every branch of a repo for anything ahead of `main`:

```bash
repo=zerobias-org/<repo>
for b in $(gh api repos/$repo/branches --paginate --jq '.[].name'); do
  [ "$b" = "main" ] && continue
  ahead=$(gh api repos/$repo/compare/main...$b --jq '.ahead_by' 2>/dev/null)
  [ "${ahead:-0}" -gt 0 ] && echo "$b: +$ahead"
done
```

## 4. Find code

```bash
# GitHub code search across the org (indexed default branches only)
gh search code --owner zerobias-org "PublishOrgTask"
gh search code --owner zerobias-org "x-oauth-providers" --extension yml

# A file's contents at any ref (branch, tag, or SHA) without cloning
gh api repos/<repo>/contents/<path>?ref=<ref> --jq '.content' | base64 -d
```

Caveats: `gh search code` indexes only the **default branch**, has rate limits,
and won't do semantic matching. For "how is X done across the org?" reach for
the **`zb-knowledge` MCP** first (see [`MCPs.md`](MCPs.md)); use `gh search
code` for exact-string lookups and when you need the GitHub-native view.

## 5. Cross-repo sweeps

Enumerate the org's repos, then apply any of the above per repo:

```bash
# All repos in the org (respect the public/private split with --visibility)
gh repo list zerobias-org --limit 500 --json name,defaultBranchRef,updatedAt --jq '.[].name'

# Example: find every open PR authored by the user, org-wide, as a table
gh search prs --owner zerobias-org --author @me --state open \
  --json repository,number,title,url \
  --jq '.[] | "\(.repository.nameWithOwner)#\(.number)  \(.title)"'
```

For a heavier, scripted sweep (audit tables across many repos), consider a small
loop over `gh repo list` output — but log what you skipped so a truncated result
doesn't read as "nothing found".

---

## Quick reference

| Goal | Command |
|------|---------|
| Am I authed? | `gh auth status` |
| My open PRs (org-wide) | `gh search prs --owner zerobias-org --author @me --state open` |
| PRs by keyword | `gh search prs --owner zerobias-org "topic"` |
| One repo's PRs | `gh pr list --repo zerobias-org/<repo> --state all` |
| Read a PR diff | `gh pr diff <n> --repo <repo>` |
| File at a ref (no clone) | `gh api repos/<repo>/contents/<path>?ref=<ref> --jq .content \| base64 -d` |
| Branches in a repo | `gh api repos/<repo>/branches --paginate --jq '.[].name'` |
| Branch vs main | `gh api repos/<repo>/compare/main...<branch> --jq '{ahead:.ahead_by,behind:.behind_by}'` |
| Code search | `gh search code --owner zerobias-org "string"` |
| List org repos | `gh repo list zerobias-org --limit 500 --json name --jq '.[].name'` |

Private org: swap `zerobias-org` → `zerobias-com` (needs access).
