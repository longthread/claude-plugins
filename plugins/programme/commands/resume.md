---
description: Resume a programme from its durable ledger
argument-hint: [programme-name]
---

Resume the programme **$1**, or resolve it if `$1` is empty.

## Resolve the programme from the tree

```bash
git rev-parse --abbrev-ref HEAD
cat "<docsRoot>/programmes/INDEX.md"
```

Match the current branch against the `branch` column. `$1` wins if given; otherwise `PROGRAMME_SLUG`, when it names a programme directory, wins over the branch — it is how a relayed session is told its programme. **Skip any row whose
`status` is `closed`** — it is not a candidate, even if its branch matches. If nothing matches and
there is exactly one open programme, use it. If several exist and none matches, **list them and
ask** — do not guess, and do not fall back to "most recently modified", which is how a session ends
up writing into the wrong programme's ledger. **Several open rows on the current branch are the same case as none** —
list those rows and ask, and take the answer as the user re-running `/programme:resume <name>`:
the re-run is what pins the programme for the rest of the session, including after a compaction.

## Read, in this order

1. `<docsRoot>/programmes/<SLUG>/ledger.md` — **in full, starting with `## The arc`**: the goal, the
   programme's terminal condition, and which phases are still `planned`. Read it before the
   position, not after — a phase read without the arc around it is a phase you cannot refuse work
   inside.
2. `<docsRoot>/programmes/<SLUG>/NEXT-SESSION.md` — follow its "Start here" block **verbatim**

Read the prompt file itself rather than acting on any summary of it, including one in this
conversation. That is deliberate: it stops the instructions being invoked in a stale copied form.

## Run every check in the State table before acting

`NEXT-SESSION.md`'s State table carries a `verify with` command beside every figure. **Run all of
them** and compare. In the repo this convention comes from, two documents currently disagree about
the same ahead-of-origin count, and one commit subject is literally "correct the ahead-of-origin
claim, which went stale as it was written."

Report any figure that has drifted, and correct `NEXT-SESSION.md` before continuing.

## Then report, before doing any work

Begin the report with exactly this line — a relaying session waits for it in this pane's output:

    Resumed programme "<SLUG>"

Then state: which programme you resolved and how; **the arc — the goal, the programme's terminal
condition, the `current` phase, and every phase still `planned`**; the position as the ledger
records it; what you measured and what drifted; and the phase's terminal condition you are working
toward, quoting its command and expected output.

Then, by the programme's mode — `INDEX.md`'s `mode` column, which the session-start context also
states (a blank cell or no column means `assisted`):

- **assisted, supervised** — ask whether to proceed.
- **autonomous** — proceed into `Start here` without asking. If drift left the next step ambiguous,
  stop and notify the user through the herdr skill instead of guessing.

## Autonomous: when to hand off

Nobody is present to say "hand off". In autonomous mode, run `/programme:handoff` yourself when
**either** the phase's terminal condition in `NEXT-SESSION.md` now passes, **or** you cannot make
further progress — a gate stays red after a fix attempt, or the next step needs a human decision.
The handoff's own stop conditions decide whether the chain continues.
