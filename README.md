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
