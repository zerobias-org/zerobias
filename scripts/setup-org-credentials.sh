#!/usr/bin/env bash
# ZeroBias ORG credential setup — check-first, prompt-only-for-missing.
#
# Verifies the existing setup and exits "already configured" when green;
# otherwise fixes ONLY the missing pieces, asking for each value at most
# once. Safe to run any time.
#
# TWO-KEY MODEL (single-key still works — see fallbacks):
#   ZB_API_KEY — ORG key: org-owner API key of the TARGET env. Used by the
#                MCP logins (zb profile, zb-knowledge headers), the
#                /dana/me owner check, and publishOrg's platform calls
#                (build-tools falls back to ZB_TOKEN when it's unset).
#   ZB_TOKEN   — REGISTRY key: auths pkg.zerobias.org (npm view/publish,
#                .npmrc interpolation) and the gate's Neon step. While the
#                registry accepts only PROD keys, this must be a prod key.
#                Rule: DON'T touch it if it works; only verify + replace.
#
# Homes it manages:
#   - zbb slot env   (ZB_API_KEY, ZB_TOKEN, ZB_ORG_ID, ZB_PLATFORM_URL,
#                     NPM_CONFIG_TAG; DATALOADER_SERVICE_URL is deliberately
#                     unset — the gate's Neon step needs its prod default)
#   - ~/.npmrc       (pkg.zerobias.org scopes; authToken = ${ZB_TOKEN})
#   - zb MCP profile (~/.config/mcp-zb/credentials.json, written directly;
#                     profile 'env' holds ${VAR} placeholders that zb
#                     resolves from its process env at load time)
# The MCPs themselves need NO registration — the repo ships .mcp.json with
# ${ZB_ORG_ID}/${ZB_API_KEY} placeholders. Launch claude THROUGH THE SLOT
# (--launch, or `zbb --slot <slot> exec claude` from a content-repo root)
# and everything resolves from the slot env; no shell exports needed.
#
# Run this YOURSELF in a normal terminal so the API keys never enter a
# Claude session. Env vars (SLOT, ZB_PLATFORM_URL, ZB_ORG_ID, ZB_API_KEY,
# ZB_TOKEN) pre-seed and skip prompts. `--reconfigure` ignores the stored
# values and asks fresh (use it to switch org/env/key).
#
# FRICTION CONTRACT: this script OWNS the zb secrets. It never tells you to
# fix your shell. Pre-existing exported values are stashed
# (ORIGINAL_<date>_<VAR> + a 600-perm backup under ~/.config/zb-secrets-backup/,
# replayable with:  eval "$(… --restore)"), sanitized (zbb's stdout banner is
# stripped), auto-verified against their target, and reused when they pass —
# prompts appear only for keys no stored candidate can satisfy.
#
# `--launch [claude args…]`: after the setup is green, exec `claude`
# through `zbb --slot <slot> exec` from the repo root — zbb injects the
# slot's env into claude, so .mcp.json and the zb profile resolve slot
# creds; nothing is exported into YOUR shell. Only KNOWLEDGE_MCP_URL (the
# per-env zb-knowledge endpoint — not a slot var) rides along. Everything
# after --launch is passed to claude, so `--launch -p "make vendor x"`
# runs headless.
#
# Every zerobias-org content repo ships an IDENTICAL copy of this script at
# scripts/setup-org-credentials.sh — deliberate duplication, kept in sync
# (repos must never depend on the meta-repo). Copies live in: vendor,
# suite, product, module, and the zerobias-org meta-repo (which runs it
# through a cloned content repo's stack — see STACK_ROOT). After editing
# one: copy to ALL, check `md5 -q` matches, and COMMIT in each repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# zbb needs an added-stack cwd — outside one, `env get/set` fail (get exits
# 1 with EMPTY output, indistinguishable from unset). In content repos the
# repo root IS the stack; the meta-repo has no zbb.yaml at its root, so its
# copy borrows the first cloned content repo's stack.
STACK_ROOT=""
for d in "$REPO_ROOT" "$REPO_ROOT/vendor" "$REPO_ROOT/suite" "$REPO_ROOT/module"; do
  [ -f "$d/zbb.yaml" ] && { STACK_ROOT="$d"; break; }
done
[ -n "$STACK_ROOT" ] || { printf 'No zbb.yaml at %s (or vendor/ suite/ module/ under it).\nRun from a content repo, or clone them first (scripts/clone-all.sh).\n' "$REPO_ROOT" >&2; exit 1; }
cd "$STACK_ROOT"   # zbb resolves the stack context from cwd

