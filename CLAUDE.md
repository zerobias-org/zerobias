# CLAUDE.md

Self-contained guidance for [Claude Code](https://claude.com/claude-code)
and other AI coding agents working in the `zerobias-org` open-source
meta-repo. Read this file first; everything you need to bootstrap the
workspace, update it, and work inside any sub-repo is here.

---

## What this repo is

The **`zerobias-org` open-source meta-repo**. It ships only this
documentation and a few helper scripts. The scripts clone every public
repository from the [`zerobias-org`](https://github.com/zerobias-org)
GitHub organization into this working tree as **standalone git clones**
— no submodules, no pinned SHAs, no meta-repo state to maintain.

Each subdirectory (`./framework/`, `./module/`, `./product/`, etc.) is a
fully-independent git clone. The meta-repo's value is giving the agent a
**single working tree** spanning the whole open-source surface so it
can read, search, and reason across all of them at once. PRs always go
to the sub-repo's own GitHub remote.

For a human-oriented overview (vocabulary, repo inventory, common
tasks), see [`README.md`](README.md). This file gives the agent-oriented
view.

---

## First-action checklist

Before doing anything substantive, orient yourself:

1. **Is the workspace bootstrapped?** Look for sub-repo directories at
   the meta-repo root (e.g. `framework/`, `module/`, `vendor/`). If
   they're missing, the user has only cloned the meta-repo skeleton —
   run the bootstrap before continuing:

   ```bash
   ./scripts/clone-all.sh        # clones every public zerobias-org repo
   ```

   Requires the GitHub CLI (`gh`) authenticated. If `gh` isn't ready,
   tell the user to run `gh auth login` first rather than trying
   workarounds.

2. **Did the user ask to refresh / update / sync everything?** Use
   `update_all.sh`, ideally with `--dry-run` first so the user sees
   the audit table before anything changes:

   ```bash
   ./scripts/update_all.sh --dry-run    # audit only
   ./scripts/update_all.sh              # interactive plan-then-execute
   ```

   The script is safe-by-default: it audits every sub-repo, prompts
   only for dirty/divergent ones, prints the full plan, and asks one
   confirmation before any destructive action.

3. **About to edit inside a sub-repo?** Always load that sub-repo's
   own docs first — they override anything in this file. Look for, in
   priority order:

   - `<sub-repo>/README.md` — always present, always authoritative
   - `<sub-repo>/CLAUDE.md` — agent rules for that sub-repo
   - `<sub-repo>/CONTRIBUTING.md` — PR mechanics, scaffold scripts,
     validation steps (`schema/CONTRIBUTING.md` is particularly
     detailed)
   - `<sub-repo>/.claude/` — sub-repo-specific skills, agents,
     settings, hooks
   - `<sub-repo>/.github/workflows/` — what CI will actually run on
     the PR (useful for matching local validation to CI expectations)
   - `<sub-repo>/MIGRATION_STATUS.md` — present in some content repos
     (`vendor/`, `suite/`) that are mid-Lerna→Gradle migration; tells
     you which command stack is canonical right now

4. **Was the user vague about which sub-repo a change belongs in?**
   Ask before editing. Common ambiguities:
   - "module" alone could mean the spec (`module/`), the ETL
     (`collectorbot/`), or the AuditgraphDB schema (`schema/`).
   - "vendor X" might need entries in `vendor/`, `product/`, `suite/`,
     and `segment/` — add them in that order.
   - "framework" can mean the framework itself (`framework/`), the
     standard it cites (`standard/`), or a crosswalk to another
     framework (`crosswalk/`).

5. **Did the user ask to add a product / vendor / compliance content,
   or wire up a full data integration?** Two skills, pick by scope:
   - **Catalog content only** (add a product + its vendor / suite? /
     segments / components / editions / compliance features / control
     links — **no** module, **no** collectorbot): use
     [`/create-product`](.claude/skills/create-product/SKILL.md). It
     researches the vendor's taxonomy, decides suite-vs-no-suite,
     **checks whether the product already exists and asks what to do**
     (update / add missing deps / nothing), and authors content-as-code
     validated by the gradle gate. This is what most catalog requests want.
   - **Full data integration** (catalog **+** Hub module **+**
     collectorbot, interface-targeted schema): use
     [`/create-connector`](.claude/skills/create-connector/SKILL.md). It
     **delegates Part 1 to `/create-product`**, then adds the module and
     collectorbot via per-phase sub-agents / handoffs.
   - Underlying model for both:
     [`.claude/docs/catalog-content-model.md`](.claude/docs/catalog-content-model.md).

---

## Concepts at a glance

Quick mental map of what each sub-repo owns. Use this to route a
request to the right repo before reading deeper.

**Compliance content**
- `standard/` — formal published text (NIST, ISO, …) broken into Elements
- `framework/` — Requirements (what must be done to comply)
- `benchmark/` — test cases (how to comply on a specific technology)
- `crosswalk/` — mappings between Requirements across Frameworks
- `compliance_feature/` — what a product offers toward a Requirement
- `kb/` — Hugo static-site documentation (NOT a content monorepo)

**Catalog**
- `vendor/` — companies that make things
- `product/` — specific offerings by a vendor
- `suite/` — groupings of related products
- `segment/` — taxonomy for categorizing products

**Integration**
- `module/` — OpenAPI-defined Hub integrations (Gradle + `zbb` plugin)
- `collectorbot/` — ETL shaping Module output into AuditgraphDB
- `schema/` — AuditgraphDB class/link definitions (read its `CONTRIBUTING.md`)
- `pipeline/` — small set of YAML pipeline configs

**Apps & UX**
- `app/` — Angular + Next.js SPA templates
- `login/` — white-label login pages (Dana SDK + Handlebars)

**Cross-cutting**
- `types/` — TypeScript typedefs (consumed by every code repo)
- `util/` — load-bearing libraries incl. the `zbb` Gradle plugin —
  changes here cascade across the org, coordinate first
- `devops/` — reusable GitHub Actions and workflows — changes cascade,
  coordinate first

**Skip**
- `framework_test/` — actual GitHub fork of `framework/` for CI
  validation; don't contribute compliance content here

Full details in [`docs/Concepts.md`](docs/Concepts.md) and the
"Repository reference" section of [`README.md`](README.md).

---

## MCP servers (when available)

Two ZeroBias MCP servers extend an agent's reach in this ecosystem.
Both require a ZeroBias account; neither is guaranteed to be
configured for the current user.

**Check availability first.** Look at your tool list for the prefixes
below. If either is missing, **proactively offer to install it** —
don't silently work around it and don't fabricate tool calls. The
offer should cover:

1. What the missing MCP adds (one-line summary of tools).
2. **Scope choice** — project-only or global:
   - **Global** (`claude mcp add -s user …`) — recommended for personal
     dev machines; available in every project.
   - **Project-only** (`claude mcp add …`, default scope) — stays
     scoped to this repo; useful for shared / per-project credentials.
3. **Shared credentials, with one caveat.** Both MCPs authenticate
   with the **same** ZeroBias platform API key + org ID, generated
   once from [`app.zerobias.com`](https://app.zerobias.com) →
   Settings → API Keys. Tell the user they only need to gather creds
   once even if they install both — *but* for `zb` specifically,
   those creds scope data access to **that one org**. If the user
   works across multiple orgs, mention that they can add more orgs
   later as `zb` profiles (`zb profile add <name>` → `zb profile use
   <name>`). `zb-knowledge` doesn't need profile switching — the
   indexed code is shared and the org ID only proves access.

Then run the `claude mcp add` commands from
[`docs/MCPs.md`](docs/MCPs.md) with the values the user provides
(never invent placeholder values — ask).

### `zb-knowledge` — semantic code search

Tool prefix: `mcp__zb-knowledge__*`. Hosted HTTP MCP, Dana-authenticated.

| Tool | Use when… |
|------|-----------|
| `search_code` | The user asks "where is X implemented?" or "show me usages of Y" across repos |
| `get_file` | You need to read a specific file from the knowledge base without having it cloned locally |
| `list_repos` | You need to confirm which repos are indexed before searching |
| `get_affected_files` | The user wants the transitive blast radius of changing a file |
| `get_dependency_chain` | You're tracing a root cause through imports/exports |
| `check_package_versions` | The user asks about a published version of a `@zerobias-org` / `@zerobias-com` package |
| `health_check` | Sanity-check connectivity if other calls are failing |

Reach for `zb-knowledge` *before* grepping the cloned working tree
when the question is open-ended ("how is X done across the org?") —
the semantic index is much faster than full-tree grep for that shape
of question. For a targeted lookup of a known symbol or file, plain
`grep`/`Read` on the local clone is fine.

### `zb` — ZeroBias platform operations

Tool prefix: `mcp__zb__zerobias_*`. Local stdio MCP, runs the
ZeroBias SDK against the live platform.

| Tool | Use when… |
|------|-----------|
| `zerobias_search` | The user asks about a platform operation by topic ("audit", "task", "boundary") |
| `zerobias_describe` | You need the parameter schema for a specific operation before calling it |
| `zerobias_execute` | You're running a platform operation against the live tenant; supports a `slim` parameter to keep responses small |

This MCP **mutates real platform state** when you call write
operations. Treat any non-`list`/`get` call as a hard-to-reverse
action and confirm with the user before executing it.

Setup details for either server: [`docs/MCPs.md`](docs/MCPs.md).

---

## CLI tools (offer to install / keep current)

Some sub-repo workflows go through CLI tools that aren't part of the
meta-repo itself. Before running them for the user, check they're
installed — and if missing or stale, **offer to install or update**
the same way you would for the MCPs above. Never silently work
around a missing tool, and never auto-upgrade without asking.

### `zbb` — ZeroBias slot/stack orchestrator CLI

Published as `@zerobias-org/zbb`. Powers the canonical compile /
publish / dataloader / slot workflows in `module/`, `vendor/`,
`suite/`, `product/`, `collectorbot/`, `schema/`. The sub-repo's own
docs assume `zbb` is on the user's `$PATH`.

**Check:**

```bash
command -v zbb >/dev/null && zbb --version    # exits cleanly if installed
```

**Offer to install if missing:**

```bash
npm install -g @zerobias-org/zbb@latest
```

**Offer to update on demand** (when the user mentions "latest", hits a
version-skew error, or asks to refresh tooling) — same command,
`@latest` re-resolves to the newest published version.

> ⚠️ Some sub-repos pin a specific `zbb` version in their docs (e.g.
> `module/`'s validate step). If a pin is documented in the sub-repo,
> honor it instead of `@latest`, and ask before changing a pinned
> version.

> Note: there is intentionally no `zbb workspace clone/update`
> shortcut. The bootstrap/refresh flow isn't slot-scoped, so it
> doesn't fit `zbb`'s slot+stack model — the bash scripts in
> `scripts/` are the canonical (and only) path.

### Other CLIs to be aware of

- **`gh`** — required by `scripts/clone-all.sh` to enumerate the org's
  public repos. The script self-checks and prints install instructions
  if it's missing; you don't need to pre-check.
- **`claude` CLI** — assumed (you're inside it). No version check needed.

---

## Finding & reusing work on GitHub (`gh` CLI)

Beyond cloning, the `gh` CLI lets you (Claude) dig through the org's GitHub
directly. **Proactively offer this** whenever a user references past work — "I
had a PR for X", "there's a branch somewhere", "did we ever try Y?". People
often have **old PRs or branches worth reusing**; surface and reuse them instead
of starting from scratch. Prefer doing it yourself over handing the user
commands — the only step that needs them is the one-time auth below.

- **One-time manual step (the "quickstart"):** the user must be authenticated.
  Check with `gh auth status`; if not, have them run `! gh auth login` in this
  session (interactive login — you can't do it for them). Everything else you run.
- **Find PRs:** their own open PRs across the org —
  `gh search prs --owner zerobias-org --author @me --state open`; by keyword —
  `gh search prs --owner zerobias-org "topic"`; one repo, all states —
  `gh pr list --repo zerobias-org/<repo> --state all`.
- **Branches ahead of `main`:** `gh api repos/<repo>/branches --jq '.[].name'`,
  then `gh api repos/<repo>/compare/main...<branch> --jq '{ahead:.ahead_by,status}'`.
- **Reuse without disturbing their checkout:** read a PR with
  `gh pr diff <n> --repo <repo>` / `gh pr view <n> --json files,commits`;
  pull one file at any branch with
  `gh api repos/<repo>/contents/<path>?ref=<branch> --jq .content | base64 -d`;
  build against it in a `git worktree`, never by switching their branch.
- **Private org too:** most integration code lives in the private `zerobias-com`
  org — the same commands work with `--owner zerobias-com` / `--repo
  zerobias-com/<repo>` if the user has access.

Full recipe catalog (code search, cherry-pick from a PR, cross-repo sweeps,
JSON field reference): [`docs/GitHubDiscovery.md`](docs/GitHubDiscovery.md).

---

## Working inside a sub-repo

Each sub-repo is an ordinary git clone. The meta-repo doesn't track or
pin sub-repo state — anything committed inside a sub-repo lives in
*that sub-repo's* history only.

**The contribution loop:**

```bash
cd <sub-repo>
# load the sub-repo's own docs first (see First-action checklist #3)

git switch -c <type>/<short-description>   # NEVER commit on main/master
# ... edit ... run the repo's validate/test step ...
git commit -m "<type>(<scope>): subject"
git push -u origin <branch>
gh pr create                               # opens against the sub-repo's GitHub
```

Once the PR merges in that sub-repo, the work is done. **No follow-up
meta-repo commit is needed** (and would be a no-op, since the meta-repo
ignores sub-repo directories).

---

## Editing rules

- **Conventional commits everywhere** — `feat:`, `fix:`, `chore:`,
  `docs:`, `deps:`. Scope where it adds value (e.g.
  `feat(module): add Okta API client`).
- **Never commit on `main` or `master`** inside a sub-repo. Always
  branch first.
- **Several content repos PR against `dev`, not `main`.** Check the
  sub-repo's README before pushing.
- **Don't add LICENSE files to sub-repos** without checking what each
  already has. The meta-repo has no LICENSE — flag this to the user
  rather than picking one.
- **Don't create CONTRIBUTING.md or LICENSE in this meta-repo** unless
  the user explicitly asks. They've been intentionally deferred.
- **Never edit generated `<repo>--<skill>` dirs under `.claude/skills/`.**
  They are gitignored copies of sub-repo skills, regenerated by
  `scripts/sync-skills.sh` (run automatically by `clone-all.sh` and
  `update_all.sh`). Each copy's header names its source — edit that
  source skill in its sub-repo instead. When following one of these
  skills, honor its execution-context header: work from the named
  sub-repo directory, and git operations target that sub-repo.

---

## Cross-repo work

Some tasks span multiple sub-repos. Common patterns to recognize and
flag to the user *before* editing:

- **New product** (`product/`) → typically needs `vendor/`,
  `segment/`, possibly `compliance_feature/` entries
- **New framework** (`framework/`) → often pairs with a `crosswalk/`
  mapping and may reference `standard/`
- **New Hub integration** (`module/`) → typically needs
  `collectorbot/` (ETL) and `schema/` (AuditgraphDB types)

When the change spans repos, list the affected sub-repos to the user
*before* editing, so they can confirm or redirect.

---

## Generated code

Several sub-repos (especially `module/`, `types/`, `schema/`) include
generated TypeScript / OpenAPI artifacts.

- Don't edit files inside `generated/` directories directly.
- The OpenAPI spec, JSON schema, or `.yml` source is the source of
  truth — edit that, then regenerate via the sub-repo's
  `npm run generate` (or equivalent).
- If unsure whether a file is generated, check the sub-repo's
  `README.md` before editing.

---

## When asked about closed-source platform pieces

This meta-repo only covers the **open-source** half of ZeroBias. If a
developer asks about:

- Authentication services (Dana / Hydra)
- The Hub server / node runtime
- The internal platform monorepo, REST/GraphQL APIs, dataloader
- Internal infrastructure (Terraform, Helm, deployment slots)

…those live in a separate, **private** organization and aren't
accessible from this repo. Be honest: tell the developer the code isn't
visible here, point at [`docs/Architecture.md`](docs/Architecture.md)
for the public contracts the open-source side must honour, and suggest
they consult their internal docs.

---

## Quick reference

- **Human-facing overview & repo inventory:** [`README.md`](README.md)
- **Domain vocabulary (deep):** [`docs/Concepts.md`](docs/Concepts.md)
- **"I want to do X" routing (deep):** [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md)
- **MCP server setup (`zb-knowledge`, `zb`):** [`docs/MCPs.md`](docs/MCPs.md)
- **Find/reuse GitHub PRs, branches, code (`gh`):** [`docs/GitHubDiscovery.md`](docs/GitHubDiscovery.md)
- **Cross-repo dependency / `npm link` patterns:** [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md)
- **NPM registry / `ZB_TOKEN` setup:** [`docs/RegistrySetup.md`](docs/RegistrySetup.md)
- **Hub modules deep dive:** [`docs/Modules.md`](docs/Modules.md)
- **Architecture & platform contracts:** [`docs/Architecture.md`](docs/Architecture.md)
- **Dataloader artifact types & relations:**
  [`.claude/docs/dataloader-artifact-map.md`](.claude/docs/dataloader-artifact-map.md)
  — every loadable artifact type, its manifest files and linking fields;
  interactive diagram at [`artifact-map/index.html`](artifact-map/index.html)
- **Catalog content model (enums, validation, feature wiring):**
  [`.claude/docs/catalog-content-model.md`](.claude/docs/catalog-content-model.md)
  — how vendor / product / segment / compliance_feature content is structured,
  validated (the gradle gate, **not** `npm run validate`), and wired
  (product → `segments` → segment `supports.yml` → `complianceFeature`). Read
  before authoring or reviewing any catalog PR by hand.
