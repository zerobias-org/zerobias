---
name: create-product
description: >-
  Add (or extend) a product and ALL its catalog dependents in the zerobias-org
  catalog — vendor → suite? → product (+ components + editions) → segment
  associations → compliance features → control links (elements.yml). CATALOG
  CONTENT ONLY: no Hub module, no collectorbot, no schema. USE THIS PROACTIVELY
  when the user wants to "add product X" / "add vendor Y and its products" /
  "register <SaaS/tool> in the catalog" / add compliance features, segments, or
  control coverage for a product — and does NOT need a data integration. It first
  checks whether the product already exists and ASKS what to do (update vs add
  missing deps vs nothing). Also invoked by /create-connector when the target
  product doesn't exist yet. Discovers state via the zb MCP, researches the
  vendor's taxonomy to decide suite-vs-no-suite, and authors content-as-code
  validated by the gradle gate (never `npm run validate`).
argument-hint: "[vendor] [product]"
---

# create-product — add (or extend) a product + all its catalog dependents

Standalone meta-repo orchestrator for the **catalog content** side only:

```
vendor → suite? → product (+ components + editions + segments)
       → compliance features → segment supports.yml (feature wiring) → control links
```

**Scope.** STOPS at catalog content. It does **not** create a Hub module or a
collectorbot, and does **not** author schema. For the full data-integration chain
use [`/create-connector`](../create-connector/SKILL.md) — which calls THIS skill
for its catalog part.

> **Read first:** [`catalog-content-model.md`](../../docs/catalog-content-model.md)
> — the canonical model (enums, gradle-gate validation, the
> `product index.yml#segments → segment supports.yml#complianceFeature`
> feature-wiring chain, NO-suite default, MCP op corrections). This skill is the
> step-by-step FLOW; that doc is the WHAT/WHY. Don't restate it — link it.

> **Two `create-product` skills, different layers.** THIS meta-repo skill
> orchestrates the whole catalog chain. The sub-repo leaf
> `product/.claude/skills/create-product` only scaffolds the product *package* —
> this skill **follows it inline** (with the known fixes below) for that one step.

## Execution model
- **In-session sub-agents** (research, discovery, scaffold) keep the main context
  small — each returns a ≤200-word report.
- **One brief** ([`brief-template.md`](brief-template.md) →
  `.connector/<vendor>-[<suite>-]<product>.md`, gitignored) is the shared state.
  Written after Phase 0.5; updated as each layer lands.
- **Content-as-code, validated by the gradle gate** (`./gradlew :…:validate`),
  never `npm run validate` (stale — rejects canonical `hostingTypes: saas`). PRs
  target **`dev`**.

## Phase 0 — parse inputs
Required (ask via `AskUserQuestion` if missing): **vendor name** + **product name**,
both natural language. Do NOT ask for canonical codes / suite / category / auth —
Phase 0.5 derives them. (Author identity is a *module* concern; not needed here.)