usage() {
  cat <<EOF
Usage: $0 [--reconfigure] [--restore] [--launch [claude args…]]

Check-first ZeroBias ORG credential setup. Verifies what's already in
place (zbb slot env, ~/.npmrc scopes, zb MCP profile, org-OWNER key,
registry key) and prompts only for the missing pieces. Safe to re-run.
Run it YOURSELF in a normal terminal — not inside a Claude session.

Options:
  --reconfigure    Ignore stored values and ask fresh (switch org/env/key).
  --restore        Print export lines that restore your ORIGINAL shell
                   values from the newest backup this script stashed.
                   Use as:  eval "\$($0 --restore)"
  --launch [args…] After setup is green, exec 'claude' through
                   `zbb --slot <slot> exec` from the stack root (= repo
                   root; in the meta-repo: the borrowed content repo) —
                   claude sees the slot's creds, verified first. Everything
                   after --launch goes to claude, so a headless run is:
                   $0 --launch -p "make vendor x"
                   and a session with Remote Control active from the start:
                   $0 --launch --remote-control
  -h, --help       Show this help.

Env vars pre-seed the prompts (each one set = one prompt skipped):
  SLOT              zbb slot name (default: reuse/create <env>-<org first 8>)
  ZB_PLATFORM_URL   target platform, e.g. https://app.zerobias.com/api
  ZB_ORG_ID         target org UUID (prompt also accepts the org NAME)
  ZB_API_KEY        ORG key — org-OWNER API key of the TARGET env
  ZB_TOKEN          REGISTRY key — PROD key that can read pkg.zerobias.org
EOF
}

RECONF=false; LAUNCH=false; RESTORE=false; CLAUDE_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --reconfigure) RECONF=true; shift ;;
    --restore) RESTORE=true; shift ;;
    --launch) LAUNCH=true; shift; CLAUDE_ARGS=("$@"); set -- ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
say()  { printf '%s\n' "$*"; }

STAMP=$(date +%Y_%m_%d)
BACKUP_DIR="$HOME/.config/zb-secrets-backup"
LAST_TARGET_FILE="$BACKUP_DIR/last-target"
REGISTRY_URL="https://pkg.zerobias.org"

