#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-session-start"
REPO=$(make_repo); cd "$REPO"   # make_repo exports XDG_STATE_HOME outside the repo

run_hook session-start.sh "$(payload SessionStart s1 startup)" "$REPO"
assert_eq "0" "$RC" "inert repo exits 0"
assert_empty "$OUT" "inert repo injects nothing"

add_programme "$REPO" "headless" "main"
HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)

run_hook session-start.sh "$(payload SessionStart s2 startup)" "$REPO"
assert_contains "$OUT" "additionalContext" "emits additionalContext"
assert_contains "$OUT" "SessionStart" "names the event in hookSpecificOutput"
assert_contains "$OUT" "Current position" "injects the current-position section"
assert_contains "$OUT" "The position line." "injects the position body"
assert_contains "$OUT" "The arc" "injects the arc"
assert_contains "$OUT" "The goal line." "injects the arc body"
assert_not_contains "$OUT" "seeded illustrations" "strips the template's HTML comments"
assert_eq "$HEAD_SHA" "$(cat "$STATE_HOME/claude-programme/s2.state" | sed -n 's/^baseline=//p')" \
  "stamps the baseline sha"

# Compact re-injects too — that is the whole point of the channel.
run_hook session-start.sh "$(payload SessionStart s3 compact)" "$REPO"
assert_contains "$OUT" "Current position" "re-injects after compaction"

# Baseline is stamped once per session: a compact must not reset the window.
git -C "$REPO" commit -q --allow-empty -m "later commit"
run_hook session-start.sh "$(payload SessionStart s2 compact)" "$REPO"
assert_eq "$HEAD_SHA" "$(cat "$STATE_HOME/claude-programme/s2.state" | sed -n 's/^baseline=//p')" \
  "compact does not re-stamp an existing baseline"

HEAD_SHA2=$(git -C "$REPO" rev-parse HEAD)

# --- Stamp-verification: retry and give-up paths.
#
# sc_state_set's own bounded flock wait is 5s (lib.sh). Holding the lock ourselves for longer than
# that forces a real, not simulated, write failure — the same code path production hits under
# contention, not a stand-in for it. `_sc_state_file` is lib.sh-private, but replicating its hashing
# by hand here would drift silently if lib.sh ever changes it.
. "$PLUGIN_ROOT/hooks/lib.sh"

hold_lock() { # hold_lock <session_id> <seconds> — occupies sc_state_set's lock sibling
  local f
  f=$(SC_SESSION_ID="$1" _sc_state_file)
  ( flock 200; sleep "$2" ) 200>"${f}.lock" &
}

# Retry path: held past the first attempt's 5s bound (so it is skipped, not written) but released
# in time for the hook's own retry to land it inside ITS 5s bound.
hold_lock s4 7
sleep 0.2
run_hook session-start.sh "$(payload SessionStart s4 startup)" "$REPO"
wait
assert_eq "0" "$RC" "retry path stays non-blocking"
assert_eq "$HEAD_SHA2" "$(SC_SESSION_ID=s4 sc_state_get baseline)" "retry recovers the stamp"
assert_empty "$ERR" "no degradation message once the retry succeeds"

# Give-up path: held past both attempts' bounds (first 5s + retry's 5s).
hold_lock s5 13
sleep 0.2
run_hook session-start.sh "$(payload SessionStart s5 startup)" "$REPO"
wait
assert_eq "0" "$RC" "give-up path stays non-blocking"
assert_empty "$(SC_SESSION_ID=s5 sc_state_get baseline)" "give-up path leaves no stamp"
assert_contains "$ERR" "baseline" "give-up is reported on stderr"
assert_contains "$OUT" "Current position" "give-up path still re-injects the position"

# A ledger written before the arc existed must still inject its position, unchanged. Strip the arc
# back off the fixture rather than building a second one — the two shapes then differ in exactly the
# thing under test. The rewrite goes via a temp file that is moved away in the same command, so it
# never shows up in the `git status --porcelain` the other hooks read.
L="$REPO/docs/programmes/headless/ledger.md"
sed -n '/^## Current position/,$p' "$L" >"$L.tmp" && mv "$L.tmp" "$L"
run_hook session-start.sh "$(payload SessionStart s9 startup)" "$REPO"
assert_contains "$OUT" "The position line." "a pre-arc ledger still injects its position"
assert_not_contains "$OUT" "The goal line." "and injects no arc, because it has none"

rm -rf "$REPO" "$STATE_HOME"
finish
