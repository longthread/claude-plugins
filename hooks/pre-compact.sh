#!/usr/bin/env bash
# PreCompact — best effort. PreCompact is NOT a confirmed member of the hookSpecificOutput union
# and does not support prompt-type hooks, so this can only emit a top-level systemMessage and may
# reach the user rather than the model. Nothing in the design depends on it.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] || exit 0

root=$(sc_project_root); [ -n "$root" ] || exit 0
slug=$(sc_resolve_programme); [ -n "$slug" ] || exit 0
ledger=$(sc_ledger_path "$slug"); [ -f "$ledger" ] || exit 0

baseline=$(sc_state_get baseline)
[ -n "$baseline" ] || exit 0
git -C "$root" merge-base --is-ancestor "$baseline" HEAD 2>/dev/null || exit 0

rel_ledger=${ledger#"$root"/}
touched=$(git -C "$root" diff --name-only "$baseline..HEAD" -- "$rel_ledger" 2>/dev/null || true)
touched="$touched$(git -C "$root" status --porcelain -- "$rel_ledger" 2>/dev/null || true)"
[ -n "$(printf '%s' "$touched" | tr -d '[:space:]')" ] && exit 0

sc_emit_system_message "Compacting, and the \"$slug\" ledger has not moved this session.
Anything measured or falsified but not written to $rel_ledger is about to leave context."
exit 0