# --restore: emit export lines that put the ORIGINAL values back, from the
# newest backup this script wrote. Use as:  eval "$(./scripts/setup-org-credentials.sh --restore)"
if $RESTORE; then
  f=$(ls -t "$BACKUP_DIR"/*.env 2>/dev/null | head -n1)
  [ -n "${f:-}" ] || { printf '# no stashed originals found in %s\n' "$BACKUP_DIR" >&2; exit 1; }
  cat "$f"
  exit 0
fi
# zbb sometimes prints a "Vault credentials refreshed: ✓ …" banner to STDOUT
# before the value (intermittent — only when the vault lease refreshes), which
# poisons $(…) captures. The value is always the LAST line — take only that.
slot_get() { # $1=var — never fails (unset var → empty; pipefail-safe)
  zbb --slot "$SLOT" env get "$1" 2>/dev/null | tail -n1 || true
}
# Per-env knowledge-mcp endpoint derived from a platform URL ($1). Keys are
# per-env and .mcp.json's zb-knowledge URL defaults to PROD — launching with
# a non-prod key and no KNOWLEDGE_MCP_URL exported is a guaranteed 401 on
# the zb-knowledge MCP at every session start.
knowledge_url() { local h; h="${1#*://}"; h="${h%%/*}"; printf 'https://api.%s/knowledge-mcp/mcp' "$h"; }
# exec claude THROUGH the slot: zbb injects the slot's stack env into
# claude (cwd = STACK_ROOT provides the stack context), so .mcp.json
# placeholders and the zb 'env' profile resolve slot creds. Only two vars
# ride along as exports: KNOWLEDGE_MCP_URL (per-env, not a slot var) and —
# on single-key slots with no stored ZB_API_KEY — a ZB_API_KEY mirror of
# ZB_TOKEN so ${ZB_API_KEY} interpolations still resolve.
launch_claude() {
  command -v claude >/dev/null || { say "✗ --launch: 'claude' not found on PATH."; exit 1; }
  local ak tok url
  url="$(slot_get ZB_PLATFORM_URL)"
  tok="$(slot_get ZB_TOKEN)"
  ak="$(slot_get ZB_API_KEY)"; ak="${ak:-$tok}"
  # Final gate: NEVER exec claude on creds that are known-broken — a session
  # launched with a dead key burns the whole run on confusing 401s.
  if ! is_owner "$ak"; then
    say "✗ --launch REFUSED: the slot's ZB_API_KEY fails the org-owner check"
    say "  against $url (bad key, or platform unreachable)."
    say "  Fix with: $0 --reconfigure"
    exit 1
  fi
  if ! registry_ok "$tok"; then
    say "✗ --launch REFUSED: the slot's ZB_TOKEN cannot read $REGISTRY_URL."
    say "  It must be a PROD-issued registry key. Fix with: $0 --reconfigure"
    exit 1
  fi
  export KNOWLEDGE_MCP_URL="$(knowledge_url "$url")"
  export ZB_API_KEY="$ak"   # slot value (when set) overrides this on inject
  say "Launching claude via slot $SLOT from $STACK_ROOT (creds verified)…"
  exec zbb --slot "$SLOT" exec claude ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
}
# Run `zb status` with creds injected (the 'env' profile resolves its
# ${VAR} placeholders from them) and require a REAL connection. `zb status`
# exits 0 even when the connection FAILS — only the output tells.
verify_zb() { # $1=url $2=org-key $3=org
  local out
  out=$(ZB_PLATFORM_URL="$1" ZB_API_KEY="$2" ZB_TOKEN="$2" ZB_ORG_ID="$3" zb status 2>&1) || return 1
  printf '%s\n' "$out" | sed 's/^/    /'
  printf '%s' "$out" | grep -q 'Connected'
}
need=() # human-readable list of what was missing

# ── Phase -1: take ownership of pre-existing shell secrets — NEVER block.
# Anything already exported is stashed (ORIGINAL_<date>_<VAR> in this
# process env, so a --launch session still sees it, PLUS a 600-perm backup
# file replayable via --restore), then sanitized. Valid after sanitizing →
# used as pre-seed; junk → ignored. The user is never told to unset things.
stash_file=""
stash() { # $1=var $2=original-value
  export "ORIGINAL_${STAMP}_$1=$2"
  if [ -z "$stash_file" ]; then
    mkdir -p "$BACKUP_DIR"
    stash_file="$BACKUP_DIR/$STAMP.$$.env"
    ( umask 077; : > "$stash_file" )
  fi
  printf 'export %s=%q\n' "$1" "$2" >> "$stash_file"
}
last_line() { printf '%s\n' "$1" | awk 'NF{v=$0} END{print v}'; }
trim() { # strip CRs + leading/trailing whitespace — pasted values often carry both
  local s="${1//$'\r'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}
mask() { # $1=secret → abc…xyz preview so the user can recognize what they entered
  if [ ${#1} -ge 8 ]; then printf '%s…%s' "${1:0:3}" "${1: -3}"; else printf '(too short to preview)'; fi
}
read_secret() { # $1=prompt $2=varname — hidden read; trimmed; masked echo-back
  local _v
  read -rsp "$1" _v; echo
  _v=$(trim "$_v")
  [ -n "$_v" ] && say "  got: $(mask "$_v") (${#_v} chars)"
  printf -v "$2" '%s' "$_v"
}
# Accept bare hosts ("ci.zerobias.com"), with/without scheme, with/without /api.
normalize_url() { # $1=raw → prints https://host/api form
  local u="$1"
  case "$u" in http://*|https://*) : ;; *) u="https://$u" ;; esac
  case "$u" in */api) : ;; *) u="${u%/}/api" ;; esac
  printf '%s' "$u"
}
valid() { # $1=var $2=value → 0 if shaped right
  case "$1" in
    ZB_ORG_ID) printf '%s' "$2" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' ;;
    ZB_PLATFORM_URL) case "$2" in http://*|https://*) return 0;; *) return 1;; esac ;;
    ZB_TOKEN|ZB_API_KEY) [ -n "$2" ] ;;
  esac
}
# ── Org-name resolution: humans know "Undefined", not UUIDs ────────────
list_orgs() { # $1=key → "id<TAB>name<TAB>slug" lines (empty on failure)
  curl -sf "$ZB_PLATFORM_URL/dana/me/orgs" \
    -H "Authorization: APIKey $1" -H "Accept: application/json" 2>/dev/null \
  | python3 -c '
import json, sys
try:
    for o in json.load(sys.stdin):
        print("\t".join([o.get("id", ""), o.get("name", ""), o.get("slug", "")]))
except Exception:
    pass' 2>/dev/null
}
org_rows() { # first NON-EMPTY /me/orgs result across all candidate keys
  # (a dead key in the shell must not shadow a working slot key — try until
  # one actually answers)
  local rows cand u k var
  for k in "${ZB_API_KEY:-}" "${ZB_TOKEN:-}"; do
    [ -n "$k" ] || continue
    rows=$(list_orgs "$k")
    [ -n "$rows" ] && { printf '%s' "$rows"; return 0; }
  done
  for cand in $(ls ~/.zbb/slots/ 2>/dev/null); do
    u=$(zbb --slot "$cand" env get ZB_PLATFORM_URL 2>/dev/null | tail -n1 || true)
    [ "$u" = "$ZB_PLATFORM_URL" ] || continue
    for var in ZB_API_KEY ZB_TOKEN; do
      k=$(zbb --slot "$cand" env get "$var" 2>/dev/null | tail -n1 || true)
      [ -n "$k" ] || continue
      rows=$(list_orgs "$k")
      [ -n "$rows" ] && { printf '%s' "$rows"; return 0; }
    done
  done
  return 1
}
ORG_NAME=""
resolve_org() { # $1=name-or-uuid → sets ZB_ORG_ID (+ORG_NAME); 1 = re-ask
  if valid ZB_ORG_ID "$1"; then ZB_ORG_ID="$1"; return 0; fi
  local rows m n
  rows=$(org_rows) || { say "  (no stored key can reach $ZB_PLATFORM_URL/dana/me/orgs — org NAMES can't be resolved; paste the org UUID)"; return 1; }
  m=$(printf '%s\n' "$rows" | awk -F'\t' -v q="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" 'tolower($2)==q || tolower($3)==q {print}')
  n=$(printf '%s' "$m" | grep -c . || true)
  if [ "$n" = "1" ]; then
    ZB_ORG_ID=$(printf '%s' "$m" | cut -f1)
    ORG_NAME=$(printf '%s' "$m" | cut -f2)
    say "  resolved org '$ORG_NAME' → $ZB_ORG_ID"
    return 0
  fi
  say "  '$1' matched $n of your orgs on $ZB_PLATFORM_URL:"
  printf '%s\n' "$rows" | awk -F'\t' '{printf "    %s  (%s)\n", $2, $1}'
  return 1
}

