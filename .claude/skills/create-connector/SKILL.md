---
name: create-connector
description: |
  End-to-end orchestrator for adding a new DATA INTEGRATION (connector) in the
  zerobias-org meta-repo: catalog → module → collectorbot, with interface-targeted
  schema. USE THIS PROACTIVELY when the user says "add a connector for X", "create
  a collector for vendor/product Y", "ingest / collect / pull data from <SaaS>",
  "new integration for <vendor>", "wire up <product> to the platform", "add a new
  data source", or names a vendor/product not yet in the catalog with intent to
  make its data available. It does NOT reimplement the catalog work — Part 1
  delegates to the `/create-product` skill (which checks if the product already
  exists and asks what to do), then this skill adds the module + collectorbot and
  targets a schema interface so concrete classes can be authored later. For
  CATALOG-ONLY needs (no module/collectorbot) use `/create-product` directly.
---

# create-connector

Meta-repo orchestrator for the full data-integration flow:
**catalog (→ `/create-product`) → module → collectorbot → schema-interface
wiring.** Chains existing skills/scaffolds; does not reimplement them.

> **Read first:** [`.claude/docs/catalog-content-model.md`](../../docs/catalog-content-model.md)
> for the catalog model. **The entire catalog side is owned by
> [`/create-product`](../create-product/SKILL.md)** — this skill *calls* it for
> Part 1, then adds module + collectorbot + schema. Don't duplicate catalog logic
> (enums, suite decision, components/editions, feature wiring, PR §9 surface) here.

## Execution model — three parts, two mechanisms, one brief

| Part | What | Mechanism | Output package (→ local registry) |
|------|------|-----------|-----------------------------------|
| **1. Catalog** (vendor → suite? → product + components/editions + segments + features) | **delegated to `/create-product`** | that skill's in-session sub-agents | `@zerobias-org/product-<v>-<s?>-<p>` |
| **2. Module** | this skill | **handoff** → native session in `module/` | `@zerobias-org/module-<v>-<s?>-<p>` |
| **3. Collectorbot** | this skill (+ interface wiring + schema TODO) | **handoff** → native session in `collectorbot/` | `@zerobias-org/collectorbot-<v>-<s?>-<p>` |

The three parts are a **publish→consume chain**: Part 3's `/create-collector`
runs `npm view` / `npm install` against the product (Part 1) and module (Part 2)
packages and **stops if they're missing**. Since we never push during a build,
those packages are made available via the **local Verdaccio registry** (see
"Local registry bridge"). This is mandatory, not optional.

### Two mechanisms — why module & collectorbot can't be sub-agents

