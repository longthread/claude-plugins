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

## Current position — <DATE>

_Nothing recorded yet. Written by `/programme:init` on <DATE>._

## Gates

<!-- trust: `reliable` | `flaky (1 in N)` | `unverified`. A result is only as good as its trust. -->
<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

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

| date | phase | file |
| ---- | ----- | ---- |