for v in ZB_PLATFORM_URL ZB_ORG_ID ZB_API_KEY ZB_TOKEN; do
  eval "cur=\${$v:-}"
  [ -n "$cur" ] || continue
  clean=$(trim "$(last_line "$cur")")
  [ "$v" = "ZB_PLATFORM_URL" ] && clean=$(normalize_url "$clean")
  if [ "$clean" != "$cur" ] || ! valid "$v" "$clean"; then
    stash "$v" "$cur"
  fi
  if valid "$v" "$clean"; then
    eval "$v=\$clean"
    [ "$clean" != "$cur" ] && say "(sanitized $v from your shell — original kept as ORIGINAL_${STAMP}_$v; --restore replays it)"
  else
    eval "unset $v"
    say "($v in your shell was unusable — kept as ORIGINAL_${STAMP}_$v, ignored here; --restore replays it)"
  fi
done

# ── Phase 0: resolve the TARGET (platform URL + org) ────────────────────
# Env vars pre-answer these. Otherwise the LAST-USED target (remembered per
# run) — or the single distinct target across all existing slots — becomes
# an Enter-to-keep default, so a re-run never re-asks what it already knows.
def_url=""; def_org=""
def_name=""
if [ -f "$LAST_TARGET_FILE" ]; then
  IFS='|' read -r def_url def_org _slot def_name < "$LAST_TARGET_FILE" || true
fi
if [ -z "$def_url" ] || [ -z "$def_org" ]; then
  pairs=""
  for cand in $(ls ~/.zbb/slots/ 2>/dev/null); do
    u=$(zbb --slot "$cand" env get ZB_PLATFORM_URL 2>/dev/null | tail -n1 || true)
    o=$(zbb --slot "$cand" env get ZB_ORG_ID 2>/dev/null | tail -n1 || true)
    [ -n "$u" ] && [ -n "$o" ] || continue
    case "$pairs" in *"$u $o"*) : ;; *) pairs="${pairs}${u} ${o}
" ;; esac
  done
  if [ "$(printf '%s' "$pairs" | grep -c .)" = "1" ]; then
    def_url=$(printf '%s' "$pairs" | awk 'NR==1{print $1}')
    def_org=$(printf '%s' "$pairs" | awk 'NR==1{print $2}')
  fi
