# Modules

Hub Modules are the integration layer between ZeroBias and the outside
world. This document covers the open-source side: what a Module is, how
to build one, and the actual contribution mechanics — verified against
the live [`module`](https://github.com/zerobias-org/module) repo
(May 2026).

---

## What a Module is

A **Module** is an **OpenAPI-defined integration** that exposes the
capabilities of an external system through a uniform contract. The
Module package contains:

1. **An OpenAPI 3.x spec** (`api.yml`) describing operations,
   parameters, and response shapes.
2. **A connection profile** (`connectionProfile.yml`) declaring what
   credentials/parameters the module needs.
3. **A connection-state declaration** (`connectionState.yml`).
4. **A connector implementation** under `src/` that maps OpenAPI
   operations onto the target system's actual API calls.
5. **Tests** under `test/`.
6. **Hub SDK bindings** under `hub-sdk/` so the Hub runtime can invoke
   the module.

> **Repo:** [`module`](https://github.com/zerobias-org/module)

The Hub runtime (closed source) loads the published module package,
manages credential storage and scheduling, and invokes module operations
on behalf of tenants.

---

## Build system: Gradle + zbb (not Lerna)

This is the most important thing to know if you've worked on `framework/`
or other content repos: **`module` does not use Lerna or `npm run validate`.**

The `module` repo uses:

- `build.gradle.kts` + `settings.gradle.kts` at the root
- `zbb.yaml` to configure the [zbb](https://github.com/zerobias-org/util)
  plugin (`util/packages/zbb`)
- Conventional npm `package.json` files inside each module sub-package
- Git **submodules** at the repo root (it has its own `.gitmodules`).

The README documents the migration from the old Lerna pattern to gradle
+ zbb. New modules use gradle exclusively.

---

## Anatomy of a module package

```
module/
├── build.gradle.kts
├── settings.gradle.kts
├── zbb.yaml
├── .gitmodules                          # module/ has its own submodules
├── package/
│   └── <vendor>/<product>/<api-type>/   # ← one folder per module
│       ├── api.yml                      # OpenAPI spec (source of truth)
│       ├── connectionProfile.yml
│       ├── connectionState.yml
│       ├── package.json
│       ├── build.gradle.kts
│       ├── src/
│       ├── test/
│       ├── hub-sdk/
│       ├── tsconfig.json
│       ├── CHANGELOG.md
│       ├── USERGUIDE.md
│       └── gate-stamp.json
└── ...
```

Real example: `package/avigilon/alta/access/` is the Avigilon Alta
Access module.

---

## Module flavours

### Connector module

Runs **inside** the Hub runtime. Reaches out to a target system via its
network-accessible API. Most modules are connectors.

### Agent module

Packaged for **on-prem deployment** to reach systems that aren't
internet-accessible. The OpenAPI contract is identical; only packaging
and deployment mode differ.

---

## Naming conventions

Modules cross several registries (NPM, sometimes Maven, sometimes PyPI),
so naming is strict.

- **Folder path:** `module/package/<vendor>/<product>/<api-type>/`
- **NPM package name:** `@zerobias-org/module-<vendor>-<product>-<api-type>`
  - Example: `package/avigilon/alta/access/` →
    `@zerobias-org/module-avigilon-alta-access`
- **Vendor / product IDs:** must match entries that already exist in
  [`vendor`](https://github.com/zerobias-org/vendor) and
  [`product`](https://github.com/zerobias-org/product). Add catalog
  entries there first if they don't exist.

---

## Building a module (high level)

The detailed step-by-step lives in
[`module/README.md`](https://github.com/zerobias-org/module/blob/main/README.md).
The general flow is gradle-driven:

```bash
cd module
git checkout -b feat/add-<vendor>-<product>-<api-type>

# 1. Scaffold the module folder (the README documents the current
#    gradle/zbb scaffolding command — check it for the canonical
#    invocation; this changes occasionally during the migration).

# 2. Edit api.yml — define operations and connection profile
# 3. Edit connectionProfile.yml and connectionState.yml
# 4. Implement the connector under src/

# 5. Validate
./gradlew :module-<vendor>-<product>-<api-type>:gate

# 6. (optional) Dry-run a publish to confirm wiring
./gradlew :module-<vendor>-<product>-<api-type>:publishToMavenLocal
# or zbb publish --dry-run, depending on current convention

git add .
git commit -m "feat(<vendor>/<product>/<api-type>): initial module"
git push origin feat/add-<vendor>-<product>-<api-type>
```

**Source of truth:** `api.yml`. Generated artifacts come from it; don't
edit generated TypeScript directly.

---

## What the Hub runtime guarantees you

If your module follows the OpenAPI contract correctly, the runtime will:

- **Validate connections.** Connection profiles are typed; the runtime
  refuses to invoke a module with a malformed connection.
- **Inject credentials.** Secrets declared in the connection profile are
  fetched from secure storage and made available to your connector at
  invocation time.
- **Handle retries and rate limits.** Standard 429/5xx handling happens
  at the runtime layer.
- **Capture telemetry.** Invocation latency, success/failure, error
  details are recorded automatically.
- **Schedule.** Modules can be invoked on a cron schedule or on demand
  via the platform API.

What it does **not** do:

- Translate the module's response into AuditgraphDB objects. That's the
  job of a paired
  [`collectorbot`](https://github.com/zerobias-org/collectorbot)
  package (same `vendor/product/api-type` path, also gradle+zbb).
- Validate the *semantics* of the module's responses. Schema validation
  exists at the OpenAPI level only; business-logic validation lives in
  your tests.

---

## Pairing modules with collectors

A typical end-to-end integration is:

```
module/package/<vendor>/<product>/<api-type>/         ← API contract
collectorbot/package/<vendor>/<product>/<api-type>/   ← AuditgraphDB ETL
```

Both reference the same `<vendor>/<product>/<api-type>` triple. The
collector consumes the module's typed output and converts it into graph
objects matching declarations in
[`schema`](https://github.com/zerobias-org/schema).

> **Note on `pipeline/`.** Earlier drafts of this doc claimed `pipeline/`
> wires modules and collectors together for scheduled execution.
> Inspecting the current
> [`pipeline`](https://github.com/zerobias-org/pipeline) repo, that's not
> what's there — it currently holds `agentskills.yml`, `hl7-fhir.yml`,
> and `mcpservers.yml`. If you need scheduled-execution wiring, ask a
> maintainer; the canonical location may have moved or may live in
> closed-source infrastructure.

---

## Module submodules

`module/` ships its own `.gitmodules`. When working inside it, you may
encounter nested submodules — typically vendor-specific SDKs or shared
test fixtures. Standard submodule rules apply (see
[`SubmoduleWorkflow.md`](SubmoduleWorkflow.md)); the meta-repo's
submodule of `module/` is independent of `module/`'s own submodules.

---

## When you don't need a new module

Before writing a new module, check whether the system you want to
integrate is already covered. The
[`module`](https://github.com/zerobias-org/module) repo lists existing
modules; the
[`vendor`](https://github.com/zerobias-org/vendor) and
[`product`](https://github.com/zerobias-org/product) repos are the
canonical catalogs.

If a module already exists but is missing an operation you need:

1. Add the operation to the existing module's `api.yml`.
2. Implement the new connector method under `src/`.
3. Add a test.
4. Run `./gradlew :<module-name>:gate`.

This is almost always preferable to forking or duplicating.

---

## Quick reference

| Question | Answer |
|----------|--------|
| Build system | **Gradle + zbb** (`zbb.yaml`, `build.gradle.kts`). Not Lerna. |
| Source of truth | `api.yml` per module |
| Where do I implement API calls? | `src/` inside the module folder |
| Per-module package name pattern | `@zerobias-org/module-<vendor>-<product>-<api-type>` |
| Folder path pattern | `module/package/<vendor>/<product>/<api-type>/` |
| Where do vendor/product IDs come from? | [`vendor`](https://github.com/zerobias-org/vendor) and [`product`](https://github.com/zerobias-org/product) — add catalog entries first |
| What loads the module's output into AuditgraphDB? | A paired `collectorbot/` package at the same `vendor/product/api-type` path |
| What handles credentials and retries? | The Hub runtime (closed source) |
| Local validation command | `./gradlew :<module-name>:gate` |
| What underlying tool powers `gate`? | `zbb` — the Gradle plugin published from [`util/packages/zbb`](https://github.com/zerobias-org/util/tree/main/packages/zbb) |
