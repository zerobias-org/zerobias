# NPM Registry Setup

Reading source code in this meta-repo is friction-free. **Installing
dependencies inside any sub-repo is not** — `@zerobias-org` packages
live on a private NPM registry that requires authentication.

This page explains the registry topology, what token you need, and how
to configure it.

---

## The registry topology

All Zerobias-related NPM scopes are served by **one private registry,
with one token**:

| Scope | Registry | Auth? |
|-------|----------|-------|
| `@zerobias-org` | `https://pkg.zerobias.org/` | **Yes — `ZB_TOKEN`** |
| `@zerobias-com` | `https://pkg.zerobias.org/` | **Yes — `ZB_TOKEN`** |
| `@auditmation` | `https://pkg.zerobias.org/` | **Yes — `ZB_TOKEN`** |
| `@auditlogic` | `https://pkg.zerobias.org/` | **Yes — `ZB_TOKEN`** |
| public `npm` | `https://registry.npmjs.org/` | No — anonymous reads work |
| **gradle plugins** `zb.*` (Maven) | `https://maven.pkg.github.com/zerobias-org/util` | **Yes — GitHub token with `read:packages`** (see [below](#github-packages-maven-gradle-plugins)) |

Key facts:

- **`pkg.zerobias.org` returns 401 to anonymous requests.** You cannot
  read or install scoped packages without a valid `ZB_TOKEN`.
- **`@zerobias-org/*` packages are not mirrored to public npmjs.com.**
  A `curl https://registry.npmjs.org/@zerobias-org/vendor-atlassian`
  returns 404.
- The repos themselves are public on GitHub. The *packages they
  produce and consume* are private.
- A single `ZB_TOKEN` resolves all four Zerobias **npm** scopes. Older
  `.npmrc` files in some sub-repos route the closed-source scopes to
  `npm.pkg.github.com`; for npm those are legacy and can be ignored in
  favor of the single-registry config in
  [`.npmrc.example`](../.npmrc.example).
- **Gradle is the exception.** Every gradle-driven repo resolves its
  `zb.*` build plugins from GitHub Packages **Maven**, which needs a
  second, personal credential — a GitHub token with `read:packages`.
  `ZB_TOKEN` cannot stand in for it. Details in
  [GitHub Packages Maven](#github-packages-maven-gradle-plugins).

---

## What this means for contributors

| You are… | You can… | You cannot… |
|----------|----------|-------------|
| A reader without a `ZB_TOKEN` | Read all source, fork repos, read documentation | Run `npm install`, build any sub-repo, publish |
| A reader with `ZB_TOKEN` | Read, install, build, run validation locally | Publish (publishing is automated by CI) |
| A maintainer | Everything | — |

If you're approaching this project as an outside contributor: be aware
that the typical "clone, install, run tests" loop **will not work** for
you out of the box. You can still:

- Read the source.
- Open issues against sub-repos describing what you'd contribute.
- Submit PRs by editing files on GitHub directly (limited to the cases
  where you don't need a working build to validate your change — most
  content-artifact additions need local validation).
- Contact the maintainers to request a token for legitimate
  contribution.

---

## Setting up `ZB_TOKEN`

### Option 1: per-meta-repo `.npmrc`

```bash
cp .npmrc.example .npmrc          # .npmrc is git-ignored
export ZB_TOKEN='your-token'
```

`npm` will substitute the env var at install time.

### Option 2: user-level `.npmrc` (required for global installs)

If you work across many machines/projects, put the same content into
`$HOME/.npmrc` instead. npm merges per-project and user-level configs
for project commands — and **global installs read only this file** (see
[Global CLI installs](#global-cli-installs) below).
`./scripts/setup-org-credentials.sh` writes these scopes into
`~/.npmrc` for you.

```bash
cp .npmrc.example ~/.npmrc
export ZB_TOKEN='your-token'
```

### Option 3: tokens in CI

In GitHub Actions (and the reusable workflows under
[`devops`](https://github.com/zerobias-org/devops)), `ZB_TOKEN` comes
from secrets — it's injected as an env var at runtime. You don't
manage `.npmrc` directly in CI; the workflow scripts do.

---

## Global CLI installs

The ZeroBias CLIs are installed **globally** (`npm i -g`), and every one
of them is a private package on `pkg.zerobias.org` — none exist on
public npm, so always use the full scoped name:

| Package (`npm i -g …@latest`) | Binary | Needed for |
|-------------------------------|--------|------------|
| `@zerobias-org/zbb` | `zbb` | every content repo: gates, publish, slots, stacks |
| `@zerobias-com/zerobias-mcp` | `zb` | the `zb` MCP server (installed by `setup-org-credentials.sh`) |
| `@zerobias-com/platform-dataloader` | `dataloader`, `datasync` | the gate's local load step in `schema/`, `product/`, `vendor/`, `suite/`, … |
| `@zerobias-com/hub-node` | — (library) | `zbb testHub` in `module/` only |

Two npm facts decide how these installs authenticate:

1. **`npm i -g` ignores the project `.npmrc`.** In global mode npm
   (≥ 7) skips the per-project file entirely and reads only
   `~/.npmrc` (plus the environment). The sub-repo `.npmrc` files —
   even the legacy ones that route `@zerobias-com` to GitHub Packages —
   never affect a `-g` install, and a copy of `.npmrc.example` inside a
   repo is not enough on its own. The `pkg.zerobias.org` scopes must be
   in **`~/.npmrc`**.
2. **`${ZB_TOKEN}` is interpolated at npm run time**, so the variable
   must be present in the shell running `npm`. After
   `setup-org-credentials.sh` the token lives in your zbb slot, not in
   your shell profile — a plain terminal has no `ZB_TOKEN` and the
   install fails with 401 / `E404`.

So the canonical form for any global install or update is through the
slot, or with the token passed inline:

```bash
zbb --slot <slot> --stack dev exec npm i -g @zerobias-com/platform-dataloader@latest
# or, without a slot (first-time bootstrap, CI images, throwaway shells):
ZB_TOKEN='<prod registry key>' npm i -g @zerobias-org/zbb@latest
```

The one unavoidable inline case is the **very first `@zerobias-org/zbb`
install on a fresh machine**: the setup script needs `zbb`, and `zbb` is
what later holds the token. Bootstrap order is in
[`QUICKSTART.md`](../QUICKSTART.md#install-zbb).

Freshness matters: the CLIs move fast and version skew fails in confusing
ways, so re-run the same `@latest` command whenever a sub-repo's
prerequisites check reports the installed version behind the registry.
Honor any version a sub-repo pins in its docs instead of `@latest`.

---

## GitHub Packages Maven (gradle plugins)

`zbb gate`, `zbb publish`, and any `./gradlew` in a content or code repo
first resolve the `zb.*` gradle plugins (`build-tools`) from GitHub
Packages Maven. Each repo's `settings.gradle.kts` reads the credential
from the shell that runs gradle:

```
mavenLocal()                                       ← dev machines with a locally-published build-tools are silently exempt
maven.pkg.github.com/zerobias-org/util             ← everyone else
    username = GITHUB_ACTOR ?: "zerobias-org"
    password = READ_TOKEN ?: NPM_TOKEN ?: GITHUB_TOKEN ?: ""     first SET var wins
```

**GitHub Packages Maven requires authentication even for public
reads.** Without a token every gradle invocation fails while resolving
the plugins (HTTP 401 from `maven.pkg.github.com`). Verified
2026-09-08 against `zerobias-org/util`:

| Credential | Scopes | Result |
|------------|--------|--------|
| anonymous | — | 401 |
| `gh auth token` **without** `read:packages` | gist, read:org, repo, workflow | 401 |
| classic PAT (`ghp_…`) | `read:packages` only | 200 |

So the scope is what matters. Set it up once, in your shell profile —
it is personal, and it is **not** stored in the zbb slot (the slot
holds only ZeroBias keys; `zbb exec` passes your shell environment
through, so a profile export reaches slot-launched Claude sessions and
gates alike):

```bash
# Option A — classic PAT with read:packages (verified):
#   github.com → Settings → Developer settings → Personal access tokens (classic)
export GITHUB_TOKEN='<classic PAT with read:packages>'

# Option B — reuse the gh CLI login (scope-gated; add the scope, then export):
gh auth refresh -s read:packages
export GITHUB_TOKEN="$(gh auth token)"
```

Check it (200 = good, 401 = missing/expired/wrong scope):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u "zerobias-org:$GITHUB_TOKEN" \
  https://maven.pkg.github.com/zerobias-org/util/com/zerobias/build-tools/maven-metadata.xml
```

Gotchas:

- gradle takes the **first set** variable in `READ_TOKEN`, `NPM_TOKEN`,
  `GITHUB_TOKEN` order. A stale `READ_TOKEN` or `NPM_TOKEN` export
  shadows a valid `GITHUB_TOKEN` — and an invalid `GITHUB_TOKEN` env var
  shadows a valid `gh` keyring login (`gh auth status` shows which one
  is active).
- `./scripts/setup-org-credentials.sh` **reports** this credential
  (probing the URL above with whichever variable gradle would use) but
  does not manage it; fix the shell export yourself and re-run.
- A machine that built `build-tools` locally (`publishToMavenLocal`) never
  hits the registry, so it can look green while a clean clone fails —
  the sub-repo `prerequisites` skills flag this exemption.

---

## Verifying your setup

From any sub-repo with `.npmrc` referencing `pkg.zerobias.org`:

```bash
npm view @zerobias-org/util-types --registry https://pkg.zerobias.org/

# If you get JSON back: your token works.
# If you get 401 / "unauthorized": ZB_TOKEN is missing or invalid.
```

For the global-install path specifically, run the check from `$HOME`
with `-g` so only `~/.npmrc` is consulted:

```bash
cd ~ && npm config get @zerobias-com:registry -g   # → https://pkg.zerobias.org
```

---

## Security notes

- **Never commit a real token** to `.npmrc`. The `.gitignore` in this
  meta-repo excludes `.npmrc` precisely for this reason; only
  `.npmrc.example` (which uses `${ZB_TOKEN}` placeholder) is tracked.
- If you accidentally commit a token, revoke it immediately and rotate.
- For CI, always use repo or org-level secrets — not committed files.
