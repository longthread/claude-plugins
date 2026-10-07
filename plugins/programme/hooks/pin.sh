#!/usr/bin/env bash
# UserPromptSubmit — pin the programme a prompt names, for the rest of this session.
#
# `/programme:resume <slug>` (or init/handoff) is the one moment a session says, unambiguously,
# which programme it is in. Recording it makes the other hooks stop inferring: on a branch several
# programmes share, inference has no right answer. Silent always — bookkeeping that talks on every
# prompt is trained away.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

sc_load_input
sc_is_inert && exit 0
[ -n "$SC_JSON" ] && [ -n "$SC_SESSION_ID" ] || exit 0

first=$(printf '%s\n' "$SC_PROMPT" | head -n1)
slug=$(printf '%s' "$first" \
  | sed -nE 's#^[[:space:]]*/programme:(resume|init|handoff)[[:space:]]+([^[:space:]]+).*$#\2#p')
[ -n "$slug" ] && sc_valid_slug "$slug" || exit 0
[ -d "$(sc_programmes_dir)/$slug" ] || exit 0

sc_state_set programme "$slug"
exit 0
