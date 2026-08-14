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

rm -rf "$REPO" "$STATE_HOME"
finish