- **In-session sub-agents** drive Part 1 (inside `/create-product`) and this
  orchestrator's own steps. A sub-agent **reads** the relevant sub-repo doc/script
  and **follows it inline** — it does NOT invoke the sub-repo's slash-command
  (those aren't registered in this session). The main session sees only each
  sub-agent's ≤200-word report.
- **Handoff prompts** drive Parts 2 & 3. `/create-module` fans out to ~20
  sequential specialist agents; `/create-collector` → `/review-collector` fans out
  to 8 **parallel** agents. A sub-agent **cannot spawn sub-agents**, so those
  skills can only run in a **fresh top-level session opened in the sub-repo**. The
  orchestrator fills a self-contained handoff prompt (templates:
  `handoff-module-template.md`, `handoff-collector-template.md`), the user runs it
  in a `module/` then `collectorbot/` session, and pastes the ≤200-word summary
  back. The orchestrator records each result in the brief.

### The brief / manifest (shared state + handoff payload)

The brief is **created by `/create-product` in Part 1** (from
[`../create-product/brief-template.md`](../create-product/brief-template.md)) at:

```
/Users/ctamas/zerobias-org/.connector/<vendor>-[<suite>-]<product>.md
```

(`.connector/` is gitignored — transient state.) It is the single source of truth
across all three parts: resolved codes, the chosen schema interface +
discriminator, package names, per-part status, exact resolved commands, findings
log. **Every handoff prompt points at the brief's absolute path** so a fresh
sub-repo session has full context. This skill updates the brief after Parts 2 & 3;
if any step fails, mark the brief `blocked`, log it, stop, and report — never
silently retry.

**Deferred MCP tools.** `mcp__zb__zerobias_*` (and `mcp__zb-knowledge__*`) are
deferred — any sub-agent that needs them must first run
`ToolSearch` with `select:mcp__zb__zerobias_search,mcp__zb__zerobias_describe,mcp__zb__zerobias_execute`.
(`/create-product` already handles this for the catalog part.)

## Part 1 — catalog content (delegated to `/create-product`)

**Do not reimplement the catalog flow here — run `/create-product`.** It owns
research → discovery → suite decision → scaffolding the whole catalog chain
(vendor → suite? → product + components + editions + segments → compliance
features → segment `supports.yml` → control links), validation via the gradle
gate, the dossier, the brief, and the PR §9 SME-review surface.

> **Test-load to your own org (no PR):** to load the product into your org while iterating,
> see `/create-product`'s dossier **§11** — the `publishOrg` recipe.

Crucially, `/create-product` **checks whether the product already exists and asks
what to do**:

- **Product missing** → it creates the product + all catalog dependents.
- **Product exists** → it surfaces that and asks (update / add missing deps /
  use-as-is). For the connector flow, **"use as-is" is the "go with that" path** —
  you just need the product package available to consume in Parts 2–3.

Two things this skill is responsible for around the delegation:

1. **Author identity** for the *module* (Part 2) — resolve now and record in the
   brief: `git config user.email` → the author table in `~/.claude/CLAUDE.md`
   (matches by working-tree path prefix; Zerobias paths → `ctamas@zerobias.com`) →
   ask via `AskUserQuestion`. (`/create-product` doesn't need it — catalog YAML has
   no author field.)
2. **Publish the product to the local registry** once it has gated green
   (`zbb --slot cc-test registry publish`) so Part 3 can consume it — see "Local
   registry bridge".

Everything about enums, the NO-suite default, components/editions, the
`segments → supports.yml` feature-wiring chain, and the PR §9 surface lives in
`/create-product` + [`catalog-content-model.md`](../../docs/catalog-content-model.md).

## Part 2 — module (handoff to a `module/` session)

`/create-module` (`module/.claude/commands/create-module.md`) is a 6-phase
workflow that **sequentially invokes ~20 specialist agents**
(`@product-specialist`, `@api-researcher`, `@api-architect`,
`@module-scaffolder`, …). A sub-agent can't spawn those, and the command isn't
registered in this session — so this part runs as a **handoff**, not a
sub-agent. **Do not reimplement the Yeoman invocation here.**

The orchestrator:

1. Fills `handoff-module-template.md` with the resolved codes + brief path and
   writes it to `.connector/handoff-module-<connector>.md`.
2. Tells the user to open a **new session in `module/`** and paste it. The
   command (note arg order `vendor service [suite]`, different from
   collectorbot's `vendor [suite] product`) is:

   ```
   cd module
   /create-module <vendor> <product> [<suite>]
   ```

3. Waits for the user's ≤200-word summary, records it in the brief, then
   ensures the module package is **published to the local registry** so Part 3
   can consume it (`zbb --slot cc-test registry publish <module-package-dir>` —
   see "Local registry bridge").

`/create-module` already discovers product metadata / API surface / auth via its
own agents, resolves `--author` from `git config user.email` and `--repository`
from the git remote, picks `--moduleType`, runs `yo @zerobias-org/module` (the
canonical generator — **not** `@auditmation/hub-module`), auto-runs `zbb build`,
and designs `api.yml` via `@api-architect`. **Do not bypass it with a manual
`yo` call** — its phase pipeline is what produces a working `api.yml` (earlier
inline drafts used the wrong generator name + a hardcoded `--repository` and
produced unusable specs with dangling `externalValue:` refs).

**Preconditions** the handoff prompt restates (the leaf command fails fast if
unmet, surface the error and stop): Node per `module/.nvmrc`, Docker running,
`@zerobias-org/generator-module` installed globally.

## Part 3 — collectorbot (handoff to a `collectorbot/` session)

`/create-collector` ends by running `/review-collector`, which **requires 8
parallel `Task` calls in a single message** — intrinsically a top-level
multi-agent operation a sub-agent can't perform. So this part is also a
**handoff**. **Do not reimplement any of it here.**

Before generating the handoff, the orchestrator must have **fixed the schema
interface in the brief** — do the schema-interface pick (below) *first*.

The orchestrator:

1. Fills `handoff-collector-template.md` with the resolved codes, the chosen
   interface(s) + discriminator, and the brief path; writes it to
   `.connector/handoff-collector-<connector>.md`.
2. Tells the user to open a **new session in `collectorbot/`, inside the loaded
   `cc-test` slot** (so npm resolves the product + module packages from local
   Verdaccio). Command (arg order `vendor [suite] product`):

   ```
   zbb slot load cc-test
   cd collectorbot
   /create-collector <vendor> [<suite>] <product>
   ```

3. Waits for the ≤200-word summary (collector path, package name, interface(s),
   generate status, `/review-collector` compliance %) and records it in the brief.

The handoff prompt carries **three CRITICAL overrides** to the leaf skill,
because its defaults will otherwise STOP or mis-author:

- **Schema → base interface, not a vendor schema.** The leaf skill's Step 1.2
  hard-checks `@auditlogic/schema-<v>-<p>` and STOPs if missing. **Skip that
  check.** Depend on `@zerobias-org/schema-zerobias-zerobias-base` (+ `-ts`) and
  target the interface, following the reference collector
  `collectorbot/package/google/gcp/iam` (see schema-interface pick).
- **Author** from `git config user.email`, not the skill's hardcoded value.
- **Module / product deps from the local registry** (slot active); no push.

> When `collectorbot/` migrates from `npm` to `zbb` + ESM, only the handoff
> prompt's environment notes change — this orchestrator stays the same.

## Schema-interface pick (orchestrator; wiring happens in Part 3)

Concrete schema work is deferred. We collect directly to an existing base
**interface**; the dataloader materializes a `Dynamic<Interface>` concrete
subclass at ingest via a discriminator field. Reference implementation:
`collectorbot/package/google/gcp/iam` (targets the `Principal` interface,
depends on `@zerobias-org/schema-zerobias-zerobias-base` + `-ts`).

This pick must happen **before** the Part 3 handoff, so the chosen interface is
fixed in the brief and baked into the collector handoff prompt. The orchestrator:

- Enumerates candidate interfaces from the local schema clone —
  `/Users/ctamas/zerobias-org/schema/package/*/*/interfaces/*.yml` (interfaces
  live in source, not on the platform). Common reusable bases: `Principal`,
  `Secret`, `Provider`, `DBMS`, `CloudEnvironment`, `Account`, `Repository`.
- Presents candidates to the user via `AskUserQuestion`, using each interface
  YAML's one-line `description:`.
- Records in the brief: the chosen interface(s), the schema package
  `@zerobias-org/schema-zerobias-zerobias-base` (+ `-ts`), and the discriminator
  field (`kind` / `type`, e.g. `principalType` in the GCP IAM reference).

The actual wiring — the `collector.yml` `classes:` entry (the field is named
`classes` but accepts interface names), `Mappers.ts` imports from `…-base-ts`,
and the `id` / `name` / discriminator / interface-required fields on each
emitted object — is performed **inside the Part 3 collector session** per the
handoff prompt, not by a separate sub-agent here.

## Finish — print schema TODO and stop

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

## Local registry bridge (the glue between the 3 parts)

The parts hand packages to each other through a **local Verdaccio registry**
(`zbb registry`, built into zbb) so a full build never touches a real registry
and never needs a push.

Setup once per machine:

```
zbb slot create cc-test
zbb --slot cc-test registry start      # or auto-starts as a dep of dana
zbb --slot cc-test registry status     # confirm healthy
zbb --slot cc-test env get REGISTRY_URL
```

Flow:

- **After Part 1**, publish the product package: from the product package dir
  inside the slot, `zbb --slot cc-test registry publish` (or pass the path).
  Verify with `zbb --slot cc-test registry list`.
- **After Part 2**, publish the module package the same way.
- **Part 3** runs inside the loaded slot, so `NPM_CONFIG_USERCONFIG` points npm
  at local Verdaccio; `/create-collector`'s `npm view` / `npm install` of the
  product + module resolve locally, and `@zerobias-org/schema-zerobias-zerobias-base`
  proxies from GitHub Packages through Verdaccio (needs `GITHUB_TOKEN` /
  `ZB_TOKEN` in env).
- Between test runs, `zbb --slot cc-test registry clear` wipes local publishes
  (next install re-fetches upstream).

Record the registry URL and per-package publish status in the brief.

## `zb` MCP usage rules

This skill is **read-only** against the `zb` MCP. Catalog additions go through PRs
to the sub-repos (via `/create-product`), not direct platform writes.

- **Catalog discovery / suite decision** happen inside `/create-product` (Part 1)
  via `store.Vendor.get` / `store.Suite.get` / `store.*.listProducts`. The
  `portal.*.search` ops cited in some sub-repo docs do not exist — use `store.*`.
- **Schema-interface pick** — enumerate interfaces from the local schema clone
  (`schema/package/*/*/interfaces/*.yml`); no MCP call needed.
- **Write guard** — any non-`list`/`get`/`search` op must pause and confirm with
  the user. The orchestrator never writes through the MCP.

If the `zb` MCP isn't configured, fall back to filesystem checks and offer to
install per the meta-repo `CLAUDE.md` MCP section; flag that discovery is
best-effort.

## Out of scope

- The catalog flow itself — owned by `/create-product` (don't duplicate it here).
- Pushing branches or opening PRs — the user drives git via the `git` skill.
- Authoring concrete schema entries — deferred (interface-targeted for now).
- Reimplementing scaffold logic that lives in a sub-repo (module's
  `/create-module`, collectorbot's `/create-collector`, schema's
  `createNewSchema.sh`).
- Modifying sub-repo docs.