fi
if [ -z "${ZB_PLATFORM_URL:-}" ]; then
  if [ -n "$def_url" ] && [ -n "$def_org" ]; then
    read -rp "Target [$def_url · ${def_name:-org} ${def_name:+(}$def_org${def_name:+)}] — Enter to keep, or type a new URL: " a || a=""
    a=$(trim "$a")
    if [ -z "$a" ]; then
      ZB_PLATFORM_URL="$def_url"; ZB_ORG_ID="${ZB_ORG_ID:-$def_org}"
    else
      ZB_PLATFORM_URL="$a"
    fi
  else
    read -rp "Platform URL [https://app.zerobias.com/api]: " a || a=""
    a=$(trim "$a")
    ZB_PLATFORM_URL=${a:-https://app.zerobias.com/api}
  fi
fi
orig_url="$ZB_PLATFORM_URL"
ZB_PLATFORM_URL=$(normalize_url "$ZB_PLATFORM_URL")
[ "$ZB_PLATFORM_URL" != "$orig_url" ] && say "(normalized platform URL → $ZB_PLATFORM_URL)"
if [ -z "${ZB_ORG_ID:-}" ]; then
  while :; do
    if [ -n "$def_org" ]; then
      read -rp "Org (name or UUID) [${def_name:-$def_org}]: " a || a=""
      a=${a:-$def_org}
    else
      read -rp "Org (name or UUID): " a || a=""
    fi
    a=$(trim "$a")
    [ -n "$a" ] || { say "✗ org is required."; exit 1; }
    resolve_org "$a" && break
    [ -t 0 ] || { say "✗ could not resolve org non-interactively."; exit 1; }
  done
fi
[ -n "${ZB_ORG_ID:-}" ] || { say "✗ org ID is required."; exit 1; }

# Typo guard on the (possibly just-prompted) target values.
valid ZB_ORG_ID "$ZB_ORG_ID" || { say "✗ '$ZB_ORG_ID' is not a UUID — re-run and check the org ID."; exit 1; }
valid ZB_PLATFORM_URL "$ZB_PLATFORM_URL" || { say "✗ '$ZB_PLATFORM_URL' is not a URL — re-run and check it."; exit 1; }

# ── Slot resolution: SLOT env wins; else REUSE any slot already holding
#    this exact target; else the canonical name <env>-<org first 8> ─────
if [ -z "${SLOT:-}" ]; then
  for cand in $(ls ~/.zbb/slots/ 2>/dev/null); do
    u=$(zbb --slot "$cand" env get ZB_PLATFORM_URL 2>/dev/null | tail -n1 || true)
    o=$(zbb --slot "$cand" env get ZB_ORG_ID 2>/dev/null | tail -n1 || true)
    if [ "$u" = "$ZB_PLATFORM_URL" ] && [ "$o" = "$ZB_ORG_ID" ]; then
      SLOT=$cand; say "Reusing slot '$SLOT' — it already holds this org/env."; break
    fi
  done
fi
if [ -z "${SLOT:-}" ]; then
  host=${ZB_PLATFORM_URL#*://}; host=${host%%/*}; envlabel=${host%%.*}
  [ "$envlabel" = "app" ] && envlabel=prod
  SLOT="${envlabel}-$(printf '%.8s' "$ZB_ORG_ID")"
  say "Using canonical slot '$SLOT' for this org/env (will create if absent)."
fi
# Remember this target (incl. org NAME) — next run's Enter-to-keep default.
if [ -z "$ORG_NAME" ]; then
  [ "$ZB_ORG_ID" = "$def_org" ] && ORG_NAME="$def_name"
fi
if [ -z "$ORG_NAME" ]; then
  ORG_NAME=$(org_rows | awk -F'\t' -v id="$ZB_ORG_ID" '$1==id{print $2; exit}' || true)
fi
mkdir -p "$BACKUP_DIR"
( umask 077; printf '%s|%s|%s|%s\n' "$ZB_PLATFORM_URL" "$ZB_ORG_ID" "$SLOT" "$ORG_NAME" > "$LAST_TARGET_FILE" )

# ── Verifiers ───────────────────────────────────────────────────────────
is_owner() { # $1=key → 0 if org-owner of the target env
  curl -sf "$ZB_PLATFORM_URL/dana/me" \
    -H "Authorization: APIKey $1" \
    -H "dana-org-id: $ZB_ORG_ID" \
    -H "Accept: application/json" 2>/dev/null | grep -q '"isAdmin" *: *true'
}
registry_ok() { # $1=token → 0 if it can read the verdaccio registry LIVE
  # A fresh --cache dir forces a real network round-trip: npm's shared cache
  # can otherwise serve metadata WITHOUT auth (false green after any recent
  # successful install with a different key).
  local rc tmp tmpcache
  tmp=$(mktemp); tmpcache=$(mktemp -d)
  printf '//pkg.zerobias.org/:_authToken=%s\n' "$1" > "$tmp"
  # Run from the throwaway dir: npm's PROJECT .npmrc (cwd upward) overrides
  # --userconfig, so testing from the repo root would silently auth with the
  # repo npmrc's ${ZB_TOKEN} from the SHELL env instead of the key under test.
  ( cd "$tmpcache" && npm view @zerobias-org/zbb version --registry "$REGISTRY_URL" \
      --userconfig "$tmp" --cache "$tmpcache" >/dev/null 2>&1 )
  rc=$?
  rm -rf "$tmp" "$tmpcache"
  return $rc
}

# ── Phase 1: CHECK what's already in place ──────────────────────────────
slot_ok=false; slot_token=""; slot_api_key=""; slot_org=""; slot_url=""
if zbb slot list 2>/dev/null | grep -q "$SLOT"; then
  slot_token=$(slot_get ZB_TOKEN || true)
  slot_api_key=$(slot_get ZB_API_KEY || true)
  slot_org=$(slot_get ZB_ORG_ID || true)
  slot_url=$(slot_get ZB_PLATFORM_URL || true)
  [ -n "$slot_token" ] && [ -n "$slot_org" ] && [ -n "$slot_url" ] && slot_ok=true
fi
$slot_ok || need+=("slot env ($SLOT)")

npmrc_ok=false
grep -q '@zerobias-org:registry' ~/.npmrc 2>/dev/null && npmrc_ok=true
$npmrc_ok || need+=("~/.npmrc scopes")

zb_ok=false
if command -v zb >/dev/null && $slot_ok; then
  # zb status exits 0 even on a FAILED connection — check the output.
  # Green needs BOTH: a real connection AND the ${VAR} placeholder marker
  # (a legacy LITERAL-creds profile ignores the injected env entirely and
  # may connect as some OTHER org — that must read as broken so Phase 3
  # rewrites it, not as green).
  zb_out=$(ZB_PLATFORM_URL="$slot_url" ZB_API_KEY="${slot_api_key:-$slot_token}" \
    ZB_TOKEN="${slot_api_key:-$slot_token}" ZB_ORG_ID="$slot_org" \
    zb status 2>/dev/null || true)
  printf '%s' "$zb_out" | grep -q 'Connected' \
    && printf '%s' "$zb_out" | grep -q '\${ZB_API_KEY}' && zb_ok=true
fi
$zb_ok || need+=("zb MCP profile")

owner_ok=false
if $slot_ok && is_owner "${slot_api_key:-$slot_token}"; then
  owner_ok=true
elif $slot_ok; then
  need+=("ORG key (stored key failed the /dana/me isAdmin check)")
fi

reg_ok=false
if $slot_ok && [ -n "$slot_token" ] && registry_ok "$slot_token"; then
  reg_ok=true
elif $slot_ok; then
  need+=("REGISTRY key (stored ZB_TOKEN cannot read $REGISTRY_URL)")
fi

if $slot_ok && $npmrc_ok && $zb_ok && $owner_ok && $reg_ok && ! $RECONF; then
  say "✓ Already configured — nothing to do."
  say "    slot:     $SLOT"
  say "    platform: $slot_url"
  verify_zb "$slot_url" "${slot_api_key:-$slot_token}" "$slot_org" || say "    org:      $slot_org"
  say ""
  say "  Re-run with --reconfigure to change org / env / keys."
  if $LAUNCH; then launch_claude; fi
  say "  Launch claude with the slot's creds:"
  say "    $0 --launch [claude args…]"
  say "  or directly (from a content-repo root):"
  say "    zbb --slot $SLOT exec claude"
  say "    (non-prod target: first export KNOWLEDGE_MCP_URL=\"$(knowledge_url "$slot_url")\")"
  exit 0
fi

say "Missing/invalid: ${need[*]}"
say "Fixing only those."

# ── Phase 2a: the ORG key (ZB_API_KEY) — ZERO prompts when a candidate
#    passes the org-OWNER check; one hidden prompt otherwise. Legacy
#    single-key setups qualify through their ZB_TOKEN.
picked=""
if ! $RECONF; then
  for src in "shell ZB_API_KEY" "slot ZB_API_KEY" "shell ZB_TOKEN" "slot ZB_TOKEN"; do
    case "$src" in
      "shell ZB_API_KEY") cand=${ZB_API_KEY:-} ;;
      "slot ZB_API_KEY")  cand=$slot_api_key ;;
      "shell ZB_TOKEN")   cand=${ZB_TOKEN:-} ;;
      "slot ZB_TOKEN")    cand=$slot_token ;;
    esac
    [ -n "$cand" ] || continue
    if is_owner "$cand"; then
      ZB_API_KEY="$cand"; picked=$src
      say "ORG key: using …${cand: -4} from $src (org-owner verified against $ZB_PLATFORM_URL)."
      break
    fi
  done
