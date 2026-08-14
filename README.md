# longthread

Claude Code plugins for work that runs long — across many sessions, and past the end of any one
context window.

```
/plugin marketplace add longthread/claude-plugins
/plugin install programme@longthread
```

## Plugins

| plugin                            | what it does                                                                                                                                                                         |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`programme`](plugins/programme/) | Carries a multi-session programme across session boundaries: a durable ledger, an interviewed handoff, and a guard that fires when a session changes code without moving the record. |

## Layout

Each plugin is self-contained under `plugins/<name>/`, with its own `.claude-plugin/plugin.json`,
its own tests, and its own README. The marketplace manifest at `.claude-plugin/marketplace.json`
lists them.

Run a plugin's tests from its own directory:

```bash
cd plugins/programme && ./tests/run-all.sh
```

## Installing from a local checkout

`claude plugin marketplace add <path>` records the path and reads it **in place** — it does not
copy. That is convenient while developing (edits are live on the next session start) but it means
the path must not move or disappear. Point it at a clone that stays put, never at a directory
inside a repo whose branch you switch.

## The site

[plugins.longthread.dev](https://plugins.longthread.dev) is generated from this repo — the plugin list comes from
`.claude-plugin/marketplace.json` and each detail page is that plugin's own `README.md`, so the site
cannot drift from the manifest.

```bash
bun install
bun run build     # -> docs/, which GitHub Pages serves
bun run serve     # build, then http://127.0.0.1:4321
```

`docs/` is committed so Pages needs no build step. Rebuild it in the same commit as any change to a
plugin README or the manifest.
