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
# The fixture carries BOTH comment shapes deliberately. `seeded illustrations` above sits in a
# single-line comment, so a stripper that only handles `<!-- ... -->` on one line still passes it.
# This phrase is on the THIRD line of the multi-line block, so only a stripper that carries `skip`
# across lines removes it.
assert_not_contains "$OUT" "Edit it only when the decomposition itself changes" \
  "strips a MULTI-LINE HTML comment"
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

# A sibling heading that merely STARTS WITH the target heading must not resume extraction. Before
# the rule order was fixed, `index($0,h)==1` fired on such a heading, re-set `grab`, and ran to EOF,
# silently swallowing the section that followed. No ledger heading is a prefix of another today;
# this is the guard that keeps a future rename from making one.
LP="$REPO/docs/programmes/headless/ledger.md"
cp "$LP" "$LP.orig"
sed -i 's|^## Settled decisions$|## Current position notes\n\nSHOULD NOT BE INJECTED.|' "$LP"
run_hook session-start.sh "$(payload SessionStart s8 startup)" "$REPO"
assert_not_contains "$OUT" "SHOULD NOT BE INJECTED" \
  "a sibling heading prefixed by the target does not resume extraction"
mv "$LP.orig" "$LP"

# A ledger written before the arc existed must still inject its position, unchanged. Strip the arc
# back off the fixture rather than building a second one — the two shapes then differ in exactly the
# thing under test. The rewrite goes via a temp file that is moved away in the same command, so it
# never shows up in the `git status --porcelain` the other hooks read.
L="$REPO/docs/programmes/headless/ledger.md"
sed -n '/^## Current position/,$p' "$L" >"$L.tmp" && mv "$L.tmp" "$L"
run_hook session-start.sh "$(payload SessionStart s9 startup)" "$REPO"
assert_contains "$OUT" "The position line." "a pre-arc ledger still injects its position"
assert_not_contains "$OUT" "The goal line." "and injects no arc, because it has none"

# --- A shared branch: name every candidate, inject no ledger ---
S=$(make_repo)
for p in alpha beta gamma; do add_programme "$S" "$p" "main"; done
run_hook session-start.sh "$(PAYLOAD_CWD="$S" payload SessionStart amb1 startup)" "$S"
assert_contains "$OUT" '\"alpha\", \"beta\", \"gamma\" all record branch \"main\"' \
  "ambiguity names every candidate and the branch"
assert_contains "$OUT" "/programme:resume <name>" "ambiguity says how to pick"
assert_not_contains "$OUT" "The position line." "ambiguity injects no ledger"

S2=$(make_repo)
for p in alpha beta; do add_programme "$S2" "$p" "main"; done
printf '| ghost | active | main | programmes/ghost/ledger.md |\n' >>"$S2/docs/programmes/INDEX.md"
run_hook session-start.sh "$(PAYLOAD_CWD="$S2" payload SessionStart amb2 startup)" "$S2"
assert_contains "$OUT" 'Programmes \"alpha\", \"beta\" all record branch' \
  "two candidates join as a pair, and a stale row is not named"
rm -rf "$S2"

# --- A worktree session gets its own branch's programme ---
R=$(make_repo)
add_programme "$R" "headless" "main"
git -C "$R" add -A && git -C "$R" commit -qm "add programme"
WT=$(mktemp -d); rmdir "$WT"
git -C "$R" worktree add -q -b feat/wt "$WT"
add_programme "$WT" "wtprog" "feat/wt"
run_hook session-start.sh "$(PAYLOAD_CWD="$WT" payload SessionStart wt1 startup)" "$WT" "$R"
assert_contains "$OUT" 'Active programme: \"wtprog\"' \
  "a session in a worktree is injected the worktree's programme, not the main checkout's"
git -C "$R" worktree remove --force "$WT"
rm -rf "$S" "$R"

# --- Stamp root + dirt fingerprint for a fresh session, on any source; never overwrite ---
C=$(make_repo)
add_programme "$C" "headless" "main"
git -C "$C" add -A && git -C "$C" commit -qm "add programme"
mkdir -p "$C/tool-cache" && echo x >"$C/tool-cache/a.ts"
git -C "$C" mv src/app.ts src/main.ts          # a staged rename: two NUL tokens in -z output
run_hook session-start.sh "$(PAYLOAD_CWD="$C" payload SessionStart c1 clear)" "$C"
assert_eq "$C" "$(SC_SESSION_ID=c1 sc_state_get root)" "a fresh session arriving with source=clear is stamped"
assert_eq "$(git -C "$C" rev-parse HEAD)" "$(SC_SESSION_ID=c1 sc_state_get baseline)" \
  "the clear-source stamp includes the baseline"
