# Handoff — Part 2 (module) · <Vendor> <Product>

> The orchestrator fills the placeholders and writes the result to
> `.connector/handoff-module-<connector>.md`. Open a **new Claude Code session
> in `module/`** and paste the body below. When `/create-module` finishes,
> paste your ≤200-word summary back into the orchestrator session.

---

You are completing **Part 2 (module)** of a connector build. Read the brief
first — it has the full resolved context:

    /Users/ctamas/zerobias-org/.connector/<connector>.md

Run the native module scaffold (note arg order = `vendor service [suite]`):

    /create-module <v> <p> [<s>]

Preconditions the leaf command checks (it fails fast if any is missing — fix,
don't bypass):
- Node version from `module/.nvmrc` active
- Docker Desktop running
- `@zerobias-org/generator-module` installed globally

When `/create-module` completes:
1. Confirm `zbb build` was green; note the module package name
   `@zerobias-org/module-<v>-<s?>-<p>`.
2. **Publish it to the local registry** so Part 3 can consume it (run inside the
   loaded `cc-test` slot):
       zbb --slot cc-test registry publish <abs-path-to-module-package-dir>
   then verify: `zbb --slot cc-test registry list`
3. Report back (≤200 words): module path, package name, build status,
   registry-publish status, any deviations or errors.

Do **NOT** push branches or open PRs — scaffold + build + local-publish only.
