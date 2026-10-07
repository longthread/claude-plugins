#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

echo "test-pin"
REPO=$(make_repo); cd "$REPO"
. "$PLUGIN_ROOT/hooks/lib.sh"
pinned() { SC_SESSION_ID="$1" sc_state_get programme; }
prompt() { payload UserPromptSubmit "$1" startup "\"prompt\":\"$2\""; }

run_hook pin.sh "$(prompt p0 '/programme:resume beta')" "$REPO"
assert_eq "0" "$RC" "inert repo exits 0"
assert_empty "$OUT" "inert repo says nothing"
assert_empty "$(ls "$STATE_HOME/claude-programme" 2>/dev/null || true)" "inert repo writes no state"

add_programme "$REPO" "alpha" "main"
add_programme "$REPO" "beta" "main"

run_hook pin.sh "$(prompt p1 '/programme:resume beta')" "$REPO"
assert_eq "beta" "$(pinned p1)" "/programme:resume <slug> pins the session"
assert_empty "$OUT" "the pin hook never speaks"

run_hook pin.sh "$(prompt p2 '/programme:handoff alpha')" "$REPO"
assert_eq "alpha" "$(pinned p2)" "/programme:handoff <slug> pins too"

run_hook pin.sh "$(prompt p3 '  /programme:resume beta please')" "$REPO"
assert_eq "beta" "$(pinned p3)" "leading whitespace and trailing words still pin"

run_hook pin.sh "$(prompt p4 '/programme:resume nope')" "$REPO"
assert_empty "$(pinned p4)" "a slug naming no programme does not pin"

run_hook pin.sh "$(prompt p5 'please resume beta')" "$REPO"
assert_empty "$(pinned p5)" "prose that mentions a programme does not pin"

run_hook pin.sh "$(prompt p6 '/programme:resume ../programmes/beta')" "$REPO"
assert_empty "$(pinned p6)" "a path is not a slug"

run_hook pin.sh "$(prompt p7 '/programme:resume')" "$REPO"
assert_empty "$(pinned p7)" "a bare /programme:resume does not pin"

# A prompt that names no /programme: command is never parsed: the hook runs on every prompt.
SHIM=$(mktemp -d); MARK="$SHIM/parsed"
for t in jq python3; do
  real=$(command -v "$t" || true); [ -n "$real" ] || continue
  printf '#!/usr/bin/env bash\necho %s >>"%s"\nexec "%s" "$@"\n' "$t" "$MARK" "$real" >"$SHIM/$t"
  chmod +x "$SHIM/$t"
done
PATH="$SHIM:$PATH" run_hook pin.sh "$(prompt p8 'just an ordinary prompt')" "$REPO"
assert_empty "$(cat "$MARK" 2>/dev/null || true)" "an ordinary prompt is not JSON-parsed at all"
PATH="$SHIM:$PATH" run_hook pin.sh "$(prompt p9 '/programme:resume beta')" "$REPO"
assert_eq "beta" "$(pinned p9)" "and a /programme: prompt still pins through the same path"
rm -rf "$SHIM"

# End to end: the pin is what SessionStart honours after a compaction on a shared branch.
run_hook session-start.sh "$(payload SessionStart p1 compact)" "$REPO"
assert_contains "$OUT" 'Active programme: \"beta\"' "a pinned session is injected its pin, not the ambiguity"

rm -rf "$REPO" "$STATE_HOME"
finish
