# Catalog content model — how vendor / product / segment / feature content fits together

Team reference for how the ZeroBias open-source **catalog content** (`vendor/`,
`suite/`, `product/`, `segment/`, `compliance_feature/`) is structured, validated,
and wired together. Distilled from real connector work (the Wiz CNAPP add,
2026-06). The [`/create-product`](../skills/create-product/SKILL.md) skill
automates this (and [`/create-connector`](../skills/create-connector/SKILL.md)
calls it for the catalog part of a full data integration); this doc is the
underlying "what / why" so anyone can author or **review** a catalog PR by hand.

---

## TL;DR — the traps that bite

1. **Validate with the gradle gate, NOT `npm run validate`.** Each content repo's
   `scripts/validate.ts` is a **stale Lerna-era leftover** with wrong enums — it
   *rejects* the canonical `hostingTypes: saas` and *accepts* a bogus `cloud`. The
   real validator is the **dataloader during `./gradlew gate`** (CI runs the
   `zbb-publish-reusable` workflow → gradle gate). Run locally:
   `./gradlew :<vendor>:[<suite>:]<product>:validate`.
2. **A package is only gate-able if it has `build.gradle.kts`** containing
   `plugins { id("zb.content") }`. `settings.gradle.kts` auto-discovers projects by
   walking the tree for that file. The Lerna-era `create-product` skill **omits it**
   — add it, or the package is invisible to the gate.
3. **Enums come from the platform model (`@zerobias-com/hydra-core`)**, not the local
   script (table below). Verify any enum via `mcp__zb-knowledge__search_code` for
   `HostingTypeEnum` / `FactoryTypeEnum` / `VspStatusEnum`.
4. **Compliance features are wired through SEGMENTS, in git** — not on the product,
   and not (primarily) via API. See "feature-wiring chain" below.

## Canonical enums (hydra-core)

| `index.yml` field | Allowed values | In practice |
|---|---|---|
| `factoryTypes[]` | `software` · `firmware` · `hardware` | ~all products = `[software]` |
| `hostingTypes[]` | `iaas` · `paas` · `saas` | a SaaS product = `[saas]` (**never** `cloud`) |
| `status` | `draft` · `active` · `rejected` · `deleted` · `verified` · `suggested` · `publishing` | products use `verified` |

`saas`/`paas`/`iaas` are **hostingTypes, not factoryTypes**. The "saas is a
factoryType" idea comes from the broken `validate.ts` — ignore it.

## The artifacts (all git content, loaded by the dataloader)

- **vendor** — `vendor/package/<v>/` — the company.
- **suite** — `suite/package/<v>/<s>/` — **RARE**; only genuine mega-brand umbrellas
  (AWS, Microsoft 365). **Default is NO suite:** even multi-product security vendors
  (Tenable → `tenable/io`, `tenable/nessus`; Cisco → `cisco/duo`, `cisco/umbrella`)
  put products directly under the vendor as siblings. A single multi-pillar platform
  (Wiz) = **one product** with its pillars as **components**. A suite code must not
  collide with the vendor code (`wiz`/`wiz` ⇒ not a suite).
- **product** — `product/package/<v>/[<s>/]<p>/`:
  - `index.yml` — identity, the canonical enums, `segments:` (UUID list), `cpeProducts`.
  - `catalog.yml` — product header + `Operations` (API surface).
  - `components/<kebab>.yml` — sub-products / modules (`id` uuid v4, `name`,
    `description`, `background`).
  - `editions/<kebab>.yml` — commercial plans (same fields). **Record each edition
    `id`** — it's the `productEditionId` for any later edition-feature override. An
    edition *may* optionally declare `components: [<codes>]` to map a plan → the
    components it includes (loader resolves codes → `productComponentIds`); currently
    unused by all catalog products (8/8 editions ship only the four base fields).
  - `build.gradle.kts` (`plugins { id("zb.content") }`), `package.json` (with
    `components/**` + `editions/**` in `files`), `logo.*`.
- **segment** — `segment/package/zerobias/<t_*>/` — a market/technology category.
  `index.yml` + **`supports.yml`** (see below).
- **compliance_feature** — `compliance_feature/package/zerobias/<f_*>/` — a capability.
  `index.yml` (id/name/description/`code`/`externalId`) + `elements.yml` (links the
  feature → published compliance Requirements; SME-gated).

## The feature-wiring chain (GIT is the source of truth)

A product's compliance-feature profile is **inherited through its segments**, in git
— two hops:

```
product index.yml#segments  →  segment/.../<t_*>/supports.yml#complianceFeature
```

`supports.yml` shape:

```yaml
supports:
  - complianceFeature: f_cadai   # an existing or new f_* code
    status: supported
    strength: high               # high | medium | low
```

Rules:
- A product **does not list features**; it lists **segments** (`index.yml#segments`).
  It inherits whatever features those segments support.
- A **NEW** `f_*` feature only connects once it's added to some segment's
  `supports.yml`. **A new feature with no `supports.yml` entry is orphaned.** So
  creating `f_*` almost always implies a matching `segment/` PR.
- Many segments ship with **no `supports.yml`** (they support nothing yet) — adding
  one is legitimate taxonomy curation. Strength ratings are an SME judgment.
- `platform.Product.patchEditionFeatures` (API/UI) is a **secondary, edition-specific
  override** (e.g. a feature gated to one edition only). It has **no git form** — use
  it only for edition exceptions, and only **after** the content PRs load (the edition
  + feature IDs must already exist in the platform).

A fully-wired connector can thus span **three content PRs**: `product/`
(index + components + editions + segments), `compliance_feature/` (new `f_*`),
`segment/` (new features into `supports.yml`).

## MCP op corrections

Sub-repo docs cite `portal.Vendor.search` / `portal.Suite.search` — **these don't
exist** in the live MCP. For catalog discovery use `store.Vendor.get` /
`store.Suite.get` / `store.Vendor.listProducts` / `store.Suite.listProducts`.

## PR hygiene

- The content repos PR against **`dev`** (not `main`).
- **Every PR body MUST carry a ⚠️ SME-review section** — the low-confidence / judgment
  items (new features/segments, judgment calls, M/L-confidence editions/components,
  candidates deliberately omitted, deferred mappings). A clean diff hides uncertainty;
  reviewers need to know what to vouch for. (`/create-connector` sources this from the
  research dossier's §9.)

---

*Source of truth wins over this doc: if a `*:validate` gate error ever cites an enum
or rule, re-check `@zerobias-com/hydra-core` (via zb-knowledge) — the dataloader is
authoritative.*
