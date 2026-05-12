# Content Artifacts

ZeroBias treats compliance content as **versioned packages** published to
NPM. This document describes the artifact types, how they're packaged,
and the actual contribution mechanics — verified by reading each repo's
README and inspecting its layout (May 2026).

For the conceptual meaning of each artifact, see
[`Concepts.md`](Concepts.md).

---

## The shared content-monorepo pattern

Most content repos in `zerobias-org` follow a common pattern, but with
**different layout depths** and a few **stack-level differences** worth
knowing about up front.

### What's common across all of them

- Each is a **monorepo** that publishes many NPM packages from one git
  repo.
- Each artifact instance lives in its own subdirectory under a top-level
  content directory (`package/...` in most, `examples/...` in
  `benchmark/`, `packages/...` in `types/`+`util/`).
- The **artifact descriptor** is `index.yml` (not `package.yml`).
- Most repos provide a **scaffold script** under `scripts/` to create a
  new artifact (`createNew<Type>.sh`).
- Standard local validation flow:
  ```bash
  npm install
  npm shrinkwrap
  npm run validate
  ```
- Publishing is **automatic on PR merge** via GitHub Actions, using the
  org-wide `zbb-publish-reusable.yml` workflow that lives in
  [`devops`](https://github.com/zerobias-org/devops).

### What differs across them

| Repo | Layout depth | PR target | Build system | Notes |
|------|--------------|-----------|--------------|-------|
| `framework` | 3 (`package/<publisher>/<category>/<version>/`) | `dev` | Lerna+Nx | 33 publishers |
| `standard` | up to 4 (`package/<class>/<jurisdiction>/<publisher>/<version>/`) | `main` | Lerna+Nx | Currently only `law/us/nara/v19/` |
| `benchmark` | 4 under `examples/` (`examples/<vendor>/<suite>/<version>/`) — **not `package/`** | `dev` | Lerna+Nx | Most real benchmarks are private |
| `crosswalk` | 3 (`package/<publisher>/<category>/<version_id>/`) | `dev` | Lerna+Nx | 5 publishers |
| `compliance_feature` | 2 (`package/zerobias/<f_id>/`) — single-vendor | `main` | Lerna+Nx | ~hundreds of `f_<abbrev>` entries |
| `product` | 3 (`package/<vendor>/<edition>/<product>/`) | `dev` | Hybrid Lerna+Gradle | 120 vendors |
| `vendor` | 1 (`package/<vendor>/`) | `main` | **Migrating Lerna→Gradle** (`zb.content`). See `MIGRATION_STATUS.md`. |
| `suite` | 2 (`package/<vendor>/<edition>/`) | `main` | **Migrating Lerna→Gradle**. See `MIGRATION_STATUS.md`. |
| `segment` | 2 (`package/zerobias/<id>/`) — single-vendor | `main` | Lerna+Nx |
| `module` | 3 (`package/<vendor>/<product>/<api-type>/`) | varies | **Gradle+zbb** (no Lerna). See [`Modules.md`](Modules.md). |
| `collectorbot` | 3 (`package/<vendor>/<product>/<api-type>/`) | varies | **Gradle+zbb** |
| `pipeline` | 1 (`package/pipeline/`) — single package containing multiple YAML configs | `main` | Lerna+Nx |
| `kb` | **not a content monorepo** — Hugo static-site source | — | Hugo | See KB notes below |

> ⚠️ **PR target branch matters.** Several content repos require PRs
> against `dev`, not `main`. Always read the repo's README before
> opening a PR.

---

## Two stacks: Lerna+Nx vs Gradle+zbb

The content monorepos are mid-migration. **New work is moving onto a
Gradle plugin called `zb.content`**, distributed by the
[`util`](https://github.com/zerobias-org/util) repo as
`packages/zbb`. The migration status:

| State | Repos |
|-------|-------|
| **Lerna+Nx only** (legacy path still canonical) | `framework`, `standard`, `benchmark`, `crosswalk`, `compliance_feature`, `segment`, `pipeline` |
| **Hybrid** (both build systems present, lerna still works) | `product` |
| **Mid-migration** (lerna→gradle in flight, see each repo's `MIGRATION_STATUS.md`) | `vendor`, `suite` |
| **Gradle+zbb only** (lerna removed or never used) | `module`, `collectorbot`, `schema` |

For Lerna repos, the contribution loop is the `npm install / shrinkwrap /
validate` flow above. For Gradle repos:

```bash
./gradlew :<artifact>:gate    # full validation for one sub-package
./gradlew gate                # full validation for the whole repo
```

`zbb` (the gradle plugin) handles validation, schema checking, version
bumping, and the publish step uniformly across these repos.

---

## Typical "add a new artifact" flow (Lerna repos)

The exact commands are in each repo's `README.md`. The general loop:

```bash
cd <content-repo>                # e.g. cd framework

# branch off the right base — check the README!
git checkout -b feat/add-<artifact-id> origin/dev   # dev for framework/benchmark/crosswalk
# or  ...                                            origin/main for others

# 1. Scaffold
sh scripts/createNewFramework.sh <publisher> <category> <version>
# (each content repo has its own scaffold script — same shape, different name)

# 2. Edit the generated index.yml + content files
# ...

# 3. Validate locally
npm install
npm shrinkwrap
npm run validate

# 4. Commit
git add .
git commit -m "feat: add <Artifact name>"
git push origin feat/add-<artifact-id>

# 5. Open PR against the right base branch on the sub-repo
```

After merge, GitHub Actions (via `devops/.github/workflows/
zbb-publish-reusable.yml`) bumps the version, builds, and publishes to
NPM.

---

## Typical "add a new artifact" flow (Gradle repos)

```bash
cd <content-repo>                # e.g. cd vendor

git checkout -b feat/add-<artifact-id>

# Use the repo's scaffolding (often documented under .claude/skills/)
# Edit index.yml + assets

./gradlew :<artifact-id>:gate    # full validation for the sub-package
git add . && git commit -m "feat: ..."
git push origin feat/add-<artifact-id>
```

The gradle path replaces `npm install/shrinkwrap/validate` entirely.

---

## Per-artifact descriptors

Every artifact has an `index.yml` that declares its identity, version,
and content. Some repos add companions:

| Repo | Per-artifact files |
|------|-------------------|
| `framework` | `index.yml`, `elements/`, `baselines/` |
| `standard` | `index.yml`, `elements/`, `elements.yml`, `versions/` |
| `benchmark` | `index.yml`, `elements/`, `baselines/` |
| `crosswalk` | `index.yml`, `elements/` |
| `compliance_feature` | `index.yml` (data-only — no source code) |
| `product` | `index.yml`, `catalog.yml`, `logo.svg` |
| `vendor` | `index.yml`, `logo.svg` |
| `suite` | `index.yml`, `logo.svg` |
| `segment` | `index.yml`, `logo.svg` |
| `module` | `api.yml`, `connectionProfile.yml`, `connectionState.yml`, `src/`, `test/` |

Companion `package.json`, `CHANGELOG.md`, `npm-shrinkwrap.json`, and
`.npmrc` are added by the scaffold script.

---

## Cross-artifact references

Artifacts can refer to each other by `(packageName, version)`. The
dataloader (closed source) resolves these into in-memory links at
ingest time.

| Reference | Direction |
|-----------|-----------|
| Framework Requirement → Standard Element | A Framework Requirement cites the formal Standard text it's based on |
| Benchmark → Framework Requirement | A Benchmark test case satisfies one or more Requirements |
| Benchmark → Product | A Benchmark test case targets a specific Product (or Suite) |
| Crosswalk → Framework | A Crosswalk maps between two Frameworks |
| Compliance Feature → Framework Requirement | A Product's Compliance Feature satisfies certain Requirements |
| Product → Vendor | A Product is offered by a Vendor |
| Product → Segment | A Product is classified by Segment taxonomy |
| Suite → Product | A Suite contains multiple Products |

If you're adding a Product/Vendor/Suite that doesn't yet exist in the
catalog, **add the catalog entries first** — otherwise references won't
resolve at validation time.

---

## Special cases

### `kb` is a Hugo site, not a content monorepo

[`kb`](https://github.com/zerobias-org/kb) is the source for a Hugo
static site (theme: `doks`). Its `config.toml`, `themes/doks/`, and
`actions/generate-kb/` are the operative pieces. There is **no
`package/` directory and no Lerna setup despite some lingering scripts
referencing them**. Contribute Hugo markdown directly; don't try to
follow the index.yml/npm-package pattern.

The repo has no README and a placeholder `CLAUDE.md`. Coordinate with
maintainers before substantial changes.

### `pipeline` is a single tiny package

[`pipeline`](https://github.com/zerobias-org/pipeline) currently contains
one sub-package (`package/pipeline/`) with three YAML files:
`agentskills.yml`, `hl7-fhir.yml`, `mcpservers.yml`. It is **not** a
"wire modules and collectors for scheduled execution" config repo (the
earlier draft of this doc claimed that — it was wrong). Treat it as a
small data-source/agent-config registry until further documentation
exists.

### `framework_test` is an actual GitHub fork

[`framework_test`](https://github.com/zerobias-org/framework_test) is a
true GitHub fork of `framework` (`fork: true`). It's used to test GitHub
Actions / PR workflows. **Don't accidentally PR compliance content
here** — open PRs against `framework` instead.

### `schema/CONTRIBUTING.md` is the gold standard

[`schema/CONTRIBUTING.md`](https://github.com/zerobias-org/schema/blob/main/CONTRIBUTING.md)
is the most detailed contribution doc in the org. It walks through the
three validation layers — local validate, local dataloader against a
Supabase scratch DB, CI dataloader against a Neon branch — and the
`approved` PR-label gate. Read it before contributing schemas.

---

## What gets generated automatically

You don't need to manage:

- Version bumps (handled by the publish workflow)
- NPM publishing (handled by `zbb-publish-reusable.yml` in `devops`)
- `npm-shrinkwrap.json` regeneration in CI (you generate it locally
  before opening the PR, then CI keeps it in sync)
- Cross-reference resolution (the closed-source dataloader does this
  on ingest)

You **do** need to manage:

- The content of `index.yml` (your edits)
- Local validation passing before you open the PR
- Targeting the right PR base branch (`dev` vs `main` — see table at top)
