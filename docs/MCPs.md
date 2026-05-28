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

Both MCPs authenticate with the **same** ZeroBias credentials. Gather
them once and you can configure either or both.

1. **ZeroBias platform account** at
   [`app.zerobias.com`](https://app.zerobias.com).
2. **API key + org ID**, generated from **Settings → API Keys**. Note
   both values — you'll paste them into the setup commands below.
3. **Claude Code** v2.0 or newer
   ([install instructions](https://docs.claude.com/en/docs/claude-code)).

> **One-org caveat for `zb`.** The credentials you set up scope
> `zb`'s data access to **that single org**. If you work across
> multiple orgs, you'll add the others later as `zb` profiles (see
> [Multi-org access](#multi-org-access-zb-profiles) below). For
> `zb-knowledge` this caveat doesn't apply — the indexed code is
> shared and the org ID only proves access; one profile is enough.

### Scope: global vs project

Both MCPs can be registered at one of two scopes when you run
`claude mcp add`:

| Scope | Flag | Stored where | When to pick it |
|-------|------|--------------|-----------------|
| **Global (user)** | `-s user` | `~/.claude.json` | Personal dev machine, want the MCP in every project |
| **Project-only** | *(default — no flag, or `-s local`)* | Per-project Claude state, **not committed** | Per-project credentials, or you don't want this MCP in unrelated projects |

> Don't use `-s project` for these MCPs — that scope writes a
> committed `.mcp.json` and would publish credentials to the repo.

The commands below show the **global** form (`-s user`). Drop the
`-s user` flag to install project-only instead.

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

Add the server with the Claude Code CLI — replace `<YOUR_ORG_ID>` and
`<YOUR_API_KEY>` with the values from
[Shared prerequisites](#shared-prerequisites). Drop `-s user` to
install project-only instead of globally.

```bash
claude mcp add -s user \
  --transport http \
  --header "dana-org-id: <YOUR_ORG_ID>" \
  --header "Authorization: ApiKey <YOUR_API_KEY>" \
  zb-knowledge \
  https://api.app.zerobias.com/knowledge-mcp/mcp
```

Or, if you prefer to edit `~/.claude.json` directly:

```json
{
  "mcpServers": {
    "zb-knowledge": {
      "type": "http",
      "url": "https://api.app.zerobias.com/knowledge-mcp/mcp",
      "headers": {
        "dana-org-id": "<YOUR_ORG_ID>",
        "Authorization": "ApiKey <YOUR_API_KEY>"
      }
    }
  }
}
```

Restart Claude Code after saving.

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
`@zerobias-org` scopes (already covered for this meta-repo in
[`RegistrySetup.md`](RegistrySetup.md); set `ZB_TOKEN` in your env):

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

**3. Configure credentials** — interactive prompts for URL, API key,
org ID, profile name:

```bash
zb setup
```

Credentials are stored at `~/.config/mcp-zb/credentials.json` and
support multiple profiles (e.g. `default`, `staging`).

**4. Verify the connection:**

```bash
zb status
```

This authenticates against the platform and prints the active user
and organization.

**5. Register with Claude Code** (drop `-s user` for project-only):

```bash
claude mcp add -s user zerobias zb
```

The credentials configured by `zb setup` are read from
`~/.config/mcp-zb/credentials.json` at runtime — they're the same
ZeroBias API key + org ID used for `zb-knowledge`, so you don't need
to gather them twice.

### Useful CLI commands

```bash
zb setup              # configure credentials (first profile)
zb status             # verify connection
zb profile list       # list profiles
zb profile add <name> # add another profile (another org / environment)
zb profile use <name> # switch active profile
zb index              # force-regenerate the operation index
zb cache              # show index cache info
zb cache clear        # clear cached index
zb update             # check for and install SDK updates
```

### Multi-org access (zb profiles)

`zb` reads credentials from a single active profile at a time. The
profile chosen by `zb profile use` determines which org's data
`zerobias_execute` can see — there's no `org_id` argument on the
meta-tools.

Typical multi-org setup:

```bash
zb profile add prod-orgA      # prompts for orgA's URL / API key / org ID
zb profile add prod-orgB      # prompts for orgB's URL / API key / org ID
zb profile use prod-orgA      # work against orgA
# … later …
zb profile use prod-orgB      # switch to orgB
```

Switching profiles takes effect for new MCP calls — there's no need
to restart Claude Code, but a long-running session may still hold the
previous SDK connection. If a recent call returns unexpected data,
verify the active profile with `zb status`.

`zb-knowledge` is **not** affected by `zb profile`; its credentials
live in `~/.claude.json` and authenticate against the shared code
index, which doesn't differ by org.

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
- **`zb status` shows auth failure** — confirm the API key and org
  ID with `zb config`, regenerate the key from
  [`app.zerobias.com`](https://app.zerobias.com) if needed.
- **`/mcp` doesn't list zerobias** — confirm with
  `claude mcp list`; re-run `claude mcp add -s user zerobias zb` if
  it's missing, then restart Claude Code.
- **Operation not in the index** — the index regenerates when the SDK
  version changes. Force-refresh with `zb cache clear && zb index`.
