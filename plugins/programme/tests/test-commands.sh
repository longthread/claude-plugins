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
MODE=$(read_c mode.md)

for f in init resume handoff status mode; do
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

# --- handoff: the one question that makes a later phase's work refusable, and the row flip ---
assert_contains "$HANDOFF" "cheaper taken now" "handoff: asks whether later-phase work should be pulled forward"
assert_contains "$HANDOFF" "The arc is corrected here or nowhere" "handoff: the arc is reconciled at handoff"
assert_contains "$HANDOFF" "becomes \`done\`" "handoff: closing a phase flips its arc row"
assert_contains "$HANDOFF" "name which rows you read to conclude that" \
  "handoff: a no-change answer to question 5 must still cite the rows"

# --- status reads progress off the arc, and defers on WHY the Archive index is not a phase count ---
assert_contains "$STATUS" "\`## The arc\` first" "status: reads the arc first"
assert_contains "$STATUS" "never read what has closed by counting" \
  "status: stops treating Archive index rows as a phase count"
assert_contains "$STATUS" "that table's own note says why" "status: defers to the ledger for the Archive index's grain"
assert_not_contains "$STATUS" "moved out purely for length" \
  "status: does NOT restate why the Archive index is not a phase count"

# --- the arc's two lifecycle edges: adopting it, and spending it at closure ---
assert_contains "$HANDOFF" "Every arc row must be \`done\` first" \
  "handoff: a programme cannot close with a row still current or planned"
assert_contains "$HANDOFF" "Programmes that predate the section" \
  "handoff: a ledger with no arc gets one written"

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
for pair in "handoff:$HANDOFF" "status:$STATUS" "mode:$MODE"; do
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

# --- a shared branch is the same case as no match: list and ask, answered by a re-run ---
assert_contains "$RESUME" "Several open rows on the current branch are the same case as none" \
  "resume: a shared branch is list-and-ask, never first match"
assert_contains "$RESUME" "re-running \`/programme:resume <name>\`" \
  "resume: the answer is a re-run, which is what pins the session"
for other in "$INIT" "$HANDOFF" "$STATUS"; do
  assert_not_contains "$other" "Several open rows on the current branch" \
    "the shared-branch rule lives only in resume.md"
done

# --- the dependency check and the column rule live in mode.md only ---
assert_contains "$MODE" "The herdr dependency check passes only if all three hold" "mode: homes the dependency check"
assert_contains "$MODE" "command -v herdr" "mode: check 1, the binary"
assert_contains "$MODE" "herdr status" "mode: check 2, a running server"
assert_contains "$MODE" "this session's own list of available skills" "mode: check 3, the skill is usable here"
assert_contains "$MODE" "add it as the **last** column" "mode: homes how a missing column is added"
assert_contains "$MODE" "do not commit" "mode: the switch is not a commit"
for other in "$INIT" "$RESUME" "$HANDOFF" "$STATUS"; do
  assert_not_contains "$other" "passes only if all three hold" "the dependency check lives only in mode.md"
  assert_not_contains "$other" "add it as the **last** column" "the column rule lives only in mode.md"
done
assert_contains "$INIT" "Which mode" "init: interviews for the mode"
assert_contains "$INIT" "| programmes/<SLUG>/ledger.md | assisted |" "init: the row carries a mode cell"
assert_contains "$STATUS" "the herdr dependency check's three results" "status: reports the check for relaying modes"

# --- resume: the relay's half ---
assert_contains "$RESUME" "otherwise \`PROGRAMME_SLUG\`, when it names a programme directory, wins over the branch" \
  "resume: PROGRAMME_SLUG precedence"
assert_contains "$RESUME" "Resumed programme \"<SLUG>\"" "resume: the fixed opening line"
assert_contains "$RESUME" "proceed into \`Start here\` without asking" "resume: autonomous proceeds"
assert_contains "$RESUME" "run \`/programme:handoff\` yourself when" "resume: autonomous starts its own handoff"
for other in "$INIT" "$HANDOFF" "$STATUS" "$MODE"; do
  assert_not_contains "$other" "otherwise \`PROGRAMME_SLUG\`" "PROGRAMME_SLUG precedence lives only in resume.md"
  assert_not_contains "$other" "run \`/programme:handoff\` yourself" "the autonomous trigger lives only in resume.md"
done

finish
