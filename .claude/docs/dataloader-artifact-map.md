# Dataloader Artifact Map

Agent- and human-readable reference for **every artifact type the ZeroBias
platform dataloader can load**, how artifacts reference each other, and the
mechanics that connect them to the platform. The interactive companion diagram
lives at [`artifact-map/index.html`](../../artifact-map/index.html) — open it
in a browser (self-contained, no build step).

> **Source state** (re-validation anchor — update when re-validated):
> - Platform repo: `zerobias-com/platform` @ `main`, registry verified at
>   commit `85f746a` (KB index) and cross-checked at HEAD via `gh api`
> - Registry file: `dataloader/src/processors/` + `dataloader/src/importer/loaderRegistry.ts`
>   (`buildLoaderRegistry()`), **37 registered entries**
> - Content anatomy: local zerobias-org clones
> - Last validated: **2026-06-12**
>
> Re-validation requires **internal access** (the dataloader source lives in
> the private `zerobias-com/platform` repo), so the `validate-artifact-map`
> skill is intentionally NOT shipped in this public repo — ZeroBias
> maintainers keep it in their personal `~/.claude/skills/`. External users:
> if the "Last validated" date looks stale or something here contradicts
> observed dataloader behavior, please open an issue on
> `zerobias-org/zerobias-org` rather than guessing.

---

## How to use this document (for agents)

- Routing: when a task involves "loading content", "publishing an artifact",
  "why doesn't X show up in the platform", or wiring a new
  vendor/product/module/collector, find the artifact type below and check its
  **linking fields** — most load failures are broken cross-references.
- This file documents the **type level**. For per-package details always read
  the authoritative processor README in
  `zerobias-com/platform:dataloader/src/processors/<type>/README.md`
  (via `zb-knowledge` `get_file` or `gh api`).
- The diagram (`artifact-map/index.html`) renders the same data interactively.
  If you change facts here, update the `NODES`/`EDGES` data in that file too.

## Core mechanics

**Type selection.** A package is loadable iff its `package.json` carries a
`zerobias` stanza (legacy name: `auditmation`) with
`import-artifact: "<type>"`. The lowercased value is looked up in the loader
registry — **package-name prefixes (`vendor-`, `module-`…) are convention
only and never parsed for routing**. Other stanza fields: `package` (dotted
identity, e.g. `amazon.aws.kms`, must triangulate with npm name and directory),
`dataloader-version` (minimum loader version), `imports[]`, `skip`,
`deprecated`, `platform-content` (minimum platform schema version), `orgId`,
`migrates-from`.

**Load ordering.** After `npm pack` + install, the dataloader walks
`npm list -a --json --omit dev`. Only deps scoped `@nfcc`, `@auditmation`,
`@auditlogic`, `@zerobias-org`, `@zerobias-com` with a registered
`import-artifact` enter the dependency list; children are inserted **before**
parents, so leaf artifacts load first and the top-level package last. Each
dependency loads in its own DB transaction; the first failure aborts the run.
**npm `dependencies` between artifact packages are therefore load-order
edges** (vendor before suite before product, frameworks before crosswalks…).

**Versioning / environments.** Version resolution uses npm dist-tags per
environment (`ENV_TYPE`; prod → `latest`); a `skip-dataloader` dist-tag skips
that exact version. *Unrevertable* types (product, suite, vendor, framework,
benchmark, standard, schema, evidencedefinition, query, evidencebot, kb, tag,
pipeline) refuse downgrades and retire older equivalents; other types can
coexist in multiple versions. Artifact identity = `UUIDv5(npm name)`.

**Naming equivalence** (`naming.ts`): scopes `@auditlogic ↔ @zerobias-org`
and `@auditmation ↔ @zerobias-com` are equivalent, with
`auditmation ↔ zerobias` substring substitution in names/codes — used for
installed-version checks, retirement and dedup. `pipeline` is the only type
that opts out.

**Migration.** `zerobias.migrates-from` re-parents a predecessor package's
content rows onto the new artifact, writes a `MigratedArtifact` sentinel
blocking future loads of the old name, and enforces manifest-ID parity before
and after. Not allowed for vendor / suite / product.

**Post-load events:** `base.ResourceLinker` (standard/framework/benchmark/
crosswalk/workflow), `base.BenchmarkLoaded`, `base.ComplianceFeatureRescan`,
`base.SyncBuiltInRoles` (rbac/role/sop).