fi
if [ -z "$picked" ]; then
  say "No stored key passes the org-OWNER check for org $ZB_ORG_ID."
  say "Generate one in the TARGET env's app UI (keys are PER-ENVIRONMENT,"
  say "and it must be an ORG OWNER key — member keys cannot load):"
  say "  ${ZB_PLATFORM_URL%/api} → Settings → API Keys"
  read_secret "ORG key — org OWNER API key (hidden): " ZB_API_KEY
  [ -n "$ZB_API_KEY" ] || { say "✗ the ORG key is required."; exit 1; }
fi

# ── Phase 2b: the REGISTRY key (ZB_TOKEN) — DON'T touch it if it works.
#    Only when no candidate can read the registry: one prompt, with the
#    explanation that it must be a PROD key. A registry OUTAGE warns and
#    continues (setup isn't hostage to the registry) but never --launches;
#    a LIVE registry rejecting the key is a hard stop — storing a key the
#    registry just refused only poisons the slot for every later session.
reg_picked=""
if ! $RECONF; then
  # Candidates in trust order: this shell, the slot, stashed ORIGINALs from
  # earlier runs (newest backup first), then every OTHER slot's ZB_TOKEN.
  # A shadowed/stale shell export must never hide a key that is known-good
  # somewhere this script already owns (that gap once let a dead key win
  # while the good one sat one candidate away).
  reg_srcs=("your shell env" "the slot"); reg_vals=("${ZB_TOKEN:-}" "$slot_token")
  for f in $(ls -t "$BACKUP_DIR"/*.env 2>/dev/null); do
    v=$(sed -n 's/^export ZB_TOKEN=//p' "$f" | tail -n1) || true
    [ -n "$v" ] || continue
    eval "v=$v"   # stash() wrote %q-quoted values; unquote
    reg_srcs+=("stashed original ${f##*/}"); reg_vals+=("$v")
  done
  for cand in $(ls ~/.zbb/slots/ 2>/dev/null); do
    [ "$cand" = "$SLOT" ] && continue
    v=$(zbb --slot "$cand" env get ZB_TOKEN 2>/dev/null | tail -n1 || true)
    [ -n "$v" ] || continue
    reg_srcs+=("slot $cand"); reg_vals+=("$v")
  done
  tried=""
  for i in "${!reg_vals[@]}"; do
    cand=${reg_vals[$i]}
    [ -n "$cand" ] || continue
    case "$tried" in *"|$cand|"*) continue ;; esac   # dedup — one npm probe per distinct key
    tried="${tried}|$cand|"
    if registry_ok "$cand"; then
      ZB_TOKEN="$cand"; reg_picked=${reg_srcs[$i]}
      say "REGISTRY key: using …${cand: -4} from ${reg_picked} (reads $REGISTRY_URL fine)."
      break
    fi
  done
