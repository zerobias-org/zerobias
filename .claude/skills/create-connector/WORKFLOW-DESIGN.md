# Connector Creation — Workflow Design (DRAFT v0.1)

> **Status: DRAFT — under active discussion, NOT ready to implement.**
> This captures the *target* end-to-end strategy for creating a connector.
> The current `/create-connector` skill (`SKILL.md` in this dir) is the *interim*
> mechanics; this doc describes where we want to take it. Grow it as we discuss;
> implement only when it feels complete.

---

## 1. The core shift

The interim skill builds **VSP → module → collectorbot** and *defers* schema
(targets a generic base interface; the dataloader materializes
`Dynamic<Interface>` at ingest).

The target workflow makes the **data-model analysis the spine**: from the
vendor's API we decide what data maps to which schema concepts, and *that*
decision drives the schema, the module operations, and the mappings. **Concrete
per-product schema packages (the AWS pattern) are the mature deliverable**, not a
permanent afterthought.

## 2. Collection target: always concrete product-schema classes

**Decided:** the target workflow does **NOT** collect onto base interfaces.
Collection always targets the product's **own concrete classes** in its **own
product schema package** — and those concrete classes **MUST extend the right
base/suite interfaces**. The interface is the contract a class implements (for
polymorphism + ontology reuse), never the collection target.

(The base-interface / `Dynamic<Interface>` approach is only the *current interim
hack* in `SKILL.md` while schema is deferred — it is **not** part of this target
design.)

**Consequence:** the concrete product schema is **on the critical path**. A
collector can't be developed or locally tested until its product schema's
concrete classes (and their `-ts`) exist. That makes local `-ts` generation a
**hard prerequisite**, not a promotion-time nicety (§6 ⭐).

The **Stage-2 analysis decides, per data entity:** which concrete class
represents it, which base/suite interface(s) that class extends, its links, and
whether it's a suite-shared entity (→ umbrella) or product-local.

## 3. Reference: the mature schema pattern (`auditlogic/schema`, AWS)

Source: `/Users/ctamas/zerobias/auditlogic/schema/` (CLAUDE.md is the model doc).

- **Layout:** suite **umbrella** package + one package **per service/product**.
  AWS = `amazon.aws.schema` (umbrella: `AwsResource`, `AwsAccount`, shared
  interfaces) + `amazon.aws.s3.schema`, `amazon.aws.iam.schema`, … (22 packages,
  ~130 classes, organized per service).
- **Naming:** npm `@auditlogic/schema-{vendor}-{suite?}-{product}` (+ `-ts`
  companion, same version); package code `{vendor}.{suite?}.{product}.schema`;
  directory mirrors the npm name.
- **Inheritance:** *classes extend interfaces only* (never other classes). Chain:
  service class → suite interface (`AwsResource`) → base interface
  (`Asset`/`CloudService` from `@zerobias-org/schema-zerobias-zerobias-base`).
  Reuse base interfaces when they fit; create vendor/suite interfaces for shared
  properties; multiple inheritance allowed.
- **Build:** Gradle + `zbb` only (lerna/nx removed). Per-package
  `build.gradle.kts` → `plugins { id("zb.schema") }`. `:gate` runs
  validate→lint→compile→test→buildArtifacts→`testIntegrationDataloader` (loads
  into an **ephemeral Neon branch**)→`writeGateStamp`. **`-ts` is generated inside
  that Neon branch** by `@zerobias-com/platform-schema-ts-generator` (no local
  path today — CLAUDE.md:112).
- **12-step "add a schema package" checklist:** CLAUDE.md:556–580.
- **Repo split:** `auditlogic/schema` = concrete vendor schemas (`@auditlogic`);
  `zerobias-org/schema` = open-source base interfaces (`@zerobias-org`). Concrete
  depends on base.

## 4. The stages (target workflow)

### Stage 1 — Research & capture (VSP + API)
- Research vendor/product taxonomy → vendor/suite?/product codes (keep current
  Phase 0.5 research sub-agent + suite-vs-no-suite logic).
- Capture the **source API**: locate/curate the OpenAPI; enumerate **all
  connection methods**.
- **Homes (decided):** curated operations → product `catalog.yml#/Operations`
  (existing mechanism, already holds operations + examples). Raw spec +
  connection-method notes → a **research folder** (don't pollute published
  artifacts). *Do NOT* store the raw vendor OpenAPI in the catalog.
- Output: VSP catalog entries + captured API understanding.

### Stage 1b — Catalog enrichment from research (confidence-tiered)
The Stage-2 research is expensive; reuse it to populate catalog artifacts — but
**gate by stakes**. (Surprising state today: only 1/660 products carry `segments:`
inline and 0/660 carry `complianceFeatures:` — these are set **in-platform**, so
populating them in YAML is a deliberate shift; see §8.)
- **Tier 1 — auto-propose, low-stakes (write after review):**
  - **segment**: rank-match the product to the best existing segment(s) from the
    fixed ~129-entry taxonomy; write UUID(s) to `index.yml#segments`.
  - **cpeProducts**: the official CPE name(s) (e.g. `amazon:aws_s3`). ⭐ **High
    leverage** — this is the ONLY thing needed to light up the entire
    **vulnerability/CVE** chain: the platform matches CPE → CVE from an external
    feed (`cpe_product → cpe → vulnerability_cpe_product → vulnerability`). We
    never author vulnerabilities; we just declare the CPE.
  - **product `index.yml`**: `description`, `url`, `apiDocsUrl`, `tags`,
    `factoryTypes`, `hostingTypes` — from research. (`logo`/`imageUrl` derivable
    but the asset needs the CDN.)
  - **editions / components** (optional): authored as child YAML
    (`<product>/editions/*.yml`, `components/*.yml`; GitHub is the exemplar) —
    licensing tiers / sub-components, derivable from product docs. Low stakes;
    include only if the product clearly has them.
