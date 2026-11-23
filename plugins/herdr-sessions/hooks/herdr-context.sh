#!/bin/sh
# SessionStart: if Claude runs inside Herdr, add the trigger rules and say which manuals to read.
# TUI first: a TUI running inside an app terminal inherits HC_TERMINAL_ID too.
if [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ]; then
  where="## You're in the Herdr TUI (\`herdr\` CLI)
This session is pane \`$HERDR_PANE_ID\` in workspace \`${HERDR_WORKSPACE_ID:-?}\` (also in \$HERDR_PANE_ID, \$HERDR_WORKSPACE_ID).
Manuals: the \`herdr\` skill (load it with the Skill tool), then \`herdr <group>\` help for the groups you need (\`herdr pane\`, \`herdr tab\`, \`herdr agent\`, \`herdr workspace\`). Use \`--current\` / \`--no-focus\` where offered."
elif [ -n "${HC_TERMINAL_ID:-}" ]; then
  where="## You're in the Herdr app (herdr-app window + hc core)
This session is terminal \`$HC_TERMINAL_ID\` (also in \$HC_TERMINAL_ID); that's not a pane id: look up its pane and space with \`herdr-app ls\`.
Manuals: \`herdr-app --skill\` for panes and tabs (pane:, tab:), \`hc --skill\` for finding, reading and messaging sessions (sessions:). Exact arguments: \`herdr-app commands\`, \`hc <command> --help\`."
else
  exit 0
fi
cat "$(dirname "$0")/../rules.md"
printf '\n%s\n' "$where"