fi
if [ -z "$reg_picked" ]; then
  say "No stored key can read $REGISTRY_URL (npm 401)."
  say "The registry key must be a PROD API key — pkg.zerobias.org currently"
  say "accepts only prod-issued keys, regardless of which env you publish"
  say "orgs into. Generate one at: https://app.zerobias.com → Settings → API Keys"
  read_secret "REGISTRY key — PROD API key (hidden): " a
  [ -n "$a" ] || { say "✗ a registry key is required (used by gate + publish)."; exit 1; }
  ZB_TOKEN="$a"
  if registry_ok "$ZB_TOKEN"; then
    say "REGISTRY key verified against $REGISTRY_URL."
  else
    # Rejected key, or registry down? An anonymous probe tells them apart:
    # a LIVE registry answers 401/403 without auth; DOWN is unreachable/5xx.
    probe=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
      "$REGISTRY_URL/@zerobias-org%2fzbb" || true)
    if [ "$probe" = "401" ] || [ "$probe" = "403" ]; then
      say "✗ $REGISTRY_URL is UP but REJECTS this key — not a valid PROD key."
      say "  STOPPING; nothing stored. Generate a prod key at"
      say "  https://app.zerobias.com → Settings → API Keys and re-run."
      exit 1
    fi
    say "⚠ $REGISTRY_URL looks unreachable (HTTP ${probe:-none}) — key can't be"
    say "  verified. Storing it; gate/publishOrg will fail until the registry is"
    say "  back. Verify with the platform team."
    if $LAUNCH; then
      say "  --launch SKIPPED — won't start a session on an unverified registry key."
      LAUNCH=false
    fi
  fi
fi

# ── Phase 3: fix only what phase 1 flagged ──────────────────────────────
if ! $slot_ok || ! $owner_ok || ! $reg_ok || $RECONF; then
  say "--- slot env ($SLOT)"
  zbb slot list 2>/dev/null | grep -q "$SLOT" || zbb slot create "$SLOT"
  # the repo's env vars are STACK-level — the stack must be in the slot
  # before `env set` can attach them ("no stack context" otherwise).
  # "already exists" is fine; any other add-failure is fatal.
  if ! out=$(zbb --slot "$SLOT" stack add "$STACK_ROOT" 2>&1); then
    printf '%s\n' "$out" | grep -qi "already exists" \
      || { printf '%s\n' "$out"; say "✗ stack add failed — STOPPING."; exit 1; }
  fi
  zbb --slot "$SLOT" env set ZB_API_KEY "$ZB_API_KEY" >/dev/null
  say "  ZB_API_KEY stored (value not shown)"
  zbb --slot "$SLOT" env set ZB_TOKEN "$ZB_TOKEN" >/dev/null
  say "  ZB_TOKEN stored (value not shown)"
  zbb --slot "$SLOT" env set ZB_ORG_ID "$ZB_ORG_ID"
  zbb --slot "$SLOT" env set ZB_PLATFORM_URL "$ZB_PLATFORM_URL"
  # DATALOADER_SERVICE_URL is intentionally NOT set: the gate's Neon step
  # auths with the prod-issued ZB_TOKEN against its prod default
  # (app.zerobias.com/api/dataloader) even for non-prod org targets — a
  # per-env override makes the prod key 401. The org load never reads it
  # (it uses ZB_PLATFORM_URL + ZB_API_KEY). Clear any stale override.
  zbb --slot "$SLOT" env unset DATALOADER_SERVICE_URL >/dev/null 2>&1 || true
  zbb --slot "$SLOT" env set NPM_CONFIG_TAG dev
