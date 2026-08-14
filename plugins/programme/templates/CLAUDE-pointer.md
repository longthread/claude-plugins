## Programme continuity

Multi-session work is tracked in `<DOCS_ROOT>/programmes/`. Resolve the active programme by matching
the current branch against `<DOCS_ROOT>/programmes/INDEX.md`, then read that programme's `ledger.md`
in full, then its `NEXT-SESSION.md`. **The ledger outranks every handoff document** — if they
disagree, the ledger is right and the handoff needs correcting.

**Write to the ledger when any of these happens, not at session end** — by session end the detail
that would have made the entry worth reading is already gone:

- a phase or slice completes, merges, or is abandoned
- a gate runs and produces a number
- a decision is settled
- something already recorded turns out to be false
- you were surprised

`/programme:resume` to start a session · `/programme:handoff` to close out a thread.
