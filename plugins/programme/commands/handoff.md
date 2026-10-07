---
description: Close out a thread — measure state, interview, correct the ledger, rewrite the prompt
argument-hint: [programme-name]
---

Close out the current thread of work on programme **$1** (resolve as `/programme:resume` does).

A handoff whose structure is right and whose content is a changelog is worthless. What makes one
valuable is what got noticed during the work. Ask accordingly.

## 1. Measure the state yourself

Read `.claude/session-continuity.json` if it exists for `docsRoot` and `compareBranch`, as
`/programme:init` does. Never accept a figure from this conversation — including one you stated
earlier.

```bash
git fetch
git status --short
git log --oneline -10
git rev-list --count "<compareBranch>..HEAD"
git rev-parse HEAD
```

Run every gate in the ledger's Gates table and record the real output in `last run` and `result`.
**If the Gates table is empty, ask what this project's gates are** and fill it, including the
`trust` column and the flake rate for any gate that has one.

## 2. Interview — do not fill blanks

**Draft all five answers before asking anything.** Each cites its evidence — a commit sha, a command
and its output, a `file:line`, a gate run. Questions 4 and 5 look forward; for them, evidence means
the arc row, or the spec or plan at `file:line`, that the answer derives from. Then, by the
programme's mode (`INDEX.md`'s `mode` column; a blank cell or no column means `assisted`):

- **assisted** — show the whole draft; the user edits or approves each answer.
- **supervised** — ask the user only the questions whose draft has no evidence; keep the rest.
- **autonomous** — keep only the answers with evidence and leave the others out of the ledger
  entirely — no `UNVERIFIED` placeholder. The second ask on question 2, below, does not apply.

The questions are not interchangeable with "what did you do?", which produces a changelog.

1. **What did you measure?** Not what you did — what number, output, or observation do you now have
   that you did not have before?
2. **What did you get wrong, and what would the next session repeat if you do not say so?**
3. **Which claims already in the ledger are now false?**
4. **What is the next terminal condition — a command, and the output that means it is done?**
5. **Does the next phase still sit where `## The arc` says — and is any later phase's work cheaper
   taken now?** Ask it against the table, row by row, not from memory. Two shapes to name out loud:
   work this phase would build that a `planned` phase later deletes, and work scoped out as "a later
   phase's" that costs less inside this one than it will on its own. **If the answer is "nothing
   to change", name which rows you read to conclude that** — the failure this question exists to
   catch is answering it from memory.

**On question 2, in assisted and supervised mode: if the session changed anything — code, plan, or doc — and the answer is
"nothing", ask again.** Rephrase toward the concrete — a wrong assumption, a review finding, a
test that passed while checking nothing, a plan defect. A session with no mistakes worth recording
is usually a session that did not look; do not settle for an empty answer because it is easier to
write.

Worked examples of answers that earned their place, from the programme this convention comes from:
a fixture corpus covered an operator without covering its semantics, so an inverted comparison
passed review, compile, and a green replay; seven guards passed while checking nothing; ten plan
defects against zero implementation defects, which redirected effort from code review to re-reading
the plan against the tree.

## 3. Write the arc, the ledger and `deferred.md`

**The arc is corrected here or nowhere.** If question 5 moved a phase, split one, dropped one, or
changed what a phase delivers, edit `## The arc` now and say what changed in the position narrative.

**A ledger with no `## The arc` gets one here.** Programmes that predate the section are the ones
whose arc has never been written down. Copy the section from
`${CLAUDE_PLUGIN_ROOT}/templates/ledger.md` above `## Current position`, and fill it by asking what
`/programme:init` asks for it — do not infer the phases from the archive, which records archiving
events rather than a plan.

Diff what the ledger claims against what you measured in step 1, and update it. Fill the tables —
Gates, Settled decisions, Open forks — and rewrite the Current position narrative to include
question 2's answer — a still-empty second ask belongs in the position too, not only in the
report.

Naming question 4's terminal condition surfaces what it leaves out: record that in
`<docsRoot>/programmes/<SLUG>/deferred.md`, with `current behaviour`, `fix shape`, and
`why deferred` filled.

## 4. Archive if a phase closed

A closed phase is archived immediately, not only once the ledger crosses the header's length
threshold — apply the header's archiving rule now regardless of length. Then run `wc -l` on the
ledger and archive further if it is still over that threshold.

**Flip the arc's rows in the same edit**: the phase that closed becomes `done`, and the one being
started becomes `current`. Archiving without the flip leaves the programme's own map claiming it is
somewhere it left.

