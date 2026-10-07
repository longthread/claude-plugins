# programme

A Claude Code plugin that carries multi-session work across session boundaries: a durable ledger, a
pointer that teaches a session when to write to it, an interviewed handoff, and a guard that fires
when a session changes code without moving the record.

## What it is

Long-running work spans many sessions. Each one ends with context exhausted and its findings in
scrollback; the next re-derives position from the code, repeats settled decisions, and loses the
expensive lessons — the ones a defect taught, not a design. `programme` gives a repo a place to put
that: `docs/programmes/<slug>/ledger.md`, kept under ~250 lines, read in full at the start of every
session.

It does not summarize your work for you. `/programme:handoff` interviews — "what did you measure",
"what did you get wrong", "which claims in the ledger are now false" — because a prompt that asks
"what did you do?" produces a changelog, and a changelog is not what makes a handoff worth reading.

## The evidence that the artifact is the mechanism, not the command

This plugin was extracted from a repo that solved session continuity over roughly fifteen sessions
before any of this existed. Measured against `docs/programme-ledger.md`'s git history,
2026-08-06 → 2026-08-12:

| measure                                  | value                                    |
| ---------------------------------------- | ---------------------------------------- |
| commits touching the ledger              | **58** in 7 days                         |
| per session (~15 sessions)               | **~4**                                   |
| growth                                   | 150 → 2322 lines, monotonic, 122 headers |
| commands that existed to trigger a write | **none**                                 |
| hooks that existed to trigger a write    | **none**                                 |
| skills that existed to trigger a write   | **none**                                 |

Four writes per session, at phase boundaries, with no hook and no skill in existence, and no command
that ever triggered one — a read-only precursor to `/programme:resume` existed for 42 of the 58
commits (added 2026-08-07) but only ever read the ledger, never wrote to it. What drove the writes
was two pieces of prose that were always loaded: the ledger header, which states its
own maintenance rule and is re-read every time the file is opened, and a `CLAUDE.md` pointer with a
precedence rule. This plugin's first job is to install those two things — a ledger that teaches its
own upkeep, and the pointer that carries the cadence — giving a new repo in minutes what took the
source repo several sessions to grow on its own. The commands are conveniences layered on top of
that artifact, not the mechanism itself.

## Install

```
/plugin marketplace add longthread/claude-plugins
/plugin install programme@longthread
```

Verified 2026-08-14: installs, enables, and the hooks resolve a real programme. `/programme:init`
was run against a 2710-line ledger, and the `Stop` guard was confirmed to fire when code moves and
the ledger does not, then latch silent.

To install from a local clone instead — edits go live on the next session start, which is what you
want while developing — give `marketplace add` the path to the **marketplace** root (the one holding
`.claude-plugin/marketplace.json`), not this plugin's directory:

```
/plugin marketplace add /abs/path/to/claude-plugins
```

**A local marketplace is read in place, never copied.** The recorded `installLocation` is the path
you gave. Point it at a clone that stays put — never at a directory inside a repo whose branch you
switch, or the plugin vanishes globally on the first checkout that predates it.

## The five commands

