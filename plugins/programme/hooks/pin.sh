#!/usr/bin/env bash
# UserPromptSubmit — pin the programme a prompt names, for the rest of this session.
#
# `/programme:resume <slug>` (or handoff; init only once the programme exists) is the one moment a
# session says, unambiguously, which programme it is in. Recording it makes the other hooks stop
# inferring: on a branch several programmes share, inference has no right answer. Silent always —
# bookkeeping that talks on every prompt is trained away.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# This runs on every prompt the user types. Read stdin once and leave before any JSON parsing unless
# the prompt could name a command at all; only then parse the three fields the pin needs.
raw=$(cat)
case "$raw" in *'/programme:'*) ;; *) exit 0 ;; esac
SC_SESSION_ID=$(_sc_str "$raw" session_id)
SC_CWD=$(_sc_str "$raw" cwd)
SC_PROMPT=$(_sc_str "$raw" prompt)
sc_is_inert && exit 0
[ -n "$SC_JSON" ] && [ -n "$SC_SESSION_ID" ] || exit 0

# The permission mode this session runs in, so a relay can start its successor with the same one
# and never a more permissive one. Recorded on any /programme: prompt — the relay's handoff may name
# no slug. Only a plain word is kept: the relay passes it on a command line.
pm=$(_sc_str "$raw" permission_mode)
case "$pm" in
  ''|*[!A-Za-z]*) ;;
  *) sc_state_set permission_mode "$pm" ;;
esac

first=$(printf '%s\n' "$SC_PROMPT" | head -n1)
slug=$(printf '%s' "$first" \
  | sed -nE 's#^[[:space:]]*/programme:(resume|init|handoff)[[:space:]]+([^[:space:]]+).*$#\2#p')
[ -n "$slug" ] && sc_valid_slug "$slug" || exit 0
[ -d "$(sc_programmes_dir)/$slug" ] || exit 0

sc_state_set programme "$slug"
exit 0
