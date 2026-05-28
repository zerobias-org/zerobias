---
name: create-connector
description: |
  End-to-end orchestrator for adding a new connector (vendor → suite? → product →
  module → collectorbot, with interface-targeted schema) in the zerobias-org
  meta-repo. USE THIS PROACTIVELY when the user says anything like "add a
  connector for X", "create a collector for vendor/product Y", "ingest /
  collect / pull data from <SaaS>", "new integration for <vendor>", "wire up
  <product> to the platform", "add a new data source", or names a
  vendor/product not yet in the catalog with intent to make its data
  available. Discovers existing VSP + schema state via the zb MCP, chains the
  existing sub-repo scaffolds (createNewProduct.sh, createNewSuite.sh,
  /create-product, yo @auditmation/hub-module, /create-collector), and
  targets a schema interface so concrete classes can be authored later.
---

# create-connector

Meta-repo orchestrator for the full flow: catalog (vendor → suite? → product)
→ module → collectorbot → schema-interface wiring. **Chains existing sub-repo
scaffolds; does not reimplement them.**

## Execution model — orchestrator + per-phase sub-agents

The main session runs as a thin orchestrator and delegates each substantial
phase to a dedicated sub-agent. The main session only sees the sub-agent's
≤200-word final report per phase. This keeps the context small across what is
otherwise a 6-phase, multi-repo flow.

| Phase | Sub-agent type | Owns |
|-------|----------------|------|
| 1 (discovery) | `Explore` | `zb` MCP + filesystem checks; returns a one-screen state table |
| 2 (catalog gaps) | `general-purpose`, one per missing layer | Scaffold + marker + `gate` |
| 3 (module) | `general-purpose` | Yeoman scaffold + `api.yml` skeleton + `gate` |
| 4 (collectorbot) | `general-purpose` | Chains the existing `/create-collector` in `collectorbot/` |
| 5 (interface wiring) | `general-purpose` | Interface picker via `zb` MCP, edits `collector.yml` + `src/Mappers.ts` |

Phase 0 (parse inputs) and Phase 6 (TODO printout) stay in the main session.

Each sub-agent brief includes: the resolved inputs, the specific sub-repo
docs to read first, and a one-paragraph success criterion. If any sub-agent
fails, stop and report — do not silently retry.

**Deferred MCP tools.** The `mcp__zb__zerobias_*` tools are deferred and must
be loaded with `ToolSearch` before they can be invoked. Any sub-agent that
needs them must run, as its first action:

```
ToolSearch with query "select:mcp__zb__zerobias_search,mcp__zb__zerobias_describe,mcp__zb__zerobias_execute" and max_results 3
```

Same for `mcp__zb-knowledge__*` if a sub-agent needs the semantic index.
Skipping this step is the #1 cause of sub-agents reporting "platform state
unknown" — call it out in every relevant brief.

## Phase 0 — parse inputs, resolve author identity

Stay in the main session.

Required from the user (ask via `AskUserQuestion` if missing):

- vendor code (e.g. `okta`)
- product code (e.g. `okta`)
- optional suite code (e.g. `aws` for `amazon/aws/s3`)
- one-line product display name / description
- OpenAPI spec URL (or "user will provide later")

**Author identity** for the module scaffold — resolve in this order, never
hardcode in the skill body:

1. `git config user.email` inside the relevant working tree
2. The author table in `~/.claude/CLAUDE.md` (matches by working-tree path
   prefix — e.g. `~/code/` and Zerobias paths → `ctamas@zerobias.com`)
3. Ask the user via `AskUserQuestion`

## Phase 1 — discover what exists (`Explore` sub-agent)

Brief an `Explore` sub-agent with the resolved inputs and tell it to:

- Load the deferred `zb` MCP tools first (see "Deferred MCP tools" above).
- Call `mcp__zb__zerobias_execute` for catalog discovery. These ops 404 on
  missing — that's the absence signal:
  - `store.Vendor.get` with `{ vendorCode: "<vendor>" }`
  - `store.Suite.get` with `{ vendorCode: "<vendor>", suiteCode: "<suite>" }` (only if suite given)
  - `store.Vendor.listProducts` with `{ vendorCode: "<vendor>" }` — then check whether the returned `items` include one with `packageCode === "<vendor>.<product>"`
  - For suite-parented products: `store.Suite.listProducts` with `{ vendorCode, suiteCode }` and look for `packageCode === "<vendor>.<suite>.<product>"`
- Cross-check local clones:
  - `/Users/ctamas/zerobias-org/vendor/package/<vendor>/`
  - `/Users/ctamas/zerobias-org/suite/package/<vendor>/<suite>/`
  - `/Users/ctamas/zerobias-org/product/package/<vendor>/[<suite>/]<product>/`
  - `/Users/ctamas/zerobias-org/module/package/<vendor>/[<suite>/]<product>/`
  - `/Users/ctamas/zerobias-org/collectorbot/package/<vendor>/[<suite>/]<product>/`
- Return a state table — for each layer (vendor / suite / product / module /
  collectorbot), one of: `exists-platform-and-local`, `exists-platform-only`,
  `exists-local-only`, `missing`.

Show the report to the user; confirm the layers we'll scaffold before
proceeding.

## Phase 2 — fill catalog gaps (vendor → suite? → product)

Order matters: vendor → suite → product. Skip layers that already exist.
For each missing layer, brief a separate `general-purpose` sub-agent.

