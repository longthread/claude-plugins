---
description: Where the programme stands, and whether its record is still true
argument-hint: [programme-name] [--gates]
---

Report on programme **$1** (resolve as `/programme:resume` does). Pass `--gates` to also run the
slow gates.

**This command writes nothing.** Not the ledger, not `NEXT-SESSION.md`, not `INDEX.md` — even when
you find something wrong. That is the whole point: a status that quietly corrects the record cannot
be used to find out whether the record is honest, because running it makes the answer yes. Report
the drift and name the file to fix; `/programme:handoff` is what writes.

Use this when you want to know where things stand without starting work. `/programme:resume` reads
the same files and then begins.

## 1. Where the programme is

From `<docsRoot>/programmes/<SLUG>/ledger.md` and its `NEXT-SESSION.md`:

- **`## The arc` first** — the goal, and the programme's terminal condition quoted verbatim. Say
  plainly that it is the programme's and that the one below is the phase's; a met phase condition
  read as a met programme condition is how a programme gets called finished with phases still
  `planned`.
- what is done and what is left, from the arc's `status` column: the `done` rows, the `current` one,
  and every row still `planned`. Do not invent a progress metric, and **never read what has closed by
  counting Archive index rows** — that table's own note says why.
- the phase's terminal condition, quoting its `Command:` and `Expected output:` verbatim

If the arc, the Current position and the Archive index disagree about what has closed, say so — that
is a real finding, not a formatting problem. **An arc whose `current` row is not the phase
`NEXT-SESSION.md` describes is the same finding**, and it is the one that means the programme has
drifted off its own map.

## 2. Whether the record is still true

`NEXT-SESSION.md`'s State table carries a `verify with` command beside every figure. **Run all of
them** and put the claimed value beside the measured one. This is the section that earns the
command: every figure in these files was true when written, and the ahead-of-origin count in the
repo this convention comes from went stale so reliably that it is now recorded as a range.

Report each as `ok` or `DRIFTED`, and give the total. Never re-derive a figure by reasoning — if a
row's `verify with` is missing or does not run, report that row as **unverifiable** rather than
guessing. A missing command is itself a defect worth naming.

Then the ledger's **Gates** table. By default **do not run these** — a gate suite can take a quarter
of an hour, and a status you cannot afford to run is a status nobody runs. Print each gate's
`result`, `last run` and `trust` as recorded, and say plainly that they were not re-run.

**With `--gates`, run them**, and apply the ledger's own rule for flaky ones: report the actual runs
rather than silently re-running to green. A gate whose `trust` names a flake rate must be quoted
with that flake attached.

## 3. What is owed

- Open rows in `<docsRoot>/programmes/<SLUG>/deferred.md`. **Say explicitly that the programme
  cannot be closed while any remain** — that is the rule those rows exist to enforce, and a count
  alone does not convey it.
- Open forks in the ledger, each with what would settle it. A fork nobody is deciding is the thing
  most likely to be silently dropped.
- The ledger's length against the archive threshold stated in its own header. Over it, say which
  position should be archived next.

## 4. Report

Lead with the programme, its `INDEX.md` status, and the branch you resolved it from. Then the three
sections above, in order.

End with the single most useful next action, and be concrete: run the unrun checks in `deferred.md`,
or correct a drifted figure in `NEXT-SESSION.md`, or start the next terminal condition. **If nothing
drifted and nothing is owed, say that in one line** rather than padding — a status report that is
the same length whether or not anything is wrong trains the reader to skim it.
