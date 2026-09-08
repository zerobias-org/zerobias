#!/bin/bash
#
# sync-skills.sh — copy every sub-repo skill into the meta-repo's root
# .claude/skills/ under a unique "<repo>--<skill>" name, injecting an
# execution-context header so each copy states which sub-repo it runs in,
# and rewriting the body so the copy is DIRECTLY invocable from the root:
#   - repo-root relative paths  ../../../X            -> ../../../<repo>/X
#   - sibling-skill paths       ../<name>/SKILL.md    -> ../<repo>--<name>/SKILL.md
#   - sibling-skill invocations /<name>, `<name>` skill -> /<repo>--<name>
#   (support files such as templates.md get the same path rewrites)
#
# Why: Claude Code only reliably loads skills from the project root's
# .claude/skills/. Sub-repo skills (module/.claude/skills/…, etc.) are
# invisible to sessions launched from the meta-repo root, and the documented
# nested-discovery / --add-dir mechanisms don't load them in practice.
#
# Idempotent full regeneration:
#   - every generated copy carries a .source marker file
#   - each run deletes all previously generated copies, then re-copies
#   - hand-written root skills (no .source marker) are never touched
#   - generated copies are gitignored (.claude/skills/*--*/) — never commit them
#
# Called automatically at the end of clone-all.sh and update_all.sh.
#
# Usage:
#   ./scripts/sync-skills.sh           # sync + summary
#   ./scripts/sync-skills.sh --quiet   # sync, print only warnings

set -u

QUIET=false
case "${1:-}" in
    --quiet) QUIET=true ;;
    -h|--help)
        sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$META_ROOT" || exit 1

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 not found — skill sync skipped." >&2
    exit 1
fi

DEST="$META_ROOT/.claude/skills"
mkdir -p "$DEST"

