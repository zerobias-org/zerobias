---
# PRODUCT RESEARCH DOSSIER — the concrete output of the research phase.
# Filled by: live interview (submitter, human-knowable items) + AI research.
# EVERY field carries a confidence (H|M|L); researched facts also carry a source.
# Low-confidence items + corrections auto-collect in §9 as the PR's SME review
# surface (§13). Each field notes WHERE it persists (validated on GitHub, 2026-06):
#   index.yml · catalog.yml · platform op (patchSegments) · module · research-only
product: <vendor>[.<suite>].<product>
status: draft            # draft | interviewed | researched | reviewed | landed
---

# Research dossier — <Vendor> <Product>

Confidence: **H** interview-confirmed / unambiguous · **M** AI-researched, likely ·
**L** AI guess → SME must vouch.

## 1. Identity & parentage   → `vendor/`, `suite/`, `product/index.yml` (PR/git)
| field | value | conf | source |
|-------|-------|:----:|--------|
| vendor name / code |  |  | vendor site |
| suite? (name/code \| none) |  |  | vendor taxonomy + catalog pre-probe |
| product name |  |  | product page |
| product code (slug) |  |  | derived |
| parentType (`vendor`\|`suite`) |  |  | derived |
| vendorId / suiteId (UUID) |  |  | catalog lookup (`zb` MCP) |

## 2. Product fields   → `product/index.yml`
| field | value | conf | source / note (incl. enum) |
|-------|-------|:----:|----------------------------|
| description |  |  | product/marketing page (write clean prose, no ellipsis fragments) |
| url |  |  | product page — **PR/git only (no API)** |
| apiDocsUrl |  |  | dev portal — **often MISSING in existing entries; add it** |
| logo |  |  | `cdn.auditmation.io/logos/<v>-<p>.svg` |
| factoryTypes | `[software]` | H | enum **software\|firmware\|hardware** |
| hostingTypes |  |  | enum **iaas\|paas\|saas**. ⚠️ no "self-hosted" value — a self-hosted product (e.g. GH Enterprise Server) = `factoryTypes:software` + an edition, NOT a hostingType; the SaaS offering → `saas` |
| status | `verified` | H | enum **draft\|publishing\|published\|released\|verified\|active** |
| tags / aliases | `[]` |  | alt names — **dedupe!** (existing entries often have junk duplicate aliases) |

Canonical enums: `@zerobias-com/hydra-core/platform-models.yml`.

## 3. CPE   → `vendor/index.yml#cpeVendors`, `product/index.yml#cpeProducts` (PR/git ONLY)
**Selection rule (validated):** include the **core product + first-party CLIs /
Actions / runners / SDKs** (e.g. `github`, `enterprise_server`, `cli`, `codeql_cli`,
`codeql_action`, `runner`). **Exclude** transitive OSS deps + low-signal tokens
(tiny NVD record count / unrelated project — e.g. `gaug.es`, `btcsuite_go-socks`).
Derive from the NVD CPE dictionary; keep NVD underscore casing.
| field | value | conf | source |
|-------|-------|:----:|--------|
| cpeVendor |  |  | NVD CPE dict |
| cpeProducts[] |  |  | NVD CPE dict (apply rule) |

Vulnerabilities link automatically + feed-delayed once these match real NVD CpeProducts (§12).

## 4. Segment   → `platform.Product.patchSegments` (in-platform) OR `product/index.yml#segments`
Most existing products carry **NO** segments in YAML (set in-platform). Research the
right segment(s) regardless; note where you'll persist it.
| field | value | conf | reasoning |
|-------|-------|:----:|-----------|
| matched segment(s) (name/UUID) |  |  | rank-match vs the fixed taxonomy |
| new segment needed? | yes/no (+ proposed code/tier/parent) |  | → separate `segment/` PR if yes |

**Feature wiring (GIT source of truth).** A product gets its compliance features
**through its segments**, two hops, both in git:
`product index.yml#segments` → `segment/…/t_*/supports.yml#complianceFeature`
(`status`, `strength`). Prefer the git path (`index.yml#segments`) over the
in-platform `patchSegments` API. ⚠️ **A NEW `f_*` feature (see §8) is orphaned
until it's added to some segment's `supports.yml`** — so creating a feature almost
always implies a `segment/` PR too. Record per matched segment: existing-vs-new,
and which `supports.yml` must gain the feature. (Full model:
[`catalog-content-model.md`](../../docs/catalog-content-model.md).)

