# ZeroBias Open-Source Meta-Repo

> One workspace that contains every public repository in the
> [`zerobias-org`](https://github.com/zerobias-org) GitHub organization —
> the open-source side of the [ZeroBias](https://zerobias.com) compliance
> automation platform.

This repo doesn't ship code of its own. It's a thin **meta-repo** that hosts
cross-repo documentation and helper scripts that clone every public
`zerobias-org` repository into a single working tree. Each sub-repo is a
plain, standalone git clone — no submodules, no pinned SHAs, just every
repo side-by-side. Once set up, you (or a coding agent like
[Claude Code](https://claude.com/claude-code)) can read, search, build, and
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

- Get the **full open-source surface** with one bootstrap step.
- **Read, grep, and reason** across every repo from a single working tree.
- Give an **AI coding agent** the full cross-repo context so it can answer
  questions, suggest implementations, and respect conventions across the
  whole ecosystem.
- Run the **helper scripts** (`scripts/clone-all.sh`, `scripts/update_all.sh`)
  that bootstrap and keep all sub-repos in sync.

---

## Quick start

## What you need


### Accounts

- **ZeroBias** at [`app.zerobias.com`](https://app.zerobias.com)
  if you want the live platform integrations below (MCPs, private NPM,
  `zb` CLI). External readers can browse all source without an account.
- **GitHub** at [`github.com`](https://github.com)

### Access Tokens

- **ZeroBias Platform Org ID and API Key**
  - [Login to ZeroBias](https://app.zerobias.com)
  - Click profile avatar (upper right)
  - Click "Create New API Key"
  - Note Organization ID and API Key (Keep these secure)
- **GitHub Personal Access Token (PAT)**
  - Create [New (Classic) PAT](https://github.com/settings/tokens/new) (read:packages)
  - Assign to environment variable `NPM_TOKEN` (or `READ_TOKEN`)

### Workstation Tools

Ensure the following tools are present on your workstation:

- **git [>= 2.34]**
- **Java [>= 21.0]**
- **Node [>= 22.20.0]**
- **Python [>= 3.12]**
- **Docker [>= 29.6.1]**
- [**Claude Code [>= 2.0]**](https://claude.com/claude-code)


This meta-repo is designed to be driven by an agent — one working tree
  spanning every public `zerobias-org` repo so the agent can read,
  search, and reason across them at once. Everything works without
  Claude Code, but most of the leverage is gone. 

### Docker Container

If you wish to run the ZeroBias tools in a Docker container, review [sandbox](./docs/Sandbox.md).


```bash
# 1. Clone this meta-repo
git clone https://github.com/zerobias-org/zerobias.git
cd zerobias

# 2. Bootstrap every public zerobias-org repo into this working tree
./scripts/clone-all.sh
```

That's it. You now have every public `zerobias-org` repo checked out
underneath this directory, each on its default branch.

> 👉 **Next stop:** [`QUICKSTART.md`](QUICKSTART.md) — Claude Code +
> MCP setup, `ZB_TOKEN`, `zbb`, and ready-to-paste example prompts
> for working in this meta-repo.

Re-running `./scripts/clone-all.sh` is safe — it only clones repos that
aren't already present. To refresh existing clones to the tip of their
default branch, run `./scripts/update_all.sh`.

**Requirements:** just `git`. The list of repos to clone lives in
[`scripts/repos.list`](scripts/repos.list) (committed to this repo),
so no GitHub-API lookup or `gh` CLI is needed at clone time.
Maintainers refresh that list when the org adds a new repo via
`scripts/refresh-repos-list.sh` (which does use `gh`).

## Docker Container

If you wish to run the ZeroBias tools in a Docker container, review [sandbox](./docs/Sandbox.md).

---

## Find your way around

Every sub-repo is independent, but they form a small ecosystem with
predictable roles. Once you know which repo owns what, the rest is just
"open that repo and follow its README."

### Concepts at a glance

| Concept | Lives in | Owns |
|---------|----------|------|
| **Standard** | [`standard/`](https://github.com/zerobias-org/standard) | The formal published text (NIST, ISO, CIS, …), broken into Elements |
| **Framework** | [`framework/`](https://github.com/zerobias-org/framework) | Requirements — *what* must be done to comply |
| **Benchmark** | [`benchmark/`](https://github.com/zerobias-org/benchmark) | Test cases — *how* to achieve compliance on a specific technology |
| **Crosswalk** | [`crosswalk/`](https://github.com/zerobias-org/crosswalk) | Mappings between Requirements across different Frameworks |
| **Compliance Feature** | [`compliance_feature/`](https://github.com/zerobias-org/compliance_feature) | What a product offers toward satisfying a Requirement |
| **KB Article** | [`kb/`](https://github.com/zerobias-org/kb) | Hugo static-site documentation |
| **Vendor / Product / Suite / Segment** | [`vendor/`](https://github.com/zerobias-org/vendor), [`product/`](https://github.com/zerobias-org/product), [`suite/`](https://github.com/zerobias-org/suite), [`segment/`](https://github.com/zerobias-org/segment) | The catalog of who makes what, grouped into taxonomy |
| **Module** | [`module/`](https://github.com/zerobias-org/module) | OpenAPI-defined Hub integration that talks to an external system |
| **Collector Bot** | [`collectorbot/`](https://github.com/zerobias-org/collectorbot) | ETL that shapes Module output into AuditgraphDB objects |
| **Schema** | [`schema/`](https://github.com/zerobias-org/schema) | AuditgraphDB class/link definitions |
| **App / Login** | [`app/`](https://github.com/zerobias-org/app), [`login/`](https://github.com/zerobias-org/login) | Customer-facing SPAs and white-label login templates |
| **Types / Util** | [`types/`](https://github.com/zerobias-org/types), [`util/`](https://github.com/zerobias-org/util) | Shared TypeScript types and load-bearing libraries (incl. `zbb` Gradle plugin) |
| **DevOps** | [`devops/`](https://github.com/zerobias-org/devops) | Reusable GitHub Actions and workflows used by every content repo |

For the full vocabulary including how artifacts cross-reference each
other, see [`docs/Concepts.md`](docs/Concepts.md).

### Common tasks → where they live

| What you want to do | Open this repo | PR target |
|---------------------|----------------|-----------|
| Add a compliance framework | `framework/` | `dev` |
| Add a standard (law/regulation text) | `standard/` | `main` |
| Add a benchmark / test-case bundle | `benchmark/` | `dev` |
| Map between two frameworks | `crosswalk/` | `dev` |
| Tie a product to a Requirement it satisfies | `compliance_feature/` | `main` |
| Add or update a vendor / product / suite / segment | `vendor/` / `product/` / `suite/` / `segment/` | usually `main` |
| Build a new Hub integration | `module/` + `collectorbot/` + `schema/` | `main` |
| Customize a tenant SPA or login screen | `app/` / `login/` | `main` |
| Touch shared TypeScript types or `zbb` plugin | `types/` / `util/` | `main` (coordinate first) |
| Change a reusable CI workflow | `devops/` | `main` (coordinate first) |

Each row has full details (layout, scaffold script, special quirks) in
[`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md).

### Contribution flow

Each sub-repo is a normal, standalone git clone. The flow is the same
whether you cloned the meta-repo or just that one repo on its own:

```bash
cd <sub-repo>                                        # e.g. cd module
cat README.md                                        # always read this first
[ -f CLAUDE.md ]       && cat CLAUDE.md              # agent guidance, if any
[ -f CONTRIBUTING.md ] && cat CONTRIBUTING.md        # repo-specific contrib rules

npm install                                          # or the repo's build step
git switch -c feat/my-change                         # never commit on main/master
# ... edit, run the repo's validate/test step ...
git commit -m "feat(scope): short description"
git push -u origin feat/my-change
gh pr create                                         # opens against the sub-repo's GitHub
```

Once the PR merges, you're done — there is no follow-up commit needed in
the meta-repo (it doesn't track sub-repo state).

> ⚠️ **NPM registry caveat.** `@zerobias-org` packages live on a
> **private NPM registry** (`https://pkg.zerobias.org/`) that returns
> 401 to anonymous requests. Without a `ZB_TOKEN`, `npm install`
> inside any sub-repo will fail. You can still read all source code
> freely, but you cannot build or run local validation. See
> [`docs/RegistrySetup.md`](docs/RegistrySetup.md) for setup, and the
> committed [`.npmrc.example`](.npmrc.example) for a reference config.

---

## Repository reference

This is the full inventory of sub-repos with layout details and per-repo
quirks. The "Find your way around" tables above are the quick path; this
section is for when you need to know the exact directory structure or
which stack a repo uses.

All sub-repos live **flat at the root** of this meta-repo (`./framework/`,
`./module/`, etc.) — no extra namespace folder, because the meta-repo
itself *is* the `zerobias-org` namespace.

> Layouts and contribution flows below were verified by reading each
> repo's actual README and inspecting its structure (May 2026).

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
> templates and workflow defaults) is intentionally skipped — there's
> nothing to develop there. Private and archived repos are also excluded.
> See [`.repoignore`](.repoignore) for the full list.

---

## Keeping everything up to date

```bash
./scripts/update_all.sh        # bring every sub-repo to latest default branch
./scripts/clone-all.sh         # also pull in any repos newly added to the org
```

`update_all.sh` works in phases — it audits each sub-repo, prompts only
when a working tree is dirty or diverged, shows the full plan, and only
then applies changes. Pass `--dry-run` to see the state table without
prompting. Repos on feature branches with clean working trees are
auto-switched back to the default branch and fast-forwarded.

> **Note:** the list of repos to clone lives in
> [`scripts/repos.list`](scripts/repos.list). If a new public repo is
> added to the org and not yet in that file, neither `clone-all.sh` nor
> `zbb workspace clone` will pick it up. Maintainers regenerate the
> list via `scripts/refresh-repos-list.sh`.

---

## Further reading

This README is the primary, holistic doc — read it top to bottom and
you have the full picture. The files under [`docs/`](docs/) are
**deep-dive references** to consult only when you need more:

| Open this when… | Document |
|-----------------|----------|
| You need the full domain vocabulary and how artifacts cross-reference each other | [`docs/Concepts.md`](docs/Concepts.md) |
| You want the wider platform context (open-source vs closed-source, runtime contracts) | [`docs/Architecture.md`](docs/Architecture.md) |
| You're publishing or loading content packages | [`docs/ContentArtifacts.md`](docs/ContentArtifacts.md) |
| You're building or fixing a Hub Module | [`docs/Modules.md`](docs/Modules.md) |
| You're consuming Hub Modules from a client SDK | [`docs/ModuleSDKs.md`](docs/ModuleSDKs.md) |
| You're setting up the `zb-knowledge` or `zb` MCP servers in Claude Code | [`docs/MCPs.md`](docs/MCPs.md) |
| You hit cross-repo dependency issues (`npm link` patterns) | [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md) |
| `npm install` is failing inside a sub-repo (401 errors) | [`docs/RegistrySetup.md`](docs/RegistrySetup.md) |
| You want the exhaustive "I want to do X → repo Y" routing | [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md) |
| You're a coding agent looking for workflow rules | [`CLAUDE.md`](CLAUDE.md) |

Each sub-repo's own `README.md` and (where present) `CLAUDE.md` /
`CONTRIBUTING.md` hold the per-repo build/test/deploy specifics — those
are authoritative for that repo and override anything here.

---

## Using this repo with Claude Code (or other coding agents)

The meta-repo is designed to give AI coding agents **full cross-repo
context** so they can answer questions, suggest implementations, and edit
across multiple repositories coherently.

```bash
cd zerobias              # start the agent from the meta-repo root
claude                   # or the agent of your choice
```

[`CLAUDE.md`](CLAUDE.md) is self-contained — an agent reading it on
first sight has everything it needs to bootstrap the workspace, update
it, and work inside sub-repos (including which per-sub-repo
`README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, and `.claude/` directories
to consult).

[`zb-dx`](https://github.com/zerobias-org/zb-dx) bundles reusable Claude
skills you can opt into.

### MCP servers

Two optional ZeroBias MCP servers extend an agent's reach into the
ecosystem. Both authenticate with the **same** ZeroBias API key + org
ID (gather once, configure both) and can be installed **globally
across all projects** or **only for this one**. The `zb` server is
single-org by default; if you work across multiple orgs, add more
profiles later via `zb profile add`. See
[`docs/MCPs.md`](docs/MCPs.md) for full setup, the scope decision, and
troubleshooting.

| Server | What it adds | Setup style |
|--------|--------------|-------------|
| **`zb-knowledge`** | Semantic code search + dependency / impact analysis across every indexed ZeroBias repo (`search_code`, `get_file`, `get_affected_files`, `get_dependency_chain`, `list_repos`, `check_package_versions`, `health_check`) | Hosted HTTP endpoint authenticated via Dana — `claude mcp add --transport http …` |
| **`zb`** | Dynamic access to the entire ZeroBias platform SDK (~1,200 operations) via three meta-tools (`zerobias_search`, `zerobias_describe`, `zerobias_execute`) | Local npm package — `npm install -g @zerobias-com/zerobias-mcp` then `zb setup` |

Running Claude Code from this meta-repo? Just ask: *"set up the MCPs"*
and Claude Code will check which (if any) are missing and walk you
through `claude mcp add` for whichever scope you pick.

---

## Contributing

Almost all contributions belong inside one of the sub-repos, not this
meta-repo. Pick a sub-repo, read its `README.md`, and open issues / PRs
against **that sub-repo's** GitHub repository. The meta-repo only tracks
the docs and helper scripts; it doesn't pin or coordinate sub-repo state,
so there's nothing to bump here after your PR merges.