D=$(SC_SESSION_ID=c1 sc_dirt_file)
assert_contains "$(cat "$D")" $'??\ttool-cache/a.ts\t' "the fingerprint lists a file inside an untracked dir (-uall)"
assert_contains "$(cat "$D")" $'R \tsrc/main.ts\t' "a rename is one entry under its new path"
assert_not_contains "$(cat "$D")" $'\tsrc/app.ts\t' "a rename's old-path token is consumed, not misread as an entry"
BEFORE=$(cat "$D")
echo y >"$C/tool-cache/b.ts"
run_hook session-start.sh "$(PAYLOAD_CWD="$C" payload SessionStart c1 compact)" "$C"
assert_eq "$BEFORE" "$(cat "$D")" "compact on a stamped session does not rewrite the fingerprint"

# A lost root write must never re-fingerprint mid-session: the .dirt file is the "stamped" mark.
F=$(SC_SESSION_ID=c1 _sc_state_file)
grep -v '^root=' "$F" >"$F.x"; mv "$F.x" "$F"
echo z >"$C/tool-cache/c.ts"
run_hook session-start.sh "$(PAYLOAD_CWD="$C" payload SessionStart c1 compact)" "$C"
assert_eq "$BEFORE" "$(cat "$D")" "compact with root missing but .dirt present does not rewrite .dirt"
rm -rf "$C"

# --- SessionStart prunes other sessions' state older than 30 days, and only that ---
P=$(make_repo)
add_programme "$P" "headless" "main"
git -C "$P" add -A && git -C "$P" commit -qm "add programme"
SD="$STATE_HOME/claude-programme"
for x in old.state old.dirt old.lock; do touch -d '40 days ago' "$SD/$x"; done
for x in fresh.state fresh.dirt; do touch "$SD/$x"; done
OUTSIDE=$(mktemp); touch -d '40 days ago' "$OUTSIDE"
touch -d '40 days ago' "$SD/old.txt"
run_hook session-start.sh "$(PAYLOAD_CWD="$P" payload SessionStart pr1 startup)" "$P"
assert_eq "absent absent absent" \
  "$(for x in old.state old.dirt old.lock; do [ -e "$SD/$x" ] && printf present || printf absent; printf ' '; done | sed 's/ $//')" \
  "old foreign .state/.dirt/.lock files are pruned"
assert_eq "present present" \
  "$(for x in fresh.state fresh.dirt; do [ -e "$SD/$x" ] && printf present || printf absent; printf ' '; done | sed 's/ $//')" \
  "fresh ones are kept"
assert_eq "present present" \
  "$([ -e "$OUTSIDE" ] && printf present || printf absent) $([ -e "$SD/old.txt" ] && printf present || printf absent)" \
  "nothing outside the state dir, nor of another kind, is touched"
assert_eq "$P" "$(SC_SESSION_ID=pr1 sc_state_get root)" "the current session still stamps"
printf 'baseline=keepme\n' >"$SD/pr2.state"; touch -d '40 days ago' "$SD/pr2.state"
run_hook session-start.sh "$(PAYLOAD_CWD="$P" payload SessionStart pr2 resume)" "$P"
assert_eq "keepme" "$(SC_SESSION_ID=pr2 sc_state_get baseline)" "the current session's own old state is never pruned"
rm -rf "$P" "$OUTSIDE"

# --- the mode reaches every session, a relayed successor included ---
MS=$(make_repo)
add_programme "$MS" "solo" "main"
run_hook session-start.sh "$(PAYLOAD_CWD="$MS" payload SessionStart md1 startup)" "$MS"
assert_contains "$OUT" "Mode: assisted" "no mode column injects Mode: assisted"
sed -i 's/| programme | status | branch | ledger |/| programme | status | branch | ledger | mode |/; s/| --------- | ------ | ------ | ------ |/| --------- | ------ | ------ | ------ | ---- |/; s/| solo | active | main | programmes\/solo\/ledger.md |/| solo | active | main | programmes\/solo\/ledger.md | supervised |/' \
  "$MS/docs/programmes/INDEX.md"
run_hook session-start.sh "$(PAYLOAD_CWD="$MS" payload SessionStart md2 startup)" "$MS"
assert_contains "$OUT" "Mode: supervised" "the INDEX mode is injected"
assert_not_contains "$OUT" "Autonomous: when to hand off" "only autonomous points at the hand-off rule"
sed -i 's/| programmes\/solo\/ledger.md | supervised |/| programmes\/solo\/ledger.md | autonomous |/' "$MS/docs/programmes/INDEX.md"
run_hook session-start.sh "$(PAYLOAD_CWD="$MS" payload SessionStart md3 startup)" "$MS"
# OUT is the hook's JSON, so the quotes around the section name arrive escaped.
assert_contains "$OUT" "Mode: autonomous — /programme:resume's \\\"Autonomous: when to hand off\\\" applies" \
  "autonomous points at resume's hand-off rule rather than restating it"
rm -rf "$MS"

rm -rf "$REPO" "$STATE_HOME"
finish