- **Tier 2 — REQUIRED but SME-validated (controls are a MUST, not deferred):**
  - **compliance_feature + controls**: linking the product's features to the controls
    they satisfy is **mandatory and comprehensive**. For each capability (SSO, MFA,
    audit logging, encryption, RBAC…), author a `compliance_feature` under the product
    and list — in its `elements.yml` — **all** the real published framework elements it
    satisfies (`standardAlias`/`elementAlias`). Each element carries a derived
    `control`, so `control → element → feature → product` IS the product↔control link
    (there is no direct field). The loader only checks elements EXIST, not that the
    mapping is correct → an **SME validates accuracy** before publish. SME gates
    correctness, not whether-to-do-it. Needs a framework/standard/control index to map
    against (enabler C). (dossier §8)
- **Out of scope for the connector flow:** `benchmark/` (tech test cases),
  `crosswalk/` (framework↔framework — same audit-weight risk).

### Stage 2 — Data-model analysis & interview ⭐ **(THE BRAIN of connector dev)**
The single most important step — the research + data-mapping assessment that
drives schema, module, and mappings. Get this right and the rest is mechanical.
- **Map raw API → schema** (an existing class, or a new concrete class to be
  extended). For each data entity the API returns, propose its target: an existing
  concrete class, or a new concrete class extending the right base/suite
  interface(s); plus its **links** to other classes and whether it's
  **suite-shared** (→ umbrella) or product-local. Flag **gaps** ("what's missing").
- **Review loop (per §13):** the AI proposes the map; whatever the submitter can
  judge is confirmed in the live interview, the rest is AI-researched with per-item
  confidence and surfaced for **SME review in the PR**. Low-confidence
  mappings/extensions are the highlighted items. Iterates until accepted.
- **Ontology & dedup:** discover existing schema via the **`zb` MCP** (+
  `zb-knowledge` when available), backed by a compact **schema ontology index**
  (enabler C) to reuse existing classes/interfaces and avoid duplicates without
  burning context.
- **Output — the mapping spec** (in the brief/design doc): per-entity *raw API
  source (operation + field) → schema class + field* (existing or extended) +
  links. The **module-operations list falls out of this** (the ops needed to
  surface the mapped fields); the mapper implements the field-level mapping.

### Stage 3 — Schema (concrete, AWS pattern) — ON THE CRITICAL PATH
- From Stage-2 selections, author the per-product schema package following the
  AWS pattern (concrete classes extending the right interfaces + links).
- **Suite umbrella — conditional.** Author a suite umbrella package (e.g.
  `amazon.aws.schema`) ONLY when resources are genuinely **shared/linked across
  the suite's products** (e.g. one AWS account/user used across all AWS services;
  one Atlassian user across products). If the suite's products have **separate,
  unlinked accounts** (you register independently per product), there is **no**
  shared umbrella — each product owns its own account class. This is a Stage-2
  judgment.
- Generate `-ts`; publish locally (verdaccio) for collector dev; eventually to
  the platform/org. **Required before Stage 5** (no base-interface stand-in).

### Stage 4 — Module (operations + connection profile), derived from Stage 2
- Stage 2 already says which API operations surface the needed data → feed
  `/create-module` a **precise operations list + connection profile** instead of
  letting it re-research from scratch.
- Output: module `api.yml` + `connectionProfile.yml` + generated client; publish
  module locally.

### Stage 5 — Collector (mappings + mapper metadata)
- Implement `Mappers.ts` (module types → schema types) per Stage-2 plan.
- **Mapper metadata (for UI):** new artifact — format + home TBD (open, §6).
- **Local dry-run testing:** the "hijack the batch" DI stub — TS-validate + log
  what would be written, no platform. The fast inner loop.

## 5. Cross-cutting enablers to build (rough priority)
- **A. Dry-run batch harness** — DI stub swapped into the Inversify container
  before `getClient()`; logs + TS-validates what *would* be batched. No platform.
  *Highest leverage, cheapest, reusable across every connector.*
- **B. Local schema-ts pipeline** — VALIDATED feasible (§6/§9): zbb-stack postgres
  + dataloader + `schema-ts-generator`, all driven by generic `PG*` env, no Neon,
  no code changes. Needs packaging into a one-command local flow + publish to
  local verdaccio.
- **C. Ontology / dedup** — Stage 2 discovers existing schema via the **`zb` MCP**
  (+ `zb-knowledge` when configured), backed by a compact **schema ontology index**
  (name → kind → description → package) to avoid context overload. No class-level
  index exists today; cheapest path = a small `:generateSchemaOntology` gradle task
  (~50 lines, reuses `SchemaPrimitives.parseYaml`, no DB) extending the existing
  `validateUniquePackageNames` scan → JSON in `schema/bundle/`.
- **D. Analysis/interview engine** — the Stage-2 guided design session.
- **E. Design-doc / brief carrier** — already started (`brief-template.md`);
  evolves into the per-connector design + mapping spec.

## 6. Open investigations / parking lot
- **✅ Local schema-ts generation — RESOLVED (validated by code reading).** Neon
  is NOT fundamental — it's just an ephemeral CI Postgres. The generator
  (`com/platform/utils/schema-ts-generator`) and dataloader
  (`com/platform/dataloader`) are generic Postgres clients reading `PG*` env; the
  generator introspects the Postgres catalog directly. `NeonDataloaderTask` merely
  creates a branch and hands those same `PG*` vars to dataloader + generator. The
  zbb-stack postgres exports exactly those vars → point them at local postgres and
  the pipeline runs locally with **no code changes**. Recipe in §9. Remaining work
  = packaging it into one command (enabler B).
- **Dedup tooling — DECIDED + finding.** Use `zb` MCP for schema discovery (+
  `zb-knowledge` for broad access) PLUS a generated **schema ontology index** to
  keep token cost down. Finding: no class/interface-level index exists today
  (closest = `validateUniquePackageNames`, package-level; `schema-bundle` = npm-dep
  list; Postgres `catalog.class` = class-level but needs a live DB) → build a small
  `:generateSchemaOntology` gradle task (no DB).
- **Interview — DECIDED:** interactive, iterative (multi-round) refinement.

