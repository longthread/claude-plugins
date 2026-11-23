#!/usr/bin/env bash
# The SessionStart hook: right section per environment, nothing outside Herdr.
set -uo pipefail
hook="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/herdr-context.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { echo '{}' | env -u HC_TERMINAL_ID -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_WORKSPACE_ID "$@" "$hook"; }

out=$(run)
check "outside Herdr: prints nothing" '[ -z "$out" ]'

out=$(run HC_TERMINAL_ID=t9)
check "app: rules included" 'grep -q "explicit triggers only" <<<"$out"'
check "app: slash-command exception included" 'grep -q "or one running in a chain I started with one" <<<"$out"'
check "app: the exception is limited to the chain's own panes" 'grep -q "never on any other session" <<<"$out"'
check "app: app section with terminal id" 'grep -q "re in the Herdr app (" <<<"$out" && grep -q "terminal \`t9\`" <<<"$out"'
check "app: points at both manuals" 'grep -q "herdr-app --skill" <<<"$out" && grep -q "hc --skill" <<<"$out"'

out=$(run HERDR_ENV=1 HERDR_PANE_ID=w1:p3 HERDR_WORKSPACE_ID=w1)
check "tui: TUI section with pane id" 'grep -q "re in the Herdr TUI (" <<<"$out" && grep -q "pane \`w1:p3\`" <<<"$out"'

out=$(run HC_TERMINAL_ID=t9 HERDR_ENV=1 HERDR_PANE_ID=w1:p3)
check "tui inside app: TUI wins" 'grep -q "re in the Herdr TUI (" <<<"$out" && ! grep -q "re in the Herdr app (" <<<"$out"'

out=$(run HERDR_ENV=1)
check "HERDR_ENV without pane id: nothing" '[ -z "$out" ]'

exit "$fail"