| Missing | Sub-agent task |
|---------|----------------|
| Vendor | `cd vendor`, read `vendor/README.md` first, run `sh scripts/createNewProduct.sh package/<vendor>`, drop `build.gradle.kts` with `plugins { id("zb.content") }`, run `./gradlew :<vendor>:gate`, leave branch ready (do not push). |
| Suite | `cd suite`, read `suite/README.md` first, run `sh scripts/createNewSuite.sh <vendor>/<suite>`, drop the marker, run `./gradlew :<vendor>:<suite>:gate`, leave branch ready. |
| Product | `cd product`, invoke the existing `/create-product` skill in that repo. It handles depth-2 vs depth-3 layout, `catalog.yml`, `npm-shrinkwrap.json`, and parent-ID lookup. (Note: `product/.claude/skills/create-product/SKILL.md` currently references non-existent `portal.*.search` ops — if that skill fails on the MCP step, fall back to vendor-ID lookup via `store.Vendor.get` and pass the resolved UUID to the skill.) |

Each sub-agent reports the branch name and the produced `gate-stamp.json`
path. The orchestrator relays and proceeds.

## Phase 3 — scaffold the module (`general-purpose` sub-agent)

Brief the sub-agent with the resolved inputs and the author email from
Phase 0:

```bash
cd module
yo @auditmation/hub-module \
  --productPackage '@zerobias-org/product-<vendor>-[<suite>-]<product>' \
  --modulePackage  '@zerobias-org/module-<vendor>-[<suite>-]<product>' \
  --packageVersion '0.0.0' \
  --description    '<Display Name>' \
  --repository     'https://github.com/zerobias-org/module' \
  --author         '<author-email-from-Phase-0>'
```

After scaffold the sub-agent:

- Reads `module/README.md`, `module/CLAUDE.md`, `module/CONTRIBUTING.md` first.
- Drops the Gradle marker: `plugins { id("zb.typescript-connector") }`.
- Wires in the user-provided `api.yml` (or a minimal placeholder if the URL
  isn't yet available).
- Leaves `connectionProfile.yml` / `connectionState.yml` as scaffold defaults
  for the user to refine.
- Runs `./gradlew :<module-path>:gate` to confirm validation is green.

## Phase 4 — chain `/create-collector` (`general-purpose` sub-agent)

The sub-agent runs the existing leaf skill in `collectorbot/`:

```bash
cd collectorbot
/create-collector <vendor> [<suite>] <product>
```

That skill already verifies module + schema deps, scaffolds directory and
symlinks, runs install / generate / build / lint, and auto-validates via
`/review-collector` (8-agent parallel review). **Do not reimplement any of
it here.**

> The `collectorbot/` repo is expected to migrate from `npm` to `zbb` + ESM.
> When that lands, the leaf skill will reflect it — this orchestrator stays
> unchanged because it only invokes the leaf skill.

## Phase 5 — wire to a schema interface (`general-purpose` sub-agent)

Concrete schema work is deferred to next week. Until then, target an
existing schema **interface** and let the dataloader materialize concrete
subclasses at ingest time via a discriminator field.

The sub-agent:

- Loads the deferred `zb` MCP tools first (see "Deferred MCP tools" above).
- Enumerates available interfaces from the local schema clone first —
  `/Users/ctamas/zerobias-org/schema/package/*/*/interfaces/*.yml` — since
  interfaces live in source, not on the platform. Optionally cross-check
  via `zerobias_search` for "schema" if a relevant op exists.
- Presents candidate generic interfaces to the user via `AskUserQuestion`,
  with the one-line `description:` field from each interface YAML. Common
  reusable bases: `Secret`, `DBMS`, `Element`, `Provider`, `CloudEnvironment`.
- In the collectorbot's `collector.yml`, lists the chosen interface(s) under
  `classes:` (the field name is `classes` but accepts interface names —
  concrete subclasses are materialized at ingest time).
- In `src/Mappers.ts`, ensures each emitted object carries:
  - `id` — stable unique identifier from the source
  - `name` — human-readable
  - the **discriminator field** expected by the interface (`kind` / `type`)
  - all required fields declared by the interface

## Phase 6 — print schema TODO and stop

Back in the main session. Print exactly:

```
TODO (schema, deferred):
  Path:     schema/package/<vendor>/[<suite>/]<product>/
  Why:      Collector currently emits to interface(s): <list>.
            Concrete classes should be authored once the data shape stabilizes.
  Scaffold: cd schema && ./scripts/createNewSchema.sh package/<vendor>/[<suite>/]<product>
```

Do **not** scaffold an empty schema entry now — targeting interfaces removes
the need this week.

## `zb` MCP usage rules

This skill is **read-only** against the `zb` MCP. Catalog additions go
through PRs to the sub-repos, not direct platform writes.

Three mandatory checkpoints use the MCP:

1. **Catalog discovery** (Phase 1) — confirm presence/absence via
   `store.Vendor.get` / `store.Suite.get` / `store.*.listProducts` before
   scaffolding. Local clones may be stale. The `portal.*.search` ops cited
   in some sub-repo docs do not exist in the live MCP — use the `store.*`
   ops here.
2. **Schema discovery** (Phase 5) — enumerate interfaces via
   `zerobias_search` + `_execute` before picking one.
3. **Write guard** — any non-`list` / `get` / `search` op must pause and
   confirm with the user. The orchestrator never writes through the MCP.

If the `zb` MCP isn't configured, fall back to filesystem checks and offer
to install per the meta-repo `CLAUDE.md` MCP section. Flag loudly that
catalog discovery is now best-effort.

## Out of scope

- Pushing branches or opening PRs — scaffolding and validation only; the
  user drives git via the existing `git` skill.
- Authoring concrete schema entries — deferred to next week.
- Reimplementing scaffold logic that already lives in a sub-repo
  (vendor's `createNewProduct.sh`, suite's `createNewSuite.sh`,
  product's `/create-product`, module's Yeoman generator,
  collectorbot's `/create-collector`, schema's `createNewSchema.sh`).
- Modifying sub-repo docs.