## Phase 0.5 — research (`general-purpose` sub-agent)
Convert the natural-language names into a complete, catalog-ready profile **before**
probing the catalog. The sub-agent (load deferred `mcp__zb__*` via `ToolSearch`
first):
1. Researches the vendor's own taxonomy (WebSearch/WebFetch) → suite-vs-no-suite
   (**default NO-suite**; suites only for genuine AWS/MS-365-scale umbrellas; a
   suite code must not collide with the vendor code — see the model doc's rule).
2. Pre-probes the catalog (`store.Vendor.listSuites` / `store.Vendor.listProducts`).
3. **Fills the COMPLETE dossier** ([`research-dossier-template.md`](research-dossier-template.md)
   → `.connector/research-dossier-<connector>.md`), every field with `H|M|L` +
   source, **including the existing-vs-new gap analysis**: segments (match vs
   `segment/package/*`), features (match vs the `compliance_feature/.../f_*` pool),
   components/editions (per-product, net-new), CPE (NVD), and candidate control
   links. Do NOT defer this to a second pass.
4. Returns a compact proposal (vendor/suite/product/category/auth/siblings/rationale).
The orchestrator calls `AskUserQuestion` (accept / override / cancel); on accept it
writes the brief, then Phase 1.

## Phase 1 — discovery (`Explore` sub-agent)
With the resolved codes, return a **state table** — for each layer
(vendor / suite / product / each matched segment / each mapped feature): one of
`exists-platform-and-local`, `exists-platform-only`, `exists-local-only`, `missing`.
Use `store.Vendor.get` / `store.Suite.get` / `store.*.listProducts` (the
`portal.*.search` ops in sub-repo docs **don't exist**) + local clones.

## Phase 1.5 — if the product ALREADY EXISTS, ask what to do  ⭐
If Phase 1 shows the **product** already exists, do **not** silently scaffold or
fail. Show the user what exists (product + which dependents are present/missing:
segments, components, editions, compliance features, control links) and call
`AskUserQuestion`:
- **Update the product** — refresh fields (description, url, apiDocsUrl, enums,
  logo) from the dossier.
- **Add missing dependents** — only the gaps (e.g. no `segments:`, no
  `components/`, no `editions/`, unwired features).
- **Add / extend compliance coverage** — new `f_*` features + `supports.yml`
  wiring + control links (`elements.yml`).
- **Nothing / cancel** — it's already complete.
Route Phase 2 to perform **only** the chosen subset. (When `/create-connector`
calls this skill and the product exists, this is its "go with that" path — confirm
usable, skip creation.)

## Phase 2 — scaffold the gaps (STRICT dependency order)
Skip layers that already exist; do only what Phase 1/1.5 selected. One
`general-purpose` sub-agent per gap:
1. **vendor** — `cd vendor`; `sh scripts/createNewProduct.sh package/<v>`; drop
   `build.gradle.kts` (`plugins { id("zb.content") }`); `./gradlew :<v>:gate`.
2. **suite?** (only if suite) — `cd suite`; `sh scripts/createNewSuite.sh <v>/<s>`;
   `./gradlew :<v>:<s>:gate`.
3. **product** — `cd product`; follow `product/.claude/skills/create-product`
   inline. **KNOWN FIXES (stale Lerna leaf):** add `build.gradle.kts`
   (`plugins { id("zb.content") }`) or it can't be gated; use `store.Vendor.get` /
   `store.Suite.get` (not `portal.*`); canonical enums (see doc:
   `factoryTypes software|firmware|hardware`, `hostingTypes iaas|paas|saas` →
   SaaS = `[saas]`, `status verified`); **validate with
   `./gradlew :<v>:[<s>:]<p>:validate`, NOT `npm run validate`.** Author
   `index.yml` (incl. `segments:` UUID list), `catalog.yml`, `components/<kebab>.yml`,
   `editions/<kebab>.yml` (record edition `id`s); add `components/**` + `editions/**`
   to `package.json` `files`.
4. **compliance features** — for each capability with **no existing `f_*`**
   (gap analysis), create a new `f_*` in `compliance_feature/` (scaffold:
   `createNewCompliancefeature.sh`; ⚠️ macOS BSD `sed -i` needs `-i ''` — fill by
   hand). `elements.yml` may start empty (control links = step 6).
5. **segment `supports.yml`** — wire features (existing + new) into their segments
   (`complianceFeature: f_*`, `status`, `strength`). ⚠️ **A new `f_*` is orphaned
   until added here** — so new features imply a `segment/` PR.
6. **control links** — `elements.yml` per feature (`standardAlias`+`elementAlias`
   OR raw `id` → published Requirements/controls). Resolved at dataload (the
   standards must be loaded). **SME-gated** — author only against real published
   `framework/`+`standard/` elements; may be left `elements: []` if deferred.

## Phase 3 — validate + PRs
- Validate every touched package: `./gradlew :<path>:validate`.
- Open **one PR per repo** touched (`vendor/`?, `suite/`?, `product/`,
  `compliance_feature/`?, `segment/`?) → base **`dev`**. Drive git via the `git`
  skill (selective staging, approval before commit, no Claude coauthor).
- **Every PR body MUST carry a ⚠️ SME-review section** from the dossier's **§9**:
  new features/segments, judgment calls, `M`/`L`-confidence editions/components,
  candidates deliberately omitted, deferred control mappings. A clean diff hides
  uncertainty. (The `git` skill handles mechanics only — YOU own composing the
  PR body + §9 surface.)

## Reference (don't restate — link)
Enums, NO-suite rule + safety, the feature-wiring chain, MCP op corrections, and PR
hygiene all live in [`catalog-content-model.md`](../../docs/catalog-content-model.md).

## Out of scope
- **Module, collectorbot, schema** — that's `/create-connector`.
- Pushing without approval — git is user-driven via the `git` skill.
