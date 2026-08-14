#!/usr/bin/env bash
# Stop — warn once per session when code moved and the programme ledger did not.
#
# Latched to at most one message per session: this fires on a judgement call, and a guard that
# nags every turn is trained away within a day. Non-blocking for the same reason.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] || exit 0

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

pathspec=()
while IFS= read -r p; do [ -n "$p" ] && pathspec+=("$p"); done < <(sc_config_arr codePathspec)
if [ ${#pathspec[@]} -eq 0 ]; then
  pathspec=('.' ':(exclude)*.md' ":(exclude)$(sc_docs_root)/" ':(exclude).claude/')
fi

changed=""
touched=""
if [ -n "$range" ]; then
  changed=$(git -C "$root" diff --name-only "$range" -- "${pathspec[@]}" 2>/dev/null || true)
  touched=$(git -C "$root" diff --name-only "$range" -- "$rel_ledger" 2>/dev/null || true)
fi
changed="$changed
$(git -C "$root" status --porcelain -- "${pathspec[@]}" 2>/dev/null || true)"
touched="$touched
$(git -C "$root" status --porcelain -- "$rel_ledger" 2>/dev/null || true)"

changed=$(printf '%s' "$changed" | tr -d '[:space:]')
touched=$(printf '%s' "$touched" | tr -d '[:space:]')

[ -z "$changed" ] && exit 0
[ -n "$touched" ] && exit 0

sc_state_set warned_stop 1
sc_emit_system_message "This session changed code, and the \"$slug\" programme ledger has not moved.

  $rel_ledger

If a phase closed, a gate produced a number, a decision was settled, or something recorded there
turned out to be false, write it now — while the detail still exists. Run /programme:handoff for
the full end-of-thread write, or just edit the ledger directly.

If this session's work does not belong to a programme, ignore this; it will not ask again."
exit 0
