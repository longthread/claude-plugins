#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-lib"
REPO=$(make_repo)
cd "$REPO"

# Inert until a programmes dir exists.
. "$PLUGIN_ROOT/hooks/lib.sh"
export CLAUDE_PROJECT_DIR="$REPO"
if sc_is_inert; then INERT=yes; else INERT=no; fi
assert_eq "yes" "$INERT" "inert with no programmes dir"

add_programme "$REPO" "headless" "main"
if sc_is_inert; then INERT=yes; else INERT=no; fi
assert_eq "no" "$INERT" "not inert once a programme exists"

# Sole-directory resolution.
assert_eq "headless" "$(sc_resolve_programme)" "resolves the only programme"

# Branch resolution wins when several exist.
git -C "$REPO" checkout -qb feat/charts
add_programme "$REPO" "charts" "feat/charts"
assert_eq "charts" "$(sc_resolve_programme)" "resolves by current branch"

# Explicit override beats the branch.
assert_eq "headless" "$(sc_resolve_programme headless)" "explicit arg overrides"

# A closed programme must not resolve, even though its branch column matches.
git -C "$REPO" checkout -qb feat/closed
add_programme "$REPO" "closedprog" "feat/closed"
sed -i 's/| closedprog | active | feat\/closed |/| closedprog | closed | feat\/closed |/' \
  "$REPO/docs/programmes/INDEX.md"
assert_empty "$(sc_resolve_programme)" "closed programme on the current branch does not resolve"

# The sole-directory fallback is a separate code path from the branch match above and needs its
# own guard: a repo with exactly one programme, closed, on the current branch must not fall
# through to "it's the only one, use it".
REPO2=$(make_repo)
add_programme "$REPO2" "only" "main"
sed -i 's/| only | active | main |/| only | closed | main |/' "$REPO2/docs/programmes/INDEX.md"
assert_empty "$(CLAUDE_PROJECT_DIR="$REPO2" sc_resolve_programme)" \
  "sole closed programme does not resolve via the fallback path"
rm -rf "$REPO2"

# Config defaults and overrides.
assert_eq "docs" "$(sc_docs_root)" "docsRoot defaults to docs"
mkdir -p "$REPO/.claude"
printf '{"docsRoot":"documentation","compareBranch":"origin/trunk"}' \
  >"$REPO/.claude/session-continuity.json"
assert_eq "documentation" "$(sc_docs_root)" "docsRoot honours config"
assert_eq "origin/trunk" "$(sc_config_get compareBranch)" "config_get reads a key"

# codePathspec is what the Stop hook builds its git pathspec from — cover it here, not there.
printf '{"codePathspec":[".",":(exclude)*.md"]}' >"$REPO/.claude/session-continuity.json"
assert_eq $'.\n:(exclude)*.md' "$(sc_config_arr codePathspec)" "config_arr reads an array"

# jq and python3 must agree: a non-string element is dropped, not stringified into the list.
printf '{"codePathspec":[".",42,null,":(exclude)*.md"]}' >"$REPO/.claude/session-continuity.json"
assert_eq $'.\n:(exclude)*.md' "$(sc_config_arr codePathspec)" "config_arr drops non-string members"

# State latch round-trips, is per-session, and overwrites a key rather than duplicating it.
SC_SESSION_ID=sess-a sc_state_set warned 1
assert_eq "1" "$(SC_SESSION_ID=sess-a sc_state_get warned)" "state round-trips"
assert_empty "$(SC_SESSION_ID=sess-b sc_state_get warned)" "state is per-session"
SC_SESSION_ID=sess-a sc_state_set warned 2
SC_SESSION_ID=sess-a sc_state_set baseline abc123
assert_eq "2" "$(SC_SESSION_ID=sess-a sc_state_get warned)" "state overwrites in place"
assert_eq "abc123" "$(SC_SESSION_ID=sess-a sc_state_get baseline)" "a second key coexists"

