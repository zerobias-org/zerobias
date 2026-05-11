# Documentation Index

A map from every concept, task, or sub-repo to the documentation that
explains it. Designed to be the **first place** a developer (or coding
agent) looks when they don't know where to start.

> All per-repo facts below were verified by reading each repo's actual
> README, top-level structure, and at least one sample sub-package
> (May 2026). See the per-repo notes for important quirks.

---

## Top-level docs

| File | What's in it |
|------|--------------|
| [`README.md`](../README.md) | Repo inventory, quick-start, layout of the meta-repo |
| [`CLAUDE.md`](../CLAUDE.md) | Workflow guidance for Claude Code and other coding agents |
| [`Concepts.md`](Concepts.md) | Domain vocabulary: Standards, Frameworks, Benchmarks, Vendors, Products, Modules, etc. |
| [`Architecture.md`](Architecture.md) | How open-source pieces fit into the broader ZeroBias platform |
| [`ContentArtifacts.md`](ContentArtifacts.md) | Packaging, publishing, and contribution mechanics for content-monorepo repos |
| [`Modules.md`](Modules.md) | Hub Modules — Gradle+zbb stack, layout, contribution flow |
| [`ModuleSDKs.md`](ModuleSDKs.md) | Client SDKs that consume Hub Modules and Platform Services (auto-generated from OpenAPI) |
| [`SubmoduleWorkflow.md`](SubmoduleWorkflow.md) | Working with git submodules without losing changes |
| [`LocalDevelopment.md`](LocalDevelopment.md) | `npm link` patterns for cross-repo dependency chains |
| [`RegistrySetup.md`](RegistrySetup.md) | NPM registry topology + `ZB_TOKEN` setup (without it `npm install` fails) |

---

## "I want to do X" → repo + how

This is the practical routing table. Pick the row that matches what
you're trying to do, then follow the link.

> ⚠️ Note on PR base branches: several content repos require PRs
> against `dev`, not `main`. Always read the repo's README first.

### Compliance content

