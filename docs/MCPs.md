# MCP servers for Claude Code

Two ZeroBias MCP (Model Context Protocol) servers integrate with
[Claude Code](https://claude.com/claude-code) and other MCP-compatible
agents. Both are optional but make agent work in this meta-repo
significantly faster.

| MCP | What it does | When to use it |
|-----|--------------|----------------|
| **`zb-knowledge`** | Semantic code search across every indexed ZeroBias repo + dependency / impact analysis | "Where is X implemented?", "Which repos use this function?", "What does this package version look like?" |
| **`zb`** | Dynamic access to every ZeroBias platform API operation (~1,200 ops via 3 meta-tools) | "List the tasks in this org", "Run a Hub operation against the live platform" |

> ⚠️ Public / external contributors without a ZeroBias account cannot
> use these MCPs. The source code in every sub-repo is still readable
> and editable without them; they just speed up cross-repo discovery
> and live platform calls for authenticated users.

---

## Shared prerequisites

> **Recommended path — skip the manual steps below.** Run
> `./scripts/setup-org-credentials.sh` (present in this meta-repo and
> every content repo): it gathers your keys once, stores them in a
> **zbb slot**, wires `~/.npmrc` and the zb profile, and verifies
> everything. Then launch claude through the slot
> (`--launch`, or `zbb --slot <slot> exec claude`) and both MCPs pick
> up that identity. The sections below explain what the script sets
> up, for understanding and troubleshooting.

Both MCPs authenticate with the **same** ZeroBias credentials. Gather
them once and you can configure either or both.

1. **ZeroBias platform account** at
   [`app.zerobias.com`](https://app.zerobias.com).
2. **API key + org ID**, generated from **Settings → API Keys** of
   the TARGET environment (keys are per-environment).
3. **Claude Code** v2.0 or newer
   ([install instructions](https://docs.claude.com/en/docs/claude-code)).

> **One-org caveat for `zb`.** The credentials you set up scope
> `zb`'s data access to **that single org**. If you work across
> multiple orgs, you'll add the others later as `zb` profiles (see
> [Multi-org access](#multi-org-access-zb-profiles) below). For
> `zb-knowledge` this caveat doesn't apply — the indexed code is
> shared and the org ID only proves access; one profile is enough.

### Scope: repo templates first, user scope only as a template

**Inside the zerobias repos you don't register anything** — each repo
ships a committed `.mcp.json` whose entries contain only `${VAR}`
templates (no secrets):

```json
{
  "mcpServers": {
    "zb-knowledge": {
      "type": "http",
      "url": "${KNOWLEDGE_MCP_URL:-https://api.app.zerobias.com/knowledge-mcp/mcp}",
      "headers": {
        "dana-org-id": "${ZB_ORG_ID}",
        "Authorization": "ApiKey ${ZB_API_KEY}"
      }
    },
    "zb": { "command": "zb" }
  }
}
```

The variables resolve from the environment claude was **launched**
with — which is why sessions are launched through a zbb slot. If you
want the MCPs available in directories outside these repos, add a
**user-scope** registration to `~/.claude.json` — but it MUST use the
same template form (paste the JSON above under `mcpServers`).

> ⚠️ **Never register with literal keys** (`claude mcp add … --header
> "Authorization: ApiKey <real-key>"`). A baked literal key is
> resolved instead of your slot's identity: sessions still connect,
> but as whatever org the pasted key belongs to — silently. This
> exact failure mode (a user-scope registration pinning every session
> to a stale dev org) is why the template rule exists.

Precedence when the same server name exists in several scopes:
local (per-project state) > project (`.mcp.json`) > user
(`~/.claude.json`). A stale local-scope registration shadows the
repo's `.mcp.json` — remove it with `claude mcp remove <name>`.

---

## `zb-knowledge` — semantic code search

Exposes the ZeroBias code knowledge base over HTTP-transport MCP,
authenticated via Dana (the ZeroBias auth service). No local install
or local credentials beyond the API key are needed — Claude Code calls
the hosted endpoint directly.

### Tools

| Tool | Purpose |
|------|---------|
| `health_check` | Verify connectivity to the index and embedding provider |
| `search_code` | Semantic search across all indexed repos |
| `get_file` | Retrieve a specific file from the knowledge base |
| `list_repos` | List every indexed repository |
| `get_affected_files` | Transitive impact of changing a file |
| `get_dependency_chain` | Trace upstream dependencies for a symbol |
| `check_package_versions` | Look up published versions of a ZeroBias package |

### Setup

**Nothing to do inside the zerobias repos** — the committed
`.mcp.json` already declares `zb-knowledge` with `${VAR}` templates.
Set up your slot with `./scripts/setup-org-credentials.sh`, then
launch claude through it (`--launch`, or
`zbb --slot <slot> exec claude`); the headers resolve from the slot's
`ZB_ORG_ID` / `ZB_API_KEY`, and `KNOWLEDGE_MCP_URL` selects the
per-env endpoint (`https://api.<env-host>/knowledge-mcp/mcp`; the
template's default is prod — `--launch` exports the right one for
non-prod targets automatically).

For coverage outside these repos, add the template form to
`~/.claude.json` under `mcpServers` (see
[Scope](#scope-repo-templates-first-user-scope-only-as-a-template) —
never literal keys):

```json
{
  "mcpServers": {
    "zb-knowledge": {
      "type": "http",
      "url": "${KNOWLEDGE_MCP_URL:-https://api.app.zerobias.com/knowledge-mcp/mcp}",
      "headers": {
        "dana-org-id": "${ZB_ORG_ID}",
        "Authorization": "ApiKey ${ZB_API_KEY}"
      }
    }
  }
}
```

Restart Claude Code after saving — env templates are resolved once at
session startup, so the identity is whatever environment you launch
claude with.

### Verify

In a Claude Code session, ask:

> List the repositories indexed in the ZeroBias Knowledge MCP.

The agent should call `list_repos` and return the indexed repos. To
test connectivity without listing data, ask it to run `health_check`.

### Troubleshooting

- **`401 Missing dana-org-id or Authorization header`** — both headers
  must be present. Re-check the `--header` flags or the JSON config.
- **`401 Invalid credentials`** — the API key is malformed, revoked,
  or doesn't belong to the org. Regenerate from your account settings
  and confirm both values match.
- **`error: missing required argument 'name'` when adding the server**
  — the positional arguments are after `--header`. See the ordering
  note in [Setup](#setup) above.
- **`Failed to connect — MCP endpoint not found`** — misleading; the
  URL is usually fine. A wrong `dana-org-id` returns a `404` that
  Claude Code renders as a missing endpoint. Confirm by calling the
  endpoint directly — a bad org ID answers with
  `{"key":"err.no.such.object","type":"Org","id":"<the id you sent>"}`,
  which names the real problem:

  ```bash
  curl -sS -X POST https://api.app.zerobias.com/knowledge-mcp/mcp \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "dana-org-id: <YOUR_ORG_ID>" \
    -H "Authorization: ApiKey <YOUR_API_KEY>" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}'
  ```

  A working pair returns `"serverInfo":{"name":"ZeroBias Knowledge MCP Server"}`.
- **MCP server not listed in `/mcp`** — the entry must be under
  `mcpServers` in `~/.claude.json`, `type` must be `http`, URL must
  match exactly. Restart Claude Code after edits.
- **Tools return no results** — verify the repo you expect is indexed
  by calling `list_repos` first. Newly added repos may take time to
  appear in the index.

The authoritative source for this setup is the
[`kb265`](https://github.com/zerobias-org/kb/tree/main/package/kb265-claude-code-mcp-setup)
KB article in the `kb/` sub-repo.

---

## `zb` — ZeroBias platform operations

Wraps the entire ZeroBias platform SDK (~1,200 operations) behind
three meta-tools, so an agent can discover and call any platform
operation without each one consuming a separate tool slot.

### Tools

| Tool | Purpose |
|------|---------|
| `zerobias_search` | Discover operations by keyword (e.g. "audit") |
| `zerobias_describe` | Fetch the parameter schema for a specific operation |
| `zerobias_execute` | Run an operation, optionally with response slimming |

The `zerobias_execute` description includes a compact index of every
operation, auto-generated from the installed SDK version, so the
agent can plan calls without first listing them.

### Setup

`zb` is published as an npm package (`@zerobias-com/zerobias-mcp`) and
runs as a stdio MCP server.

**1. Configure your `.npmrc`** for the `@zerobias-com` and
`@zerobias-org` scopes (`setup-org-credentials.sh` writes this;
`ZB_TOKEN` comes from the slot at run time — background in
[`RegistrySetup.md`](RegistrySetup.md)):

```ini
@zerobias-com:registry=https://pkg.zerobias.org
@zerobias-org:registry=https://pkg.zerobias.org
//pkg.zerobias.org/:_authToken=${ZB_TOKEN}
```

**2. Install globally:**

```bash
npm install -g @zerobias-com/zerobias-mcp
```

This installs the `zb` binary on your `$PATH`.

**3. Configure credentials — the script does this.**
`./scripts/setup-org-credentials.sh` writes the `env` profile into
`~/.config/mcp-zb/credentials.json` holding **`${VAR}` placeholder
strings** (`${ZB_PLATFORM_URL}` / `${ZB_ORG_ID}` / `${ZB_API_KEY}`)
and activates it. zb resolves the placeholders from its process env
at load time — so the identity is whatever slot you launch claude
through. Manual equivalent: `zb setup env` interactively, entering
the literal placeholder strings at each prompt (the prompts accept
`${VAR_NAME}`; don't pipe them in — piped setup exits 0 without
saving).

**4. Verify the connection** — inject the slot env, since a bare
shell has no creds by design:

```bash
zbb --slot <slot> exec zb status
```

This authenticates against the platform and prints the active user
and organization. A bare `zb status` reporting
`(ZB_API_KEY: NOT SET)` is the expected loud failure, not a bug.

**5. Register with Claude Code** — nothing to do inside the zerobias
repos (the committed `.mcp.json` declares `zb`). For other
directories:

```bash
claude mcp add -s user zb zb
```

No env stanza and no keys in the registration: zb inherits the
launching environment and resolves the profile placeholders from it.

### Useful CLI commands

```bash
zb setup              # configure credentials (script does this — see step 3)
zbb --slot <slot> exec zb status   # verify connection (slot env injected)
zb profile list       # list profiles ('env' with ${VAR} placeholders = active)
zb profile add <name> # add a literal profile (legacy key storage)
zb profile use <name> # switch active profile (avoid — pins every session)
zb index              # force-regenerate the operation index
zb cache              # show index cache info
zb cache clear        # clear cached index
zb update             # check for and install SDK updates
```

### Multi-org access (zbb slots)

**One slot per org/env, chosen at launch time** — this is the
mechanism, for both MCPs at once. `zerobias_execute` has no `org_id`
argument; the session's whole identity comes from the environment
claude was launched with:

```bash
./scripts/setup-org-credentials.sh         # run once per target (prompts env + org)
zbb slot list                              # see your slots (<env>-<org-prefix>)
zbb --slot prod-74fc0422 exec claude       # session as org A on prod
zbb --slot qa-57c741cf   exec claude       # separate session as org B on qa
```

Switching identity means **restarting claude through the other
slot** — env templates and the zb profile placeholders are resolved
once at session startup, so a running session never changes org
mid-flight (a feature: no accidental cross-org calls).

`zb profile use` is NOT the switching mechanism anymore: the active
`env` profile deliberately contains `${VAR}` placeholders that follow
the launch environment. Legacy literal profiles (`dev`, `qa`, …) may
still exist in `~/.config/mcp-zb/credentials.json` as key storage,
but activating one pins every session on this machine to that org —
prefer slots.

### Response slimming

`zerobias_execute` responses are slimmed by default — any object with
an `id` field is reduced to `{id, name, type}` to keep agent context
small. Override via the `slim` parameter:

```javascript
// Full response (no slimming)
zerobias_execute({ path: "platform.Task.list", params: {...}, slim: false })

// Only keep specific fields
zerobias_execute({ path: "platform.Task.list", params: {...},
                   slim: { keepOnly: ["id", "name", "status"] } })

// Auto-slim but keep one field full
zerobias_execute({ path: "platform.Task.list", params: {...},
                   slim: { keepFull: ["workflow"] } })

// Auto-slim and remove some fields entirely
zerobias_execute({ path: "platform.Task.list", params: {...},
                   slim: { remove: ["workflow", "nextTransitions"] } })
```

### Architecture (in one diagram)

```
User asks Claude Code something
        ↓
Claude sees the compact operation index in zerobias_execute's description
        ↓
Claude identifies the operation (e.g. "platform.Task.list")
        ↓
(optional) zerobias_describe() for parameter shape
        ↓
zerobias_execute("platform.Task.list", { status: "todo" })
        ↓
MCP routes to: sdk.platform.getTaskApi().list(...)
        ↓
Slimmed result returned to Claude
```

### Troubleshooting

- **`zb` not found** — make sure `npm install -g` succeeded and your
  global npm `bin` is on `$PATH`.
- **`zb status` shows `(ZB_API_KEY: NOT SET)` / MISSING_ENV_VAR** —
  expected in a bare shell: the `env` profile resolves from the
  launching environment. Run it through the slot:
  `zbb --slot <slot> exec zb status`. A real auth failure under the
  slot means the slot's key is dead — re-run
  `./scripts/setup-org-credentials.sh`.
- **`/mcp` doesn't list zb** — inside the zerobias repos the
  committed `.mcp.json` declares it (check the one-time trust
  prompt wasn't declined); elsewhere confirm with `claude mcp list`
  and re-run `claude mcp add -s user zb zb`, then restart Claude
  Code.
- **Operation not in the index** — the index regenerates when the SDK
  version changes. Force-refresh with `zb cache clear && zb index`.