# Concurrent writers to distinct keys in the same session must not lose updates. Real processes,
# not `()` subshells (a subshell's $$ aliases the parent's and would hide the race). 50 pre-existing
# keys widen the read-modify-write window; measured against the unlocked implementation this drops
# to 8-12/100 survivors, so 100/100 here is a real pass, not a run that never contended.
RACE_N=100
for i in $(seq 1 50); do
  bash -c ". \"$PLUGIN_ROOT/hooks/lib.sh\"; SC_SESSION_ID=sess-race sc_state_set pre$i val$i"
done
for i in $(seq 1 "$RACE_N"); do
  bash -c ". \"$PLUGIN_ROOT/hooks/lib.sh\"; SC_SESSION_ID=sess-race sc_state_set key$i val$i" &
done
wait
SURVIVED=0
for i in $(seq 1 "$RACE_N"); do
  [ "$(SC_SESSION_ID=sess-race sc_state_get "key$i")" = "val$i" ] && SURVIVED=$((SURVIVED + 1))
done
assert_eq "$RACE_N" "$SURVIVED" "$RACE_N concurrent writers to distinct keys all survive"

# --- The root follows the session, not the directory it started in ---
R=$(make_repo)
add_programme "$R" "headless" "main"
git -C "$R" add -A && git -C "$R" commit -qm "add programme"
WT=$(mktemp -d); rmdir "$WT"
git -C "$R" worktree add -q -b feat/wt "$WT"
add_programme "$WT" "wtprog" "feat/wt"
assert_eq "$WT" "$(SC_CWD="$WT" CLAUDE_PROJECT_DIR="$R" sc_project_root)" \
  "root follows the hook's cwd into a worktree"
assert_eq "wtprog" "$(SC_CWD="$WT" CLAUDE_PROJECT_DIR="$R" sc_resolve_programme)" \
  "a worktree session resolves its own branch's programme"
assert_eq "$R" "$(SC_CWD="$R/src" CLAUDE_PROJECT_DIR="$R" sc_project_root)" \
  "a subdirectory cwd resolves to the repo top level"
assert_eq "$R" "$(SC_CWD="/nonexistent-$$" CLAUDE_PROJECT_DIR="$R" sc_project_root)" \
  "a vanished cwd falls back to CLAUDE_PROJECT_DIR"
git -C "$R" worktree remove --force "$WT"

# --- A shared branch is ambiguous, never first-match ---
S=$(make_repo)
for p in alpha beta gamma; do add_programme "$S" "$p" "main"; done
assert_empty "$(CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "three open programmes on one branch resolve to nothing"
assert_eq $'alpha\nbeta\ngamma' "$(CLAUDE_PROJECT_DIR="$S" sc_branch_candidates)" \
  "all three are reported as candidates"
SC_SESSION_ID=pin1 sc_state_set programme beta
assert_eq "beta" "$(SC_SESSION_ID=pin1 CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "a session pin beats the branch"
assert_eq "gamma" "$(PROGRAMME_SLUG=gamma CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "PROGRAMME_SLUG beats the branch"
assert_eq "beta" "$(SC_SESSION_ID=pin1 PROGRAMME_SLUG=gamma CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "a pin beats PROGRAMME_SLUG"
assert_empty "$(PROGRAMME_SLUG=nope CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "PROGRAMME_SLUG naming no programme is ignored"
assert_empty "$(PROGRAMME_SLUG=../programmes/alpha CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "PROGRAMME_SLUG cannot be a path"
SC_SESSION_ID=pin2 sc_state_set programme ghost
assert_empty "$(SC_SESSION_ID=pin2 CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "a pin naming no programme is ignored"
sed -i 's/| alpha | active | main |/| alpha | closed | main |/' "$S/docs/programmes/INDEX.md"
SC_SESSION_ID=pin3 sc_state_set programme alpha
assert_eq "alpha" "$(SC_SESSION_ID=pin3 CLAUDE_PROJECT_DIR="$S" sc_resolve_programme)" \
  "a pin naming a closed programme still resolves — it was asked for by name"
rm -rf "$R" "$S"

rm -rf "$REPO" "$STATE_HOME"
finish