## 7. Decisions so far (this conversation)
- Heavy phases (module, collector) run as **handoff prompts** to native sub-repo
  sessions (sub-agents can't spawn the nested specialist/parallel agents).
- A **brief/manifest** is the shared state + handoff payload (`.connector/`,
  gitignored).
- **Collection targets concrete product-schema classes only** (which MUST extend
  the right base/suite interfaces). No collecting on bare interfaces in the target
  design; interface/`Dynamic` is the current interim hack only → concrete schema
  is on the critical path.
- Concrete schema follows the **AWS pattern** (`auditlogic/schema`): per-product
  packages, classes extend interfaces, links between classes.
- **Suite umbrella is conditional** — author it only when resources are genuinely
  shared/linked across the suite's products; otherwise each product owns its own.
- **Local schema-ts VALIDATED**: zbb-stack postgres + dataloader + generator, all
  generic `PG*` env, no Neon, no code changes (§9) — unblocks "everything local."
- **Spec home**: curated ops → `catalog.yml#/Operations`; raw spec → research
  folder; not the catalog artifact.
- **Testing (precise boundary):** local Postgres WITH schema loaded is part of the
  local env (enables local `-ts` gen + class-level link defs); the **"linker"**
  (object-version link processing at batch ingest) is org-only. Local collector
  test = stub/dry-run batch; real ingest + object-linking + dedup = the
  developer's own org.
- **Stage 2 (research + data-mapping assessment) is THE BRAIN** of connector dev.
- **Mapping = raw API → schema** (existing or extended class); module ops fall out.
- **Dedup** = `zb` MCP + `zb-knowledge` + a generated schema ontology index
  (no class-level index exists yet → small `:generateSchemaOntology` gradle task).
- **Interaction model** = live interview first (submitter answers what they know,
  scoped to human-knowable items) → AI researches the gaps with per-item
  confidence → PR(s) that **highlight low-confidence items** → SME approves/rejects.
  New segment / new compliance_feature = separate, flagged PRs. (§13)
- **Catalog enrichment from research (confidence-tiered, Stage 1b):** auto-propose
  segment + product description/url/apiDocsUrl (low-stakes, write after review);
  compliance_feature only as SME-gated DRAFTS mapped to real published elements
  (never auto-assert — validation is shape-only). benchmark/crosswalk out of scope.
- **Mapper metadata for UI** → deferred to v2.
- Mode: planning only; implement when this doc is complete.

## 8. Next questions (to converge)
- Design the **Stage-2 mapping-spec format** concretely (per-entity rows: API
  operation + field → schema class + field, existing/extended, links, transform
  note).
- Build order of enablers (A dry-run batch · B local schema pipeline · C ontology
  index · D analysis engine) when we move to implementation.
- Anything else before the doc is "ready enough" to implement?

## 9. Validated: local schema → `-ts` pipeline (no Neon)
1. Start local Postgres via the **zbb stack** → it exports `PGHOST/PGPORT/PGUSER/
   PGPASSWORD/PGDATABASE`.
2. Run the **dataloader** against it to load base schema + the new product schema.
3. Run **`schema-ts-generator`** with the same `PG*` env → introspects the local
   catalog → emits `-ts`.
4. `zbb registry publish` the `-ts` to **local verdaccio**.
5. Collector dev consumes it from local verdaccio.

Seam: generic `PG*` env — `NeonDataloaderTask.kt:213-220` builds the `pgEnv` map;
`SchemaTsGenerator.kt` spawns every subprocess with `ctx.pgEnv`; the generator's
`main.ts` connects via the standard `@zerobias-com/util-pg` config. No code
changes; remaining work = packaging into one command (enabler B).

✅ **Confirmed local.** Step 2 is *schema dataloading* — loading class/interface
DEFINITIONS (incl. class-level link defs) into the local Postgres so the catalog
can be introspected. This is part of the local environment (the DB lives
locally). It is NOT the "linker" (object-version link processing at batch
ingest), which stays org-only. So this local `-ts` pipeline stands — no org
round-trip per schema change.

## 10. Risks & insights to resolve
- **Testing strategy — DECIDED (precise boundary).** Two distinct link levels:
  - **Class-level links = schema definitions** (e.g. `S3Bucket.policy →
    S3BucketPolicy`). Loaded into a **local Postgres via schema dataloading** —
    this IS local and required; it's what `schema-ts` introspects (§9).
  - **Object-level links = real links between collected object *instances***
    (object versions), created by the **"linker"** at batch-ingest. **NOT local.**
  Therefore:
  - **Local collector test = stub / dry-run batch** (enabler A): TS-validates +
    logs what *would* be batched. No real ingest, no object-linking locally.
  - **Integration = the developer's own org.** Load artifacts (schema, module,
    collector) to the org and test against the REAL platform — that's where batch
    ingest, object-level link resolution, and dedup/groupId get verified.
  - Tradeoff accepted by design: object-link/dedup bugs surface at org-level
    integration, not locally.
- **Mapping is raw API → schema (DECIDED — keep it simple).** Stage 2 maps at the
  raw-API level; the module-operations list falls out of it. Light caution: ensure
  the module's generated types actually surface the API fields the mapping
  references, so the mapper has them — but keep the artifact a single raw-API →
  schema map, not a separate dual contract.

## 11. Product graph (reference — everything a product links to)
`catalog.product` is a VIEW over `store.product`; vendor/suite/segment relations
live in the generic `hydra.resource` tree + `resource_link` graph; versioned
attributes hang off `product_version`. The full edge set, tagged by how the
connector flow treats it:

- **Core (created by the flow):** vendor · suite · product · module
  (`store.module.parent_id`=product) · **collector_bot** ("bots",
  `catalog.collector_bot_product.product_id` + resource_link) · schema
  (`schema.product_id`).
- **Research-derivable enrichment (Stage 1b):** segment (resource_link) ·
  **cpeProducts** (`cpe_product` → auto vuln chain) · description / url /
  apiDocsUrl / tags / factoryTypes / hostingTypes · **editions**
  (`catalog.product_edition` + child YAML) · **components**
  (`catalog.product_component` + child YAML).
