#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-pre-compact"
REPO=$(make_repo); cd "$REPO"
add_programme "$REPO" "headless" "main"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "add programme"
mkdir -p "$STATE_HOME/claude-programme"

seed_baseline() {
  printf 'baseline=%s\n' "${2:-$(git -C "$REPO" rev-parse HEAD)}" \
    >"$STATE_HOME/claude-programme/$1.state"
}

# No baseline stamped -> silent, non-blocking.
run_hook pre-compact.sh "$(payload PreCompact s1)" "$REPO"
assert_eq "0" "$RC" "no baseline exits 0"
assert_empty "$OUT" "no baseline says nothing"

# Code committed, ledger untouched -> warns. Must emit a top-level systemMessage and MUST NOT
# emit hookSpecificOutput: PreCompact is not a confirmed member of that union, and this is the
# constraint that fails silently (not a validation error) if the shape drifts back.
BASE=$(git -C "$REPO" rev-parse HEAD)
seed_baseline s2 "$BASE"
echo "change" >>"$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: change code"
run_hook pre-compact.sh "$(payload PreCompact s2)" "$REPO"
assert_eq "0" "$RC" "warning path still exits 0"
assert_contains "$OUT" "systemMessage" "emits a systemMessage"
assert_not_contains "$OUT" "hookSpecificOutput" "never emits hookSpecificOutput"

# Ledger committed inside the range -> silent, even though code also moved.
seed_baseline s3
echo "moved" >>"$REPO/docs/programmes/headless/ledger.md"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "docs(ledger): move position"
echo "more" >>"$REPO/src/app.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat: more code"
run_hook pre-compact.sh "$(payload PreCompact s3)" "$REPO"
assert_empty "$OUT" "silent when the ledger moved in range"

# Rewritten history: baseline no longer an ancestor. Unlike stale-ledger.sh, pre-compact.sh has no
# worktree fallback here — deliberate, since PreCompact is best-effort and not load-bearing. Assert
# silence, not a fallback warning.
printf 'baseline=%s\n' "0000000000000000000000000000000000000000" \
  >"$STATE_HOME/claude-programme/s4.state"
echo "more" >>"$REPO/src/app.ts"
run_hook pre-compact.sh "$(payload PreCompact s4)" "$REPO"
assert_eq "0" "$RC" "unknown baseline exits 0"
assert_empty "$OUT" "unknown baseline stays silent, no worktree fallback"

rm -rf "$REPO" "$STATE_HOME"
finish