**Cross-reference mechanisms** (four): npm dependencies (ordering), UUID `id`
values in YAML, codes / dotted package identities, and `$ref` into a
dependency's published files (e.g. module OpenAPI → product
`catalog.yml#/Product`).

---

## Artifact type inventory (37)

| `import-artifact` | Group | Main files | References (→ type via field) |
|---|---|---|---|
| `vendor` | Catalog | `index.yml`, logo | → tag (`tags[]`); CPE codes (`cpeVendors[]`) |
| `suite` | Catalog | `index.yml` | → vendor (`vendorId`/`vendorCode` + npm dep) |
| `product` | Catalog | `index.yml`, `catalog.yml`, `components/`, `editions/`, `features/`, `supports.yml` | → vendor (`vendorId`), suite (`suiteId` when `parentType: suite`), segment (`segments[]` UUIDs), compliance_feature (`supports.yml`; `features/*.yml` mints child features) |
| `segment` | Catalog | `index.yml`, `supports.yml` | → segment_type (`segmentType`), segment (`parents[]`), compliance_feature (`supports.yml`) |
| `segment_type` | Catalog | `index.yml` | (rank taxonomy: domain/category/tool/feature_group) |
| `tag` | Catalog | `<TagType>/<name>.yml` | referenced by `tags[]` UUIDs from most types |
| `catalog_overview` | Catalog | `folders/*.yml` | → schema (`rows[].className`), raw `countQuery` SQL |
| `standard` | Compliance | `index.yml`, `elements/*.yml`, `baselines/` | element `parent` chains; generic `links` map; npm dep on publisher suite |
| `framework` | Compliance | standard files + control fields | standard specialization (Controls); → standard (`overlayStandard`+`overlayElement`); SCF packages (`complianceforge.scf*`) populate ScfControl/ScfDomain |
| `benchmark` | Compliance | standard files + test-case fields | standard specialization (TestCases); → **schema** (`subjectTypes[]` must equal Class names) |
| `crosswalk` | Compliance | `index.yml`, `elements.yml`, `versions/*.yml` | → standard/framework (`sourceStandard`/`targetStandard` dotted codes; `sourceElement`/`targetElement` aliases); both must be npm deps |
| `compliance_feature` | Compliance | `index.yml`, `elements.yml` | → compliance_feature_type (`complianceFeatureTypes[]`), standard/framework/benchmark elements (`{standardAlias, elementAlias}` or `id`) |
| `compliance_feature_type` | Compliance | `index.yml` | (enum of feature type codes) |
| `schema` | Integration | `fields/`, `enums/`, `documents/`, `interfaces/`, `classes/` | → schema (`zerobias.imports[]`, `extends`, `linkTo`); product schemas npm-depend on their product |
| `coretype` | Integration | none (code-generated) | writes core `Field`/`DataType` rows into the same tables as schema |
| `module` | Integration | bundled OpenAPI yml, `generated/api/manifest.json`, `connectionProfile.yml`, `runtimeConfig.yml` | → product (`info.x-product-infos[].$ref` → `catalog.yml#/Product`, ≥1 required), oauth (`x-oauth-providers[]`), module (`*-interface-*` deps: dataproducer/fileproducer) |
| `collectorbot` | Integration | `hub.yml`, `parameters.yml`, `collector.yml` | → module (`hub.yml modules{}` npm name + `moduleId`), product (`hub.yml products{}` code + UUID), schema (`collector.yml classes{}`; shared classes rejected) |
| `pipeline` | Integration | `pipeline/*.yml`, `deprecated.yml` | → product (`productId`), collectorbot (`collectorArtifact` npm name); writes Cron rows + EventBridge schedules |
| `oauth` | Integration | `index.yml` (`{id, url}`) | → VSP by **package-code convention** (resolved Vendor→Suite→Product → `vspId`) |
| `sharedobject` | Integration (hidden) | `objects/<ClassName>/*.yml` | → schema (dir name must be an existing *shared* Class); virtual — no artifact_version row |
| `query` | Evidence | `index.yml` | → schema (GraphQL template classes → classIds), standard (`elementIds[]`), evidencedefinition (`evidenceDefinitionIds[]`) |
| `evidencedefinition` | Evidence | `index.yml` | → SCF framework (`controls[]` codes, `*` = required; `domains[]`) |
| `evidencebot` | Evidence | `index.yml` | → query (`graphqlQueryVersionId`), evidencedefinition (`evidenceDefinitionId`), standard (`elements[]` code pairs) |
| `evidencerequestlist` | Evidence | `*.yml` per list | → framework (`frameworkVersionId` + element codes), evidencedefinition (`evidenceDefinitionId(s)`) |
| `alertbot` | Evidence | `index.yml`, `REMEDIATION.md` | → query (`graphqlQueryVersionId`), role (`roles[]`), standard (`elementIds[]`) |
| `alert_trigger` | Evidence | `trigger/*.yml` | → role (`roles[]`); event/cron selectors |
| `rbac` | Org/ops | `permissions/`, `roles/`, `security/` | permission templates + CatalogRole + access rules; emits SyncBuiltInRoles |
| `role` | Org/ops | `job_duties.yml`, `qualifications.yml`, `categories/`, `work_roles/` | work-role catalog; ids must equal `uuidv5(code, Nil)` |
| `sop` | Org/ops | `roles.yml`, `controls/<SCF-CODE>.yml` | → SCF framework (filename = existing SCF control code), role (`roles[]`) |
| `workflow` | Org/ops | `skill/ status/ field/ role/ workflow/ activity/ triggers/` (fixed order) | → role (RACI codes); statuses/transitions/custom fields; event triggers |
| `nav` | Org/ops | `extras/`, `<ui_version>/{app,folder,page,section,label,action}/` | → rbac (`permission/*` refs); cross-refs as `"{type}/{code}"` strings |
| `kb` | Org/ops | `index.md` front-matter | → ANY resource/package (`relatesTo[]` → `relates_to` links; standard targets get `standard.kbArticleId` back-ref) |
| `cron` | Org/ops | `crons/*.yml` | platform scheduled jobs (table shared with pipeline's collector_bot crons) |
| `dev_user` | Org/ops | `users/*.yml` | hydra seed users; **ENV_TYPE=dev only** |
| `bundle` | Meta | `package.json` only | pure aggregator: npm deps carry the real artifacts (NullModule, short-circuited) |
| `vsp` | Meta (stub) | — | legacy no-op ("We no longer handle old VSP artifacts") |
| `policy` | Meta (stub) | — | registered but unimplemented no-op |

Also present but **not loadable**: `processors/example/` (unregistered
developer template). `types/` and `util/` repos publish libraries, not
artifacts (no `import-artifact`).

## Hidden DB-level couplings

Relations that don't appear in any manifest but exist at the database level —
check these when a change "shouldn't affect" another type but does:

- **product ↔ segment**: both write `Offering` + `ComplianceFeatureSupport`
  (one shared support matrix).
- **pipeline ↔ cron**: pipeline writes `Cron` rows (type `collector_bot`) into
  the cron artifact's table, plus shared-boundary `BoundaryProduct`/`Component`.
- **rbac ↔ role ↔ sop ↔ workflow**: all converge on `CatalogRole`
  (`roleDao.loadFromTemplate`).
- **benchmark → schema**: test-case `subjectTypes[]` validated against
  existing `Class` names at load time.
- **evidencedefinition / sop → SCF**: link only against `ScfControl`/`ScfDomain`
  rows, populated exclusively by `complianceforge.scf*` framework packages.
- **module ↔ oauth**: meet in `OAuthProvider` (resolved per VSP).
- **coretype → schema**: writes `core.*` fields into the same
  Schema/Field/DataType tables schema artifacts build on.

## Identity & convention cheatsheet

- Stable identity in YAML = immutable UUID `id` (repo-wide unique) + human
  `code`; package identity is the dotted string ending in the type
  (`<vendor>.[<suite>.]<product>.<type>`).
- Hierarchies: element `parent:` (standard family, by element file code),
  segment `parents:` (codes), product `parentType` + `vendorId`/`suiteId`.
- Module's `moduleId` lives top-level in `package.json` and is what
  collectorbot `hub.yml` references.
- Collectorbot mapping logic is TypeScript (`Mappers.ts`), not declarative.
- Newer Gradle-era counterparts of module/schema/collectorbot live in private
  `auditlogic/*` repos; public repos may lag (e.g. public `module/` holds only
  a handful of modules).
