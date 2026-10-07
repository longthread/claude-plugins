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

_sc_bool() { # _sc_bool <json> <key> -> "true" when the key is JSON true, else empty
  [ -n "$SC_JSON" ] || { printf ''; return 0; }
  case "$SC_JSON" in
    jq) printf '%s' "$1" | jq -r --arg k "$2" 'if .[$k] == true then "true" else empty end' 2>/dev/null \
          || printf '' ;;
    python3)
      printf '%s' "$1" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print("true" if d.get(sys.argv[1]) is True else "")' "$2" 2>/dev/null || printf ''
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
  SC_PROMPT=$(_sc_str "$raw" prompt)
  SC_STOP_HOOK_ACTIVE=$(_sc_bool "$raw" stop_hook_active)
  export SC_SESSION_ID SC_CWD SC_EVENT SC_SOURCE SC_PROMPT SC_STOP_HOOK_ACTIVE
}

# The hook input's cwd first: Claude Code fixes CLAUDE_PROJECT_DIR at the directory the session
# STARTED in, while cwd follows the session — into a worktree, or a subdirectory. Resolving from
# CLAUDE_PROJECT_DIR first is how a session working in a worktree was told the main checkout's
# programme, for days, in the field.
sc_project_root() {
  local d top
  for d in "${SC_CWD:-}" "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || continue
    [ -n "$top" ] && { printf '%s' "$top"; return 0; }
  done
  printf ''
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

sc_valid_slug() { # a slug is a directory name, never a path
  case "$1" in ''|.|..) return 1 ;; esac
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

# Open INDEX.md slugs whose branch column equals the current branch, one per line.
sc_branch_candidates() {
  local dir branch
  dir=$(sc_programmes_dir); branch=$(sc_current_branch)
  [ -n "$dir" ] && [ -n "$branch" ] && [ -f "$dir/INDEX.md" ] || { printf ''; return 0; }
  awk -F'|' -v b="$branch" '
    /^\|/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $3); gsub(/^[ \t]+|[ \t]+$/, "", $4)
      if ($4 == b && $3 != "closed" && $2 != "programme" && $2 !~ /^-+$/) print $2
    }' "$dir/INDEX.md"
}

# Explicit arg > session pin > PROGRAMME_SLUG > the UNIQUE open INDEX.md row on the current branch
# > sole open programme dir > empty. Two or more rows on the branch is ambiguity, and ambiguity
# resolves to nothing: the first match is how every session on a shared branch was told the same,
# wrong, programme. A pin or PROGRAMME_SLUG naming a closed programme still resolves — it was asked
# for by name; only the inferred paths skip closed rows.
sc_resolve_programme() {
  [ -n "${1:-}" ] && { printf '%s' "$1"; return 0; }
  local dir pin cands n count sole d
  dir=$(sc_programmes_dir)
  [ -n "$dir" ] && [ -d "$dir" ] || { printf ''; return 0; }

  if [ -n "${SC_SESSION_ID:-}" ]; then
    pin=$(sc_state_get programme)
    if [ -n "$pin" ] && sc_valid_slug "$pin" && [ -d "$dir/$pin" ]; then
      printf '%s' "$pin"; return 0
    fi
  fi
  if [ -n "${PROGRAMME_SLUG:-}" ] && sc_valid_slug "$PROGRAMME_SLUG" && [ -d "$dir/$PROGRAMME_SLUG" ]; then
    printf '%s' "$PROGRAMME_SLUG"; return 0
  fi

  cands=$(sc_branch_candidates)
  n=$(printf '%s' "$cands" | grep -c . || true)
  [ "$n" -eq 1 ] && { printf '%s' "$cands"; return 0; }
  [ "$n" -gt 1 ] && { printf ''; return 0; }

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

# What the Stop guard counts as "code": codePathspec from config, else everything except markdown,
# docsRoot and .claude/. One element per line; callers read it with mapfile.
sc_code_pathspec() {
  local p any=""
  while IFS= read -r p; do
    [ -n "$p" ] && { printf '%s\n' "$p"; any=1; }
  done < <(sc_config_arr codePathspec)
  [ -n "$any" ] || printf '%s\n' '.' ':(exclude)*.md' ":(exclude)$(sc_docs_root)/" ':(exclude).claude/'
}

sc_dirt_file() { local f; f=$(_sc_state_file); printf '%s' "${f%.state}.dirt"; }

# sc_dirt_snapshot <root> [pathspec...] — the working tree's dirt as "XY<TAB>path<TAB>blob" lines.
# -uall so a new file inside an already-untracked directory is its own entry rather than invisible
# behind the directory's single line. -z so spaces and quotes in paths survive; a rename or copy
# carries its old path as a second NUL-terminated token, consumed here so it is not read as an entry.
# Past SC_DIRT_CAP (default 2000) entries it prints `overflow` and stops: a tree that dirty was
# never going to give the guard a clean signal.
sc_dirt_snapshot() {
  local root=$1; shift
  local cap=${SC_DIRT_CAP:-2000} entry xy path blob n=0 i j=0
  local -a xys=() paths=() files=() blobs=()
  [ $# -gt 0 ] || set -- .
  while IFS= read -r -d '' entry; do
    xy=${entry:0:2}; path=${entry:3}
    case $xy in R*|C*) IFS= read -r -d '' _ || true ;; esac
    n=$((n + 1))
    if [ "$n" -gt "$cap" ]; then printf 'overflow\n'; return 0; fi
    xys+=("$xy"); paths+=("$path")
  done < <(git -C "$root" status --porcelain=v1 -z --untracked-files=all -- "$@" 2>/dev/null)

  # One git process for every hash: a process per dirty file would put the stamp's cost on the
  # number of dirty files, inside SessionStart's 15 s timeout.
  for path in "${paths[@]}"; do
    [ -f "$root/$path" ] && [ ! -L "$root/$path" ] && files+=("$path")
  done
  if [ ${#files[@]} -gt 0 ]; then
    mapfile -t blobs < <(printf '%s\n' "${files[@]}" | git -C "$root" hash-object --stdin-paths 2>/dev/null)
  fi
  for i in "${!paths[@]}"; do
    path=${paths[$i]}
    if [ -f "$root/$path" ] && [ ! -L "$root/$path" ]; then
      blob=${blobs[$j]:--}; j=$((j + 1))
    else
      blob=-
    fi
    printf '%s\t%s\t%s\n' "${xys[$i]}" "$path" "$blob"
  done
}

# sc_dirt_new <start-file> <current-lines> — current entries not present, verbatim, at session start.
# Same status, path and content as at start means the session did not touch it.
sc_dirt_new() {
  printf '%s\n' "$2" | grep -vxF -f "$1" | grep . || true
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

# SessionStart and Stop both carry hookSpecificOutput.additionalContext to the model — Stop's was
# verified live on 2026-10-06 (Claude Code 2.1.292): the model's next
# turn read it, and the follow-up Stop arrived with stop_hook_active=true. PreCompact remains
# unverified and keeps a user-only systemMessage.
sc_emit_additional_context() {
  [ -n "$SC_JSON" ] || return 0
  printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' \
    "$1" "$(_sc_jsonstr "$2")"
}

# The Stop warning: to the model as context (one extra turn), and to the user as a systemMessage.
sc_emit_stop_warning() {
  [ -n "$SC_JSON" ] || return 0
  local s; s=$(_sc_jsonstr "$1")
  printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":%s},"systemMessage":%s}\n' "$s" "$s"
}
