# herdr-sessions

Inside [Herdr](https://herdr.dev), open another Claude Code session beside this one, or message
sessions that are already running, by starting your message with `pane:`, `tab:` or `sessions:`.

## The problem it solves

Herdr runs many Claude Code sessions side by side. Asking one session to start or talk to another
means it has to know Herdr's commands, and when it's allowed to use them. Without rules it either
can't, or it does it when you didn't ask.

**herdr-sessions** gives Claude three explicit triggers and nothing else. Without a trigger, it never
opens or messages another session.

## How you use it

1. `pane: run the tests and fix failures` — a new Claude Code session opens in a split beside this
   one, with a self-contained brief (it has none of your context). Your cursor stays here.
2. `tab: in ~/other-repo, update the docs, name it docs` — the same, but in a new background tab in
   this space. Add details in plain words: where, what to call it.
3. `sessions: ask the api session if the migration finished` — Claude finds the matching session,
   sends it a message that says who is asking, and tells you what it replied.
4. Anything else — nothing. Claude never opens sessions on its own to split up its work; it uses
   sub-agents for that as usual. The one exception is a slash command or skill you invoke (or one
   running in a chain you started with one) that itself says to open, read, message or close panes:
   that counts as the trigger for exactly those steps, and only on its own pane and the panes that
   chain opened. Your other sessions stay off limits.

<!-- site:figures -->

## What it will never do on its own

- Message a session that isn't idle. If one is busy or waiting on a permission prompt, it tells you
  instead of answering for it.
- Close, interrupt or type into a session it didn't open, unless you ask.
- Guess. If more than one session matches what you said, it lists them and asks.
- Rely on memorised commands. It reads Herdr's own manual, so it keeps working when Herdr changes.

## Words you'll see

| word    | meaning                                                                                                                                         |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Herdr   | A terminal multiplexer built for coding agents: a desktop app (`herdr-app` + `hc`) or a terminal UI (`herdr`). The plugin works out which one. |
| pane    | A split inside the current tab, so you see both sessions at once.                                                                               |
| tab     | A separate tab in the same space, opened without switching you to it.                                                                           |
| trigger | The first word of your message: `pane:`, `tab:` or `sessions:`.                                                                                 |

## Is it for you?

- **A good fit:** you run Claude Code inside the Herdr app or the Herdr TUI.
- **Also a fit:** a devcontainer added to Herdr as a machine. Only `hc` is inside it, but all three
  triggers still work: new sessions show up as tabs or splits in that machine's space. `sessions:`
  there reaches only the machines added inside the container; to reach the host's sessions too,
  add the host as a machine there (`hc machine add`).
- **Not a fit:** anywhere else. Outside Herdr the plugin does nothing at all.

## Install

```
/plugin marketplace add longthread/claude-plugins
/plugin install herdr-sessions@longthread
```

---

## Reference

How it detects Herdr, and how to run its tests.

## How it works

One `SessionStart` hook. Outside Herdr it prints nothing. Inside, it adds a short set of rules
(`rules.md`) and says which manual to read:

| detected by | Herdr | manual Claude reads on the first trigger |
| --- | --- | --- |
| `HERDR_ENV=1` and `HERDR_PANE_ID` | TUI | the `herdr` skill (installed by `herdr integration install claude`), then `herdr <group>` help |
| `HC_TERMINAL_ID` | app | `herdr-app --skill` for panes and tabs, `hc --skill` for sessions |
| `HC_TERMINAL_ID`, `hc` but no `herdr-app` | core only (e.g. a devcontainer) | `hc --skill`; panes and tabs via the `herdr.space` / `herdr.tab` labels |

The TUI is checked first: a TUI started inside an app terminal inherits `HC_TERMINAL_ID` too. Each
row also needs its commands on `PATH`; when they're missing the hook says the triggers are
unavailable here, rather than pointing at a manual that isn't installed.

The plugin carries **no Herdr command syntax**. Herdr changes often and ships version-matched
manuals, so the plugin holds only what the manuals can't know: when to act, what each trigger must
produce (e.g. `pane:` is a visible split, not a background child), and guardrails — target this
session's own pane, never answer another session's permission prompt, never kill or close what it
didn't create, ask when a match is ambiguous.

## Tests

```bash
cd plugins/herdr-sessions && ./tests/run-all.sh
```