| What you want to do | Repo | Layout | PR target | Scaffold |
|---------------------|------|--------|-----------|----------|
| Add a compliance framework / control set | [`framework`](https://github.com/zerobias-org/framework) | `package/<publisher>/<category>/<version>/` | `dev` | `sh scripts/createNewFramework.sh` |
| Add a formal standard (law/regulation source text) | [`standard`](https://github.com/zerobias-org/standard) | `package/<class>/<jurisdiction>/<publisher>/<version>/` | `main` | `sh scripts/createNewStandard.sh` |
| Add a benchmark / test-case bundle | [`benchmark`](https://github.com/zerobias-org/benchmark) | `examples/<vendor>/<suite>/<version>/` (note: `examples/`, not `package/`) | `dev` | `sh scripts/createNewBenchmark.sh` |
| Map between two frameworks | [`crosswalk`](https://github.com/zerobias-org/crosswalk) | `package/<publisher>/<category>/<version_id>/` | `dev` | `sh scripts/createNewCrosswalk.sh` |
| Add a compliance feature that a product offers | [`compliance_feature`](https://github.com/zerobias-org/compliance_feature) | `package/zerobias/f_<abbrev>/` | `main` | `sh scripts/createNewCompliancefeature.sh` |
| Write a knowledge-base article | [`kb`](https://github.com/zerobias-org/kb) | Hugo static-site source (theme: `doks`) | n/a | — (Hugo content, not a content monorepo) |

After the scaffold script: edit the generated `index.yml`, then
`npm install && npm shrinkwrap && npm run validate`, then PR.

### Catalog: vendors, products, suites, segments

| What you want to do | Repo | Layout | Stack |
|---------------------|------|--------|-------|
| Add or update a vendor | [`vendor`](https://github.com/zerobias-org/vendor) | `package/<vendor>/` | **Migrating Lerna→Gradle.** Prefer `./gradlew :<vendor>:gate`. See `MIGRATION_STATUS.md` in-repo. |
| Add or update a product | [`product`](https://github.com/zerobias-org/product) | `package/<vendor>/<edition>/<product>/` | Hybrid Lerna+Gradle |
| Add or update a product suite | [`suite`](https://github.com/zerobias-org/suite) | `package/<vendor>/<edition>/` | **Migrating Lerna→Gradle.** See `MIGRATION_STATUS.md` in-repo. |
| Add or update a segment (taxonomy node) | [`segment`](https://github.com/zerobias-org/segment) | `package/zerobias/<id>/` | Lerna+Nx |

> **Catalog ordering matters.** If you're introducing a new
> vendor + product + suite together, add them in that order so each
> can reference the previous.

### Integration

| What you want to do | Repo | Layout | Stack |
|---------------------|------|--------|-------|
| Build / fix a Hub integration module | [`module`](https://github.com/zerobias-org/module) | `package/<vendor>/<product>/<api-type>/` | **Gradle+zbb** (not Lerna). NPM scope `@zerobias-org/module-<vendor>-<product>-<api-type>`. Validate: `./gradlew :<module>:gate`. See [`Modules.md`](Modules.md). |
| Build / fix an ETL collector | [`collectorbot`](https://github.com/zerobias-org/collectorbot) | `package/<vendor>/<product>/<api-type>/` | **Gradle+zbb**. README is empty — coordinate with maintainers. |
| Define an AuditgraphDB schema | [`schema`](https://github.com/zerobias-org/schema) | `package/<vendor>/<group>/<schema-name>/` | Lerna+Nx. **Read [`schema/CONTRIBUTING.md`](https://github.com/zerobias-org/schema/blob/main/CONTRIBUTING.md)** — it's the most detailed contrib doc in the org. |
| Add a data-source / agent-pipeline config | [`pipeline`](https://github.com/zerobias-org/pipeline) | Single sub-package `package/pipeline/<file>.yml` | Lerna. Currently small (~3 yml files). |

### Apps, login templates, types

| What you want to do | Repo | Layout / stack |
|---------------------|------|----------------|
| Customize / build a tenant SPA | [`app`](https://github.com/zerobias-org/app) | `package/zerobias/example-angular`, `example-nextjs`. Nx Angular workspace. |
| Add a white-label login page (per customer) | [`login`](https://github.com/zerobias-org/login) | `package/<customer>/` Lerna monorepo. Built on `@auditmation/dana-login-sdk` + Handlebars. |
| Fix / extend ZeroBias TypeScript types | [`types`](https://github.com/zerobias-org/types) | `packages/` (Lerna+Nx). README is missing — read per-sub-package READMEs. |
| Fix / extend cross-repo utilities | [`util`](https://github.com/zerobias-org/util) | `packages/` (Lerna+Nx+Gradle). **Includes `zbb` Gradle plugin, `codegen`, `module-tester` — load-bearing. Coordinate first.** |

### DevOps & dev experience

| What you want to do | Repo | Notes |
|---------------------|------|-------|
| Add / change a reusable GitHub Action or workflow | [`devops`](https://github.com/zerobias-org/devops) | Hosts the org-wide `zbb-publish-reusable.yml` and 12 other reusable workflows. **Coordinate before changing — changes cascade across content repos.** README is stale. |
| Improve the spec-driven-dev tooling for AI agents | [`get-shit-done`](https://github.com/zerobias-org/get-shit-done) | **MIT-licensed fork** of `gsd-build/get-shit-done`. Multi-runtime (Claude Code, Codex, Cursor, etc.). Distributed via `npx`. |
| Share a Claude skill / dev pattern / guide | [`zb-dx`](https://github.com/zerobias-org/zb-dx) | Mostly placeholder dirs today. Coordinate via `IDEAS.md` and the `#zb-dx` Slack channel. Self-register profile in `participants/`. |

### Things you should NOT contribute to

| Repo | Why |
|------|-----|
| [`framework_test`](https://github.com/zerobias-org/framework_test) | **Actual GitHub fork of `framework`**, used to test CI/PR workflows. Open compliance-content PRs against `framework`, not here. |
| `.github` | Org-level configuration repo (issue templates, etc.). Not part of this meta-repo. |

---

## Concept → primary repo

| Concept | Primary repo | See also |
|---------|--------------|----------|
| Standard | [`standard`](https://github.com/zerobias-org/standard) | `framework`, `crosswalk` |
| Framework | [`framework`](https://github.com/zerobias-org/framework) | `standard`, `benchmark`, `crosswalk` |
| Benchmark | [`benchmark`](https://github.com/zerobias-org/benchmark) | `framework`, `module` |
| Crosswalk | [`crosswalk`](https://github.com/zerobias-org/crosswalk) | `framework` |
| Compliance Feature | [`compliance_feature`](https://github.com/zerobias-org/compliance_feature) | `product`, `framework` |
| KB Article (Hugo) | [`kb`](https://github.com/zerobias-org/kb) | any |
| Vendor | [`vendor`](https://github.com/zerobias-org/vendor) | `product`, `suite` |
| Product / Service | [`product`](https://github.com/zerobias-org/product) | `vendor`, `suite`, `segment`, `compliance_feature` |
| Suite | [`suite`](https://github.com/zerobias-org/suite) | `product`, `vendor` |
| Segment (taxonomy) | [`segment`](https://github.com/zerobias-org/segment) | `product` |
| Module (Hub integration) | [`module`](https://github.com/zerobias-org/module) | `collectorbot`, `schema`, `vendor`, `product` |
| Collector Bot (ETL) | [`collectorbot`](https://github.com/zerobias-org/collectorbot) | `module`, `schema` |
| Pipeline config | [`pipeline`](https://github.com/zerobias-org/pipeline) | — |
| AuditgraphDB Schema | [`schema`](https://github.com/zerobias-org/schema) | `collectorbot` |
| Custom SPA | [`app`](https://github.com/zerobias-org/app) | — |
| Custom Login screen | [`login`](https://github.com/zerobias-org/login) | — |
| Domain TypeScript types | [`types`](https://github.com/zerobias-org/types) | every code repo |
| Cross-repo utilities (incl. `zbb` Gradle plugin) | [`util`](https://github.com/zerobias-org/util) | every content repo |
| Reusable GitHub workflows | [`devops`](https://github.com/zerobias-org/devops) | every repo's CI |
| Meta-prompting / spec-driven dev | [`get-shit-done`](https://github.com/zerobias-org/get-shit-done) | — |
| Claude skills / dev hints | [`zb-dx`](https://github.com/zerobias-org/zb-dx) | — |

---

## Audience guide

### For developers new to ZeroBias
1. [`README.md`](../README.md)
2. [`Concepts.md`](Concepts.md)
3. [`Architecture.md`](Architecture.md)
4. The "I want to do X" table above
5. The target sub-repo's `README.md` (and `CONTRIBUTING.md` if present)

### For compliance content contributors
1. [`Concepts.md`](Concepts.md) — Compliance content artifacts section
2. [`ContentArtifacts.md`](ContentArtifacts.md) — packaging & PR mechanics
3. The "Compliance content" table above
4. Target repo's `README.md`

### For integration developers (modules, collectors)
1. [`Concepts.md`](Concepts.md) — Integration section
2. [`Modules.md`](Modules.md)
3. [`module/` README](https://github.com/zerobias-org/module)
4. [`schema/CONTRIBUTING.md`](https://github.com/zerobias-org/schema/blob/main/CONTRIBUTING.md) (the org's most detailed contrib doc)
5. [`collectorbot/` README](https://github.com/zerobias-org/collectorbot) — note: empty

### For app / login template developers
1. [`Concepts.md`](Concepts.md) — Apps & UX
2. [`app/` README](https://github.com/zerobias-org/app)
3. [`login/` README](https://github.com/zerobias-org/login)

### For AI coding agents
1. [`CLAUDE.md`](../CLAUDE.md) (workflow rules)
2. [`Concepts.md`](Concepts.md) (vocabulary)
3. This index (navigation)
4. Per-sub-repo `CLAUDE.md` for the sub-repo being worked on

---

## What's *not* documented here

Closed-source platform internals — authentication, the Hub runtime,
dataloader, internal APIs, infrastructure — live in a separate private
organization. They aren't reproduced in this meta-repo. If you need them,
consult the internal platform documentation.

The contracts the open-source side must honour (OpenAPI shape for
Modules, `index.yml` shapes for content artifacts, `zbb` Gradle plugin
conventions, etc.) **are** documented here — that's the boundary
contributors interact with.
