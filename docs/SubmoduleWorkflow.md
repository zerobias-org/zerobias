# Submodule Workflow

This meta-repo uses **git submodules** to embed every public
`zerobias-org` repository under a single working tree. Submodules are
powerful, but they have sharp edges. This page is the survival guide.

---

## Mental model

Two key facts about git submodules:

1. **Each subdirectory is an independent git repository.** It has its
   own remote, its own branches, its own history. Changes you make
   inside it belong to *that repo*, not to the meta-repo.
2. **The meta-repo only stores a pointer.** For each submodule it
   records "this submodule should be at commit `<sha>`". When you run
   `git submodule update`, git checks out that exact SHA — possibly in
   detached-HEAD state.

That second point is the source of most submodule pain. Internalize it
before you start making changes.

---

## Clone

```bash
# Preferred: clone + initialize submodules in one step
git clone --recurse-submodules https://github.com/zerobias-org/zerobias.git

# Already cloned without that flag?
cd zerobias
git submodule update --init --recursive
```

---

## Make a change inside a sub-repo

This is the most common task. The pattern:

```bash
# 1. Enter the sub-repo
cd module                                # or any other sub-repo

# 2. Check what state you're in — DO THIS EVERY TIME
git status
git branch
#  └─ If it says "HEAD detached at <sha>" or you're on main/master,
#     create a feature branch BEFORE editing.

# 3. Make a feature branch
git checkout -b feat/my-change

# 4. Edit, build, test as normal for that sub-repo
# ...

# 5. Commit IN THE SUB-REPO
git add .
git commit -m "feat: short description"

# 6. Push the feature branch and open a PR against the sub-repo
git push origin feat/my-change
# (open PR on github.com/zerobias-org/module)
```

The meta-repo doesn't know about your branch yet — and that's fine. The
meta-repo only cares about the SHA *after your PR is merged*.

---

## After your PR is merged

The maintainer (or you, with permission) updates the meta-repo to point
at the new SHA:

```bash
# Back in the meta-repo root
cd ..

# Pull latest main on the sub-repo
cd module
git checkout main
git pull origin main
cd ..

# The meta-repo will now show the submodule as modified
git status        # shows: modified: module (new commits)
git add module
git commit -m "deps(module): bump to <short-sha>"
git push
```

You can do this for many submodules in one batch using the helper script:

```bash
./scripts/update_all.sh
```

It pulls latest `main` on every submodule that's currently on `main`,
and reports which ones moved.

---

## The five most common traps

### 1. "Detached HEAD" after `git submodule update`

**Symptom:** Inside a sub-repo, `git status` says
`HEAD detached at <sha>`.

**Why:** That's the SHA the meta-repo pinned. You're not on any branch.

**Fix:** Before editing anything, make a feature branch:

```bash
git checkout -b feat/my-change
```

If you've already edited and committed in detached-HEAD state, your
commits aren't lost — but they aren't on any branch. Use:

```bash
git branch feat/my-change          # name the current commit
git checkout feat/my-change        # switch onto it
```

### 2. Accidental commit to `main`

**Symptom:** You forgot to make a branch and committed straight onto
`main` in a sub-repo.

**Fix (before pushing):**

```bash
cd <sub-repo>
git branch feat/my-change          # mark current state as a branch
git reset --hard origin/main       # rewind main back to remote
git checkout feat/my-change        # switch to the branch
```

If you already pushed to `main`: open a revert PR; don't force-push.

### 3. `git submodule update` while in the middle of work

**Symptom:** Your work-in-progress branch disappears; the sub-repo
silently jumps back to the meta-repo's pinned SHA.

**Why:** `git submodule update` (without `--merge` or `--rebase`)
checks out the meta-repo's recorded SHA, overwriting your current
branch's HEAD.

**Fix:** Don't run `git submodule update` while working inside a
sub-repo. If you must sync the meta-repo, do it from the meta-repo
root and only when no sub-repo has uncommitted work.

### 4. Meta-repo shows submodule as "modified" unexpectedly

**Symptom:** After running some sub-repo command, `git status` in the
meta-repo shows `modified: <sub-repo>` even though you didn't intend
to update its pinned SHA.

**Why:** Either:

- You pulled new commits into the sub-repo (intentional bump — stage
  and commit if that's what you want),
- Or the sub-repo is on a different SHA than what the meta-repo
  expected (e.g. detached-HEAD jumped). Reset with
  `git submodule update <sub-repo>` to snap back.

### 5. Pushing meta-repo changes that reference unmerged sub-repo SHAs

**Symptom:** You commit a meta-repo bump pointing at a SHA that hasn't
been merged to the sub-repo's `main` yet. The meta-repo CI fails for
other developers because that SHA isn't fetchable.

**Fix:** Always merge the sub-repo PR *first*, then bump the meta-repo
to the resulting `main` SHA. Never bump to a feature-branch SHA.

---

## Useful commands

```bash
# Status of every submodule (branch + SHA)
git submodule status

# Pull every submodule to the SHA the meta-repo currently pins
git submodule update --init --recursive

# Run a command in every submodule (e.g. show branch)
git submodule foreach 'git branch --show-current'

# Re-sync remote URLs (after editing .gitmodules)
git submodule sync --recursive

# Remove a submodule cleanly (when a repo is retired)
git submodule deinit <path>
git rm <path>
rm -rf .git/modules/<path>
```

---

## Why we accept the complexity

Submodules are sharper than monorepo subdirectories, but they preserve
something we care about: **each sub-repo has its own canonical git
history, issues, releases, and access control.** The meta-repo gives
you cross-repo *visibility* without sacrificing per-repo *autonomy*.

For a slower, more careful walk through the same material, the official
git documentation on submodules is excellent:
<https://git-scm.com/book/en/v2/Git-Tools-Submodules>.
