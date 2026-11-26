#!/bin/sh
# SessionStart: if Claude runs inside Herdr, add the trigger rules and say which manuals to read.
# TUI first: a TUI running inside an app terminal inherits HC_TERMINAL_ID too.
# Env vars alone aren't enough: a devcontainer's Herdr core sets HC_TERMINAL_ID without herdr-app.
has() { command -v "$1" >/dev/null 2>&1; }
unreachable() {
  printf '%s\n' "# Herdr: not reachable here
This session runs in a Herdr terminal ($1), but \`$2\` isn't on PATH (e.g. inside a container). \`pane:\`, \`tab:\` and \`sessions:\` can't work: if I use one, tell me so and don't do it some other way. Never open panes, tabs or sessions, or read from or send to other terminals."
  exit 0
}
if [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ]; then
  has herdr || unreachable "pane \`$HERDR_PANE_ID\`" herdr
  where="## You're in the Herdr TUI (\`herdr\` CLI)
This session is pane \`$HERDR_PANE_ID\` in workspace \`${HERDR_WORKSPACE_ID:-?}\` (also in \$HERDR_PANE_ID, \$HERDR_WORKSPACE_ID).
Manuals: the \`herdr\` skill (load it with the Skill tool), then \`herdr <group>\` help for the groups you need (\`herdr pane\`, \`herdr tab\`, \`herdr agent\`, \`herdr workspace\`). Use \`--current\` / \`--no-focus\` where offered."
elif [ -n "${HC_TERMINAL_ID:-}" ]; then
  has hc || unreachable "terminal \`$HC_TERMINAL_ID\`" hc
  if has herdr-app; then
    where="## You're in the Herdr app (herdr-app window + hc core)
This session is terminal \`$HC_TERMINAL_ID\` (also in \$HC_TERMINAL_ID); that's not a pane id: look up its pane and space with \`herdr-app ls\`.
Manuals: \`herdr-app --skill\` for panes and tabs (pane:, tab:), \`hc --skill\` for finding, reading and messaging sessions (sessions:). Exact arguments: \`herdr-app commands\`, \`hc <command> --help\`."
  else
    where="## You're on a Herdr core without the app (\`hc\` only, e.g. a devcontainer)
This session is terminal \`$HC_TERMINAL_ID\` (also in \$HC_TERMINAL_ID) on this machine's core; the Herdr window runs on another machine, and \`herdr-app\` isn't here. Manual: \`hc --skill\`; exact arguments: \`hc <command> --help\`.
The window shows an \`hc\` terminal only if it carries the label \`herdr.space=<id>\`: as a new background tab in that space, or, with \`herdr.tab=<id>\` too, as a split in that tab (you can't pick the side). Read both ids from this session's own labels (\`hc get \$HC_TERMINAL_ID --json\`). \`tab:\` uses the space label, \`pane:\` both; start either so it outlives this session. If the label you need is missing, tell me; never fall back to an unlabelled background terminal.
For \`sessions:\`, \`hc ls\` lists only this machine and the machines added here (\`hc machine ls\`); sessions on the Herdr window's own machine are often not among them, though they can still message you. If what I asked for isn't listed, say it may run on a machine not reachable from here (name the machines you can reach); don't report that it doesn't exist."
  fi
else
  exit 0
fi
cat "$(dirname "$0")/../rules.md"
printf '\n%s\n' "$where"
