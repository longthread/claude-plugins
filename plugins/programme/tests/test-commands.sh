#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-commands"
C="$PLUGIN_ROOT/commands"

# Fold newlines to spaces as well as squeezing runs of spaces. A formatter rewraps prose at 100
# columns, so any asserted phrase can acquire a newline mid-sentence. That breaks assert_contains
# (a visible failure) but it also breaks assert_not_contains SILENTLY — a rule restated across a
# wrap would read as correctly single-homed. The negative assertions below are the ones enforcing
# single-homing, so this fold is what makes them mean anything.
read_c() { tr '\n' ' ' <"$C/$1" 2>/dev/null | tr -s ' ' || printf ''; }

INIT=$(read_c init.md)
RESUME=$(read_c resume.md)
HANDOFF=$(read_c handoff.md)
STATUS=$(read_c status.md)

for f in init resume handoff status; do
  assert_contains "$(read_c $f.md)" "description:" "$f: has frontmatter description"
done

# --- init seeds the arc, or it ships permanently empty ---
assert_contains "$INIT" "What are its phases, in order, and which one are you starting?" \
  "init: interviews for the phase map"
assert_contains "$INIT" "a one-row arc is honest" "init: an unknown decomposition still yields a row"
assert_contains "$INIT" "the output that means the WHOLE programme is done" \
  "init: interviews for the programme's terminal condition, distinct from the phase's"

# --- resume: the arc frames the phase rather than trailing it ---
assert_contains "$RESUME" "starting with \`## The arc\`" "resume: reads the arc before the position"
assert_contains "$RESUME" "every phase still \`planned\`" "resume: its report names what remains"

# --- status is read-only, and that is the property the whole command rests on ---
assert_contains "$STATUS" "writes nothing" "status: states it writes nothing"
assert_contains "$STATUS" "/programme:handoff" "status: names handoff as the thing that writes"

# A status that repairs what it inspects cannot report on the record's honesty. Pin the reason,
# not just the rule: a future edit that adds "and fix it while you are there" has to delete this.
assert_contains "$STATUS" "cannot be used to find out whether the record is honest" \
  "status: pins WHY it must not write"

# --- gates are expensive; default must be not-run, with an opt-in ---
assert_contains "$STATUS" "do not run these" "status: gates are not run by default"
assert_contains "$STATUS" "--gates" "status: gates are opt-in by flag"
assert_contains "$STATUS" "not re-run" "status: must say gates were not re-run"

# --- the State table is the section that earns the command ---
assert_contains "$STATUS" "verify with" "status: runs the State table's verify-with commands"
assert_contains "$STATUS" "unverifiable" "status: a missing verify command is reported, not guessed"

# --- deferred rows block closure; a bare count does not carry that ---
assert_contains "$STATUS" "cannot be closed" "status: says open deferred rows block closure"

# --- single-homing: resolution lives in resume.md, and nowhere else ---
assert_contains "$RESUME" "Match the current branch against the" "resume: homes the resolution algorithm"
assert_contains "$RESUME" "status" "resume: homes the closed-status skip rule"
for pair in "handoff:$HANDOFF" "status:$STATUS"; do
  name=${pair%%:*}
  body=${pair#*:}
  assert_contains "$body" "resolve as \`/programme:resume\` does" "$name: defers resolution to resume"
  assert_not_contains "$body" "Match the current branch against the" "$name: does NOT restate resolution"
done

# --- single-homing: the archive threshold is a number, and it lives in the ledger template ---
assert_contains "$(tr -s ' ' <"$PLUGIN_ROOT/templates/ledger.md")" "250" "ledger template: homes the threshold"
assert_not_contains "$STATUS" "250" "status: does NOT restate the archive threshold"
assert_contains "$STATUS" "threshold stated in its own header" "status: defers to the header for the threshold"

# --- single-homing: how-to-write rules stay in the ledger template ---
assert_not_contains "$STATUS" "Correct in place" "status: does NOT restate the correct-in-place rule"
assert_not_contains "$STATUS" "Absolute dates" "status: does NOT restate the dates rule"

finish
