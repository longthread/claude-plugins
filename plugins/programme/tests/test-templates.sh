#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-templates"
T="$PLUGIN_ROOT/templates"

# Fold newlines to spaces, then squeeze runs of spaces. Two formatter behaviours make this
# necessary, and the second is the dangerous one:
#
#   padding — table headers are padded to the widest cell, so `| claim | value |` becomes
#   `| claim | value   |`. Measured: this happened to NEXT-SESSION.md's State table.
#
#   rewrapping — prose is rewrapped at the column limit, so an asserted phrase can acquire a newline
#   mid-sentence. That breaks assert_contains visibly, but breaks assert_not_contains SILENTLY: a
#   rule restated across a wrap reads as correctly single-homed. The negative assertions below are
#   the entire enforcement of single-homing, so without this fold they can pass while proving
#   nothing.
read_t() { tr '\n' ' ' <"$T/$1" 2>/dev/null | tr -s ' ' || printf ''; }

L=$(read_t ledger.md)
N=$(read_t NEXT-SESSION.md)
D=$(read_t deferred.md)
W=$(read_t deferred-work.md)
I=$(read_t INDEX.md)
C=$(read_t CLAUDE-pointer.md)

# --- ledger.md: HOW to write, as prose; everything else as columns ---
assert_contains "$L" "Correct in place" "ledger: correct-in-place rule"
assert_contains "$L" "UNVERIFIED" "ledger: cite-or-flag rule"
assert_contains "$L" "Absolute dates" "ledger: absolute-dates rule"
assert_contains "$L" "250" "ledger: archive threshold"
assert_contains "$L" "## Current position" "ledger: position section"
assert_contains "$L" "| gate | command | last run | result | trust |" "ledger: gates table carries trust"
assert_contains "$L" "| date | decision | who | why |" "ledger: decisions table carries who+why"
assert_contains "$L" "| opened | fork | options | what would settle it |" "ledger: forks table forces a settler and an opened date"
assert_contains "$L" "| date | phase | file |" "ledger: archive index table"

# --- the arc: the one section that is neither rewritten at handoff nor moved by archiving ---
assert_contains "$L" "## The arc" "ledger: the arc section exists"
assert_contains "$L" "**Goal:**" "ledger: the arc carries the programme's goal"
assert_contains "$L" "the programme's, not the phase's" "ledger: the arc's terminal condition is scoped to the programme"
assert_contains "$L" "| phase | status | what it delivers |" "ledger: the arc is a table with a status column"
assert_contains "$L" "exactly one row is \`current\`" "ledger: the arc's status vocabulary is pinned"
assert_contains "$L" "handoff does NOT rewrite and archiving does NOT move" "ledger: the arc states why it is durable"
assert_contains "$L" "Row count is NOT a phase count" "ledger: the Archive index states its own grain"

# The phase-level terminal condition stays distinct from the programme-level one. Both use the same
# Command/Expected-output schema deliberately — the scope line is the only thing separating them, so
# it has to live in exactly one of the two files.
assert_contains "$N" "once this phase is done" "prompt: its terminal condition is the PHASE's"
assert_not_contains "$N" "not the phase's" "prompt does NOT restate the programme-level scope"

# Ordering is invisible to read_t, which folds the file to one line. The arc's whole claim is that
# it frames the position rather than trailing it, and placement is the only thing making that true —
# so this check reads the file unfolded. `|| true` because grep exits 1 on no match and this file
# runs under `set -e`, which would otherwise kill the suite instead of reporting the failure.
# `||` binds to the whole pipeline, not just `cut` — verified in this shell, both with and without
# a match. Do not "fix" this into a brace group; it already covers the grep.
arc_ln=$(grep -n '^## The arc$' "$T/ledger.md" | head -1 | cut -d: -f1 || true)
pos_ln=$(grep -n '^## Current position' "$T/ledger.md" | head -1 | cut -d: -f1 || true)
if [ -n "$arc_ln" ] && [ -n "$pos_ln" ] && [ "$arc_ln" -lt "$pos_ln" ]; then
  ord=above
else
  ord="arc=${arc_ln:-missing} pos=${pos_ln:-missing}"
fi
assert_eq "above" "$ord" "ledger: the arc sits ABOVE Current position"

# --- CLAUDE-pointer.md: WHEN to write, and cross-file precedence ---
assert_contains "$C" "not at session end" "pointer: cadence is here"
assert_contains "$C" "a gate runs and produces a number" "pointer: a concrete trigger"
assert_contains "$C" "outranks" "pointer: ledger precedence"
assert_contains "$C" "INDEX.md" "pointer: how to resolve the programme"
assert_contains "$C" "NEXT-SESSION.md" "pointer: names NEXT-SESSION.md"

# --- NEXT-SESSION.md: observables and re-derivable figures, as schema ---
assert_contains "$N" "Replaced wholesale" "prompt: replace rule"
assert_contains "$N" "**Command:**" "prompt: terminal condition is a command"
assert_contains "$N" "**Expected output:**" "prompt: terminal condition is checkable"
assert_contains "$N" "| claim | value | verify with |" "prompt: every figure carries its check"

# --- deferred tables: fix shape as schema, not prose ---
assert_contains "$D" "| item | current behaviour | fix shape | why deferred |" "deferred: row schema"
assert_contains "$D" "cannot be closed" "deferred: promotion obligation"
assert_contains "$W" "current behaviour | fix shape" "deferred-work: row schema"
assert_contains "$W" "promoted from" "deferred-work: promotion provenance"

assert_contains "$I" "| programme | status | branch | ledger |" "INDEX: parsed header row"

# --- session-continuity.json: exact key set, so a duplicated or orphaned key doesn't hide in a
# format the string-based checks above never read. This is how "gates": [] survived — it duplicated
# the ledger's Gates table from inside a .json, outside every assert_contains/not_contains above. ---
if command -v jq >/dev/null 2>&1; then
  SC_KEYS=$(jq -Sr 'keys | join(",")' <"$T/session-continuity.json" 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  SC_KEYS=$(python3 -c 'import json,sys; print(",".join(sorted(json.load(sys.stdin))))' \
    <"$T/session-continuity.json" 2>/dev/null)
else
  SC_KEYS=""
fi
assert_eq "compareBranch,docsRoot" "$SC_KEYS" "session-continuity.json: exact key set"

# --- single-home: no file restates a rule that lives in another ---
assert_not_contains "$L" "not at session end" "ledger does NOT restate the cadence"
assert_not_contains "$L" "outranks" "ledger does NOT restate precedence"
assert_not_contains "$L" "fix shape" "ledger does NOT restate the deferred rule"
assert_not_contains "$C" "Correct in place" "pointer does NOT restate how-to-write"
assert_not_contains "$N" "Correct in place" "prompt does NOT restate how-to-write"
assert_not_contains "$D" "UNVERIFIED" "deferred does NOT restate cite-or-flag"

finish
