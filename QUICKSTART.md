# Quickstart

Get productive in the `zerobias` meta-repo in ~10 minutes. For depth,
[`README.md`](README.md) is the canonical reference; this page is the
fastest path to actually doing something.

---

## What you need


### Accounts

- **ZeroBias** at [`app.zerobias.com`](https://app.zerobias.com)
  if you want the live platform integrations below (MCPs, private NPM,
  `zb` CLI). External readers can browse all source without an account.
- **GitHub** at [`github.com`](https://github.com)

### Access Tokens

- **ZeroBias Platform Org ID and API Key**
  - [Login to ZeroBias](https://app.zerobias.com)
  - Click profile avatar (upper right)
  - Click "Create New API Key"
  - Note Organization ID and API Key (Keep these secure)
- **GitHub Personal Access Token (PAT)**
  - Create [New (Classic) PAT](https://github.com/settings/tokens/new) (read:packages)
  - Assign to environment variable `NPM_TOKEN` (or `READ_TOKEN`)

### Workstation Tools

Ensure the following tools are present on your workstation:

- **git [>= 2.34]**
- **Java [>= 21.0]**
- **Node [>= 22.20.0]**
- **Python [>= 3.12]**
- **Docker [>= 29.6.1]**
- [**Claude Code [>= 2.0]**](https://claude.com/claude-code)

This meta-repo is designed to be driven by an agent — one working tree
  spanning every public `zerobias-org` repo so the agent can read,
  search, and reason across them at once. Everything works without
  Claude Code, but most of the leverage is gone. 

### Docker Container

If you wish to run the ZeroBias tools in a Docker container, review [sandbox](./docs/Sandbox.md).

---

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

## NPM registry — set `ZB_TOKEN`

`@zerobias-org` and `@zerobias-com` packages live on a **private NPM
registry**. The reference config is committed at
[`.npmrc.example`](.npmrc.example) and each sub-repo already wires its
own `.npmrc` to it — **you don't write any config**. You only need to
export one env var:

```bash
export ZB_TOKEN=<your-private-registry-token>    # add to ~/.zshrc or ~/.bashrc
```

Get the token from your ZeroBias account. Without it, source code is
fully readable but `npm install` inside sub-repos will 401. Details and
CI patterns: [`docs/RegistrySetup.md`](docs/RegistrySetup.md).

## Install the MCPs (make Claude Code actually smart)

Two ZeroBias MCP servers transform Claude Code in this repo. Both use
the **same** ZeroBias API key + org ID — gather once.

**1. Get your credentials.** Log into
[`app.zerobias.com`](https://app.zerobias.com) → **Settings → API
Keys** → create one. Note the **API key** and the **org ID** shown
there.

**2. `zb-knowledge` (semantic code search across the whole org).**
Hosted HTTP MCP, no local install. Run once:

```bash
claude mcp add -s user \
  --transport http \
  --header "dana-org-id: <YOUR_ORG_ID>" \
  --header "Authorization: ApiKey <YOUR_API_KEY>" \
  zb-knowledge \
  https://api.app.zerobias.com/knowledge-mcp/mcp
```

`-s user` installs globally (recommended for your dev machine). Drop
the flag for project-only. **Don't** use `-s project` — that scope
writes a committed `.mcp.json` and would leak your key.

**3. `zb` (live platform operations — ~1,200 ops behind 3 meta-tools).**
Local stdio MCP — needs an npm install + a one-time `zb setup`:

```bash
npm install -g @zerobias-com/zerobias-mcp     # puts the `zb` binary on PATH
zb setup                                       # interactive: URL, API key, org ID, profile name
zb status                                      # verify connection
claude mcp add -s user zerobias zb            # register with Claude Code
```

`zb setup` writes credentials to `~/.config/mcp-zb/credentials.json`.
Same key + org ID as `zb-knowledge` — no double entry.

**Multi-org users — `zb` profiles.** `zb` reads one profile at a time
(scopes data access to that org). To work across orgs:

```bash
zb profile add prod-orgA      # prompts for orgA's URL / API key / org ID
zb profile add prod-orgB
zb profile use prod-orgA      # switch — no Claude Code restart needed
zb profile list               # see all profiles + which is active
```

`zb-knowledge` isn't profile-scoped — the indexed code is shared, the
org ID just proves access.

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
Where is the GitHub module's authentication implemented?
```
> Cross-repo semantic search via `zb-knowledge`. Returns file paths
> with line numbers.

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
