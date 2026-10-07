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

Match the current branch against the `branch` column. `$1` wins if given. **Skip any row whose
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

State: which programme you resolved and how; **the arc — the goal, the programme's terminal
condition, the `current` phase, and every phase still `planned`**; the position as the ledger
records it; what you measured and what drifted; and the phase's terminal condition you are working
toward, quoting its command and expected output. Then ask whether to proceed.
