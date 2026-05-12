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

Key facts:

- **`pkg.zerobias.org` returns 401 to anonymous requests.** You cannot
  read or install scoped packages without a valid `ZB_TOKEN`.
- **`@zerobias-org/*` packages are not mirrored to public npmjs.com.**
  A `curl https://registry.npmjs.org/@zerobias-org/vendor-atlassian`
  returns 404.
- The repos themselves are public on GitHub. The *packages they
  produce and consume* are private.
- A single `ZB_TOKEN` resolves all four Zerobias scopes — you don't
  need a separate GitHub Packages token. Older `.npmrc` files in some
  sub-repos route the closed-source scopes to `npm.pkg.github.com`;
  those are legacy and can be ignored in favor of the single-registry
  config in [`.npmrc.example`](../.npmrc.example).

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

### Option 2: user-level `.npmrc`

If you work across many machines/projects, put the same content into
`$HOME/.npmrc` instead. npm merges per-project and user-level configs.

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

## Verifying your setup

From any sub-repo with `.npmrc` referencing `pkg.zerobias.org`:

```bash
npm view @zerobias-org/util-types --registry https://pkg.zerobias.org/

# If you get JSON back: your token works.
# If you get 401 / "unauthorized": ZB_TOKEN is missing or invalid.
```

---

## Security notes

- **Never commit a real token** to `.npmrc`. The `.gitignore` in this
  meta-repo excludes `.npmrc` precisely for this reason; only
  `.npmrc.example` (which uses `${ZB_TOKEN}` placeholder) is tracked.
- If you accidentally commit a token, revoke it immediately and rotate.
- For CI, always use repo or org-level secrets — not committed files.
