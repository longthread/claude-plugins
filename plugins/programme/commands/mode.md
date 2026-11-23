---
description: Switch a programme between assisted, supervised and autonomous
argument-hint: <programme-name> <assisted|supervised|autonomous>
---

Set programme **$1**'s mode to **$2** (resolve as `/programme:resume` does). `$2` must be exactly
`assisted`, `supervised` or `autonomous`; anything else is refused.

What a mode does at each point of a relay is stated where that point happens — `/programme:handoff`
for the interview and the relay, `/programme:resume` for whether to proceed. This command only
records the choice, after checking it can be honoured.

## 1. Check the dependencies — supervised and autonomous only

Supervised and autonomous relay through herdr: the Herdr TUI, using the herdr skill, or the Herdr
app, using its two manuals. This session is in the TUI when `HERDR_ENV` is `1` and `HERDR_PANE_ID`
is non-empty — checked first, because a TUI started inside an app terminal inherits the app's
variable too — and otherwise in the app when `HC_TERMINAL_ID` is non-empty. In neither, the check
fails: this session is not running inside Herdr.

**The herdr dependency check passes only if all three hold** — in the TUI:

1. `command -v herdr` succeeds;
2. `herdr status` reaches a running server — a client/server version difference that herdr itself
   reports as compatible passes;
3. the `herdr` skill is in this session's own list of available skills. A skill file on disk that
   this session cannot load does not count.

In the app:

1. `command -v herdr-app` and `command -v hc` both succeed;
2. `herdr-app --skill` and `hc --skill` both print their manuals — the app's equivalent of the skill;
3. `herdr-app ls` reaches the running window and lists this session's terminal, `$HC_TERMINAL_ID`.

If any check fails, **refuse**: name the check and its fix — install herdr, start its server, install
or enable the herdr skill; for the app, install `herdr-app` and `hc`, open the Herdr window, or start
Claude in a Herdr terminal — and change nothing. `assisted` never runs this check; it needs nothing
but this plugin.

## 2. Write the one cell

In `<docsRoot>/programmes/INDEX.md`, set the programme's `mode` cell to `$2`. If the table has no
`mode` column yet, add it as the **last** column — header, separator, and a blank cell on every other
row — then write the cell. Change nothing else, and do not commit: the edit lands with the next
commit, like any `INDEX.md` change.

## 3. Report

Old mode — the cell read as `INDEX.md`'s header comment states, quoting the raw cell when it was
blank or not one of the three — → new mode; each check's result when one ran; and the branch whose
`INDEX.md` you edited. `INDEX.md` is per branch, so a session in another branch's worktree keeps
that branch's mode until this change is merged there.
