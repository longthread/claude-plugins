# programme — changelog

> **What changed in each release, for someone deciding whether to upgrade.** Not a commit log — a
> reader here already has the plugin installed and wants to know what will be different afterwards.
> The writing rules are in `templates/CHANGELOG.md` at the repo root.

## 0.4.0 — 2026-10-07

**Nothing to do to upgrade.** A programme with no `mode` in `INDEX.md` is `assisted`, which behaves
as 0.3.0 did apart from the drafted interview and the printed next-session commands. An unknown or
blank mode reads as `assisted`.

### Added

- **Three modes per programme — `assisted`, `supervised`, `autonomous` — chosen at `/programme:init`
  and switched with the new `/programme:mode`.** The mode is a column in `INDEX.md`, and every
  session whose programme resolves is told it at start.
- **Handoff relays to the next session.** In supervised and autonomous mode it opens the next
  session in a herdr pane, primed with `/programme:resume`, and closes its own pane once the
  successor has resolved the programme and started — only ever a pane the relay opened. Autonomous
  sessions start their own handoff when the phase's terminal condition passes or they cannot
  progress, and the chain stops at a failing gate, a blocked dialog, the programme's terminal
  condition, a missing next target, a session that could not progress (a next step that needs a
  human decision among them), or the relay cap (`relayCap`, default 10). A successor that is
  blocked, exits, errors or times out leaves both panes open and stops the chain. Autonomous never
  closes a programme on its own: it writes the rest of the handoff and tells you closure awaits
  you.
- **Relayed sessions inherit the permission mode of the session that handed off** — never a more
  permissive one.

### Changed

- **The handoff interview is drafted, with evidence, before anything is asked.** Assisted shows the
  whole draft for you to edit; supervised asks only what it could not back with evidence; autonomous
  keeps only evidenced answers and lists the rest by number.
- **`/programme:resume` honours `PROGRAMME_SLUG`** and prints a fixed first line as soon as it has
  resolved the programme and started, in every mode, before the ledger is read; a relaying session
  waits for that line, not for the checks or the report.
- **The relaying modes need herdr and its skill**; `/programme:mode` checks both and refuses without
  them. Assisted needs neither.

## 0.3.0 — 2026-10-06

**Nothing to do to upgrade.** No ledger, template or config changes. Sessions already running keep
the old `Stop` behaviour until they restart. The hooks' per-session state, under
`~/.local/state/claude-programme/`, is now pruned of other sessions' files older than 30 days.

### Fixed

- **A session in a worktree is told its own programme, not the main checkout's.** The hooks now
  resolve from the directory the session is working in. They used the directory it started in,
  which never follows a session into a worktree.
- **Programmes that share a branch are no longer guessed between.** With two or more open
  programmes on the current branch, the session is told all of their names and how to pick one,
  and no ledger is injected; the `Stop` and `PreCompact` hooks stay silent. Previously every session
  on that branch was handed the first one listed.
- **The `Stop` guard no longer fires on files that were already dirty when the session began.**
  An untracked directory, or another session's uncommitted work, used to trigger it minutes into a
  read-only resume — and since it warns once per session, that spent its only warning. A file
  renamed into the code paths before the session began (`notes.md` to `src/notes.ts`) no longer
  counts either.
- **A stale or duplicated `INDEX.md` row no longer makes a programme ambiguous.** Only rows naming
  a programme directory that exists count, once each.

### Changed

- **The `Stop` guard's warning now reaches the model, not only you.** It costs one extra turn, at
  most once per session, and tells the model it may simply say the work is not programme work. In
  an adopting repo, the user-only warning never once led to a ledger write.

### Added

- **`/programme:resume <name>` pins that programme for the rest of the session**, including after a
  compaction, and every hook follows the pin. `/programme:handoff <name>` pins the same way; a new
  programme is pinned by the first such command after `/programme:init` creates it. A
  `PROGRAMME_SLUG` environment variable does the same for a session launched by a script or another
  agent.

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
