# Local Development

Several `zerobias-org` repos depend on each other at the NPM-package level
— for example, many repos consume types from
[`types`](https://github.com/zerobias-org/types) or utilities from
[`util`](https://github.com/zerobias-org/util). When you're modifying a
dependency *locally* and want a consumer to pick up your changes without
publishing first, you need `npm link`.

This page is the survival guide for that.

---

## The problem

You're editing `types/` locally. A separate package — say `module/` —
declares `@zerobias-org/types` as a dependency in its `package.json`.
By default `module/` resolves that dependency from its installed
`node_modules/` (which holds the published version). Your local edits
in `types/` don't reach `module/`.

`npm link` solves this by creating a symlink from the consumer's
`node_modules/@zerobias-org/types` to your local `types/` build output.

---

## The quick pattern

For a single dependency, in two terminals (or just two `cd`s):

```bash
# 1. In the dependency, build and "publish" locally
cd types
npm run build
npm link

# 2. In the consumer, link against the local build
cd ../module
npm link @zerobias-org/types
npm run build
```

After this, anything you change in `types/` is visible to `module/` —
**but you must rebuild `types/`** for the change to take effect (linked
packages still serve their built output, not their source).

---

## Chained dependencies

The real complexity is **transitive** dependencies. Suppose:

```
types  ──used by──▶  util  ──used by──▶  module
```

To make a change in `types/` flow all the way to `module/`, you need to:

```bash
# 1. types: build + link
cd types
npm run build
npm link

# 2. util: link types, build, then link util itself
cd ../util
npm link @zerobias-org/types
npm run build
npm link

# 3. module: link both, then build
cd ../module
npm link @zerobias-org/types
npm link @zerobias-org/util
npm run build
```

**Rule of thumb:** every package in the chain needs to (a) link the
versions it imports and (b) be linked itself if anything further down
the chain consumes it.

---

## When changes "aren't taking effect"

The classic symptom: you edit a file in a dependency, you rebuild the
consumer, nothing changes. Run through this checklist:

1. **Did you rebuild the dependency?** Linking exposes the *build
   output*. Source changes don't propagate without `npm run build` in
   the dependency.
2. **Is the link actually there?** From the consumer, check:
   ```bash
   ls -la node_modules/@zerobias-org/<pkg>
   ```
   If it's not a symlink, the link is broken — re-run `npm link <pkg>`.
3. **Did `npm install` overwrite the link?** Re-running `npm install` in
   the consumer can replace the symlink with the published version.
   Re-link after any install.
4. **Wrong workspace?** Some sub-repos are Lerna/Nx workspaces with
   internal cross-links. Use the repo's own `npm run reset` or
   `npm run bootstrap` script when in doubt — it's usually correct for
   intra-repo linking.

---

## Unlinking

When you're done and want to go back to the published version:

```bash
cd <consumer>
npm unlink --no-save @zerobias-org/<pkg>
npm install
```

Then in the dependency, optionally:

```bash
cd <dependency>
npm unlink
```

---

## Watch mode

If you're iterating fast on a dependency, run its build in watch mode
so you don't have to rebuild manually:

```bash
cd types
npm run build:watch       # if the repo defines it
# or
npx tsc --watch           # generic TypeScript fallback
```

The consumer will see updated build output on the next time it loads
the module (most apps require a restart; library consumers will pick up
on next compile).

---

## When *not* to use npm link

- **CI runs.** Linking is a local-dev technique. CI should always
  install from the registry. Don't commit `package.json` changes that
  reference local paths.
- **One-off scripts.** If you just want to test a function from one repo
  against fixtures from another, sometimes copying the function into a
  scratch file is faster than setting up a full link chain.
- **When the consumer is in a different runtime.** Linking only works
  for the JavaScript/TypeScript dependency graph. If you're testing a
  module from Python via a generated SDK, you need to regenerate and
  install — linking won't help.

---

## Per-repo specifics

Each sub-repo's `README.md` and `CLAUDE.md` may add repo-specific
caveats — e.g. some repos use Lerna and have a `npm run reset` that
handles intra-repo links automatically; others are simpler and just
need a plain `npm install`. Read the sub-repo's own docs first.