## 5. Editions / Components   → `product/editions|components/*.yml` (PR/git)
- **editions = commercial PLANS** (Free, Pro, Team, Enterprise…). Shape:
  `id, name, description, background` **+ `components: [<component codes>]`** — the
  sub-products that plan includes (loader resolves codes → `productComponentIds`).
  ⭐ **Determine the edition→component mapping** (which plan includes which
  component) and author it. Guard against swapped/cross-pasted copy (real GitHub bug).
- **components = sub-products / features** (Actions, Packages, Codespaces, Copilot,
  Advanced Security, Pages, Issues, …). **Be COMPLETE** — existing entries are often
  ~1 of N. Shape: `id (uuid v4), name, description, background`. (component→editions
  is one-directional — author the link on the edition's `components:`.)
- ⚠️ **The product `index.yml` `components` field is IGNORED** by the loader (declared
  in the interface, never read). The edition's `components:` (component **codes**,
  resolved `getByProductAndCode`; missing = non-fatal warning) is the ONLY live
  edition↔component link. id-vs-code: product `segments` = id|code; segment `parents`
  + edition `components` = **codes only**; vendor/suite parents = **UUIDs**.
- **Feature ↔ edition ↔ component links live in a separate `supports.yml`** — each
  row says *feature X is supported by edition Y, via component Z (Z optional)*:
  ```yaml
  supports:
    - complianceFeature: <id | code | packageCode>   # REQUIRED
      edition:   <id | code>      # optional
      component: <id | code>      # optional
      strength:  low|medium|high  # optional, default medium
      status:    supported|...    # optional, default unknown
  ```
  product→compliance-feature = a `features/<code>.yml` + a `supports.yml` row (**no**
  `complianceFeatures:` field on `index.yml`). segment→feature = the *segment*
  package's own `supports.yml`. Full package layout: `index.yml · catalog.yml ·
  editions/*.yml · components/*.yml · features/*.yml · supports.yml`.
- **Deployment variants** (e.g. Cloud vs Server) are NOT a component — model as
  distinct **editions** (+ the hostingTypes note), don't muddle into one.
- ⚠️ **Provenance (`sourceUrl` + `verifiedAt`) is a PROPOSED schema enhancement** —
  the current edition/component schema only accepts `id/name/description/background`,
  so do NOT put extra fields in the committed YAML (it would fail the gate). Until
  the schema adds them, keep source + verified-date in the **PR description** /
  `.research/`.

## 6. Connection / auth methods   → MODULE `connectionProfile.yml` (NOT a product field)
Auth/connection is a **module** concern — the product artifact has no slot for it.
Research it here for the module handoff; don't expect it in `product/index.yml`.
- auth type(s): `oauth2 | apiKey | http(basic|bearer) | openIdConnect | mutualTLS`
- profile/base (`@zerobias-org/types-core/schema/`) + per-method required fields: …

## 7. API surface (operations)   → `product/catalog.yml#Operations` (curated)
⚠️ Existing `catalog.yml` can be a **stale API snapshot** (pinned internal version)
— flag missing namespaces. Raw spec → `.research/.../raw/` (research-only).

## 8. Compliance features + CONTROLS   [REQUIRED — comprehensive; SME-validated for accuracy]
- **MANDATORY on product research:** every feature must be linked to the controls it
  satisfies, **comprehensively** (don't leave satisfied controls unlinked). Core
  deliverable — NOT deferred.
- For each capability the product has (SSO, MFA, audit logging, encryption, RBAC,
  key mgmt, logging/SIEM export, …): map it to **all** the framework elements/controls
  it satisfies.
- **Mechanism** (verified vs dataloader@main + `compliance_feature/` repo). TWO layers,
  both currently empty for most products:
  1. **Feature → control** (GENERIC, shared): the 144 reusable features live in
     `compliance_feature/package/zerobias/f_<code>/` (`index.yml` = the feature;
     `elements.yml` = its controls). Each entry is `standardAlias` (→ a **Standard**,
     `StandardDAO.getByAlias`) + `elementAlias` (→ its element, `getByStandardAndAlias`),
     OR a raw element/control `id` (id path tries element→framework_element→control→
     test_case). Handler `ComplianceFeatureElementsFileHandler` → `upsertElement`.
     **Resolution is a live DB lookup at DATALOAD** — the referenced standard/framework
     + elements must already be loaded in the target env or it throws; `validate.ts`
     checks shape ONLY (`id` OR both aliases), never resolution; **no package.json dep
     needed**. ⚠️ **As of 2026-06 every `elements.yml` is `elements: []`** — the
     feature→control layer is 100% unpopulated repo-wide (this is why no control link
     shows in the UI for ANY product). A control = a framework element with
     `elementType: control` (ISO 27001 cloned; SOC2/AICPA NOT cloned).
  2. **Product → feature**: the product links to the generic feature via its own
     `supports.yml` (`complianceFeature: <f_code|id|packageCode>` + `edition` +
     optional `component`). Products have NO `features/` of their own for these.
  Platform joins `control → element → feature → product`. Both layers must be filled
  before controls surface; layer 1 (generic `elements.yml`) is the shared bottleneck.
- **Accuracy gate:** the loader only checks elements EXIST (non-existent → rejected),
  NOT that the mapping is *correct*. Map only to **real published elements** + have an
  **SME validate semantic correctness**. SME gates *accuracy*, not *whether to do it*.
- **Control index source = `zb` MCP** (enabler C, verified): `platform.Framework.listFrameworks`
  → frameworks; `listFrameworkElements(frameworkId, versionId, keywords?)` → the
  per-framework **elements that ARE the controls** (authored in `elements.yml` by
  `standardAlias`/`elementAlias`); `scfSearch(text)` / `listScfControls` → the unified
  **SCF** overlay (each SCF control carries `frameworkElementId` → element → derived
  control). ⚠️ Query an env with the **compliance catalog loaded** — the `qa` profile
  is EMPTY (zero frameworks); switch profile (`meta.switchProfile`) to the right env.

## 9. Low-confidence + CORRECTIONS → SME review surface (auto-collected)
- every **L**; new-segment proposals; all compliance mappings; **AND any corrections
  to an existing entry** found during review (swapped / duplicated / stale fields).

## 10. Add plan   (§15 / §18)
- **PR(s):** vendor? · suite? · product (incl. url, cpeProducts, segments, editions,
  components) · new segment? · compliance_feature draft?  → **PR against `dev`**.
- **API:** product↔segment association (if not carried in YAML).
- Target branches: most → `dev` (env-deploy); merge = load + approval.
- ⚠️ **Versioning is automatic — NEVER hand-bump.** All repos auto-version via Lerna/CI
  on conventional-commit merge. A dev load that no-ops on version is a publish-timing
  issue, not a cue to manually edit `package.json` versions (see `product/CLAUDE.md`).
- ⚠️ **No npm dependency for feature/control links.** `supports.yml` (→ feature by code)
  and `elements.yml` (→ standard/element by alias) resolve against the **live DB at
  dataload**, not via package deps — don't add the feature/framework as a dependency.
- ⚠️ **zbb/Gradle repos need `zbb gate` before publish — do NOT author via the GitHub
  API/web.** Repos that publish via zbb (`compliance_feature`, `module`, `collectorbot`,
  `schema`, any vendor/suite mid-Gradle-migration — tell by a `build.gradle.kts` +
  `gate-stamp.json` in the package) require a fresh `gate-stamp.json` from `zbb gate`
  that matches the committed content; the publish preflight rejects a stale stamp
  (`gate-stamp.json is missing or invalid`) and fails ALL packages. Edit in a **local
  clone → `zbb gate` → commit the stamp → PR**. ⚠️ **`product` is ALSO zbb-gated**
  (confirmed — PR #35's content change failed publish identically; its `lerna.json` is
  legacy). Don't assume ANY content repo is gate-free — check for `gate-stamp.json` +
  `build.gradle.kts` in the package. A version-ONLY change passes (sourceHash unchanged),
  but a CONTENT change (yml) drifts the stamp → must be re-gated → can't be authored via API.
  To gate locally: (1) `zbb --slot <s> stack add <repo-root>` to make the repo a reachable
  stack; (2) from the package dir run `zbb --slot <s> gate` with **`ZB_TOKEN` UNSET**
  (`env -u ZB_TOKEN`). The Neon `testDataloader` task is guarded by `onlyIf(ZB_TOKEN
  present)` — absent token → it SKIPS (warning) and the stamp still writes; a present-but-
  **expired** `ZB_TOKEN` → 401 hard-fail (the gating cred is **`ZB_TOKEN`**, NOT
  `NEON_API_KEY` — the zbb.yaml/task comments are stale). The stamp can't be hand-faked,
  and the API shortcut can't produce it — gate locally. CI runs the real Neon dataloader
  with valid creds, so the content is still validated there.

## 11. Load mechanics: dependency order + `publishOrg` (org-direct, no PR)
- **Artifacts load dependencies child-before-parent.** The dataloader `npm install`s the
  artifact's `@zerobias-org/*` deps and loads them in order (vendor → suite? → product),
  resolving each from the **registry** via its package.json range (vendor pinned `latest`).
  A product load pulls + loads its vendor automatically — you do NOT pre-load the chain.
  (Confirmed: a wiz product load auto-installed `vendor-wiz@1.0.0` before the product.)
- **`publishOrg`** (zbb gradle task, content repos) loads straight to your org, bypassing
  the PR + dev version-gate: gate → `npm publish` org-private `<semver>-rc.<orgIdStripped>.<n>`
  → POST a dataloader job to your org. Publishes **only the leaf package** (no chain handling
  — the dataloader resolves deps from the registry). Conditions: `ZB_TOKEN` = **admin token
  of the target org** (a different-org token fails the `/dana/me` check); package.json
  `zerobias.orgId` = target org UUID; **plain-semver** pkg version; **brand-new / org-owned
  name only** (rejects shared-catalog names like the github product / `f_*` features).
- ⚠️ **Load authz (org users):** you can only queue **org-private** (`-rc.<org>`) dataloader
  jobs; a catalog-version load (plain semver, e.g. `vendor-wiz@1.0.0`) is **403 Forbidden**
  (`JobProducerImpl.queueJob`). So `publishOrg` of a new org-owned artifact is the ONLY
  user-accessible load path — you cannot load shared-catalog content into your org yourself
  (that needs a platform admin).
- **Required run env** — put these where zbb reads its env: the **slot/stack `env:`** (a plain
  shell `export` does NOT reach the build). Keep the secret in the slot's *local* env
  (`zbb --slot <s> env set ZB_TOKEN …` — not a committed file); the non-secret URLs/tag can live
  in the stack's `zbb.yaml` `env:`:
  - `ZB_TOKEN` — org-admin token of the target org (mask it in logs).
  - `ZB_PLATFORM_URL: https://<env>/api` — publishOrg uses it for BOTH `/dana/me` and
    `/dataloader/jobs` (default is prod `app.zerobias.com/api`).
  - `DATALOADER_SERVICE_URL: https://<env>/api/dataloader` — a **separate** var the gate's
    `dataloaderExec` (NeonDataloaderTask) reads; it does NOT honor `ZB_PLATFORM_URL`, so if you
    set only ZB_PLATFORM_URL the gate hits prod and 401s. Set both.
  - `NPM_CONFIG_TAG: dev` — npm 11 requires a dist-tag for prereleases; set it via env (no code
    edit) so the `-rc.<org>` publish is accepted/tagged. (`ENV_TYPE: dev` only drives dependency
    dist-tag resolution, not the publish tag.)
  - `PUBLISH_ORG_REGISTRY_URL: https://pkg.zerobias.org` (org-private registry; this is the default).
- **Composite build:** the gate compiles `build-tools` from source via
  `includeBuild("../util/packages/build-tools")`, so the run dir MUST sit **beside** the `util`
  clone (a `/tmp` worktree breaks the relative path → silently falls back to the published
  plugin). The gate's local Neon load uses the `@zerobias-com/platform-dataloader` global — keep
  it current (`npm i -g @zerobias-com/platform-dataloader@latest`).
- **Re-load without re-publishing (fast path):** once an org-private artifact is published, you
  can (re)load it any time by POSTing the dataloader job directly — no gate, no re-publish:
  `POST https://<env>/api/dataloader/jobs` with body
  `{"artifactName":"<pkg>","artifactVersion":"<semver>-rc.<orgIdStripped>.<n>"}` and headers
  `Authorization: APIKey <ZB_TOKEN>` + `dana-org-id: <orgUUID>`; poll
  `GET …/dataloader/jobs/<id>` until `completed` (a full org-owned product — vendor + ~dozens of
  components/editions — loads in ~10s). Confirm it landed:
  `GET …/api/store/products/<vendorCode>.<productCode>` (by package **code**, e.g. `wiz.wiz`,
  NOT the UUID) → returns the org-owned product + `…/versions`.
- **Promote to the shared catalog (PR to `dev`):** the ONLY change is to **delete
  `zerobias.orgId` from package.json** — that flips the artifact owner from your org to NilUUID
  (= shared catalog; owner is `effectiveOwnerId = zerobias.orgId ?? NilUUID`). **No re-gate
  needed:** for content packages `package.json` is NOT part of the gate-stamp `sourceHash` (it
  hashes the `files` payload — `index.yml`/`catalog.yml`/`logo.*`), so adding the orgId (to load
  to your org) then removing it (for the PR) leaves the stamp valid. Don't hand-edit `version`
  (CI/Lerna owns it). Commit the content + the existing `gate-stamp.json`, PR against `dev`; the
  leftover `-rc.<org>.<n>` org-private npm versions don't collide with the catalog semver.