## 5. Rewrite `NEXT-SESSION.md` wholesale

Replace the file; do not append a section. Fill the Terminal condition command and expected output
from interview answer 4, and give every row of the State table a working `verify with` command.

## 6. If this handoff closes the programme

**Every arc row must be `done` first.** A row still `current` or `planned` means the programme has
work left and this closure is premature — either the work is not finished, or the phase was dropped
and the arc should say so, with the reason. Closing is where the one-`current`-row rule is spent:
after it, no row is `current`, because there is no next phase.

**Do not mark it closed while `<docsRoot>/programmes/<SLUG>/deferred.md` has open rows.** Each must
be either **promoted** to `<docsRoot>/deferred-work.md` with its fix shape intact and
`promoted from` set to the slug (then delete the row from `deferred.md`), or **killed**, with the
reason recorded in step 4's archive file — or, if no phase closed this handoff, in a new
`<docsRoot>/programmes/<SLUG>/archive/<YYYY-MM-DD>-closed.md` written for the closure. Add that
closure file's row to the ledger's Archive index table too, the same as step 4's phase-close
archive — an unindexed archive file is as good as deleted. Then set
`<docsRoot>/programmes/INDEX.md`'s status to `closed`.

If `<docsRoot>/deferred-work.md` already exists without a `promoted from` column, add the column
(header plus a blank cell on its existing rows) before appending — do not write a five-column row
into a table whose header still has four.

## 7. Report

Show: what you measured versus what the ledger claimed, with each gate's result quoted alongside its
`trust`; the arc as it now stands, naming any row whose `status` or wording you changed and why;
every claim you corrected; the interview answers as recorded — if question 2's second ask
still yielded nothing, record `asked twice, none recorded`; what was archived; and anything you
could not verify, named as unverified.

In autonomous mode, list the questions left out for want of evidence — numbers only.

## 8. Relay to the next session

The ledger and `NEXT-SESSION.md` are already written; the relay carries nothing they do not.

**Stop instead of relaying** when any of these holds — leave this pane as it is and, in supervised
or autonomous mode, notify the user through the herdr skill with the reason:

- a gate failed in step 1;
- a phase closed in this handoff, and the mode is `assisted` or `supervised`;
- the arc's programme terminal condition now passes — the programme is done;
- this session's `PROGRAMME_RELAY` (absent means 0) has reached the cap: `relayCap` in
  `.claude/session-continuity.json`, default 10;
- the mode is `autonomous` and question 4 was left out — the next session would have no terminal
  condition to work toward or to stop on.

**assisted** — print, for the user to run: `/clear`, then `/programme:resume <SLUG>`. If
`HERDR_ENV=1`, also offer to open the next session in a pane as supervised does; do it only on a yes.

**supervised, autonomous** — run the herdr dependency check `/programme:mode` states. If it fails,
print assisted's commands for this handoff instead, say which check failed, and leave the mode as it
is. Otherwise, using the herdr skill:

1. open a new pane beside this one, in this tab, at this session's project root, with
   `PROGRAMME_SLUG=<SLUG>` and `PROGRAMME_RELAY=<this session's value + 1>` in its environment;
2. start Claude in it as the agent `prog-<SLUG>-<that number>`, with this session's permission mode —
   the recorded value, read with the command below. If nothing is recorded, start with Claude Code's
   default and say so. **Never pass a more permissive mode than the one recorded.**
3. send `/programme:resume <SLUG>`, and wait until its output shows the line
   `Resumed programme "<SLUG>"`, or until it is blocked. Do not wait for it to go idle — an
   autonomous successor keeps working after its report;
4. if it is blocked — a trust or permission dialog — notify the user, leave both panes, and stop.
   **Never answer the dialog.**
5. otherwise notify the user that relay `<that number>` resumed. Then, **only if this session's own
   `PROGRAMME_RELAY` is 1 or more** — the relay opened this pane — close this pane
   (`$HERDR_PANE_ID`) as your very last action. Relay 0's pane is the one the user started the chain
   in: never close it, and never close any other pane.

The permission mode this session recorded:

```bash
f="${XDG_STATE_HOME:-$HOME/.local/state}/claude-programme/$(printf '%s' "$CLAUDE_CODE_SESSION_ID" | tr -c 'A-Za-z0-9._-' '_').state"
sed -n 's/^permission_mode=//p' "$f" 2>/dev/null
```