- **Automatic / not authored by us:** vulnerabilities/CVE — FK chain
  `cpe_product → cpe → vulnerability_cpe_product → vulnerability` (CVE in
  `external_id`), populated from an external feed via CPE match · **offering**
  (licensing: `product_version_id` + `product_edition_id`) · **"services"** = a
  `segment_version` with `is_service=true` (NOT a product child).
- **Out of scope for the flow:** compliance_feature (Tier-2 SME draft only;
  resource_link, not a catalog FK) · **alert_bot** (no product FK — links
  graphql_query/artifact/package) · control / crosswalk / standard / benchmark /
  test_case / test_suite (all have `product_id` FK but are compliance content,
  other expertise) · platform `connector` entity (`catalog.connector.product` —
  the runtime deployable).

Source: `util/packages/content-schema/sql/content-schema.sql` (catalog.* DDL).

## 12. Product research — touchpoint inventory (build this phase first)
Everything the research phase must GATHER (sources) and PRODUCE (artifacts/fields)
for one product. Tags: [research] needs sourcing · [auto] low-stakes auto-fill ·
[fixed] constant · [draft] SME-gated · [optional].

### Sources to gather from
- Vendor site / product page → name, description, url, logo. [research]
- Developer portal / API docs → apiDocsUrl, operation list + example I/O,
  auth/connection methods. [research]
- **NVD CPE dictionary** (nvd.nist.gov CPE search/API) → cpeProducts + cpeVendors.
- Editions / pricing page → editions. [optional]
- Components / sub-product docs → components (GitHub exemplar). [optional]
- Trust center / security & compliance docs → compliance_feature drafts. [draft]

