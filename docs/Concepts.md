# Core Concepts

This document defines the **domain vocabulary** used across the
`zerobias-org` open-source repositories. If you're new to ZeroBias —
or you just want to ground a coding agent in the right terms — start
here.

Concepts are grouped by what they describe:

- [Compliance content artifacts](#compliance-content-artifacts)
- [Catalog: products, vendors, segments](#catalog-products-vendors-segments)
- [Integration: modules, collectors, pipelines](#integration-modules-collectors-pipelines)
- [Data: schemas and AuditgraphDB](#data-schemas-and-auditgraphdb)
- [Apps & UX](#apps--ux)

Each section names the **primary sub-repo(s)** that hold the
corresponding artifacts.

---

## Compliance content artifacts

ZeroBias treats compliance content as a catalog of versioned packages. The
core artifact types are:

### Standard

> **Repo:** [`standard`](https://github.com/zerobias-org/standard)

A formal published document — typically issued by a standards body (NIST,
ISO, CIS, …) — broken down into **Elements** that can be referenced
elsewhere. Elements are the atomic units that Requirements and test cases
point to.

A Standard answers "what is the canonical published text?". It does not,
on its own, prescribe what an organization must *do*.

### Framework

> **Repo:** [`framework`](https://github.com/zerobias-org/framework)

A set of **Requirements** that describe **what must be done** to comply,
typically organized into families, controls, or sub-controls. Frameworks
are *non-prescriptive* — they state the requirement, not the implementation.

A Framework usually maps onto one or more Standards (for citation) and
onto Benchmarks (for testable implementations).

### Benchmark

> **Repo:** [`benchmark`](https://github.com/zerobias-org/benchmark)

A collection of **test cases** that describe **how to achieve compliance**
with a specific Framework Requirement on a specific technology. Benchmarks
*are* prescriptive ("set this config flag to `true`"; "ensure no IAM user
has `*:*` permissions"). One Framework Requirement may have many
Benchmarks across different vendors / products.

### Crosswalk

> **Repo:** [`crosswalk`](https://github.com/zerobias-org/crosswalk)

A mapping between Requirements across different Frameworks. Crosswalks
answer questions like "if I'm already compliant with NIST 800-53 AC-2,
which ISO 27001 controls have I partially or fully satisfied?".

### Compliance Feature

> **Repo:** [`compliance_feature`](https://github.com/zerobias-org/compliance_feature)

A feature description that ties Products/Vendors back to the Framework
Requirements they help satisfy. A Compliance Feature is what a product
*offers* — e.g. "Okta provides multi-factor authentication that
contributes to satisfying NIST AC-2(11)".

### Knowledge Base Article

> **Repo:** [`kb`](https://github.com/zerobias-org/kb)

Free-form documentation, guidance, and how-to articles. Unlike the other
content repos, **`kb` is a Hugo static site** (theme: `doks`), not a
Lerna monorepo of NPM packages. Contribute Hugo markdown directly under
the site's content tree; coordinate with maintainers before substantial
changes (the repo currently has no README and a placeholder `CLAUDE.md`).

---

## Catalog: products, vendors, segments

ZeroBias catalogs the universe of products and services that organizations
use, so compliance content can refer to them precisely.

### Vendor

> **Repo:** [`vendor`](https://github.com/zerobias-org/vendor)

An entity (typically a company) that offers products or services. A
Vendor record holds canonical metadata: legal name, URL, etc.

### Product (Service)

> **Repo:** [`product`](https://github.com/zerobias-org/product)

A specific offering by a Vendor. Examples: "Okta Workforce Identity",
"AWS S3", "GitHub Enterprise Cloud". Products link to a Vendor and to one
or more Segments (taxonomy) and Compliance Features.

### Suite

> **Repo:** [`suite`](https://github.com/zerobias-org/suite)

A grouping of related Products — e.g. "Microsoft 365" is a Suite that
contains Exchange Online, SharePoint Online, Teams, etc. as Products.

### Segment

> **Repo:** [`segment`](https://github.com/zerobias-org/segment)

The **taxonomy** used to categorize Products and Services into domains,
categories, sub-categories, tools, and services. Segments answer "what
*kind* of thing is this product?" (e.g. "IAM → Identity Provider →
Workforce IdP"). Many compliance-content queries depend on Segment
metadata to filter by product category.

---

## Integration: modules, collectors, pipelines

The platform reaches into external systems through an integration layer.

### Module (Hub Module)

> **Repo:** [`module`](https://github.com/zerobias-org/module)

An **OpenAPI-defined integration** that exposes a remote system (a SaaS
product, an on-prem appliance, a legacy IoT device, …) as a uniform set
of REST operations. A Module is a *spec plus generated client code* — it
declares the operations available and the connection profile needed.

Modules are consumed by the Hub runtime (which lives in the closed-source
platform). From the open-source side, you write the Module spec and tests;
the Hub runtime handles deployment, secrets, scheduling, and execution.

Two flavours:

- **Connector module** — runs centrally and reaches *out* to a target
  system via its API.
- **Agent module** — packaged for on-prem deployment to reach systems
  that aren't internet-accessible (legacy networks, IoT, OT, …).

See [`Modules.md`](Modules.md) for the full module-developer guide.

### Collector Bot

> **Repo:** [`collectorbot`](https://github.com/zerobias-org/collectorbot)

An ETL process that takes the output of a Module invocation and loads it
into AuditgraphDB as graph objects conforming to a Schema. Where the
Module knows *how to talk to a remote system*, the Collector knows *how
to shape that data into the compliance graph*.

### Pipeline

> **Repo:** [`pipeline`](https://github.com/zerobias-org/pipeline)

Conceptually: a configuration that chains data sources together for
ingestion. **In practice**, the public `pipeline` repo currently
contains a single sub-package (`package/pipeline/`) with three YAML
configs: `agentskills.yml`, `hl7-fhir.yml`, `mcpservers.yml`. Treat it
as a small registry of data-source pipeline configurations until further
documentation lands; ask a maintainer before assuming it does
module/collector orchestration.

---

## Data: schemas and AuditgraphDB

### AuditgraphDB

ZeroBias stores compliance state in a **timeseries graph database**
called AuditgraphDB. Its key properties:

- **Object-with-versions** model: each object has identity and many
  versions over time, so historical queries are first-class.
- **Typed**: every object conforms to a class declared in a Schema.
- **Linked**: objects reference each other via typed link fields
  (single/multi-valued, uni/bidirectional).
- Queryable via **GraphQL**.

You don't run AuditgraphDB from this open-source repo — that's part of
the closed-source platform. But every Schema, Collector, and Query
artifact you'll see in `zerobias-org` is shaped by it.

### Schema

> **Repo:** [`schema`](https://github.com/zerobias-org/schema)

Type definitions for AuditgraphDB objects — classes, properties, links,
and relationships. Schemas declare what kinds of objects can exist and
how they relate.

A Module's output is typed against one or more Schemas via its
corresponding Collector.

---

## Apps & UX

### Custom App

> **Repo:** [`app`](https://github.com/zerobias-org/app)

Example single-page applications that consume the ZeroBias platform API.
Includes Angular and Next.js templates for iframe-embedded and
standalone deployments. Use these as a starting point for building
custom customer-facing apps on top of the platform.

### Custom Login

> **Repo:** [`login`](https://github.com/zerobias-org/login)

White-label custom login pages. Built on the Dana Login SDK and rendered
through Handlebars templates, so each tenant can theme the login flow
without forking the platform UI.

---

## Cross-cutting

### Types

> **Repo:** [`types`](https://github.com/zerobias-org/types)

Lerna+Nx monorepo (`packages/`, plural) of TypeScript typedefs for
ZeroBias domain objects, plus vendor-specific typedef bundles for
Amazon, Atlassian, Google, and Microsoft, and a Spectral ruleset
package for API-spec linting. The repo's README is missing — look at
the per-sub-package READMEs instead.

### Util

> **Repo:** [`util`](https://github.com/zerobias-org/util)

**Load-bearing infrastructure**, not "just utilities". Lerna+Nx+Gradle
monorepo (`packages/`, plural) shipping ~17 sub-packages including:

- **`zbb`** — the Gradle plugin that powers content-monorepo
  lifecycles across `module`, `collectorbot`, `vendor`, `suite`,
  `product`, `schema`.
- **`codegen`** — OpenAPI Generator used by Hub modules.
- **`module-tester`**, **`module-test-client`**, **`content-schema`**,
  **`connector`**, **`api-client-base`**, **`invoker`**,
  **`secrets-manager`**, **`build-tools`**, **`logger`**,
  **`spectral-config`**, **`eslint-config`**, etc.

Changes to `util` ripple across the org. Coordinate before bumping any
of its sub-packages.

---

## Concept → Repo cheat sheet

| Concept | Primary repo | Often paired with |
|---------|--------------|-------------------|
| Standard | `standard` | `framework`, `crosswalk` |
| Framework | `framework` | `standard`, `benchmark`, `crosswalk` |
| Benchmark | `benchmark` | `framework`, `module` |
| Crosswalk | `crosswalk` | `framework` |
| Compliance Feature | `compliance_feature` | `product`, `framework` |
| KB Article | `kb` | any |
| Vendor | `vendor` | `product`, `suite` |
| Product / Service | `product` | `vendor`, `suite`, `segment`, `compliance_feature` |
| Suite | `suite` | `product`, `vendor` |
| Segment | `segment` | `product`, `vendor` |
| Module | `module` | `collectorbot`, `schema`, `pipeline` |
| Collector Bot | `collectorbot` | `module`, `schema`, `pipeline` |
| Pipeline | `pipeline` | `module`, `collectorbot` |
| Schema | `schema` | `collectorbot`, `module` |
| Custom App | `app` | — |
| Custom Login | `login` | — |
| Domain Types | `types` | every code repo |
| Utilities | `util` | every code repo |

For deeper architectural context — how these artifacts fit together at
runtime — see [`Architecture.md`](Architecture.md).