- **`/programme:init <name>`** — bootstraps a programme: copies the templates into
  `docs/programmes/<slug>/`, adds a row to `docs/programmes/INDEX.md`, installs the `CLAUDE.md`
  pointer, and interviews for the arc (the goal, the programme's own terminal condition, and a row per phase),
the starting position, this phase's terminal condition, and the project's gates (with their trust). Refuses on a repo that looks like a series of unrelated tickets rather
  than a running thread, unless told to proceed anyway.
- **`/programme:resume [name]`** — resolves the active programme from the current branch against
  `INDEX.md`, reads the ledger in full — `## The arc` first, so the goal and the phases still to come frame the
phase rather than trail it — then `NEXT-SESSION.md` verbatim, then **runs** every command in
  the State table's `verify with` column rather than trusting the values next to them — the source
  repo has a live example of two documents disagreeing about the same figure.
- **`/programme:handoff [name]`** — the deliberate end-of-thread write. Measures state itself
  (`git fetch`, ahead-of-compare count, every declared gate), asks the five interview questions — the fifth against the arc, so a later phase's work can be pulled
forward or a doomed piece of work refused — corrects the ledger in place, reconciles the arc, archives a closed phase, and rewrites `NEXT-SESSION.md` wholesale.
  On a closing handoff, refuses to mark the programme closed while `deferred.md` still has open rows.
- **`/programme:status [name] [--gates]`** — where the programme is, then whether its record is
  still true: runs every `verify with` command in the State table and reports what has drifted, lists
  what is owed, and stops. **It writes nothing, deliberately** — a status that quietly corrects the
  record cannot tell you whether the record is honest, because running it makes the answer yes. Slow
  gates are printed as recorded, with their `trust` and `last run`, and only run with `--gates`.
- **`/programme:mode <name> <mode>`** — records the mode in `INDEX.md` after checking that
  supervised or autonomous can be honoured.

## The arc, and why it is a table

Every other section of the ledger is phase-scoped. `Current position` is rewritten wholesale at each
handoff and archived when a phase closes, so a goal written there does not outlive the phase that
recorded it — it survives only if someone restates it every phase, which is discipline, not
structure, and this plugin's whole argument is that the artifact is the mechanism.

`## The arc` is the one section a handoff does not rewrite and archiving does not move: the goal, the
programme's terminal condition as a command and its expected output, and a row per phase with a
`status` of `done` · `current` · `planned`. It is a table rather than a paragraph because a paragraph
restating the goal is an instruction whose omission changes no artifact, while the row a handoff has
to flip is checkable. Its job is to make work refusable — code a `planned` phase deletes is not worth
writing, and a `planned` phase's work is sometimes cheaper taken now — which is exactly what
`/programme:handoff`'s fifth question asks against it.

## The config file

`.claude/session-continuity.json`, created by `/programme:init` if absent, with `docsRoot` and
`compareBranch` only:

```json
{
  "docsRoot": "docs",
  "compareBranch": "origin/main"
}
```

- `docsRoot` — where `programmes/` lives. Defaults to `docs`.
- `compareBranch` — what `resume` and `handoff` measure "ahead of" against.
- `codePathspec` — optional, not written by `/programme:init`. Overrides what the `Stop` guard
  counts as "code changed"; its default (everything except markdown, `docsRoot`, and `.claude/`) is
  derived from `docsRoot`, not hardcoded, so a repo whose `docsRoot` isn't `docs` still gets it
  right without this key.
- `relayCap` — optional. How many sessions an autonomous or supervised chain may relay through
  before it stops; default 10.

A dedicated file rather than `settings.json`: the gate list is structured, which rules out `env`, and
unknown keys in `settings.json` are not a contract worth relying on.

## Which programme a session is in, and what the `Stop` guard counts

The hooks resolve the programme from the directory the session is **working in** — a worktree
resolves its own branch's programme — in this order: a programme pinned by `/programme:resume
<name>` or `/programme:handoff <name>` earlier in the session (a new programme is pinned by the
first such command after `/programme:init` creates it); a `PROGRAMME_SLUG` environment variable;
the **one** open `INDEX.md` row whose branch is the current branch; the only open programme. When
several open programmes share the branch, nothing is assumed: `SessionStart` names them and says
how to pick, and the `Stop` and `PreCompact` hooks stay silent. The pin comes from a silent
`UserPromptSubmit` hook that reads each prompt only to spot `/programme:resume|handoff <name>`, and
stores just that slug.

The `Stop` guard counts what **this session** changed: commits since it started, and working-tree
changes measured against a fingerprint of the dirt that was already there when it began. A session
that moves to another worktree is judged on its commits only. It warns once per session, to the
model as well as to you — one extra turn — and the model may answer that the work is not programme
work. A user-only warning was tried first; measured in an adopting repo, it never once led to a
ledger write.

## Modes, and the relay

Each programme has a mode in `INDEX.md` — `assisted` (the default), `supervised` or `autonomous` —
set at `/programme:init` or with `/programme:mode`. It decides two things: how much of the handoff
interview is put to you, and whether a handoff starts the next session itself.

| relay point       | assisted                           | supervised                        | autonomous                                |
| ----------------- | ---------------------------------- | --------------------------------- | ----------------------------------------- |
| handoff interview | drafted with evidence; you edit it | you're asked only the unevidenced | evidenced answers only; the rest left out |
| the next session  | printed for you to start           | opened in a herdr pane            | opened in a herdr pane                    |
| after it resumes  | asks to proceed                    | asks to proceed                   | proceeds; hands off by itself             |
| a phase closes    | stop                               | stop                              | continue                                  |

Supervised and autonomous need [herdr](https://herdr.dev) and its skill; they do every herdr step
through that skill, so this plugin carries no herdr code of its own. A relayed session gets the same
permission mode as the one that handed off, and only a pane the relay opened is ever closed, and
only once the successor's `Resumed programme` line has appeared. The chain stops at a failing gate,
a blocked dialog, the programme's terminal condition, a missing next target, a next step that needs a
human decision, or `relayCap` relays (default 10); a successor that is blocked, exits, errors or
times out leaves both panes open. An unknown or blank mode reads as `assisted`.

## When NOT to use it

This fits multi-session programme work with a running thread — the kind where a session would ever
have to ask "where were we?" It does not fit a repo that is a series of unrelated tickets. Point it
at one of those and the ledger goes stale, and a stale ledger is worse than no ledger: it actively
misleads, the way a comment describing behaviour the code no longer has misleads. `/programme:init`
asks before bootstrapping for exactly this reason, and will refuse on silence.

With no `.claude/session-continuity.json` and no `docs/programmes/` directory, every hook exits 0
silently — a repo that hasn't opted in feels nothing.

## Deliberately not built

- **A checkpoint-detection hook** (watching tool calls for merges, gate runs, version bumps). It
  would add machinery to enforce a behaviour that already happened 58 times without it, and a hook
  that fires on every qualifying tool call risks nagging on ordinary work.
- **A session journal.** The ledger already serves that role — it's written at each checkpoint, not
  only at session end.
- **A `SessionEnd` warning.** By session end the model can no longer act and the record most in need
  of saving is already lost — a scolding, not a save. The `Stop` guard, latched to fire once and
  addressed to the model, catches the same lapse while the work is still fresh enough to act on.
- **A `ledger-discipline` skill.** It had no moment where it was the only thing loaded: editing the
  ledger requires reading it, and the header is right there. It was also the largest source of
  duplicated rules in an earlier draft of this design. Its content lives in the two files that are
  already loaded at the moments it would have fired — the ledger header and the `CLAUDE.md` pointer.

## `PreCompact` is unverified

`hooks/pre-compact.sh` warns when the ledger hasn't moved and a compaction is about to discard
whatever hasn't been written. **This channel is unverified**: `PreCompact` is not a confirmed member
of Claude Code's `hookSpecificOutput` union and does not support prompt-type hooks, so its output may
reach only the user, never the model. **Nothing in this design depends on it.** The load-bearing
mechanism is the ledger header and the `CLAUDE.md` pointer (see above); `SessionStart`'s
`additionalContext` re-injection after compaction is confirmed and does the real work of
post-compaction recovery.

## Where each rule lives — exactly one home

Every rule below has exactly one home, in prose where the rule is about _when_ or _why_, and as a
table schema where the rule can be a column instead. `tests/test-templates.sh` reads the six
markdown templates and `tests/test-commands.sh` reads the five commands; both assert that a rule
appears in its home **and** that it does not appear anywhere else. Neither reaches the hooks.

Both readers fold newlines to spaces before matching. Without that, a rule restated across a
formatter's line wrap satisfies the negative assertion while the duplication is right there —
the guard passes precisely when it should fire. That hole was live until 2026-08-14.

`session-start.sh` restates two of these rules
(the ledger-outranks-handoff precedence and "verify, don't trust") when it re-injects the ledger
position after compaction; whether that is duplication or the only thing carrying those two rules
across a compaction boundary is open (the live-run checklist's Question 2, in the repo this was extracted from).

| rule                                 | home                      | form                                        |
| ------------------------------------ | ------------------------- | ------------------------------------------- |
| when to write (the cadence)          | `CLAUDE.md` pointer       | prose — needed away from the file           |
| ledger outranks every handoff        | `CLAUDE.md` pointer       | prose — the only file above both            |
| correct in place                     | `ledger.md` header        | prose — genuinely about that file           |
| cite or flag `UNVERIFIED`            | `ledger.md` header        | prose — governs its narrative               |
| absolute dates                       | `ledger.md` header        | prose                                       |
| archive past 250 lines               | `ledger.md` header        | prose — about its own size                  |
| who decided, and why                 | `ledger.md`               | schema — `who` \| `why` columns             |
| gate trust                           | `ledger.md` Gates table   | schema — `trust` column                     |
| the goal, and which phases remain    | `ledger.md` The arc       | schema — `status` column                    |
| an archive row is not a closed phase | `ledger.md` Archive index | prose — about its own table                 |
| don't trust a figure, re-derive      | `NEXT-SESSION.md`         | schema — `verify with` column               |
| terminal conditions as observables   | `NEXT-SESSION.md`         | schema — `command` + `expected`             |
| fix shape, not a title               | both deferred tables      | schema — `current behaviour` \| `fix shape` |
| promotion before close               | `deferred.md` header      | prose — that file's lifecycle               |
| verify against the tree              | `commands/resume.md`      | procedure                                   |
| resolve which programme is active    | `commands/resume.md`      | procedure — the others defer to it          |
| resolve a shared branch by asking    | `commands/resume.md`      | procedure — the hooks stay silent instead   |
| report without repairing             | `commands/status.md`      | procedure                                   |
| the five interview questions         | `commands/handoff.md`     | procedure                                   |
| the herdr dependency check           | `commands/mode.md`        | procedure                                   |
| what a mode does at each relay point | `commands/handoff.md` · `commands/resume.md` | procedure, where each point happens |
| `PROGRAMME_SLUG` precedence          | `commands/resume.md`      | procedure                                   |
| when an autonomous session hands off | `commands/resume.md`      | procedure                                   |
| relay stop conditions, the cap       | `commands/handoff.md`     | procedure                                   |
| which pane a relay may close         | `commands/handoff.md`     | procedure                                   |
| what the `mode` column means, and how to read it | `templates/INDEX.md` | prose — its header comment            |

`fix shape` appears in two tables — `deferred.md` and `deferred-work.md` — because deferred work has
two lifetimes: some items die with the programme, some outlive it. That is one schema definition
shared by two tables, not a rationale stated twice.

One pair is prose on both sides deliberately: `deferred.md`'s header says an item that outlives the
programme belongs in `deferred-work.md`, and `deferred-work.md`'s header says an item scoped to one
programme belongs back in `deferred.md`. Each file states its own scope, which is unique per file;
the routing half is the same rule read from the opposite side, and both halves have to exist so a
maintainer who opens only one of the two files can still find the door.

Full rationale for every design decision here, including the three corrections made against measured
evidence: `docs/tooling/2026-08-12-session-continuity-plugin-design.md` in the repo this plugin was
extracted from.