fi

if ! $npmrc_ok; then
  say "--- ~/.npmrc scopes"
  printf '@zerobias-com:registry=https://pkg.zerobias.org\n@zerobias-org:registry=https://pkg.zerobias.org\n//pkg.zerobias.org/:_authToken=${ZB_TOKEN}\n' >> ~/.npmrc
fi

if ! $zb_ok || $RECONF; then
  say "--- zb MCP profile (write-once interpolated profile 'env')"
  command -v zb >/dev/null || ZB_TOKEN="$ZB_TOKEN" npm install -g @zerobias-com/zerobias-mcp
  # Profile 'env' stores LITERAL ${VAR} placeholder strings; zb resolves
  # them from its process env at load time. The profile is written
  # DIRECTLY (python3) — piping values into `zb setup` non-interactively
  # exits 0 WITHOUT SAVING (its hidden API-key prompt needs a TTY), which
  # silently left literal creds baked into profiles for months. With
  # placeholders, whatever env claude is launched with (slot exec /
  # --launch) is what zb uses; a shell with no ZB_* fails LOUD
  # (MISSING_ENV_VAR) instead of silently using another org's key.
  python3 - <<'PY'
import json, os, pathlib
f = pathlib.Path(os.path.expanduser('~/.config/mcp-zb/credentials.json'))
f.parent.mkdir(parents=True, exist_ok=True)
data = {}
if f.exists():
    try:
        data = json.loads(f.read_text())
    except Exception:
        data = {}
if not isinstance(data, dict):
    data = {}
data.setdefault('profiles', {})['env'] = {
    'url': '${ZB_PLATFORM_URL}',
    'org-id': '${ZB_ORG_ID}',
    'api-key': '${ZB_API_KEY}',
}
data['active'] = 'env'
tmp = f.with_name(f.name + '.tmp')
tmp.write_text(json.dumps(data, indent=2) + '\n')
os.chmod(tmp, 0o600)
tmp.replace(f)
PY
  # Injected real creds prove this zb version resolves ${VAR} refs (a
  # pre-placeholder zb would send the literal string and fail to connect).
  verify_zb "$ZB_PLATFORM_URL" "$ZB_API_KEY" "$ZB_ORG_ID" \
    || { say "✗ zb cannot connect through the placeholder profile."
         say "  Likely an outdated zb — update it and re-run:"
         say "    npm install -g @zerobias-com/zerobias-mcp@latest"
         exit 1; }
  say "  zb profile 'env' active — creds resolve from the launching env"
  say "  (slot exec / --launch); shells without ZB_* fail loud by design."
fi

# ── Phase 4: verify the ORG key is an org OWNER (always, on final values)
say "--- verifying org OWNER (admin) of $ZB_ORG_ID"
resp=$(curl -s -w '\n%{http_code}' "$ZB_PLATFORM_URL/dana/me" \
     -H "Authorization: APIKey $ZB_API_KEY" \
     -H "dana-org-id: $ZB_ORG_ID" \
     -H "Accept: application/json")
code=${resp##*$'\n'}
body=${resp%$'\n'*}
if printf '%s' "$body" | grep -q '"isAdmin" *: *true'; then
  say "OK — org owner confirmed."
elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
  say "✗ The ORG key does not AUTHENTICATE against $ZB_PLATFORM_URL (HTTP $code)."
  say "  API keys are PER-ENVIRONMENT — generate one in the TARGET env's app:"
  say "  ${ZB_PLATFORM_URL%/api} → Settings → API Keys (org $ZB_ORG_ID)."
  say "  STOPPING. Re-run and PASTE the new key (don't keep the old one)."
  exit 1
else
  say "✗ The ORG key authenticates (HTTP $code) but is NOT an org owner/admin of"
  say "  $ZB_ORG_ID — member keys cannot load artifacts — or this dana"
  say "  predates the isAdmin field. STOPPING. Get an OWNER key, re-run."
  exit 1
fi

say ""
if $LAUNCH; then launch_claude; fi
say "Done. Launch claude with the slot's creds:"
say "  $0 --launch [claude args…]"
say "or directly (from a content-repo root):"
say "  zbb --slot $SLOT exec claude"
say "  (non-prod target: first export KNOWLEDGE_MCP_URL=\"$(knowledge_url "$(slot_get ZB_PLATFORM_URL)")\")"
say "First interactive session per repo shows a one-time .mcp.json trust prompt;"
say "headless runs load it without prompting."
