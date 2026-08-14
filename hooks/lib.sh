#!/usr/bin/env bash
# Shared config, programme resolution, and output helpers for the programme hooks.
#
# Programme identity resolves from the branch rather than from a stored "active" value because the
# Stop hook runs with no user present to disambiguate — so both hooks and commands must share one
# tree-derived algorithm.

SC_JSON=""
if command -v jq >/dev/null 2>&1; then SC_JSON=jq
elif command -v python3 >/dev/null 2>&1; then SC_JSON=python3
fi

_sc_str() { # _sc_str <json> <key>
  [ -n "$SC_JSON" ] || { printf ''; return 0; }
  case "$SC_JSON" in
    jq) printf '%s' "$1" | jq -r --arg k "$2" '.[$k] // empty' 2>/dev/null || printf '' ;;
    python3)
      printf '%s' "$1" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
v=d.get(sys.argv[1])
print(v if isinstance(v,str) else "")' "$2" 2>/dev/null || printf ''
      ;;
  esac
}

_sc_arr() { # _sc_arr <json> <key>  -> newline separated
  [ -n "$SC_JSON" ] || { printf ''; return 0; }
  case "$SC_JSON" in
    jq)
      printf '%s' "$1" \
        | jq -r --arg k "$2" '(.[$k] // []) | map(select(type == "string")) | .[]' 2>/dev/null \
        || printf ''
      ;;
    python3)
      printf '%s' "$1" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print("\n".join(x for x in (d.get(sys.argv[1]) or []) if isinstance(x,str)))' "$2" 2>/dev/null || printf ''
      ;;
  esac
}

sc_load_input() {
  local raw
  raw=$(cat)
  SC_SESSION_ID=$(_sc_str "$raw" session_id)
  SC_CWD=$(_sc_str "$raw" cwd)
  SC_EVENT=$(_sc_str "$raw" hook_event_name)
  SC_SOURCE=$(_sc_str "$raw" source)
  export SC_SESSION_ID SC_CWD SC_EVENT SC_SOURCE
}

sc_project_root() {
  local start=${CLAUDE_PROJECT_DIR:-${SC_CWD:-$PWD}}
  git -C "$start" rev-parse --show-toplevel 2>/dev/null || printf ''
}

_sc_config_raw() {
  local root
  root=$(sc_project_root)
  [ -n "$root" ] && [ -f "$root/.claude/session-continuity.json" ] \
    && cat "$root/.claude/session-continuity.json" || printf '{}'
}

sc_config_get() { _sc_str "$(_sc_config_raw)" "$1"; }
sc_config_arr() { _sc_arr "$(_sc_config_raw)" "$1"; }

sc_docs_root() {
  local v
  v=$(sc_config_get docsRoot)
  printf '%s' "${v:-docs}"
}

sc_programmes_dir() {
  local root
  root=$(sc_project_root)
  [ -n "$root" ] || { printf ''; return 0; }
  printf '%s/%s/programmes' "$root" "$(sc_docs_root)"
}

sc_is_inert() {
  local d
  d=$(sc_programmes_dir)
  [ -z "$d" ] || [ ! -d "$d" ]
}

sc_current_branch() {
  local root
  root=$(sc_project_root)
  [ -n "$root" ] || { printf ''; return 0; }
  git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || printf ''
}

# Explicit arg > INDEX.md row matching the current branch > sole programme dir > empty.
sc_resolve_programme() {
  [ -n "${1:-}" ] && { printf '%s' "$1"; return 0; }
  local dir branch match count sole
  dir=$(sc_programmes_dir)
  [ -n "$dir" ] && [ -d "$dir" ] || { printf ''; return 0; }

  branch=$(sc_current_branch)
  if [ -n "$branch" ] && [ -f "$dir/INDEX.md" ]; then
    match=$(awk -F'|' -v b="$branch" '
      /^\|/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $3); gsub(/^[ \t]+|[ \t]+$/, "", $4)
        if ($4 == b && $3 != "closed" && $2 != "programme" && $2 !~ /^-+$/) { print $2; exit }
      }' "$dir/INDEX.md")
    [ -n "$match" ] && { printf '%s' "$match"; return 0; }
  fi

  count=0
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    count=$((count + 1))
    sole=$(basename "$d")
  done
  if [ "$count" -eq 1 ]; then
    [ "$(_sc_index_status "$dir" "$sole")" = "closed" ] && { printf ''; return 0; }
    printf '%s' "$sole"
    return 0
  fi
  printf ''
}

# Status column for a slug's INDEX.md row, trimmed; empty if there is no INDEX.md or no row —
# an absent row is not "closed", so a programme dir with no index still resolves as before.
_sc_index_status() {
  local dir=$1 slug=$2
  [ -f "$dir/INDEX.md" ] || { printf ''; return 0; }
  awk -F'|' -v s="$slug" '
    /^\|/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $3)
      if ($2 == s) { print $3; exit }
    }' "$dir/INDEX.md"
}

sc_ledger_path() {
  local dir
  dir=$(sc_programmes_dir)
  [ -n "$dir" ] && [ -n "${1:-}" ] || { printf ''; return 0; }
  printf '%s/%s/ledger.md' "$dir" "$1"
}

_sc_state_file() {
  local base key
  base="${XDG_STATE_HOME:-$HOME/.local/state}/claude-programme"
  mkdir -p "$base" 2>/dev/null || true
  key=$(printf '%s' "${SC_SESSION_ID:-unknown}" | tr -c 'A-Za-z0-9._-' '_')
  printf '%s/%s.state' "$base" "$key"
}

sc_state_get() {
  local f
  f=$(_sc_state_file)
  [ -f "$f" ] || { printf ''; return 0; }
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$f"
}

_sc_state_write() {
  local f=$1 key=$2 val=$3 tmp
  tmp="${f}.tmp$$.$RANDOM"
  { [ -f "$f" ] && grep -v "^$key=" "$f" || true; } >"$tmp" 2>/dev/null
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$f"
}

# Concurrent hook invocations (e.g. overlapping Stop/SessionStart events) share one state file per
# session; without a lock the read-modify-write below races and silently drops updates. flock is
# not on macOS by default — when it's missing we fall back to the unlocked write (no worse than
# before), but when it IS present and a wait times out we skip the write entirely rather than
# writing unlocked, since writing unlocked while a concurrent writer holds the lock is exactly the
# lost-update this exists to prevent. The wait is bounded so a hook never blocks a turn on it.
sc_state_set() {
  local f
  f=$(_sc_state_file)
  if command -v flock >/dev/null 2>&1; then
    ( flock -w 5 200 || exit 0; _sc_state_write "$f" "$1" "$2" ) 200>"${f}.lock"
  else
    _sc_state_write "$f" "$1" "$2"
  fi
}

_sc_jsonstr() {
  case "$SC_JSON" in
    jq) printf '%s' "$1" | jq -Rs . ;;
    python3) printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' ;;
    *) printf '""' ;;
  esac
}

sc_emit_system_message() {
  [ -n "$SC_JSON" ] || return 0
  printf '{"systemMessage":%s}\n' "$(_sc_jsonstr "$1")"
}

# SessionStart is the only event confirmed to be a member of the hookSpecificOutput union; emitting
# this shape for Stop fails validation silently. See the design doc's "Why those channels".
sc_emit_additional_context() {
  [ -n "$SC_JSON" ] || return 0
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' \
    "$1" "$(_sc_jsonstr "$2")"
}
