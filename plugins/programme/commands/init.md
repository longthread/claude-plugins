---
description: Bootstrap a programme — ledger, handoff prompt, deferred file, and the CLAUDE.md pointer
argument-hint: <programme-name>
---

Bootstrap a programme called **$1** so that multi-session work on it survives session boundaries.

If `$1` is empty, ask for a name before doing anything else. Derive `<SLUG>` from it: lowercase,
non-alphanumerics to hyphens.

## 1. Establish the ground truth

Run these and use the results; do not accept any figure from the conversation:

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git remote -v
date +%Y-%m-%d
```

Read `.claude/session-continuity.json` if it exists for `docsRoot` (default `docs`) and
`compareBranch` (default `origin/main`, or `origin/master` if that is what the remote has).

## 2. Refuse when it does not fit

A ledger suits work with a running thread across sessions. For a repo that is a series of unrelated
tickets it goes stale and then actively misleads — worse than nothing.

If `<docsRoot>/programmes/<SLUG>/` already exists, **stop and say so.** Do not overwrite a ledger;
offer `/programme:resume <SLUG>` instead.

Before creating anything else, if nothing in the conversation or the repo already shows a running
multi-session thread, **ask the user directly**: is `$1` ongoing work a later session would need to
resume, or a series of unrelated tickets? The test is whether a session would ever have to ask
"where were we?" — if not, a ledger only rots. Do not proceed on silence; the user can override and
say to bootstrap anyway.

## 3. Create the files

Copy from `${CLAUDE_PLUGIN_ROOT}/templates/`, substituting `<PROGRAMME_NAME>`, `<SLUG>`, `<DATE>`,
`<BRANCH>`, `<COMPARE_BRANCH>`, `<DOCS_ROOT>`. Substitute **only** those six literal token strings —
every other angle-bracketed span in a template is content, not a placeholder for you to fill:
`ledger.md`'s `archive/<YYYY-MM-DD>-<phase>.md` and `NEXT-SESSION.md`'s
`<a command a later session can actually run>`, `<what it prints once this phase is done>`, and
`<the spec or plan this phase executes>` are filled in later, by whoever writes those entries — not
by this command. A blanket replace of every `<…>` corrupts all five. **Copy each template's header
verbatim** — those headers are the mechanism, and every rule in them is stated in exactly one place.

- `ledger.md` → `<docsRoot>/programmes/<SLUG>/ledger.md`
- `NEXT-SESSION.md` → `<docsRoot>/programmes/<SLUG>/NEXT-SESSION.md`
- `deferred.md` → `<docsRoot>/programmes/<SLUG>/deferred.md`
- create the empty directory `<docsRoot>/programmes/<SLUG>/archive/`
- `INDEX.md` → `<docsRoot>/programmes/INDEX.md` **only if absent**; otherwise append one row
- `deferred-work.md` → `<docsRoot>/deferred-work.md` **only if absent**
- `session-continuity.json` → `.claude/session-continuity.json` **only if absent**, with `docsRoot`
  and `compareBranch` set to what you measured

The `INDEX.md` row is `| <SLUG> | active | <BRANCH> | programmes/<SLUG>/ledger.md |`.

**Delete every table row containing `(example)`, and the `<!-- Rows marked (example) … -->` comment
line, in every file you just wrote above** (`ledger.md`, `deferred.md`, and `deferred-work.md` when
you created it because it was absent). Those rows exist only to teach cell grain to a human reading
the template source — a real programme starts with empty tables, and a comment describing rows that
no longer exist is worse than no comment at all. If `deferred-work.md` already existed, you did not
write to it, so there is nothing to strip there.

## 4. Install the pointer

Append `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE-pointer.md` (with `<DOCS_ROOT>` substituted) to the
repo root `CLAUDE.md`, creating it if absent. If a "Programme continuity" section is already there —
the span from its `## Programme continuity` heading to the next `##` heading or end of file — replace
that span in place rather than adding a second.

This step matters more than any command in this plugin: an always-loaded pointer plus a ledger whose
header states how to write it is what actually kept a ledger current across ~15 sessions, with no
hook and no command that ever triggered a write — a read-only precursor to `/programme:resume`
existed for most of that window but never caused one.

## 5. Seed the position and the gates, by interview

Do not write a placeholder position. Ask, and write the answers in:

1. What is this programme trying to achieve, in one sentence?
2. **What is its terminal condition — a command a later session can run, and the output that means
   it is done?** Put it in `NEXT-SESSION.md`'s Terminal condition fields.
3. What is already true today that a fresh session would otherwise re-derive?
4. What decisions are already settled, who settled them, and why? One row each in Settled decisions.
5. **What are this project's gates, and which of them are flaky?** One row each in the ledger's
   Gates table, filling the `trust` column. Ask for the flake rate where there is one.

Each answer **replaces** a placeholder already sitting in the file it targets — questions 1 and 3
replace `ledger.md`'s `_Nothing recorded yet._` under `## Current position` with the actual
narrative, and question 2 replaces `NEXT-SESSION.md`'s `<a command a later session can actually
run>` / `<what it prints once this phase is done>` tokens. Leaving the placeholder text next to the
answer is the same defect as not asking.

`NEXT-SESSION.md`'s `Start here` block gets the same treatment: `/programme:resume` follows it
**verbatim**, so `_Nothing to resume yet._` cannot stand next to a position and terminal condition
the interview just established. Write the first concrete step toward question 2's terminal
condition — if that step really is just "read the ledger and begin," say so explicitly rather than
leaving the template's placeholder sentence in place.

## 6. Report

Show the file tree created, the `INDEX.md` row, and the exact `CLAUDE.md` change.
