# herdr-sessions — changelog

> **What changed in each release, for someone deciding whether to upgrade.** Not a commit log — a
> reader here already has the plugin installed and wants to know what will be different afterwards.
> The writing rules are in `templates/CHANGELOG.md` at the repo root.

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
