#!/usr/bin/env bash
# Stop — warn once per session when THIS session changed code and the programme ledger did not.
#
# "This session" is the committed range since SessionStart's baseline, plus working-tree changes
# measured against the dirt fingerprint stamped beside it: a path dirty at start and untouched since
# is not this session's change. Without that, an untracked directory or a sibling session's dirt
# spent the guard's only warning minutes into a read-only resume.
#
# Latched to one warning per session, and skipped while stop_hook_active is set. The warning
# reaches the model — one extra turn, at most once — because a user-only warning was measured to
# produce no ledger write at all; it also tells the model how to decline when the work is not
# programme work.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] || exit 0
[ "$SC_STOP_HOOK_ACTIVE" = "true" ] && exit 0

root=$(sc_project_root); [ -n "$root" ] || exit 0
slug=$(sc_resolve_programme); [ -n "$slug" ] || exit 0
ledger=$(sc_ledger_path "$slug"); [ -f "$ledger" ] || exit 0
[ -n "$(sc_state_get warned_stop)" ] && exit 0

rel_ledger=${ledger#"$root"/}
baseline=$(sc_state_get baseline)
range=""
if [ -n "$baseline" ] && git -C "$root" merge-base --is-ancestor "$baseline" HEAD 2>/dev/null; then
  range="$baseline..HEAD"
fi

mapfile -t pathspec < <(sc_code_pathspec)

changed=""
touched=""
if [ -n "$range" ]; then
  changed=$(git -C "$root" diff --name-only "$range" -- "${pathspec[@]}" 2>/dev/null || true)
  touched=$(git -C "$root" diff --name-only "$range" -- "$rel_ledger" 2>/dev/null || true)
fi

stamped_root=$(sc_state_get root)
dirt=$(sc_dirt_file)
if [ -n "$stamped_root" ] && [ "$stamped_root" != "$root" ]; then
  : # The session moved to another worktree: its fingerprint describes a different tree. Committed
    # range only — silence over a guess.
elif [ -n "$stamped_root" ] && [ -f "$dirt" ] && ! grep -qx overflow "$dirt"; then
  # The whole tree, exactly as SessionStart took it: a pathspec-limited snapshot reports a rename
  # that straddles the pathspec (notes.md -> src/notes.ts) as an add, which the fingerprint never
  # recorded. Diff like with like, then sort what is new into code and ledger.
  # A path dirty at start and since reverted to clean is not in the new snapshot, so it is not
  # counted — deliberately: undoing pre-existing dirt is not this session writing code.
  new=$(sc_dirt_new "$dirt" "$(sc_dirt_snapshot "$root")")
  if [ "$new" = overflow ]; then
    changed="$changed
overflow"   # too dirty now to tell: as before, that counts as changed code
    touched="$touched
$(sc_dirt_new "$dirt" "$(sc_dirt_snapshot "$root" "$rel_ledger")")"
  elif [ -n "$new" ]; then
    declare -A is_code=()
    while IFS= read -r -d '' entry; do
      case ${entry:0:2} in R*|C*) IFS= read -r -d '' _ || true ;; esac
      is_code[${entry:3}]=1
    done < <(git -C "$root" status --porcelain=v1 -z --untracked-files=all -- "${pathspec[@]}" 2>/dev/null)
    while IFS= read -r line; do
      path=${line#*$'\t'}; path=${path%$'\t'*}
      [ -n "$path" ] || continue
      [ -n "${is_code[$path]:-}" ] && changed="$changed
$path"
      [ "$path" = "$rel_ledger" ] && touched="$touched
$path"
    done <<<"$new"
  fi
else
  # No fingerprint (a session stamped before this version, or one too dirty to fingerprint): the
  # whole working tree, as before.
  changed="$changed
$(git -C "$root" status --porcelain -- "${pathspec[@]}" 2>/dev/null || true)"
  touched="$touched
$(git -C "$root" status --porcelain -- "$rel_ledger" 2>/dev/null || true)"
fi

changed=$(printf '%s' "$changed" | tr -d '[:space:]')
touched=$(printf '%s' "$touched" | tr -d '[:space:]')

[ -z "$changed" ] && exit 0
[ -n "$touched" ] && exit 0

sc_state_set warned_stop 1
sc_emit_stop_warning "This session changed code, and the \"$slug\" programme ledger has not moved.

  $rel_ledger

If a phase closed, a gate produced a number, a decision was settled, or something recorded there
turned out to be false, write it now — while the detail still exists. Run /programme:handoff for
the full end-of-thread write, or edit the ledger directly.

If this session's work does not belong to a programme, say so in one line and stop — no ledger
edit is owed, and this will not ask again."
exit 0
