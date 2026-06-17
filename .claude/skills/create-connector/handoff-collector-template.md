# Handoff — Part 3 (collectorbot) · <Vendor> <Product>

> The orchestrator fills the placeholders and writes the result to
> `.connector/handoff-collector-<connector>.md`. Open a **new Claude Code
> session in `collectorbot/`, inside the loaded `cc-test` slot** (so npm
> resolves the product + module packages from local Verdaccio), and paste the
> body below. Paste your ≤200-word summary back when done.

---

You are completing **Part 3 (collectorbot)**. Read the brief first:

    /Users/ctamas/zerobias-org/.connector/<connector>.md

**Environment** — run inside the slot so the local registry is active and the
product + module packages (published in Parts 1 & 2) resolve locally:

    zbb slot load cc-test
    zbb --slot cc-test registry status     # confirm healthy
    zbb --slot cc-test registry list       # product-<…> and module-<…> present?

Run the native collector scaffold (note arg order = `vendor [suite] product`):

    /create-collector <v> [<s>] <p>

**CRITICAL overrides to the leaf skill** — state these to the collector session
up front, because the default skill will otherwise STOP or do the wrong thing:

1. **SCHEMA — target the BASE interface, do not require a vendor schema.**
   The leaf skill's Step 1.2 hard-checks `@auditlogic/schema-<v>-<p>` and STOPs
   if missing. **Skip that check.** Instead follow the reference collector
   `collectorbot/package/google/gcp/iam`:
   - `package.json` deps:
         "@zerobias-org/schema-zerobias-zerobias-base": "latest"
         "@zerobias-org/schema-zerobias-zerobias-base-ts": "latest"
   - `collector.yml` lists the chosen interface(s) under the scoped key:
         classes:
             - "@zerobias-org/schema-zerobias-zerobias-base":
                 - <Interface>          # e.g. Principal / Secret / Provider
   - `src/Mappers.ts` imports interface types from
     `@zerobias-org/schema-zerobias-zerobias-base-ts/dist/src/index.js`
   - **every emitted object carries**: `id`, `name`, the `<discriminator>`
     field (`kind`/`type`), and all interface-required fields. The dataloader
     materializes `Dynamic<Interface>` at ingest from the discriminator.

2. **AUTHOR — resolve from `git config user.email`**, not the hardcoded
   `ctamas@zerobias.com` in the leaf skill.

3. **MODULE / PRODUCT deps come from the LOCAL registry** (slot active). Do not
   expect them on the public registry; do not push anything.

After `/create-collector` and its automatic `/review-collector` (8-agent) run,
report back (≤200 words): collector path, package name, chosen interface(s),
generate status (`generated/BaseClient.ts` present?), `/review-collector`
compliance %, and any issues or deviations.

Do **NOT** push branches or open PRs.
