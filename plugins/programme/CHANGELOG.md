# programme — changelog

> **What changed in each release, for someone deciding whether to upgrade.** Not a commit log — a
> reader here already has the plugin installed and wants to know what will be different afterwards.
> The writing rules are in `templates/CHANGELOG.md` at the repo root.

## 0.2.0 — 2026-08-20

**Nothing to do to upgrade.** A ledger written before this release keeps working unchanged, and
picks up the new section at its next `/programme:handoff`.

### Added

- **`## The arc`, above `## Current position` in the ledger** — the programme's goal, its own
  terminal condition as a command and expected output, and a table with a row per phase and a
  `status` of `done` · `current` · `planned`. Every other section is phase-scoped: the position is
  rewritten wholesale at each handoff and archived when a phase closes, so a goal recorded there did
  not outlive the phase that recorded it. This is the one section a handoff does not rewrite and
  archiving does not move.
- **`/programme:handoff` asks one question against it** — whether the next phase still sits where the
  map says, and whether any later phase's work is cheaper taken now. That question is the point of
  the section: it is what makes work in front of you refusable when a later phase will delete it.
- **The `SessionStart` hook injects the arc** alongside the current position, so it reaches a session
  with no command run — including after a compaction, which is when the ledger is most needed and
  least present.
- **`/programme:init` interviews for it** — seven questions now, not five. The two new ones are the
  programme's terminal condition, kept distinct from the phase's, and the phase list.
- **Closing a phase flips its row to `done`; closing a programme is refused** while any row is still
  `current` or `planned`.
- **A ledger with no arc adopts one at its next handoff**, so programmes that predate this release
  are not left behind — they are precisely the ones whose arc has never been written down.

### Changed

- **`/programme:resume` reads the arc first** and reports every phase still `planned`. The arc frames
  the phase rather than trailing it.
- **`/programme:status` reports progress from the arc's `status` column.** It previously read what
  had closed by counting Archive index rows, which was wrong: that table also gains a row whenever a
  position is moved out purely for length, and again when a programme closes.
- **A programme-level terminal condition now has a home.** `/programme:status` used to ask for it
  "if the ledger states one" — there was no place to state it, so a met phase condition could read
  as a finished programme.

### Fixed

- **A ledger section no longer swallows the one after it** when the following heading begins with the
  same text. A ledger carrying both `## Archive` and `## Archive index` would have had the first run
  to the end of the file, taking every later section with it.
- **`/programme:init` no longer contradicts itself** about which angle-bracketed spans it fills: its
  file-copying step said they were filled later by someone else, while its interview step filled two
  of them.

## 0.1.0 — 2026-08-14

### Added

- **First marketplace release.** A durable ledger at `docs/programmes/<slug>/ledger.md` with its
  templates, four commands — `/programme:init`, `/programme:resume`, `/programme:handoff`,
  `/programme:status` — an always-loaded `CLAUDE.md` pointer carrying the write cadence, and a `Stop`
  guard that fires once per session when code moved and the ledger did not.
