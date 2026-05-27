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
- **Cross-repo dependency / `npm link` patterns:** [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md)
- **NPM registry / `ZB_TOKEN` setup:** [`docs/RegistrySetup.md`](docs/RegistrySetup.md)
- **Hub modules deep dive:** [`docs/Modules.md`](docs/Modules.md)
- **Architecture & platform contracts:** [`docs/Architecture.md`](docs/Architecture.md)
