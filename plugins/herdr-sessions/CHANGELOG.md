# herdr-sessions — changelog

> **What changed in each release, for someone deciding whether to upgrade.** Not a commit log — a
> reader here already has the plugin installed and wants to know what will be different afterwards.
> The writing rules are in `templates/CHANGELOG.md` at the repo root.

## 0.1.1 — 2026-11-26

### Fixed

- **`pane:`, `tab:` and `sessions:` work inside a devcontainer** — a container added to Herdr as a
  machine has only `hc`, not `herdr-app`, and Claude used to be pointed at a manual that wasn't
  there. Now it opens the new session through `hc`, so it appears as a tab or a split in that
  machine's space. If no Herdr command is on the path at all, Claude tells you the triggers are
  unavailable instead of trying.
- **A container session no longer says a host session doesn't exist** — from inside a container,
  `hc` sees only the machines added there, which usually leaves out the host. When a `sessions:`
  request names something it can't see, Claude now says it may be out of reach and lists the
  machines it can reach.

## 0.1.0 — 2026-11-22

### Added

- **`pane:`, `tab:` and `sessions:` triggers inside Herdr** — start a message with one to open a new
  Claude Code session in a split or a background tab beside this one, or to find and message the
  sessions already running. Nothing opens or is messaged without one of these triggers.
- **Works in the Herdr app and the Herdr TUI** — a SessionStart hook works out which one the session
  is in and points Claude at that Herdr's own manuals, so the plugin carries no Herdr command syntax.
- **Commands that drive Herdr themselves still work** — a slash command or skill you invoke, or one
  running in a chain you started with one, that itself says to open, read, message or close Herdr
  panes counts as the trigger for exactly those steps, and only on its own pane and the panes that
  chain opened.
