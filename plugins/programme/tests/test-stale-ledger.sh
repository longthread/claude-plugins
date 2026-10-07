#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-stale-ledger"
REPO=$(make_repo); cd "$REPO"

# Inert: no programmes dir at all.
run_hook stale-ledger.sh "$(payload Stop s1)" "$REPO"
assert_eq "0" "$RC" "inert repo exits 0"
assert_empty "$OUT" "inert repo says nothing"

add_programme "$REPO" "headless" "main"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "add programme"
mkdir -p "$STATE_HOME/claude-programme"

# seed_baseline <session> [sha]. Defaults to CURRENT HEAD, which is what the worktree-scoped cases
# need: seeding them at the original root commit puts an earlier ledger commit inside baseline..HEAD,
# so the guard is correctly silent and the assertion tests nothing. Three cases below were vacuous
# for exactly that reason before this was measured.
seed_baseline() {
  printf 'baseline=%s\n' "${2:-$(git -C "$REPO" rev-parse HEAD)}" \
    >"$STATE_HOME/claude-programme/$1.state"
}

# Code committed, ledger untouched -> warn.
BASE=$(git -C "$REPO" rev-parse HEAD)
seed_baseline s2 "$BASE"
echo "change" >>"$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: change code"
run_hook stale-ledger.sh "$(payload Stop s2)" "$REPO"
assert_eq "0" "$RC" "warning path still exits 0"
assert_contains "$OUT" "systemMessage" "emits a systemMessage"
assert_contains "$OUT" "ledger" "message names the ledger"

# Latched: the same session does not warn twice.
run_hook stale-ledger.sh "$(payload Stop s2)" "$REPO"
assert_empty "$OUT" "latched — silent on the second Stop"

# Ledger committed inside the range -> silent, even though code also moved.
seed_baseline s3
echo "moved" >>"$REPO/docs/programmes/headless/ledger.md"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "docs(ledger): move position"
echo "more" >>"$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: more code"
run_hook stale-ledger.sh "$(payload Stop s3)" "$REPO"
assert_empty "$OUT" "silent when the ledger moved in range"

# Uncommitted code counts too (baseline = HEAD, so the range is empty).
seed_baseline s4
echo "wip" >>"$REPO/src/app.ts"
run_hook stale-ledger.sh "$(payload Stop s4)" "$REPO"
assert_contains "$OUT" "systemMessage" "uncommitted code also warns"
git -C "$REPO" checkout -q -- .

# Uncommitted ledger edit silences it.
seed_baseline s5
echo "wip" >>"$REPO/src/app.ts"
echo "wip note" >>"$REPO/docs/programmes/headless/ledger.md"
run_hook stale-ledger.sh "$(payload Stop s5)" "$REPO"
assert_empty "$OUT" "uncommitted ledger edit silences it"
git -C "$REPO" checkout -q -- .

# Markdown is not code — tracked or untracked, nested or top level.
seed_baseline s6
echo "prose" >"$REPO/docs/notes.md"
run_hook stale-ledger.sh "$(payload Stop s6)" "$REPO"
assert_empty "$OUT" "docs-only change does not warn"
rm -f "$REPO/docs/notes.md"

seed_baseline s8
echo "x" >"$REPO/README.md"
run_hook stale-ledger.sh "$(payload Stop s8)" "$REPO"
assert_empty "$OUT" "untracked top-level .md does not warn"
rm -f "$REPO/README.md"

# Rewritten history: baseline no longer an ancestor -> fall back to the worktree, never crash.
printf 'baseline=%s\n' "0000000000000000000000000000000000000000" \
  >"$STATE_HOME/claude-programme/s7.state"
echo "more" >>"$REPO/src/app.ts"
run_hook stale-ledger.sh "$(payload Stop s7)" "$REPO"
assert_eq "0" "$RC" "unknown baseline exits 0 rather than crashing"
assert_contains "$OUT" "systemMessage" "unknown baseline falls back to the worktree"

# --- Only this session's changes count (fingerprint stamped by the real SessionStart) ---
git -C "$REPO" checkout -q -- . ; git -C "$REPO" clean -qfd -- src
start() { run_hook session-start.sh "$(payload SessionStart "$1" startup)" "$REPO"; }

mkdir -p "$REPO/tool-cache" && echo x >"$REPO/tool-cache/a.ts" && echo x >"$REPO/src/my file.ts"
start f1
run_hook stale-ledger.sh "$(payload Stop f1)" "$REPO"
assert_empty "$OUT" "dirt that predates the session (incl. a path with a space) does not warn"
echo y >"$REPO/tool-cache/b.ts"
run_hook stale-ledger.sh "$(payload Stop f1)" "$REPO"
assert_contains "$OUT" "additionalContext" "a new file inside a pre-existing untracked dir warns"
assert_contains "$OUT" '"hookEventName":"Stop"' "the warning is addressed to the model as Stop context"
assert_contains "$OUT" "systemMessage" "and the user sees it too"
assert_contains "$OUT" "say so in one line" "the warning gives the model a way out"
rm -rf "$REPO/tool-cache" "$REPO/src/my file.ts"

