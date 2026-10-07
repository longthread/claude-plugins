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

Supervised and autonomous relay through herdr, using the herdr skill. **The herdr dependency check
passes only if all three hold:**

1. `command -v herdr` succeeds;
2. `herdr status` reaches a running server — a client/server version difference that herdr itself
   reports as compatible passes;
3. the `herdr` skill is in this session's own list of available skills. A skill file on disk that
   this session cannot load does not count.

If any check fails, **refuse**: name the check and its fix — install herdr, start its server, install
or enable the herdr skill — and change nothing. `assisted` never runs this check; it needs nothing
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
