#!/usr/bin/env bash
# SessionStart — stamp the comparison baseline, and re-inject the programme's arc and current position.
#
# Injecting on source=compact is the load-bearing case: after compaction the model has lost the
# ledger from context, and SessionStart is the only event confirmed to carry additionalContext.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] || exit 0

root=$(sc_project_root); [ -n "$root" ] || exit 0

# Stamp once per session. Re-stamping on compact would reset the window mid-session, which is
# precisely the long session the Stop guard exists for.
if [ -z "$(sc_state_get baseline)" ]; then
  head=$(git -C "$root" rev-parse HEAD 2>/dev/null || printf '')
  if [ -n "$head" ]; then
    sc_state_set baseline "$head"
    # sc_state_set can silently skip its write on a lock timeout, returning 0 either way — a lost
    # stamp here degrades the Stop guard to working-tree-only comparison with nothing reported
    # anywhere. Verify the write landed and retry once before giving up.
    if [ "$(sc_state_get baseline)" != "$head" ]; then
      sc_state_set baseline "$head"
    fi
    if [ "$(sc_state_get baseline)" != "$head" ]; then
      printf 'programme: SessionStart could not stamp the comparison baseline after a retry — the Stop guard will fall back to working-tree-only comparison this session.\n' >&2
    fi
  fi
fi

slug=$(sc_resolve_programme); [ -n "$slug" ] || exit 0
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