### Artifacts / fields to produce
- **vendor/** `index.yml` (create if missing): name, code, description, url,
  **cpeVendors[]**, logo.
- **suite/** `index.yml` (if suite): name, code, description.
- **product/** `index.yml`:
  - [research] name, code, description, url, apiDocsUrl, logo, **cpeProducts[]**,
    **segments[]** (UUID match), vendorId / suiteId.
  - [fixed] status=`verified` (enum draft|publishing|published|released|verified|
    active), type=`product`, parentType (`vendor|suite`), factoryTypes=`[software]`
    (enum software|firmware|hardware).
  - [optional, usually empty] hostingTypes (enum iaas|paas|saas), tags, aliases.
  - Canonical enums live in `@zerobias-com/hydra-core/platform-models.yml`.
    `type`/`parentType` are index.yml + `contentType`=`json` (catalog.yml) are
    dataloader concepts, NOT `Product.create` API fields.
- **product/** `catalog.yml`: `Product{name, versions, package, description, link,
  contentType: json}` + **`Operations{}`** — curated ops (description, versions,
  link, example inputs/outputs). [research]
- **product/editions/*.yml**, **components/*.yml** [optional]: id/name/description.
- **segment**: assign existing UUID(s) [auto]; rarely create a new one.
- **compliance_feature**: capabilities + candidate Requirement mappings [draft,
  SME-gated] (Stage 1b Tier 2).

### Derived now, built later (capture in the research dossier)
- **Connection methods → module `connectionProfile.yml`.** Auth `type` ∈ OpenAPI
  {oauth2, apiKey, http(basic/bearer), openIdConnect, mutualTLS}; compose from
  `@zerobias-org/types-core/schema/` base profiles (oauthTokenProfile,
  oauthClientProfile, tokenProfile, basicConnection, …). [research — "all
  connection methods"]
- **Module operations** → fall out of the Stage-2 data-mapping.
- **Schema mapping** → Stage 2 (the brain).

### CPE recipe (unlocks vulnerabilities — automatic but feed-delayed)
1. Look the vendor/product up in the NVD CPE dictionary.
2. From each `cpe:2.3:a:<vendor>:<product>:…`, take **vendor:product** only (keep
   NVD underscore casing, e.g. `github:enterprise_server`).
3. List **all** relevant component CPEs (CLIs, SDKs, runners), not just flagship.
4. Vendor token → `vendor/index.yml#cpeVendors`; products → `product/index.yml#
   cpeProducts`. Empty list if NVD has none.
5. Free text, unvalidated by us. Vulnerabilities then link **automatically but
   feed-delayed**: on product-change `ProductChangeEventHandler.scanCpeProducts`
   links product↔`CpeProduct` — *iff* the NVD CPE-dictionary collector already
   ingested that `vendor:product` token (else it "backs off"); the NVD CVE
   collector attaches CVEs to the same `CpeProduct`. So token accuracy (a real NVD
   CPE) matters. Model: `cpe_product` → `cpe` → `vulnerability_cpe_product` →
   `vulnerability`.

## 13. Interaction model — interview first, PR fallback, SME review
Capture human knowledge cheaply up front, let the AI research the rest, and
concentrate expert attention only where it's needed.

1. **Live interview (submitter).** Any user can suggest a product. Ask ONLY what a
   submitter plausibly knows — suite membership, auth method, editions, product
   positioning, "is this in segment X?" — NOT research-heavy internals (CPE
   tokens, schema mappings, operation lists).
2. **AI research fills the gaps.** Whatever the submitter doesn't know (or to
   validate/augment) the AI researches (vendor docs, NVD CPE, API spec, schema
   ontology), producing best-guess values **each tagged with a confidence**.
3. **PR(s).** Interview answers + AI research assemble into the artifact PR(s).
   The PR description **highlights every low-confidence item** (AI guesses,
   uncertain segment matches, draft compliance features) so the reviewer knows
   exactly where to look. Keep committed YAML lean, but **annotating opaque UUID
   lists with a trailing `#` comment is encouraged** — especially `segments:`
   (segment name + the feature that satisfies it) — since bare UUIDs are
   unreadable. Caveat: a **platform-side re-publish** re-serializes clean YAML and
   **strips comments** (§15D), so they're durable for git-managed edits but not
   guaranteed; keep the authoritative rationale (UUID↔name mapping, field
   reasoning, confidence flags) in the **PR description** too.
4. **SME review.** An SME approves / rejects / edits, focusing on the flagged
   items — the async fallback for everything the submitter couldn't confirm.

Per-item **confidence is tracked end to end**: interview-confirmed = high (rides
through); AI-guessed = surfaced. Low-confidence items are the PR's review surface.

### Handling new / uncertain catalog entries
- **Assign existing segment (confident):** in the product PR, unflagged.
- **Uncertain segment:** interview the submitter first ("does it do X → segment
  Y?"); if unknown, AI picks best match + alternatives, flagged low-confidence in
  the product PR → SME decides.
- **New segment needed:** shared, hierarchical taxonomy change → a SEPARATE
  `segment/` PR (proposed code / tier / parent), explicitly flagged, reviewed
  deliberately before the product references it.
- **New / proposed compliance_feature:** always a SEPARATE `compliance_feature/`
  PR, DRAFT-labelled, mapped only to real published elements, SME-gated (audit
  weight; validation is shape-only).

## 14. Change surface per artifact — PR vs API vs UI vs change-request
Three channels exist; **git is the system of record** for the catalog.

### Channels
- **PR/git** — every artifact authored as YAML in the open-source repos + gate.
  Canonical.
- **Platform API** (`platform.*` under `/catalog/*`) — full CRUD for product,
  segment, compliance_feature, editions, components + **association patches**
  (`patchProductSegments`, `patch*Features`). **No** vendor/suite create
  (suggest-only); cpe read-only. The UI is a thin client over this API.
- **Change-request** — a `catalog.request` table exists (artifact_type ∈ product,
  vendor, suite, segment, compliance_feature, schema, collector_bot, connector…;
  lifecycle requested→approved/rejected→in_progress→complete) but is **NOT exposed
  as a public API op** today. Only API-surfaced staged paths: the **suggestion
  family** (`createSuggestedVendor/Product`) + `store.Order.create`.

### Sync direction (the load-bearing fact)
Dataloader is a **one-way importer**: YAML → platform, deterministic-UUID upsert,
**no reverse sync**.
- Any field in YAML is **git-authoritative and overwritten on reload** — API/UI
  edits to YAML-backed fields are ephemeral.
- **Associations** (product↔segment, product↔compliance) are the exception: YAML
  *can* carry them but almost never does (3/660, 0/660), so they're set/held
  **in-platform** via patch API and persist because no YAML governs them. Putting
  them in YAML makes git authoritative and **clobbers** the platform value.

### Gate depth (how far PR automation goes) — verified
- **Local gradle/lerna validators = shape-only** (npm/package/dir triangulation,
  logo, UUID collision, TS compile).
- **Reference-correctness = the DATALOADER** (CI on a Neon branch, label-gated, OR
  a local dataloader run): UUIDs/codes/enums, segment parent codes, compliance
  element-alias **existence**, schema extends/linkTo resolution. A **non-existent**
  element/class is caught here; a **real-but-wrong** compliance mapping is caught
  **nowhere** (human only).
- **No CODEOWNERS** in any of the 6 content repos — the only human gate is the
  social `approved` label (maintainer-by-convention; gates CI execution, not
  merge). A shaped, reference-valid PR can auto-pass; semantic correctness is the
  SME's job (§13).
- **PR branch:** vendor/suite/product/segment/module/collectorbot → `main`;
  **compliance_feature → `dev`**, **schema → `dev`** (cross-fork, approved-label).

### Recommended channel per artifact (connector flow)
- **vendor, suite, product, segment-entry, compliance_feature-entry, editions,
  components, module, collectorbot, schema** → **PR/git** (system of record).
- **product↔segment association** → write to `product/index.yml#segments` (PR);
  accept it becomes git-authoritative (overwrites platform-set segments). Low
  stakes. ⟵ open decision (§8).
- **product↔compliance association** → keep **in-platform** (SME applies via patch
  API after reviewing the draft) rather than auto-PR — audit weight + current
  practice. ⟵ open decision (§8).
- **change-request** → the `catalog.request` *table* isn't exposed, but
  **`store.Order.create`** IS the callable intake (`type=product` → a `verified`
  product; `type=catalog` → request to fully catalog it) + the suggestion family.
  No generic approve/reject op. See §15.

## 15. Adding a product to the platform — concrete paths
Three callable channels; **git/PR is the durable system of record**, and for
several fields it's the ONLY channel. (Op contracts via `zerobias_describe`, qa.)

### A. PR / git (canonical, durable) — carries the FULL research output
YAML in the content repos → PR → merge → CI publishes the content npm package →
dataloader loads it (artifact-versioned upsert). The **only** path that:
- creates **vendor** and **suite** (no API create for either),
- sets **cpeProducts** and product **url** (no API inputs for these), and
- is the git source of record (API-created rows exist only in the DB, not the
  content repos — see §15B / §17).
The research dossier maps 1:1 onto these YAML files (§12). **Primary add path.**

### B. Platform API (`platform.*` `/catalog/*`) — products/segments/editions/
components/associations; durable, but off the git source-of-record
- `Product.create` — req `name, description, code`; opt `vendorId, suiteId,
  segmentIds[], imageUrl, tags, factoryTypes(software|firmware|hardware),
  hostingTypes(iaas|paas|saas), complianceFeatures[]{complianceFeatureId,
  supportStatus(supported|unsupported|edition_supported|partially_supported),
  productComponentId?, supportStrength(low|medium|high)?}`. **No `url`/`cpeProducts`.**
- `Product.patchSegments` — `{productId}` + `addSegments[]/removeSegments[]`.
- `Product.createEdition` / `createComponent` — `{productId}` + `name, description,
  code, background` (+ `patchEditionComponents` to cross-wire).
- `Segment.create` — `name, segmentTypeId` (+ parentIds, productIds…).
- `ComplianceFeature.create` — `name, complianceFeatureTypes[], scope`.
- **CPE = read-only** (`getByCpe`, `listCpes`) — no write op.
Use for: **associations** (product↔segment) + fast in-platform edits. API-created
rows ARE durable (the loader never prunes them, ~0.97), but they live only in the
DB — NOT the git content repos, and can't set `url`/`cpe` (no vendor/suite either).

### C. `store.Order.create` — intake / "request" front door
`POST /orders`. `type=product` = low-fidelity order (new product + vendor/suite
parents) → product(s) in `verified` status; `type=catalog` = request to fully
catalog a verified product → module; `type=operation`. Plus the suggestion family
(`createSuggestedVendor`, `Boundary.createSuggestedProduct`, …). No generic
approve/reject.

### Concrete recommendation (per artifact)
| Artifact | Add via |
|----------|---------|
| vendor, suite | **PR/git only** |
| product core (incl. `url`, `cpeProducts`) | **PR/git** (API is durable but drops url+cpe & isn't in the content repos) |
| product↔segment association | API `patchProductSegments` (or YAML) |
| segment entry / new segment | PR/git (taxonomy) or API `Segment.create` |
| editions, components | PR/git or API |
| compliance_feature | PR/git (SME-gated) |
| "please catalog X" intake | `store.Order.create` (`type=product`/`catalog`) |

**Net:** PR/git carries the full research and is the durable record — but the
**`events` service auto-exports DB→git on publish** (§15D), so you can also load
via API/MCP now and let git catch up. API for associations + the fast loop;
`store.Order.create` as a front-door intake.

### D. DB→git auto-sync (the events service) — changes the calculus
There IS a reverse sync (not `datasync`, which is import-only). The platform
**`events` service** serializes a catalog entity to YAML and **pushes directly to
`zerobias-org/<artifactType>` on `main`** (`events/src/common.ts`
`setupGitWorkspace`+`pushArtifactChanges`, as "Zerobias Team" via `CATALOG_REPO_PAT`;
**no PR**). **Trigger:** the entity's status reaches `Publishing`, which
`TaskExtendedChangeEventHandler` sets when a human completes the cataloging
**task**. Lifecycle: `Draft → … → Released → Publishing → Published`. A
`createSuggestedProduct` / `Order` / `Product.create` seeds a **draft DB row (+ a
task)**; completing the task auto-exports it to git. ⇒ **No manual YAML needed** —
load via API now (visible in dev immediately), git syncs on publish. "API products
absent from git" holds only while still Draft/unpublished.

## 16. Artifact types the workflow can touch (index)
Detail: §11 graph · §12 research · §15 add paths.

### Catalog onboarding (research phase → primarily PR/git)
| Artifact | Action | Channel | Stakes |
|----------|--------|---------|--------|
| **vendor** | create/edit | PR/git **only** | low |
| **suite** (if suite) | create/edit | PR/git **only** | low |
| **product** (core + scalar fields) | create/edit | PR/git (primary) | low |
| ↳ **cpeProducts / cpeVendors** | set | PR/git **only** → auto-links CVEs | low |
| ↳ **catalog.yml Operations** | curate | PR/git | low |
| **segment — assign existing** | associate | API `patchProductSegments` or YAML | low |
| **segment — create new** | create | PR/git (taxonomy, flagged) | med (shared) |
| **product editions** | create/edit | PR/git or API | low |
| **product components** | create/edit | PR/git or API | low |
| **compliance_feature** (+ assoc) | draft | PR/git or API — **SME-gated** | HIGH (audit) |

### Connector build (downstream stages)
| **module** | create | PR/git |
| **collectorbot** | create | PR/git |
| **schema** (product/suite concrete classes) | create | PR/git |

### Intake (optional front door)
| **store.Order** (`type=product`/`catalog`) | request | API |

### Automatic — NOT authored
- **vulnerabilities / CVE** — linked via `cpeProducts` (CPE→CVE feed).

### Explicitly NOT touched
- vendor/suite via API (PR-only) · **alert_bot** (no product link) · **offering** ·
  **services** (= a `segment` flavor, `is_service`) · control / crosswalk /
  standard / benchmark / test_case / test_suite · the platform **`connector`**
  runtime entity.

## 17. Confidence audit — post-verification (2026-06-05)
A verification pass (zb-knowledge + platform clones, qa) closed all but one item.

### ✅ Resolved by verification
- **API-created product durability (§15B) — CORRECTED.** Earlier "not durable" was
  WRONG. A content load is a strictly per-package additive upsert; the dataloader
  never enumerates or prunes products outside the loaded bundle (the catalog-wide
  `deleteByArtifactVersion` exists in the DAO but is **never called**; only a
  package's own `deprecate:true` self-deletes its own row). **API-created products
  ARE durable (~0.97).** Real caveat: they live only in the DB, not the git content
  repos (no YAML → no `url`/`cpe`, invisible to git workflows).
- **No API create for vendor/suite; no approve/reject op — CONFIRMED (high).**
  Route specs: vendor = `createSuggestedVendor` + admin `requestVendor/claimVendor`
  only; suite = `listSuites` only (not even a suggestion); zero approve/reject/
  changeRequest ops anywhere. Product DOES have direct `createProduct` (read-only
  design is deliberate). Intake = `store.Order.create` + suggestions; approval is
  out-of-band.
- **cpe→CVE linking — RESOLVED (B): automatic but feed-delayed + gated.** Setting
  `cpeProducts` links product↔`CpeProduct` on product-change
  (`ProductChangeEventHandler.scanCpeProducts`); CVEs attach via separate,
  independently-scheduled NVD CPE-dictionary + CVE collectors. No per-product
  authoring — but appears only after the feed runs AND only if the token matches a
  `CpeProduct` the NVD dictionary already ingested (else "backing off"). → derive
  the token from the real NVD dictionary.
- **Product enums — CERTAIN.** The YAML/API "discrepancy" was sparse usage, not
  conflict. One canonical source (`@zerobias-com/hydra-core/platform-models.yml`,
  `$ref`'d by the API, imported by the dataloader, matches live `describe`):
  factoryTypes=`software|firmware|hardware` · hostingTypes=`iaas|paas|saas` ·
  status=`draft|publishing|published|released|verified|active` (new→verified) ·
  parentType=`vendor|suite` · contentType=`json|text|markdown|html`. type/parentType
  (index.yml) + contentType (catalog.yml) are dataloader concepts, NOT API fields.
- **Gate depth — CONFIRMED + sharpened.** Reference-resolution (compliance element
  aliases; schema extends/linkTo) is **dataloader-only** (CI on Neon, label-gated,
  OR a local dataloader run) — local gradle/lerna validators are shape-only. A
  **non-existent** element/class → caught by the dataloader; a **real-but-wrong**
  compliance mapping → caught NOWHERE (human only). **No CODEOWNERS** in any of the
  6 content repos; only the social `approved` label (gates CI execution, not merge).
  Branch-protection settings aren't in-tree (unverifiable).
- **Dry-run batch needs no collector edits — CONFIRMED (~92%).** Seam = the
  Inversify container: `this.platform` is `@inject`ed into `BaseClient`, never
  constructed by the collector. `container.rebind(TYPES.platform).toConstantValue(
  dryRunPlatform)` before `getClient()` swaps the write path with zero collector
  edits (stub `getBatchApi()` logs + TS-validates; must return
  `isConnected()===true`, `batch.ts:91`). Residual 8%: `generated/` is gitignored,
  so templates verified, not a materialized container.

### ⏳ Still genuinely open
- **Local schema-`ts` gen end-to-end (~65%, §9).** Code says Neon isn't
  fundamental; never RUN. Needs one real local run (the GraphQL-test subprocess +
  schema-load specifics could bite).
- **NVD feed cadence** — the cpe/CVE collectors' schedule lives in the private job
  system; "feed-delayed" is confirmed, exact timing isn't.

## 18. Fast path — research → dev DB → UI today (ignore schema-ts + cpe)
Goal: research a product today, load the comprehensive research into the **dev**
DB, see it in the UI. Draft/suggested status is fine. Channel-agnostic.

### The improvement: go API-first, let git auto-sync
Because the events service exports DB→git on publish (§15D), the fast loop needs
**no manual YAML/PR**. Load into the DB via API/MCP → visible in dev now → git
catches up on publish.

### Action list (prioritized)
1. **Research → dossier** (`research-dossier-template.md`), skipping cpe + schema-ts.
2. **Ensure parents exist in dev.** `store.Vendor.get` / `Suite.get`; if vendor
   missing → `createSuggestedVendor`. ⚠️ **Suite has NO API create** — if the
   product needs a *new* suite, that's a gap (git/order only) → for the first run,
   pick a no-suite product or one whose suite already exists.
3. **Load the product, max fidelity.** `platform.Product.create` (name, description,
   code, vendorId, suiteId?, segmentIds, factoryTypes, hostingTypes,
   complianceFeatures) → then `patchSegments`, `createEdition`/`createComponent`,
   `catalog.yml` Operations where supported. (url/cpe not API-settable — skip now.)
   Durable, immediately in the DB.
   - Lower-friction alt: `createSuggestedProduct` → Draft + cataloging task; or
     `store.Order.create type=product`.
4. **See it in the dev UI** — confirm where draft/suggested products surface.
5. **(Later) publish** — complete the cataloging task → events service auto-pushes
   YAML to `zerobias-org/product`. Closes the loop; no manual authoring.

### Decisions/unknowns to resolve before executing
- Target env = **dev** (`dev` MCP profile / creds) vs current **qa**?
- Authorize **write** ops via `zerobias_execute` (this mutates the chosen env).
- Where do **draft/suggested** products surface in the UI?
- Suite-create gap — pick a first product needing no new suite.

### Suggested-VSP-via-API — reality (verified 2026-06-05)
The suggested path is thinner than hoped:
- **Product — WORKS.** `platform.Boundary.createSuggestedProduct` (needs a
  `boundaryId`) creates a real **Draft `store.product` + version** with
  name/description/url/segments/factoryTypes/hostingTypes (no operations/editions/
  suite). Visible in dev.
- **Vendor — the obvious op is a STUB.** `createSuggestedVendor` only writes a
  `suggested_vendor` row; its handler is a no-op (no draft, no task). The
  functional vendor path is **`Admin.requestVendor`/`claimVendor`** (org-scoped
  request → task → `publishVendor`).
- **Suite — NONE.** No create/suggest op, no suite-parent in any payload;
  `store.Order.create` is **stubbed** (`OrderProducerImpl.create` throws). New
  suite = **git-only** unless the platform adds `createSuggestedSuite` (+ wire the
  `SuiteChangeEventHandler` create branch; the publish side already exists).
- **Approval IS API-drivable:** `platform.Task.update` `PATCH /app/tasks/{id}`
  with `{transitionId: <Done-transition>}` (no separate approve op); Ops/insider-
  owned task. Completion → status flip → events serializes YAML to git.
- **⚠️ Git-publish is PROD-ONLY** — in dev/qa the publish handlers early-return
  (`ENV_TYPE !== Prod`); approval flips DB status (visible in UI) but does NOT push
  to git. The git round-trip is a Prod behavior.
- **Net:** suggested **product** (+ vendor via admin-request) is API-creatable &
  insider-approvable; **new suite forces git**; **git-sync needs Prod**. For a dev
  demo, `platform.Product.create` (direct) or `createSuggestedProduct` under an
  existing vendor/boundary is the working path.

### Git VSP → dev (the COMPLETE path — verified, recommended for full VSP)
Better than the API path for a full VSP — handles a new suite, lands live in dev:
1. **Author parent-first** in the content repos: vendor → suite → product, each
   scaffolded + `build.gradle.kts` (`zb.content`) marker + `:gate` →
   `gate-stamp.json`. (Gate = dry-run dataloader vs ephemeral Neon; no env DB.)
2. **PR target depends on the repo (corrected 2026-06-05).** product / vendor /
   suite / segment / module / collectorbot → **PR to `main`** (their own
   convention; `product/CLAUDE.md`: "all PRs target main"). `dev`/`qa`/`uat` are
   **workflow-synced env branches (outputs)** — the publish `sync` job propagates
   `main → uat → qa → dev` after a successful main publish. So these repos are
   **prod-first**: main-merge publishes (`latest` → prod) then syncs down to dev.
   Only **schema / compliance_feature** PR to `dev`. Publish fires on **merge/push**
   (branch→dist-tag `main→latest, qa→qa, dev→dev, uat→uat`), not PR-open. V/S/P have
   no PR-time CI — the real pre-check is the local `:gate`/`validateContent`
   (commits `gate-stamp.json`).
   ⓘ **No clean dev-only git path** for product/vendor/suite (dev is synced from
   main). To preview a change in **dev without prod**, use the **API** against the
   dev env (`platform.Product.patchSegments`/`patch`) — instant, dev-only,
   ephemeral; the git PR-to-`main` is the durable/prod fix.
3. **Env load is event-driven:** publish emits a release event → AWS event-router
   → each env's `dataloader-service` loads the matching dist-tag into THAT env's
   Postgres + emits a ChangeEvent (UI updates). So the **dev** package auto-loads
   into the **dev** DB.
- **No approved-label gate** for V/S/P (schema-only); only hard gate =
  `gate-stamp.json` preflight.
- **Lands LIVE** (Verified/Published, not draft) — a real catalog product in dev UI.
- **PR = the approval gate.** One PR per repo (V/S/P are separate repos → up to 3),
  to `main` for those repos. The reviewer's **merge** is the human approval (git
  analog of the API `Task.update`) AND the publish trigger (→ **prod** for
  main-targeted repos, then synced to dev). Merge in **parent order** (vendor →
  suite → product). A product under an existing vendor+suite = one PR (to `main`).
- **Cycle:** ~3 commits + push to `dev`; CI publish a few min/package; async load
  shortly after (**green CI = published, NOT yet loaded**). Gotchas: parent
  ordering (vendor loads before suite before product — IDs resolve against the live
  env DB), gate must pass, load is async (SQS/Lambda).
- **vs API:** git is complete + durable + handles new suite + auto-promotes across
  envs; API is faster single-env but suite-blocked, suggested-only, git-sync
  Prod-only. **For a full VSP into dev, push ×3 to `dev` is the canonical route.**

## 19. Research corpus — local raw + segment intelligence (`.research/`)
A persistent, **gitignored** store of everything gathered during research (far more
than the artifacts need), so Claude reuses it instead of re-searching, and segment
knowledge is amortized across products. Decisions: lives in-repo at `.research/`;
plain folder now (semantic index later); competitive/segment research is
on-demand + segment-cached.

### Location & structure — `.research/` at the meta-repo root (gitignored)
```
.research/
  segments/<segment>/
    overview.md  common-features.md  peers.md   # ours + competitors, cached per segment
    sources.md
  vendors/<vendor>/
    overview.md  auth-overview.md
  products/<vendor>/[<suite>/]<product>/
    dossier.md          # the structured research output (entrypoint; §research-dossier-template)
    raw/                # fetched bytes: openapi.json, api-docs.html, pricing.html, changelog…
    processed/          # operations.md · auth.md · editions.md · components.md · versions.md · notes.md
    competitors.md      # similar products + comparison (→ links into segments/)
    sources.md          # provenance: URL → raw file → fetched-at
```

### Reuse model — plain folder now, index later
v1: Claude reads `dossier.md` first, then `processed/`, then `raw/` as needed
(read/grep, zero infra). Phase 2: a local semantic index over `.research/` (like
zb-knowledge) once the corpus spans many products/segments.

### Segment / competitive research — on-demand, segment-cached
Done when entering a **new segment** (or on request), NOT per product: research
peer/competitor products, distill the **common features** typical of that segment,
store under `segments/<segment>/`, and **reuse for all sibling products**. Feeds
Stage 2 (the brain): "what a product in this segment should expose."

### Freshness & provenance
Every source recorded in `sources.md` with URL + `fetched-at`; research goes stale
(versions, editions, API changes) → re-fetch on demand, timestamp says when. Keep
both **raw** (fetched bytes) and **semi-processed** (distilled md).

### How it fits
brief = orchestration state · **research corpus = raw depth + segment intelligence**
· dossier = structured output (drawn from the corpus) · artifacts = the subset that
lands in the DB/git.

## 20. Dry-run learnings — GitHub product review (2026-06-05)
First real exercise: research GitHub vs its existing catalog entry. Validated the
process AND surfaced both product fixes and template fixes.

### GitHub accuracy findings (fixes to the existing entry)
- **Data bugs:** `aliases` = 6 identical `github.github` dupes; **pro/team edition
  `background` text is SWAPPED** (pro.yml says "Team includes", team.yml says "Pro
  includes").
- **Missing:** `segments` (none — biggest gap), `apiDocsUrl`, `hostingTypes`
  (empty → `saas`), `components` (only `dependabot` of ~13: Actions, Packages,
  Codespaces, Copilot, Advanced Security, Pages, Issues, …).
- **Stale/wrong:** `cpeProducts` mixes junk (`gaug.es`, `owslib`,
  `btcsuite_go-socks`, `491-project`) + misses `cli`/`codeql_cli`; `description`
  sloppy; `enterprise` edition collapses Cloud + Server; `catalog.yml` ops are an
  old snapshot (no codespaces/packages/copilot/dependabot namespaces).

### Process/template updates applied (`research-dossier-template.md`)
- Each field now says **where it persists** (index.yml / catalog.yml / platform
  patch / module) — segments/apiDocsUrl/cpeVendors have no product-API slot.
- Shipped the **controlled enums** (factoryTypes, hostingTypes, status) inline; noted
  hostingTypes has **no self-hosted value** (Enterprise-Server-style = factoryType
  `software` + an edition, not a hostingType).
- **cpeProducts selection rule**: core product + first-party CLIs/Actions/runners;
  exclude transitive OSS deps / low-signal tokens.
- **Auth/connection routed to the MODULE** (not a product field).
- **editions vs components vs deployment** clarified; added **sourceUrl +
  verifiedAt** per edition/component to stop stale data rotting.
- §9 now also captures **corrections to existing entries** (swaps/dupes/stale).

### Verdict
The process works and is high-value — it caught real bugs in a live product on the
first run. The template needed the persistence-map + enums + cpe rule + provenance;
now applied.
