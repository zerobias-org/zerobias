# ZeroBias Open-Source Meta-Repo

> One workspace that contains every public repository in the
> [`zerobias-org`](https://github.com/zerobias-org) GitHub organization —
> the open-source side of the [ZeroBias](https://zerobias.com) compliance
> automation platform.

This repo doesn't ship code of its own. It's a thin **meta-repo** that uses
git submodules to pull every public `zerobias-org` repository into a single
working tree, alongside cross-repo documentation and tooling. Once cloned,
you have a unified workspace where you (or a coding agent like
[Claude Code](https://claude.com/claude-code)) can read, search, build and
contribute across all repositories without juggling separate clones.

---

## Why this exists

ZeroBias is a compliance automation platform with a layered ecosystem:

- **Closed-source platform services** (auth, hub, hydra, dataloader, etc.)
  live in a private organization and aren't part of this repo.
- **Open-source content and integrations** — compliance frameworks,
  standards, benchmarks, crosswalks, Hub integration modules, product
  catalogs, custom app/login templates, and developer tooling — live in
  [`zerobias-org`](https://github.com/zerobias-org). **That's what this
  meta-repo aggregates.**

You can absolutely clone and work on any single `zerobias-org` repo on its
own. The meta-repo is useful when you want to:

- Get the **full open-source surface** in one `git clone`.
- Make changes that **span multiple repos** (e.g. adding a new product
  catalog entry that references a vendor and a segment).
- Give an **AI coding agent** the full cross-repo context so it can answer
  questions, suggest implementations, and respect conventions across the
  whole ecosystem.
- Run the **helper scripts** (`scripts/add_repos.sh`, `scripts/update_all.sh`)
  that keep all sub-repos in sync.

---

## Quick start

```bash
# Clone with all submodules (recommended)
git clone --recurse-submodules https://github.com/zerobias-org/zerobias.git
cd zerobias

# Or, if you already cloned without --recurse-submodules:
git submodule update --init --recursive
```

That's it. You now have every public `zerobias-org` repo checked out
underneath this directory.

### Working with a single sub-repo

Each subdirectory is a fully-functional clone of the corresponding
`zerobias-org` repository. Build, test and develop inside it exactly the
way you would after a normal `git clone`:

```bash
cd module        # or framework, or product, etc.
cat README.md
npm install && npm run build  # or whatever the sub-repo's README says
```

Changes you make to files inside a sub-repo are tracked by *that sub-repo's*
git history — not by the meta-repo. See
[`docs/SubmoduleWorkflow.md`](docs/SubmoduleWorkflow.md) for the full
"how do I commit my changes" walkthrough.

> ⚠️ **NPM registry caveat.** `@zerobias-org` packages live on a
> **private NPM registry** (`https://pkg.zerobias.org/`) that returns
> 401 to anonymous requests. Without a `ZB_TOKEN`, `npm install`
> inside any sub-repo will fail. You can still read all source code
> freely, but you cannot build or run local validation. See
> [`docs/RegistrySetup.md`](docs/RegistrySetup.md) for setup, and the
> committed [`.npmrc.example`](.npmrc.example) for a reference config.

### Keeping everything up to date

```bash
./scripts/update_all.sh        # pull latest main on every submodule
./scripts/add_repos.sh         # discover new repos added to zerobias-org
```

---

## Repository inventory

All sub-repos live **flat at the root** of this meta-repo (so
`./framework/`, `./module/`, etc.) — no extra namespace folder, because the
meta-repo itself *is* the `zerobias-org` namespace.

> Layouts and contribution flows have been verified by reading each
> repo's actual README and inspecting its structure (May 2026). The
> short descriptions below link to the exact contribution mechanism per
> repo — see [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md)
> for the "I want to do X → run command Y in repo Z" table.

### Core libraries (multi-package node monorepos)

| Repo | Purpose |
|------|---------|
| [`types`](https://github.com/zerobias-org/types) | Lerna+Nx monorepo of TypeScript typedefs under `packages/` — vendor-specific (`amazon`, `atlassian`, `google`, `microsoft`), `core`, `hub-types`, plus a `format-spectral-ruleset`. **README is missing.** |
| [`util`](https://github.com/zerobias-org/util) | Lerna+Nx+Gradle monorepo under `packages/`. **Load-bearing**: ships `zbb` (the Gradle plugin used by `module`/`vendor`/`suite`/`product`/`collectorbot`/`schema`), `codegen` (OpenAPI generator for Hub modules), `module-tester`, `content-schema`, `connector`, `invoker`, etc. Not "just utilities" — touching this cascades across the org. |
| [`schema`](https://github.com/zerobias-org/schema) | AuditgraphDB schema definitions (classes + catalog) under `package/<vendor>/<group>/<schema-name>/`. **README is empty; `CONTRIBUTING.md` is the substantive doc** (most detailed in the org — explains the validation layers including local dataloader against Supabase scratch DB and CI dataloader against a Neon branch). |

### Content (compliance artifacts)

All use a `package/.../index.yml` content-package pattern, but **layout depth varies**:

| Repo | Layout | PR target | Scaffold script |
|------|--------|-----------|-----------------|
| [`framework`](https://github.com/zerobias-org/framework) | `package/<publisher>/<category>/<version>/` (3 levels) | `dev` | `sh scripts/createNewFramework.sh` |
| [`standard`](https://github.com/zerobias-org/standard) | `package/<class>/<jurisdiction>/<publisher>/<version>/` (up to 4 levels) | `main` | `sh scripts/createNewStandard.sh` |
| [`benchmark`](https://github.com/zerobias-org/benchmark) | `examples/<vendor>/<suite>/<version>/` (not `package/`) | `dev` | `sh scripts/createNewBenchmark.sh` |
| [`crosswalk`](https://github.com/zerobias-org/crosswalk) | `package/<publisher>/<category>/<version_id>/` (3 levels) | `dev` | `sh scripts/createNewCrosswalk.sh` |
| [`compliance_feature`](https://github.com/zerobias-org/compliance_feature) | `package/zerobias/<f_id>/` (2 levels, single vendor) | `main` | `sh scripts/createNewCompliancefeature.sh` |
| [`kb`](https://github.com/zerobias-org/kb) | **Hugo static-site source** (NOT a content monorepo) | n/a | — |

After scaffold: edit `index.yml`, then `npm install && npm shrinkwrap && npm run validate`, then PR.

### Catalog (products, services, vendors)

| Repo | Layout | Notes |
|------|--------|-------|
| [`product`](https://github.com/zerobias-org/product) | `package/<vendor>/<edition>/<product>/` (3 levels) | Hybrid Lerna + Gradle (in migration) |
| [`vendor`](https://github.com/zerobias-org/vendor) | `package/<vendor>/` (1 level) — 464 entries | **Migrating Lerna → Gradle (`zb.content` plugin).** New canonical flow: `./gradlew :<vendor>:gate`. Legacy `npm install/shrinkwrap/validate` will be removed. See `MIGRATION_STATUS.md`. |
| [`suite`](https://github.com/zerobias-org/suite) | `package/<vendor>/<edition>/` (2 levels) | Same lerna→gradle migration as `vendor`. See `MIGRATION_STATUS.md`. |
| [`segment`](https://github.com/zerobias-org/segment) | `package/zerobias/<id>/` (2 levels, single vendor) | Lerna. PR against `main`. |

### Integration

| Repo | Layout | Stack |
|------|--------|-------|
| [`module`](https://github.com/zerobias-org/module) | `package/<vendor>/<product>/<api-type>/` (3 levels) | **Gradle + zbb** (not Lerna). NPM scope: `@zerobias-org/module-<vendor>-<product>-<api-type>`. Each sub-package has `api.yml`, `connectionProfile.yml`, `connectionState.yml`, `src/`, `test/`, `hub-sdk/`. The repo itself uses git submodules (`.gitmodules`). |
| [`collectorbot`](https://github.com/zerobias-org/collectorbot) | `package/<vendor>/<product>/<api-type>/` (3 levels) | **Gradle + zbb**. **README is empty.** Pairs with `module/`. |
| [`pipeline`](https://github.com/zerobias-org/pipeline) | Single sub-package `package/pipeline/` containing YAML pipeline configs | Lerna. Currently holds `agentskills.yml`, `hl7-fhir.yml`, `mcpservers.yml`. Despite the name, *not* a "wire module + collector for scheduled execution" config — it's a small set of pipeline definitions. **README is one line.** |

### Apps & UX

| Repo | Layout | Notes |
|------|--------|-------|
| [`app`](https://github.com/zerobias-org/app) | `package/zerobias/<app-name>/` — currently 2 sub-packages (`example-angular`, `example-nextjs`) | Nx Angular workspace + Next.js example for iframe-embedded SPAs |
| [`login`](https://github.com/zerobias-org/login) | `package/<customer>/` (Lerna monorepo, one sub-package per customer) | Built on `@auditmation/dana-login-sdk` + Handlebars. README reads as single-customer but repo is multi-tenant |

### DevOps & developer experience

| Repo | Purpose |
|------|---------|
| [`devops`](https://github.com/zerobias-org/devops) | **CI backbone**: composite GitHub Actions (`actions/`), 23 hoisted Nx variants (`nx-actions/`), 13 reusable workflows (including the org-wide `zbb-publish-reusable.yml` that every content monorepo calls into), and Docker images. **Coordinate before changing** — modifications cascade across many repos. |
| [`get-shit-done`](https://github.com/zerobias-org/get-shit-done) | **MIT-licensed fork of `gsd-build/get-shit-done`**. Meta-prompting / spec-driven dev system supporting Claude Code, OpenCode, Gemini CLI, Codex, Copilot, Cursor, Windsurf, Antigravity. Distributed via `npx get-shit-done-cc`. The only repo in the org with a real OSS LICENSE. |
| [`zb-dx`](https://github.com/zerobias-org/zb-dx) | Developer-experience knowledge repo: `automation/`, `friction-log/`, `guides/`, `patterns/`, `skills/`, `templates/`, `participants/`. Most `skills/` and `guides/` are still placeholders. Discovery via `IDEAS.md` + the `#zb-dx` Slack channel. |

### Test fixtures

| Repo | Notes |
|------|-------|
| [`framework_test`](https://github.com/zerobias-org/framework_test) | **Actual GitHub fork** of `framework` (`parent: zerobias-org/framework`). Used to validate GitHub Actions and PR workflows. **Do not contribute compliance content here** — open PRs against `framework` instead. |

> **Note on excluded repos.** `.github` (the org-level meta repo for issue
> templates and workflow defaults) is intentionally not a submodule —
> there's nothing to develop there. Private and archived repos are also
> excluded. See [`.repoignore`](.repoignore) for the full list.

---

## Documentation

Curated documentation lives under [`docs/`](docs/). Start here:

| Document | What it covers |
|----------|----------------|
| [`docs/Concepts.md`](docs/Concepts.md) | Core domain concepts: Standards, Frameworks, Benchmarks, Crosswalks, Modules, Vendors, Products, Segments |
| [`docs/Architecture.md`](docs/Architecture.md) | How the open-source pieces fit into the broader ZeroBias platform |
| [`docs/ContentArtifacts.md`](docs/ContentArtifacts.md) | The content catalog system and how artifacts are published & loaded |
| [`docs/Modules.md`](docs/Modules.md) | Hub module system: what modules are and how they're built |
| [`docs/ModuleSDKs.md`](docs/ModuleSDKs.md) | Client SDKs for consuming Hub Modules and Platform Services (TypeScript, multi-language vision) |
| [`docs/SubmoduleWorkflow.md`](docs/SubmoduleWorkflow.md) | Working with git submodules without losing your changes |
| [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md) | npm link patterns and cross-repo dependency chains |
| [`docs/RegistrySetup.md`](docs/RegistrySetup.md) | NPM registry topology, ZB_TOKEN setup, what's reachable without a token |
| [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md) | Map from every concept to the doc that explains it |
| [`CLAUDE.md`](CLAUDE.md) | Workflow guidance for Claude Code (and other coding agents) using this meta-repo |

Inside each sub-repo, look for its own `README.md` and (where present)
`CLAUDE.md` — they hold the per-repo build/test/deploy specifics.

---

## Using this repo with Claude Code (or other coding agents)

The meta-repo is designed to give AI coding agents **full cross-repo
context** so they can answer questions, suggest implementations, and edit
across multiple repositories coherently.

```bash
cd zerobias              # start the agent from the meta-repo root
claude                   # or the agent of your choice
```

[`CLAUDE.md`](CLAUDE.md) documents the recommended workflow — load
hierarchical context, ask about the target component, navigate via
[`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md), and respect
the per-sub-repo `CLAUDE.md` files for component-specific guidance.

[`zb-dx`](https://github.com/zerobias-org/zb-dx) bundles reusable Claude
skills you can opt into.

---

## Contributing

Almost all contributions belong inside one of the sub-repos, not this
meta-repo. Pick a sub-repo, read its `README.md`, and open issues / PRs
against **that sub-repo's** GitHub repository. The meta-repo is updated
separately to bump the pinned submodule SHAs once your changes are
merged.
