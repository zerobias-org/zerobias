# `.claude/` — Claude Code configuration

This directory holds Claude Code configuration that ships with the
meta-repo.

| File | Purpose |
|------|---------|
| `settings.json` | Project-wide Claude Code settings — committed to the repo and shared across contributors. Currently pre-approves common read-only and helper-script commands so they don't trigger a permission prompt every time. |
| `settings.local.json` | Per-developer overrides. Git-ignored. Edit freely. |

For the AI-workflow rules an agent should follow when working in this
repo, see [`../CLAUDE.md`](../CLAUDE.md). For per-sub-repo guidance,
look for a `CLAUDE.md` inside each sub-repo.

Reusable Claude skills for the `zerobias-org` ecosystem live in the
[`zb-dx`](https://github.com/zerobias-org/zb-dx) repo (already a
submodule under `./zb-dx/`).
