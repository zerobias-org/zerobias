# Architecture (Open-Source Side)

This document describes how the open-source `zerobias-org` repositories
fit into the broader ZeroBias platform — and where the boundary between
open-source and closed-source sits.

It is intentionally high-level. Per-repo `README.md` and `CLAUDE.md`
files cover internal architecture of individual sub-repos.

---

## The two-sided architecture

ZeroBias has two cooperating halves:

1. **Closed-source platform services.** Authentication, authorization,
   the integration runtime ("Hub"), the dataloader, REST/GraphQL APIs,
   AuditgraphDB, deployment infrastructure. None of this lives in
   `zerobias-org`.
2. **Open-source content & integrations.** Compliance frameworks,
   benchmarks, product catalog, integration module specs, ETL collector
   bots, schemas, custom apps/logins, dev tooling. **All of this lives
   in `zerobias-org` and is aggregated by this meta-repo.**

The two halves communicate through stable **contracts**:

- Modules expose an **OpenAPI** spec the Hub runtime can introspect and
  invoke.
- Collector bots produce **typed objects** matching declarations in
  Schemas (which AuditgraphDB enforces).
- Content packages (frameworks, benchmarks, crosswalks, etc.) are
  published as **NPM packages**; the dataloader subscribes to them and
  ingests their content on update.
- Custom Apps & Logins consume **public platform APIs** (REST/GraphQL)
  and the **Dana Login SDK** respectively.

If you're working on the open-source side, you mostly need to know the
contracts — not the internals of the closed-source services.

---

## The content catalog flow

```
                  (you, contributing in zerobias-org)
                                │
                                ▼
   ┌──────────────────────────────────────────────┐
   │   Open-source content repos                  │
   │   framework/  standard/  benchmark/          │
   │   crosswalk/  product/   vendor/  segment/   │
   │   suite/  compliance_feature/  kb/           │
   └──────────────────────────┬───────────────────┘
                              │ publish (NPM)
                              ▼
                  Versioned content packages
                              │
                              ▼
   ┌──────────────────────────────────────────────┐
   │   ZeroBias platform (closed source)          │
   │   - dataloader ingests packages              │
   │   - APIs serve content to tenants            │
   │   - tenants compose frameworks, vendors,     │
   │     products into their compliance posture   │
   └──────────────────────────────────────────────┘
```

What this means for contributors:

- **Publishing is mostly automated.** Most content repos auto-publish on
  merge to `main` via GitHub Actions. Check the repo's `README.md`.
- **Semver matters.** Content artifacts are referenced by version.
  Breaking changes (renaming a Requirement ID, removing a Product) need a
  major-version bump.

See [`ContentArtifacts.md`](ContentArtifacts.md) for the artifact
publishing model in detail.

---

## The integration flow

```
        (you, contributing in zerobias-org)
                       │
                       ▼
   ┌────────────────────────────────────────┐
   │   module/                              │
   │   OpenAPI spec describing operations   │
   │   on a target system + connection      │
   │   profile types                        │
   └─────────────┬──────────────────────────┘
                 │ npm package
                 ▼
   ┌────────────────────────────────────────┐
   │   Hub runtime (closed source)          │
   │   - loads module package               │
   │   - manages connections & credentials  │
   │   - schedules invocations              │
   │   - invokes module operations          │
   └─────────────┬──────────────────────────┘
                 │ raw operation output
                 ▼
   ┌────────────────────────────────────────┐
   │   collectorbot/                        │
   │   ETL: transforms module output into   │
   │   graph objects (typed against         │
   │   schema/ declarations)                │
   └─────────────┬──────────────────────────┘
                 │ typed objects
                 ▼
   ┌────────────────────────────────────────┐
   │   AuditgraphDB (closed source)         │
   │   - stores typed objects + versions    │
   │   - graph queries via GraphQL          │
   └────────────────────────────────────────┘
```

The module/collectorbot split lets one team focus on **how to talk to
the remote system** (module) and another on **how to shape that data for
compliance** (collector) — they evolve independently.

A `pipeline/` configuration wires specific modules and collectors
together for execution.

---

## Catalog relationships

The catalog repos reference each other:

```
                          segment
                            ▲
                            │ classifies
                            │
   vendor ◄──── makes ──── product ────► compliance_feature
     ▲                       │
     │ groups                │ part of
     │                       ▼
     └──── owns ───────── suite
```

In code, these references are typed strings (`vendorId`, `productId`,
`segmentId`, …) declared in [`types/`](https://github.com/zerobias-org/types).

---

## Deployment shape (high level)

Closed-source services are deployed as a multi-tenant SaaS. Each tenant
("Boundary") sees a slice of the catalog and accumulates their own
state in AuditgraphDB. The open-source layer is the *content* that fills
those slices — published once, consumed by every tenant.

For most open-source contributors this distinction is invisible. You add
a compliance framework or product entry, it gets published, and tenants
see it on next sync. You don't manage tenant isolation, RBAC, or storage
— those are the closed-source platform's job.

---

## Stable contracts you can rely on

If you're building inside `zerobias-org` repos, these contracts are
guaranteed not to break without a major-version bump:

| Contract | Defined in | Used by |
|----------|-----------|---------|
| Module OpenAPI spec format | `module/` per-repo conventions + `types/` | Hub runtime |
| Connection profile types | `types/` | `module/`, Hub runtime |
| Schema declaration format | `schema/` | `collectorbot/`, AuditgraphDB |
| Framework / Benchmark / Crosswalk file shapes | per-repo `README.md` | dataloader |
| Vendor / Product / Suite / Segment record shapes | `types/` | catalog APIs |
| Compliance feature schema | `types/` | catalog APIs |

If you change any of these, treat it as a breaking change and call it out
explicitly in the PR.

---

## What's *not* covered here

For closed-source internals — auth, hydra, the Hub runtime, dataloader,
SQL schemas, deployment slots, etc. — you need access to the internal
platform documentation. None of it is reproduced here; this meta-repo
respects that boundary intentionally.