# Prune every previously generated copy (identified by the .source marker).
for d in "$DEST"/*/; do
    [ -d "$d" ] || continue
    [ -f "$d/.source" ] && rm -rf "$d"
done

# Rewrites a skill markdown file: prefixes the frontmatter name (synthesizing
# frontmatter for bare files) and injects the execution-context header.
transform() { # <src> <dst> <repo> <new-name> <src-rel> <siblings-csv> [support]
    python3 - "$@" <<'PYEOF'
import json, re, sys

src, dst, repo, newname, srcrel, siblings_csv = sys.argv[1:7]
support = len(sys.argv) > 7 and sys.argv[7] == "support"
siblings = [x for x in siblings_csv.split(",") if x]
prefix = repo.replace("_", "-")
text = open(src, encoding="utf-8", errors="replace").read()

def rewrite_body(b: str) -> str:
    # Paths that climb to the sub-repo root land on the META root once the
    # copy lives in ROOT/.claude/skills/<copy>/ — point them into the sub-repo.
    # Order matters: the sibling-skill rule first (it is more specific), then
    # the generic climb, but never re-prefix a path that already names a repo.
    for sib in siblings:
        b = re.sub(rf"\(\.\./{re.escape(sib)}/", f"(../{prefix}--{sib}/", b)
        # slash commands live in <repo>/.claude/commands/ and reach skills as ../skills/<name>/
        b = re.sub(rf"\(\.\./skills/{re.escape(sib)}/", f"(../{prefix}--{sib}/", b)
    b = re.sub(rf"\(\.\./\.\./\.\./(?!{re.escape(repo)}/)", f"(../../../{repo}/", b)
    if not support:
        # Slash invocations of sibling skills: /name, `/name`, (`/name`).
        for sib in siblings:
            b = re.sub(rf"(?<![\w/-])/{re.escape(sib)}(?![\w-])", f"/{prefix}--{sib}", b)
            # "the `name` skill" phrasing used by the leaf skills
            b = re.sub(rf"`{re.escape(sib)}` skill", f"`{prefix}--{sib}` skill", b)
    return b

if support:
    open(dst, "w", encoding="utf-8").write(rewrite_body(text))
    sys.exit(0)

header = (
    f"> **GENERATED — do not edit.** Source: [`{srcrel}`](../../../{srcrel}); "
    f"edit it in the `{repo}` sub-repo and re-run `scripts/sync-skills.sh`.\n"
    ">\n"
    f"> **Execution context:** this skill belongs to the `{repo}/` sub-repo, "
    "which is its own git repository. Run everything from "
    f"`{repo}/` under the workspace root — every relative path, command, and "
    f"file reference below resolves against `{repo}/`, never the meta-repo "
    f"root. Read `{repo}/CLAUDE.md` first if it isn't already loaded. Git "
    "operations (branch, commit, push, PR) target the "
    f"`{repo}` repository — never the meta-repo.\n"
    ">\n"
    "> **Other repos:** all sub-repos sit side by side under the workspace "
    f"root, so a path climbing out of `{repo}/` (e.g. `../vendor/`, "
    "`../product/`) lands on a sibling sub-repo — a separate git repository "
    "with its own rules: load its `CLAUDE.md`/docs before touching it, and "
    "commit any changes there in that repo, not here.\n\n"
)

fm, body = None, text
if text.startswith("---"):
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n?(.*)$", text, re.S)
    if m:
        fm, body = m.group(1), m.group(2)

if fm is not None:
    # Root copies must be model-invocable even where the source skill is
    # user-invocation-only inside its own repo.
    lines = [
        l for l in fm.split("\n")
        if not re.match(r"^\s*disable[-_]?(?i:modelinvocation|model[-_]invocation)\s*:", l)
    ]
    for i, line in enumerate(lines):
        if re.match(r"^name\s*:", line):
            lines[i] = f"name: {newname}"
            break
    else:
        lines.insert(0, f"name: {newname}")
    fm_out = "\n".join(lines)
else:
    desc = ""
    for line in body.split("\n"):
        s = line.strip()
        if not s or s[0] in "#`>-|":
            continue
        desc = re.sub(r"[`*_]", "", s)[:160]
        break
    desc = desc or "Sub-repo skill."
    fm_out = f"name: {newname}\ndescription: {json.dumps(desc + ' (from the ' + repo + ' sub-repo)')}"

open(dst, "w", encoding="utf-8").write(f"---\n{fm_out}\n---\n\n{header}{rewrite_body(body).lstrip()}")
PYEOF
}

synced=0
repos_with_skills=0
warned=0

for entry in */; do
    repo="${entry%/}"
    src_root="$repo/.claude/skills"
    [ -d "$src_root" ] || [ -d "$repo/.claude/commands" ] || continue
    ((repos_with_skills++)) || true
    prefix="$(echo "$repo" | tr '_' '-')"
    # Sibling skill names of this repo (dirs with SKILL.md + bare .md files) —
    # needed so cross-references between a repo's own skills get re-prefixed.
    siblings=""
    for sd in "$src_root"/*/; do [ -f "${sd}SKILL.md" ] && siblings="$siblings,$(basename "$sd")"; done
    for f in "$src_root"/*.md; do [ -f "$f" ] && [ "$(basename "$f" .md)" != README ] && siblings="$siblings,$(basename "$f" .md)"; done
    siblings="${siblings#,}"

    # Skill directories: <repo>/.claude/skills/<name>/SKILL.md (+ support files)
    for sd in "$src_root"/*/; do
        [ -f "${sd}SKILL.md" ] || continue
        skill="$(basename "$sd")"
        out="$DEST/${prefix}--${skill}"
        rm -rf "$out"
        cp -R "${sd%/}" "$out"
        # Support markdown (templates.md, …): same path rewrites, no header.
        for sf in "$out"/*.md; do
            [ -f "$sf" ] && [ "$(basename "$sf")" != SKILL.md ] && transform "$sf" "$sf" "$repo" "" "" "$siblings" support
        done
        if transform "${sd}SKILL.md" "$out/SKILL.md" "$repo" "${prefix}--${skill}" "${sd}SKILL.md" "$siblings"; then
            printf '%s\n' "${sd%/}" > "$out/.source"
            ((synced++)) || true
        else
            echo "⚠️  failed to transform ${sd}SKILL.md — skipped" >&2
            rm -rf "$out"
            ((warned++)) || true
        fi
    done

    # Bare skill files: <repo>/.claude/skills/<name>.md
    # Precedence: a DIRECTORY skill of the same name wins — repos mid-migration
    # keep the old flat file beside the new <name>/SKILL.md until it's deleted,
    # and the flat copy must not clobber the dir copy.
    for f in "$src_root"/*.md; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .md)"
        [ "$base" = "README" ] && continue
        [ -f "$src_root/$base/SKILL.md" ] && continue
        out="$DEST/${prefix}--${base}"
        rm -rf "$out"
        mkdir -p "$out"
        if transform "$f" "$out/SKILL.md" "$repo" "${prefix}--${base}" "$f" "$siblings"; then
            printf '%s\n' "$f" > "$out/.source"
            ((synced++)) || true
        else
            echo "⚠️  failed to transform $f — skipped" >&2
            rm -rf "$out"
            ((warned++)) || true
        fi
    done

    # Slash commands: <repo>/.claude/commands/<name>.md — synced the same way.
    # On a name clash with a skill from the same repo, the skill wins.
    for f in "$repo/.claude/commands"/*.md; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .md)"
        [ "$base" = "README" ] && continue
        out="$DEST/${prefix}--${base}"
        [ -d "$out" ] && continue
        mkdir -p "$out"
        if transform "$f" "$out/SKILL.md" "$repo" "${prefix}--${base}" "$f" "$siblings"; then
            printf '%s\n' "$f" > "$out/.source"
            ((synced++)) || true
        else
            echo "⚠️  failed to transform $f — skipped" >&2
            rm -rf "$out"
            ((warned++)) || true
        fi
    done
done

if [ "$QUIET" = false ]; then
    echo "Synced $synced skills from $repos_with_skills sub-repos into .claude/skills/ (as <repo>--<skill>)."
    [ "$warned" -gt 0 ] && echo "⚠️  $warned skill(s) skipped — see warnings above."
fi
exit 0
