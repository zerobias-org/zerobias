# Quickstart

Get productive in the `zerobias` meta-repo in ~10 minutes. For depth,
[`README.md`](README.md) is the canonical reference; this page is the
fastest path to actually doing something.

---

## What you need

- **Git.**
- **Linux or macOS — or WSL2 on Windows.** `zbb` does not run natively on
  Windows: every invocation fails in the Node ESM loader with
  `Received protocol 'c:'` (the bin shim hands the loader a drive-letter
  path where a `file://` URL is required). A Windows-native build is not
  planned. **On Windows, do everything below inside WSL2** — that is the
  supported path and the one this toolchain is verified on. Full setup
  walkthrough (bare Windows → running `claude` session):
  [`docs/WindowsWSLSetup.md`](docs/WindowsWSLSetup.md).
- **[Claude Code](https://claude.com/claude-code)** v2.0 or newer. This
  meta-repo is designed to be driven by an agent — one working tree
  spanning every public `zerobias-org` repo so the agent can read,
  search, and reason across them at once. Everything works without
  Claude Code, but most of the leverage is gone.
- **A ZeroBias account** at [`app.zerobias.com`](https://app.zerobias.com)
  if you want the live platform integrations below (MCPs, private NPM,
  `zb` CLI). External readers can browse all source without an account.

## Bootstrap

```bash
git clone https://github.com/zerobias-org/zerobias.git
cd zerobias
./scripts/clone-all.sh                  # clones every public sub-repo
claude                                  # open Claude Code here
```

`clone-all.sh` is re-runnable (skips repos you already have).
`./scripts/update_all.sh --dry-run` audits drift later; without
`--dry-run` it interactively refreshes.

## Org credentials & MCPs — one script, one slot

Everything credential-related — the private-NPM token, the two
ZeroBias MCPs (`zb-knowledge` semantic code search, `zb` live platform
operations), and your platform API key — lives in a **zbb slot** (a
named environment context) and is configured by one script. No shell
exports, no pasting keys into `claude mcp add`.

**1. Get your keys.** Log into your target env's app (e.g.
[`app.zerobias.com`](https://app.zerobias.com)) → **Settings → API
Keys**. You need an **org OWNER key** for the target org, and (for
gates/publishing) a **prod registry key**.

**2. Run the setup script yourself** — in a normal terminal, *not*
inside a Claude session, so your keys never enter the session.
Requires `zbb` (see [Install `zbb`](#install-zbb) below):

```bash
./scripts/setup-org-credentials.sh
```

It's check-first and safe to re-run: it finds or creates your slot
(canonically named after the org slug — `zerobias` for prod, prefixed
`ci-undefined` for any other env), stores the keys there, wires
`~/.npmrc` and the zb MCP profile (as `${VAR}` placeholders that
resolve from the launching env), and verifies everything against the
platform. It prompts only for what's missing.

Need a second identity for the same org (another API key), or a slot
name of your own? Preset `SLOT` — it skips the reuse of an existing
matching slot:

```bash
SLOT=zerobias-admin ZB_API_KEY=<other-key> ./scripts/setup-org-credentials.sh
```

Each identity lives in its own slot; you pick one at launch with
`--slot`. With several slots holding the same org, always name the
slot explicitly — auto-reuse takes the first match it finds.

**3. Launch Claude Code through the slot** — this is what makes the
MCPs (and npm, gates, publishes) use those creds:

```bash
./scripts/setup-org-credentials.sh --launch     # verify + launch in one
# or directly, from any content-repo root:
zbb --slot <your-slot> exec claude
```

The repos ship committed `.mcp.json` files containing only `${VAR}`
templates — no secrets — so the MCPs pick up whatever identity the
slot injects at launch. A session started *without* a slot fails
loudly (`MISSING_ENV_VAR` / `NOT SET`) instead of silently using
someone else's key. That's by design.

> ⚠️ Never register the MCPs with literal keys
> (`claude mcp add … --header "Authorization: ApiKey abc123"`). A
> baked key silently overrides whatever slot you launch through and
> you end up querying the wrong org. Template form only — details in
> [`docs/MCPs.md`](docs/MCPs.md).

**Multi-org / multi-env: one slot each.** Re-run the script per target
(it prompts for env + org), then pick your identity at launch time:

```bash
zbb slot list                              # see your slots
zbb --slot prod-74fc0422 exec claude       # work as org A on prod
zbb --slot qa-57c741cf   exec claude       # separate session as org B on qa
```

Switching identity = launching through a different slot (the env is
read once at claude startup).

**Plain-terminal npm** (outside Claude): the registry token lives in
the slot too — run `zbb --slot <slot> exec npm install`, or export
`ZB_TOKEN` yourself per
[`docs/RegistrySetup.md`](docs/RegistrySetup.md).

For troubleshooting (`401`, MCP not listed, stale index, etc.):
[`docs/MCPs.md`](docs/MCPs.md).

## Install `zbb`

`zbb` is the ZeroBias CLI that wraps Gradle for every content sub-repo
(`zbb compile`, `zbb publish`, `zbb dataloader`, slot/stack management).
Most contributions need it:

```bash
npm install -g @zerobias-org/zbb@latest
```

`@latest` re-resolves to the newest published version any time you
re-run.

**Runtime versions.** `zbb` declares `engines: { node: '>=22.0.0' }`, but the
content sub-repos pin specific versions — `module/.nvmrc` and
`collectorbot/.nvmrc`. Run `nvm use` inside each sub-repo rather than relying
on whatever is global; a Node-major mismatch surfaces as opaque ESM loader
errors. Java 17 and a running Docker daemon are also required for
`zbb` slots/stacks.

## Example prompts to try

Open Claude Code in the meta-repo and try these. The agent already
knows the layout — you don't need to point it at specific files.

```
Add a connector for github.
```
> Discovers existing catalog state via the `zb` MCP, scaffolds what's
> missing across `vendor` / `product` / `module` / `collectorbot`, and
> stops with a clear schema TODO. Works for any SaaS.

```
Where is the Avigilon Alta Access module's authentication implemented?
```
> Cross-repo semantic search via `zb-knowledge`. Returns file paths
> with line numbers — here, `connect()` in
> `module/package/avigilon/alta/access/src/AvigilonAltaAccessClient.ts`.

```
What's the difference between a vendor, a product, a suite, and a segment?
```
> Concise sourced answer from the meta-repo docs and `zb-knowledge`.

```
Refresh every sub-repo to its tip.
```
> Runs `./scripts/update_all.sh --dry-run` first, asks before applying.

```
Add a benchmark for CIS Docker on Kubernetes.
```
> Routes to `benchmark/`, loads its CONTRIBUTING.md, walks the scaffold.

```
What does CI actually run on a module PR?
```
> Reads `module/.github/workflows/` and summarizes the gate.

```
I want to add a new compliance framework for SOC 2 Type II.
```
> Asks the right disambiguation questions (framework vs standard vs
> crosswalk) before editing anything.

## Where to go next

- [`README.md`](README.md) — full repo inventory, concepts table, contribution flow
- [`docs/DOCUMENTATION_INDEX.md`](docs/DOCUMENTATION_INDEX.md) — *"I want to do X"* routing
- [`docs/Concepts.md`](docs/Concepts.md) — domain vocabulary, deeper
- [`docs/MCPs.md`](docs/MCPs.md) — MCP setup details + troubleshooting
- [`docs/RegistrySetup.md`](docs/RegistrySetup.md) — `ZB_TOKEN` setup for building, CI patterns
- [`docs/LocalDevelopment.md`](docs/LocalDevelopment.md) — cross-repo `npm link` workflows