echo pre >>"$REPO/src/app.ts"
start f2
run_hook stale-ledger.sh "$(payload Stop f2)" "$REPO"
assert_empty "$OUT" "a file dirty at start and untouched since does not warn"
echo again >>"$REPO/src/app.ts"
run_hook stale-ledger.sh "$(payload Stop f2)" "$REPO"
assert_contains "$OUT" "additionalContext" "a file dirty at start and edited again warns"
git -C "$REPO" checkout -q -- .

echo note >>"$REPO/docs/programmes/headless/ledger.md"
start f3
echo code >>"$REPO/src/app.ts"
run_hook stale-ledger.sh "$(payload Stop f3)" "$REPO"
assert_contains "$OUT" "additionalContext" "a ledger dirty at start but untouched since is not 'the ledger moved'"
git -C "$REPO" checkout -q -- .

start f4
echo code >>"$REPO/src/app.ts"
run_hook stale-ledger.sh "$(payload Stop f4 startup '"stop_hook_active":true')" "$REPO"
assert_empty "$OUT" "stop_hook_active suppresses the guard"
run_hook stale-ledger.sh "$(payload Stop f4)" "$REPO"
assert_contains "$OUT" "additionalContext" "and does not spend the latch"
git -C "$REPO" checkout -q -- .

# A staged rename straddling the code pathspec (.md -> .ts) that predates the session is not a change.
echo "notes" >"$REPO/notes.md"
git -C "$REPO" add notes.md && git -C "$REPO" commit -qm "notes"
git -C "$REPO" mv notes.md src/notes.ts
start r1
run_hook stale-ledger.sh "$(payload Stop r1)" "$REPO"
assert_empty "$OUT" "a rename across the pathspec staged before the session does not warn"
git -C "$REPO" mv src/notes.ts notes.md

start r2
echo prose >"$REPO/docs/new notes.md"
run_hook stale-ledger.sh "$(payload Stop r2)" "$REPO"
assert_empty "$OUT" "fingerprinted: a new markdown file outside the code pathspec does not warn"
echo code >"$REPO/src/new file.ts"
run_hook stale-ledger.sh "$(payload Stop r2)" "$REPO"
assert_contains "$OUT" "additionalContext" "fingerprinted: a new code file with a space in its path warns"
rm -f "$REPO/docs/new notes.md" "$REPO/src/new file.ts"
start r3
echo code >>"$REPO/src/app.ts"; echo note >>"$REPO/docs/programmes/headless/ledger.md"
run_hook stale-ledger.sh "$(payload Stop r3)" "$REPO"
assert_empty "$OUT" "fingerprinted: a ledger edited this session silences it"
git -C "$REPO" checkout -q -- .

# Over the cap: whole-tree comparison, said once on stderr, never blocking.
mkdir -p "$REPO/gen" && for i in 1 2 3 4; do echo "$i" >"$REPO/gen/f$i.ts"; done
SC_DIRT_CAP=3 run_hook session-start.sh "$(payload SessionStart f5 startup)" "$REPO"
assert_contains "$ERR" "more than 3 dirty paths" "overflow is reported once on stderr"
run_hook stale-ledger.sh "$(payload Stop f5)" "$REPO"
assert_contains "$OUT" "additionalContext" "overflow falls back to the whole working tree"
rm -rf "$REPO/gen"
start f6
mkdir -p "$REPO/gen" && for i in 1 2 3 4; do echo "$i" >"$REPO/gen/f$i.ts"; done
SC_DIRT_CAP=3 run_hook stale-ledger.sh "$(payload Stop f6)" "$REPO"
assert_contains "$OUT" "additionalContext" "a tree that overflows only at Stop counts as changed code"
rm -rf "$REPO/gen"

# The session moved to another worktree: the fingerprint is not comparable; committed range only.
WT=$(mktemp -d); rmdir "$WT"
git -C "$REPO" worktree add -q -b feat/moved "$WT"
start m1
echo wip >>"$WT/src/app.ts"
run_hook stale-ledger.sh "$(PAYLOAD_CWD="$WT" payload Stop m1)" "$WT" "$REPO"
assert_empty "$OUT" "moved root: uncommitted dirt in the new root is not compared"
git -C "$WT" commit -qam "feat: code in the worktree"
run_hook stale-ledger.sh "$(PAYLOAD_CWD="$WT" payload Stop m1)" "$WT" "$REPO"
assert_contains "$OUT" "additionalContext" "moved root: the committed range still counts"
git -C "$REPO" worktree remove --force "$WT"

# Ambiguous programme: silent — it cannot ask, and naming the wrong one is the bug.
A=$(make_repo)
add_programme "$A" "one" "main"; add_programme "$A" "two" "main"
git -C "$A" add -A && git -C "$A" commit -qm "two programmes"
run_hook session-start.sh "$(PAYLOAD_CWD="$A" payload SessionStart a1 startup)" "$A"
echo code >>"$A/src/app.ts"
run_hook stale-ledger.sh "$(PAYLOAD_CWD="$A" payload Stop a1)" "$A"
assert_empty "$OUT" "an ambiguous programme keeps the guard silent"
rm -rf "$A"

rm -rf "$REPO" "$STATE_HOME"
finish
