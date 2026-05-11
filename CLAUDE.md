# CLAUDE.md

Guidance for [Claude Code](https://claude.com/claude-code) and other AI
coding agents working in this repository.

## What this repo is

This is the **`zerobias-org` open-source meta-repo**. It contains no code
of its own — only documentation, helper scripts, and git submodules
pointing at every public repository in the
[`zerobias-org`](https://github.com/zerobias-org) GitHub organization.

Each subdirectory (`./framework/`, `./module/`, `./product/`, etc.) is a
fully-independent git repo. The meta-repo's job is to give an agent a
**single working tree** that spans the whole open-source surface, so it
can read, search, and reason across all of them at once.

See [`README.md`](README.md) for the full repo inventory.

## How to start a session

**Always start the agent from this directory** (the meta-repo root). That
way Claude can:

- See every sub-repo's documentation and code at once.
- Follow cross-references between repos (e.g. a product entry that links
  to a vendor, segment, and compliance feature).
- Suggest changes that span multiple repos.

```bash
cd path/to/zerobias-org   # meta-repo root
claude                    # start Claude Code here
```

If the developer has already `cd`'d *into* a sub-repo, the agent should
proactively:

1. Read that sub-repo's own `README.md` and `CLAUDE.md` (if present).
2. Then read the **meta-repo's** `CLAUDE.md` (this file) and
   `docs/Concepts.md` for cross-repo context.
3. Mention to the developer that running from the meta-repo root unlocks
   richer context.

## Context-loading order for any task

When a developer asks for help, load context in this order. Stop as soon
as you have enough — don't read everything proactively.

1. **Always:** this `CLAUDE.md`, plus
   [`docs/Concepts.md`](docs/Concepts.md) for domain vocabulary.
2. **Identify the target sub-repo(s).** Ask the developer if it's not
   obvious. Examples of how to ask:
   - "Which artifact are you changing — a framework, a benchmark, a
     module, or something in the product catalog?"
   - "Should this change live in `module/` (the integration spec) or
     in `collectorbot/` (the ETL)?"
3. **Read the sub-repo's `README.md` and `CLAUDE.md`** (if it has one).
   Those override anything in this meta-repo.
4. **Related sub-repos** — look at `docs/DOCUMENTATION_INDEX.md` for
   "Concept → Repo" mappings. A change to `product/` might also touch
   `vendor/`, `segment/`, or `compliance_feature/`.
5. **Topical meta-repo docs** as needed: `docs/Architecture.md`,
   `docs/ContentArtifacts.md`, `docs/Modules.md`,
   `docs/SubmoduleWorkflow.md`, `docs/LocalDevelopment.md`.

## Cross-repo work

Many tasks span multiple sub-repos. A few common patterns:

- **Adding a new product** (`product/`) usually means cross-referencing a
  `vendor/`, fitting it into the `segment/` taxonomy, and possibly
  declaring `compliance_feature/` entries.
- **Adding a new framework** (`framework/`) often pairs with a matching
  `crosswalk/` entry mapping its Requirements onto another framework, and
  may reference `standard/` for the underlying formal document.
- **Adding a Hub integration** (`module/`) typically pairs with a
  `collectorbot/` ETL package that converts the module's output into
  AuditgraphDB objects defined in `schema/`.

When a task spans repos, list the affected sub-repos to the developer
*before* editing anything, so they can confirm or redirect.

## Editing rules

- **Never edit inside a sub-repo without making it clear that the change
  belongs to that sub-repo's git history**, not to the meta-repo. The
  meta-repo only tracks *which commit* each submodule is pinned to.
- **Use feature branches inside sub-repos.** Never commit straight to
  `main`/`master`. After a sub-repo PR is merged, the meta-repo's pinned
  SHA is updated separately (see `docs/SubmoduleWorkflow.md`).
- **Follow conventional commits** in both sub-repos and meta-repo:
  `feat:`, `fix:`, `deps:`, `chore:`, `docs:`, etc. Scope where it adds
  value (e.g. `feat(module): ...`).
- **Don't add LICENSE files to sub-repos** without checking what each one
  already has. The meta-repo itself currently has no LICENSE — flag this
  to the developer rather than picking one yourself.
- **Don't create a CONTRIBUTING.md or LICENSE in this meta-repo** unless
  the developer explicitly asks for one — they've been intentionally
  deferred.

## Generated code

Several sub-repos (especially `module/`, `types/`, `schema/`) include
generated TypeScript / OpenAPI artifacts.

- Don't edit files inside `generated/` (or similar) directories directly.
- The OpenAPI spec, JSON schema, or `.yml` source is the source of truth —
  edit that, then regenerate via the sub-repo's `npm run generate` (or
  equivalent).
- If unsure whether a file is generated, check the sub-repo's `README.md`
  before editing.

## Submodules: things that bite

Submodules have sharp edges. The most common traps:

1. **Detached HEAD after `git submodule update`.** If a sub-repo shows
   `(HEAD detached at <sha>)`, *checkout a branch before making changes*.
2. **Working on `main` inside a sub-repo.** Always make a feature branch
   first.
3. **Running `git submodule update` while in the middle of work.** This
   resets the sub-repo to the meta-repo's pinned SHA and can throw away
   your work-in-progress branch. Don't run it from inside a sub-repo
   you're editing.

Full walkthrough: [`docs/SubmoduleWorkflow.md`](docs/SubmoduleWorkflow.md).

## When asked to "update everything"

Use the helper scripts at the meta-repo root:

```bash
./scripts/update_all.sh      # pull latest main on every submodule
./scripts/add_repos.sh       # discover any new zerobias-org repos
```

`update_all.sh` prints which submodules moved forward. After it runs,
`git status` in the meta-repo will show those submodules as "modified" —
that's expected; staging and committing them updates the pinned SHAs.

## When asked about closed-source platform pieces

This meta-repo only covers the **open-source** half of ZeroBias. If a
developer asks about:

- Authentication services (Dana / Hydra)
- The Hub server / node runtime
- The internal platform monorepo, REST/GraphQL APIs, dataloader
- Internal infrastructure (Terraform, Helm, deployment slots)

…those live in a separate, **private** organization and aren't accessible
from this repo. Be honest: tell the developer the code isn't visible
here, point them at any relevant public concept docs
(`docs/Architecture.md` describes the contracts the open-source side
must honour), and suggest they consult their internal docs.

## Quick reference

- **Repo inventory & layout:** [`README.md`](README.md)
- **Domain vocabulary:** [`docs/Concepts.md`](docs/Concepts.md)
- **How docs are organized:** [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md)
- **How submodules work here:** [`docs/SubmoduleWorkflow.md`](docs/SubmoduleWorkflow.md)
- **Local dev / npm link:** [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md)
