# <PROGRAMME_NAME> — programme ledger

> **Where this programme stands, what was decided and why, and what is still open.** It survives
> session boundaries and context compaction, so a later session reads its position instead of
> re-deriving it from the code.
>
> **How to write here.** (_When_ to write is in the repo's `CLAUDE.md` — it has to be known away
> from this file.)
>
> - **Correct in place.** Never append an entry that contradicts an earlier one — fix the earlier
>   one and say what changed. A reader cannot tell which of two contradicting entries is current.
> - **Cite or flag.** Every claim below carries a `file:line`, a commit sha, or a date. If you did
>   not verify it, write `UNVERIFIED` on it: an omitted qualifier reads as a measurement.
> - **Absolute dates only** (`YYYY-MM-DD`).
> - **Archive past 250 lines.** Move the closing position to `archive/<YYYY-MM-DD>-<phase>.md` and
>   add its row to the index below. An unread ledger fails silently, and length is what makes it
>   unread.

## The arc

<!-- The one section here that handoff does NOT rewrite and archiving does NOT move. Every other
     section is one or both, which is how a programme's reason for existing leaves the working set.
     Edit it only when the decomposition itself changes, and say what changed. -->
<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

**Goal:** <what this programme is for, in one sentence>

**Terminal condition — the programme's, not the phase's.**

**Command:** `<a command a later session can run to prove the whole programme is done>`
**Expected output:** `<what that command prints once the whole programme is done>`

| phase                                  | status  | what it delivers                                    |
| -------------------------------------- | ------- | --------------------------------------------------- |
| (example) 1 — the differential harness | done    | a replay harness a deliberate mutation reddens      |
| (example) 2 — the notification bus     | current | delivery reaches a device with no client attached   |
| (example) 3 — the compound engine      | planned | multi-condition rules evaluate outside the frontend |

`status` is `done` · `current` · `planned`, and **exactly one row is `current`** — until the
programme closes, when every row is `done` and none is `current`. A later phase's row is what makes
work in front of you refusable: code that a `planned` phase deletes is not worth writing, and a
`planned` phase's work is sometimes cheaper taken now.

## Current position — <DATE>

_Nothing recorded yet. Written by `/programme:init` on <DATE>._

## Gates

<!-- trust: `reliable` | `flaky (1 in N)` | `unverified`. A result is only as good as its trust. -->

| gate                | command         | last run   | result | trust    |
| ------------------- | --------------- | ---------- | ------ | -------- |
| (example) typecheck | `bun run build` | 2026-01-01 | pass   | reliable |

## Settled decisions

| date       | decision                                             | who   | why                                                                      |
| ---------- | ---------------------------------------------------- | ----- | ------------------------------------------------------------------------ |
| 2026-01-01 | (example) adopted Valtio over Zustand for new stores | priya | Zustand's selector API caused referential-stability bugs across 3 stores |

## Open forks

| opened     | fork                                     | options                                                           | what would settle it                   |
| ---------- | ---------------------------------------- | ----------------------------------------------------------------- | -------------------------------------- |
| 2026-01-01 | (example) sync via polling vs. websocket | polling (simple, higher latency) · websocket (complex, real-time) | a latency budget from the product spec |

## Archive index

<!-- Every archiving event lands here, including a position moved out purely for length. Row count
     is NOT a phase count — `## The arc`'s status column is what says what has closed. -->

| date | phase | file |
| ---- | ----- | ---- |
