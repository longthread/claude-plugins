#!/usr/bin/env bash
# SessionStart — stamp the comparison baseline, and re-inject the programme's arc and current position.
#
# Injecting on source=compact is the load-bearing case: after compaction the model has lost the
# ledger from context. SessionStart and Stop both carry additionalContext to the model (Stop's
# verified live 2026-10-06, Claude Code 2.1.292); this is the one that fires after a compaction.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] || exit 0

root=$(sc_project_root); [ -n "$root" ] || exit 0

# Other sessions' bookkeeping, a month stale: state, locks, fingerprints and orphaned temp files.
# Only in the plugin's own state dir, and never this session's files — a resumed old session keeps
# its stamps.
state_file=$(_sc_state_file)
find "$(sc_state_dir)" -maxdepth 1 -type f \
  \( -name '*.state' -o -name '*.lock' -o -name '*.dirt' -o -name '*.tmp*' \) \
  ! -name "$(basename "${state_file%.state}")."'*' -mtime +30 -delete 2>/dev/null || true

# stamp <key> <value> <what is lost> — sc_state_set can silently skip its write on a lock timeout,
# returning 0 either way, so a lost stamp would degrade the Stop guard with nothing reported
# anywhere. Verify the write landed, retry once, and say so on stderr if it still did not.
stamp() {
  sc_state_set "$1" "$2"
  [ "$(sc_state_get "$1")" = "$2" ] || sc_state_set "$1" "$2"
  [ "$(sc_state_get "$1")" = "$2" ] && return 0
  printf 'programme: SessionStart could not stamp the %s after a retry — %s\n' "$1" "$3" >&2
}

# Stamp once per session. Re-stamping on compact would reset the window mid-session, which is
# precisely the long session the Stop guard exists for.
if [ -z "$(sc_state_get baseline)" ]; then
  head=$(git -C "$root" rev-parse HEAD 2>/dev/null || printf '')
  [ -n "$head" ] && stamp baseline "$head" \
    'the Stop guard will fall back to working-tree-only comparison this session.'
fi

# The root and the dirt fingerprint, stamped with the baseline's rule: once per session_id, on ANY
# source, never overwritten. Not startup-only — the session after /clear arrives with a NEW
# session_id and source=clear, and it is the most common session there is. The fingerprint file
# itself is the "already stamped" mark: keyed on root instead, a lost root write would re-take the
# fingerprint at the next compaction and absorb everything the session had changed so far.
dirt=$(sc_dirt_file)
if [ ! -f "$dirt" ]; then
  sc_dirt_snapshot "$root" >"$dirt.tmp$$" 2>/dev/null || true
  mv -f "$dirt.tmp$$" "$dirt" 2>/dev/null || true
  stamp root "$root" 'the Stop guard will compare the whole working tree this session.'
  if grep -qx overflow "$dirt" 2>/dev/null; then
    printf 'programme: more than %s dirty paths at session start — the Stop guard compares the whole working tree this session.\n' \
      "${SC_DIRT_CAP:-2000}" >&2
  fi
fi

slug=$(sc_resolve_programme)
if [ -z "$slug" ]; then
  # Ambiguity is a result, not a fallthrough: name every candidate and inject no ledger. Guessing
  # is how every session on a shared branch was handed the same wrong programme.
  cands=$(sc_branch_candidates)
  case "$cands" in
    *$'\n'*)
      list=$(printf '%s\n' "$cands" | sed 's/.*/"&"/' | paste -sd, - | sed 's/,/, /g')
      sc_emit_additional_context SessionStart "Programmes $list all record branch \"$(sc_current_branch)\". None is assumed. Run /programme:resume <name> to pick one for this session."
      ;;
  esac
  exit 0
fi
ledger=$(sc_ledger_path "$slug"); [ -f "$ledger" ] || exit 0

# The arc as well as the position. This channel — not `/programme:resume` — is what puts a ledger
# into a session's working set: it fires on every start and after every compaction, with no command
# run. Injecting only the position is what made phase-local reasoning the default.
# HTML comments are dropped: they instruct whoever writes the file and are noise to a reader.
sc_section() { # sc_section <heading> <file> — the heading and its body, to the next `## `
  awk -v h="$1" '
    grab && /^## / { exit }
    index($0, h) == 1 { grab = 1; print; next }
    !grab { next }
    /<!--/ { skip = 1 }
    skip { if (/-->/) skip = 0; next }
    { print }
  ' "$2"
}

arc=$(sc_section '## The arc' "$ledger")
position=$(sc_section '## Current position' "$ledger")
[ -n "$position" ] || exit 0

# A ledger written before the arc existed injects exactly what it did before.
if [ -n "$arc" ]; then
  body="$arc

$position

The arc above is the programme's; the position is the current phase's."
else
  body=$position
fi

rel_ledger=${ledger#"$root"/}
sc_emit_additional_context SessionStart "Active programme: \"$slug\" — $rel_ledger

$body

This is the ledger's recorded position, not a verified one. Any count, sha, or ahead-of-origin
figure in it may be stale; check the tree before relying on one. The ledger outranks any handoff
document — if they disagree, correct the handoff."
exit 0
