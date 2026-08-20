# Programme arc — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `programme` plugin a durable `## The arc` section at the top of the ledger — the programme's goal, its own terminal condition, and a phase table with a `status` column — and wire the four commands to seed it, read it first, reconcile it, and report from it.

**Architecture:** Every existing ledger section is phase-scoped. `## Current position` is rewritten wholesale at each handoff (`commands/handoff.md` step 3) and archived when a phase closes (step 4 plus the ledger header's move rule), so a goal written there does not outlive the phase that recorded it. `## The arc` is the one section a handoff does not rewrite and archiving does not move. It is a table rather than prose because the row a handoff must flip is checkable and a paragraph is not. The commands change around it: `init` interviews for it, `resume` reads it before the position, `handoff` asks one question against it and flips its rows, `status` reports from its `status` column instead of miscounting the Archive index.

**Tech Stack:** Markdown templates and command prompts; bash test harness (`tests/harness.sh` — `assert_contains` / `assert_not_contains` / `assert_eq`); `bun run site/build.mjs` for the published site.

**Spec:** https://github.com/longthread/claude-plugins/issues/1 and the agreed scope in https://github.com/longthread/claude-plugins/issues/1#issuecomment-5359334021

## Global Constraints

- **Working directory for every command below:** `/home/srinath/_workarea/personal/github/longthread/claude-plugins`. Plugin paths are relative to `plugins/programme/`.
- **Gate for every task:** `cd plugins/programme && bash tests/run-all.sh` — six suites, **108 assertions, 0 failed** at the pre-change baseline (`test-commands` 24 · `test-lib` 17 · `test-pre-compact` 8 · `test-session-start` 16 · `test-stale-ledger` 13 · `test-templates` 30).
- **Single-homing is enforced by the negative assertions** in `tests/test-templates.sh` and `tests/test-commands.sh`. No file may restate a rule that lives in another. Every rule introduced by this plan is stated in exactly one file; the plan names which.
- **Both test files fold each file to one line** (`tr '\n' ' ' | tr -s ' '`) before matching, so an asserted phrase must contain single spaces only and must not span a construct the fold would alter. Section *ordering* is invisible to that fold — Task 1 adds the one check that reads the file unfolded.
- **No formatter runs in this repo** (no prettier config, no CI workflow), so hand-aligned table pipes stay as written.
- **`docs/` is generated output.** `site/build.mjs` calls `rmSync(OUT, {recursive: true, force: true})` on it. Never hand-edit `docs/`; never put working files there. This plan lives in `plans/` for that reason.
- **Status vocabulary, verbatim:** `done` · `current` · `planned`.
- **Branch:** all work lands on `feat/programme-arc`, cut from `main`. Do not push.

---

### Task 0: Branch

- [ ] **Step 1: Cut the branch**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git status --short          # expect: empty
git checkout -b feat/programme-arc
```

- [ ] **Step 2: Record the baseline**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected, exactly:

```
test-commands
24 run, 0 failed
test-lib
17 run, 0 failed
test-pre-compact
8 run, 0 failed
test-session-start
16 run, 0 failed
test-stale-ledger
13 run, 0 failed
test-templates
30 run, 0 failed
```

If any suite is already red, **stop** — this plan assumes a green baseline and every later step reads "the new assertions fail, nothing else does."

---

### Task 1: `## The arc` in the ledger template

**Files:**

- Modify: `plugins/programme/templates/ledger.md` (insert a section between the header blockquote and `## Current position`; move one comment line off `## Gates`; add a note under `## Archive index`)
- Test: `plugins/programme/tests/test-templates.sh`

**Interfaces:**

- Consumes: nothing.
- Produces — the exact anchor strings later tasks reference:
  - heading `## The arc` (Tasks 3, 4, 5 quote it)
  - `**Goal:**` (Task 2 fills it)
  - `**Terminal condition — the programme's, not the phase's.**` (Task 5 quotes the scope)
  - table header `| phase | status | what it delivers |` (Tasks 2 and 4 write rows)
  - status vocabulary `done` · `current` · `planned` and the rule `exactly one row is \`current\``
  - Archive-index note `Row count is NOT a phase count` (Task 5 defers to it rather than restating it)
  - three angle-bracket spans Task 2 fills: `<what this programme is for, in one sentence>`, `<a command a later session can run to prove the whole programme is done>`, `<what that command prints once the whole programme is done>`

- [ ] **Step 1: Write the failing assertions**

Add to `plugins/programme/tests/test-templates.sh`, immediately after the existing `assert_contains "$L" "| date | phase | file |" "ledger: archive index table"` line:

```bash
# --- the arc: the one section that is neither rewritten at handoff nor moved by archiving ---
assert_contains "$L" "## The arc" "ledger: the arc section exists"
assert_contains "$L" "**Goal:**" "ledger: the arc carries the programme's goal"
assert_contains "$L" "the programme's, not the phase's" "ledger: the arc's terminal condition is scoped to the programme"
assert_contains "$L" "| phase | status | what it delivers |" "ledger: the arc is a table with a status column"
assert_contains "$L" "exactly one row is \`current\`" "ledger: the arc's status vocabulary is pinned"
assert_contains "$L" "handoff does NOT rewrite and archiving does NOT move" "ledger: the arc states why it is durable"
assert_contains "$L" "Row count is NOT a phase count" "ledger: the Archive index states its own grain"

# The phase-level terminal condition stays distinct from the programme-level one. Both use the same
# Command/Expected-output schema deliberately — the scope line is the only thing separating them, so
# it has to live in exactly one of the two files.
assert_contains "$N" "once this phase is done" "prompt: its terminal condition is the PHASE's"
assert_not_contains "$N" "not the phase's" "prompt does NOT restate the programme-level scope"

# Ordering is invisible to read_t, which folds the file to one line. The arc's whole claim is that
# it frames the position rather than trailing it, and placement is the only thing making that true —
# so this check reads the file unfolded. `|| true` because grep exits 1 on no match and this file
# runs under `set -e`, which would otherwise kill the suite instead of reporting the failure.
# `||` binds to the whole pipeline, not just `cut` — verified in this shell, both with and without
# a match. Do not "fix" this into a brace group; it already covers the grep.
arc_ln=$(grep -n '^## The arc$' "$T/ledger.md" | head -1 | cut -d: -f1 || true)
pos_ln=$(grep -n '^## Current position' "$T/ledger.md" | head -1 | cut -d: -f1 || true)
if [ -n "$arc_ln" ] && [ -n "$pos_ln" ] && [ "$arc_ln" -lt "$pos_ln" ]; then
  ord=above
else
  ord="arc=${arc_ln:-missing} pos=${pos_ln:-missing}"
fi
assert_eq "above" "$ord" "ledger: the arc sits ABOVE Current position"
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-templates.sh
```

Expected: `40 run, 8 failed`. Ten assertions are added; **two of them pass immediately** and must — `prompt: its terminal condition is the PHASE's` (`NEXT-SESSION.md` already says `once this phase is done`) and `prompt does NOT restate the programme-level scope`. The other eight are red, including the ordering one reporting `arc=missing pos=19`. Every pre-existing assertion still `ok`.

- [ ] **Step 3: Insert the arc section**

In `plugins/programme/templates/ledger.md`, insert between the header blockquote's last line (`>   unread.`) and `## Current position — <DATE>`:

```markdown
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

`status` is `done` · `current` · `planned`, and **exactly one row is `current`**. A later phase's row
is what makes work in front of you refusable: code that a `planned` phase deletes is not worth
writing, and a `planned` phase's work is sometimes cheaper taken now.
```

- [ ] **Step 4: Move the `(example)` comment off `## Gates`**

The arc is now the first table in the file, so the file-wide `(example)` note belongs there and must not be stated twice. Under `## Gates`, delete this line only:

```
<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->
```

Leave the `<!-- trust: ... -->` line above it untouched. `commands/init.md` step 3 already says to delete "the `<!-- Rows marked (example) … -->` comment line" — singular — so moving it keeps that instruction true.

- [ ] **Step 5: Give the Archive index its own grain note**

Replace the `## Archive index` block's opening so it reads:

```markdown
## Archive index

<!-- Every archiving event lands here, including a position moved out purely for length. Row count
     is NOT a phase count — `## The arc`'s status column is what says what has closed. -->

| date | phase | file |
| ---- | ----- | ---- |
```

- [ ] **Step 6: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-templates` reports `40 run, 0 failed`; every other suite unchanged from the Task 0 baseline.

- [ ] **Step 7: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/templates/ledger.md plugins/programme/tests/test-templates.sh
git commit -m "feat(programme): add the arc — a durable goal and phase map above Current position"
```

---

### Task 2: `/programme:init` seeds the arc

**Files:**

- Modify: `plugins/programme/commands/init.md` (step 3's angle-bracket-span list; step 5 in full)
- Test: `plugins/programme/tests/test-commands.sh`

**Interfaces:**

- Consumes: Task 1's three arc spans, the `| phase | status | what it delivers |` header, and the `done`/`current`/`planned` vocabulary.
- Produces: nothing later tasks read. Renumbers step 5's interview from 5 questions to 7; `NEXT-SESSION.md`'s `Start here` paragraph now points at **question 4**, not question 2.

- [ ] **Step 1: Write the failing assertions**

Add to `plugins/programme/tests/test-commands.sh`, immediately before the `# --- status is read-only` block:

```bash
# --- init seeds the arc, or it ships permanently empty ---
assert_contains "$INIT" "What are its phases, in order, and which one are you starting?" \
  "init: interviews for the phase map"
assert_contains "$INIT" "a one-row arc is honest" "init: an unknown decomposition still yields a row"
assert_contains "$INIT" "the output that means the WHOLE programme is done" \
  "init: interviews for the programme's terminal condition, distinct from the phase's"
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-commands.sh
```

Expected: `27 run, 3 failed`, the three new ones red.

- [ ] **Step 3: Fix step 3's span list, which this change would otherwise falsify**

`commands/init.md` step 3 currently says the non-token angle-bracket spans "are filled in later, by whoever writes those entries — **not by this command**", while step 5 says the command fills two of them by interview. That contradiction predates this plan; the arc adds three more spans and makes it worse, so resolve it here. Replace this sentence:

```
`ledger.md`'s `archive/<YYYY-MM-DD>-<phase>.md` and `NEXT-SESSION.md`'s
`<a command a later session can actually run>`, `<what it prints once this phase is done>`, and
`<the spec or plan this phase executes>` are filled in later, by whoever writes those entries — not
by this command. A blanket replace of every `<…>` corrupts all five.
```

with:

```
`ledger.md`'s `archive/<YYYY-MM-DD>-<phase>.md` and `NEXT-SESSION.md`'s `<the spec or plan this
phase executes>` are filled in later, by whoever writes those entries. `## The arc`'s three spans
and `NEXT-SESSION.md`'s `<a command a later session can actually run>` /
`<what it prints once this phase is done>` are filled by **step 5's interview**, not by this copy.
A blanket replace of every `<…>` corrupts all eight.
```

- [ ] **Step 4: Rewrite step 5**

Replace the whole of `## 5. Seed the position and the gates, by interview` — heading, question list, and the two paragraphs after it, up to but not including `## 6. Report` — with:

```markdown
## 5. Seed the arc, the position and the gates, by interview

Do not write a placeholder position. Ask, and write the answers in:

1. What is this programme trying to achieve, in one sentence?
2. **What is the programme's terminal condition — a command a later session can run, and the output
   that means the WHOLE programme is done?**
3. **What are its phases, in order, and which one are you starting?** One row each in `## The arc`,
   `status` `current` on the one being started and `planned` on the rest. If the decomposition does
   not exist yet, write the single row for the phase being started and say that is all that is
   known — a one-row arc is honest; an empty one is the omission this section exists to prevent.
4. **What is THIS phase's terminal condition — a command, and the output that means the phase is
   done?** Put it in `NEXT-SESSION.md`'s Terminal condition fields. It is question 2's answer only
   if this is the only phase; if it is not, writing the same condition in both places makes the
   programme look finished the moment the first phase closes.
5. What is already true today that a fresh session would otherwise re-derive?
6. What decisions are already settled, who settled them, and why? One row each in Settled decisions.
7. **What are this project's gates, and which of them are flaky?** One row each in the ledger's
   Gates table, filling the `trust` column. Ask for the flake rate where there is one.

Each answer **replaces** a placeholder already sitting in the file it targets — questions 1–3
replace `ledger.md`'s three `## The arc` spans and its example rows, question 5 replaces
`_Nothing recorded yet._` under `## Current position` with the actual narrative, and question 4
replaces `NEXT-SESSION.md`'s `<a command a later session can actually run>` / `<what it prints once
this phase is done>` tokens. Leaving the placeholder text next to the answer is the same defect as
not asking.

`NEXT-SESSION.md`'s `Start here` block gets the same treatment: `/programme:resume` follows it
**verbatim**, so `_Nothing to resume yet._` cannot stand next to a position and terminal condition
the interview just established. Write the first concrete step toward question 4's terminal
condition — if that step really is just "read the ledger and begin," say so explicitly rather than
leaving the template's placeholder sentence in place.
```

- [ ] **Step 5: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-commands` `27 run, 0 failed`; `test-templates` `40 run, 0 failed`; the other four unchanged.

- [ ] **Step 6: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/commands/init.md plugins/programme/tests/test-commands.sh
git commit -m "feat(programme): interview for the arc at init, and fix step 3's span list"
```

---

### Task 3: `/programme:resume` reads the arc first

**Files:**

- Modify: `plugins/programme/commands/resume.md` (the "Read, in this order" list; the closing report paragraph)
- Test: `plugins/programme/tests/test-commands.sh`

**Interfaces:**

- Consumes: Task 1's `## The arc` heading and `planned` status value.
- Produces: nothing later tasks read.

- [ ] **Step 1: Write the failing assertions**

Add to `plugins/programme/tests/test-commands.sh`, immediately after the three `init:` assertions from Task 2:

```bash
# --- resume: the arc frames the phase rather than trailing it ---
assert_contains "$RESUME" "starting with \`## The arc\`" "resume: reads the arc before the position"
assert_contains "$RESUME" "every phase still \`planned\`" "resume: its report names what remains"
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-commands.sh
```

Expected: `29 run, 2 failed`.

- [ ] **Step 3: Amend the read order**

In `commands/resume.md`, replace item 1 of `## Read, in this order`:

```
1. `<docsRoot>/programmes/<SLUG>/ledger.md` — **in full**
```

with:

```
1. `<docsRoot>/programmes/<SLUG>/ledger.md` — **in full, starting with `## The arc`**: the goal, the
   programme's terminal condition, and which phases are still `planned`. Read it before the
   position, not after — a phase read without the arc around it is a phase you cannot refuse work
   inside.
```

- [ ] **Step 4: Amend the report**

Replace the paragraph under `## Then report, before doing any work`:

```
State: which programme you resolved and how; the position as the ledger records it; what you
measured and what drifted; and the terminal condition you are working toward, quoting its command
and expected output. Then ask whether to proceed.
```

with:

```
State: which programme you resolved and how; **the arc — the goal, the programme's terminal
condition, the `current` phase, and every phase still `planned`**; the position as the ledger
records it; what you measured and what drifted; and the phase's terminal condition you are working
toward, quoting its command and expected output. Then ask whether to proceed.
```

- [ ] **Step 5: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-commands` `29 run, 0 failed`; all other suites unchanged.

- [ ] **Step 6: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/commands/resume.md plugins/programme/tests/test-commands.sh
git commit -m "feat(programme): resume reads the arc first, and reports what remains"
```

---

### Task 4: `/programme:handoff` asks against the arc and flips its rows

**Files:**

- Modify: `plugins/programme/commands/handoff.md` (step 2's interview; step 3's heading and body; step 4; step 7's report)
- Test: `plugins/programme/tests/test-commands.sh`

**Interfaces:**

- Consumes: Task 1's `## The arc` heading and the `done`/`current` status values.
- Produces: the interview is now **five** questions, not four — Task 6 updates the README line that says "four".

- [ ] **Step 1: Write the failing assertions**

Add to `plugins/programme/tests/test-commands.sh`, immediately after the two `resume:` assertions from Task 3:

```bash
# --- handoff: the one question that makes a later phase's work refusable, and the row flip ---
assert_contains "$HANDOFF" "cheaper taken now" "handoff: asks whether later-phase work should be pulled forward"
assert_contains "$HANDOFF" "The arc is corrected here or nowhere" "handoff: the arc is reconciled at handoff"
assert_contains "$HANDOFF" "becomes \`done\`" "handoff: closing a phase flips its arc row"
assert_contains "$HANDOFF" "name which rows you read to conclude that" \
  "handoff: a no-change answer to question 5 must still cite the rows"
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-commands.sh
```

Expected: `33 run, 4 failed`.

- [ ] **Step 3: Add interview question 5**

In `commands/handoff.md` step 2, after question 4 (`**What is the next terminal condition — a command, and the output that means it is done?**`) and before the `**On question 2: …**` paragraph, insert:

```markdown
5. **Does the next phase still sit where `## The arc` says — and is any later phase's work cheaper
   taken now?** Ask it against the table, row by row, not from memory. Two shapes to name out loud:
   work this phase would build that a `planned` phase later deletes, and work scoped out as "a later
   phase's" that costs less inside this one than it will on its own. **If the answer is "nothing
   to change", name which rows you read to conclude that** — the failure this question exists to
   catch is answering it from memory.
```

- [ ] **Step 4: Make step 3 write the arc**

Change step 3's heading from:

```
## 3. Write the ledger and `deferred.md`
```

to:

```
## 3. Write the arc, the ledger and `deferred.md`
```

and insert this paragraph immediately under the heading, before the existing `Diff what the ledger claims…` paragraph:

```markdown
**The arc is corrected here or nowhere.** If question 5 moved a phase, split one, dropped one, or
changed what a phase delivers, edit `## The arc` now and say what changed in the position narrative.
```

- [ ] **Step 5: Make step 4 flip the rows**

In step 4 (`## 4. Archive if a phase closed`), append this paragraph after the existing `A closed phase is archived immediately…` paragraph:

```markdown
**Flip the arc's rows in the same edit**: the phase that closed becomes `done`, and the one being
started becomes `current`. Archiving without the flip leaves the programme's own map claiming it is
somewhere it left.
```

- [ ] **Step 6: Add the arc to the report**

In step 7, change:

```
Show: what you measured versus what the ledger claimed, with each gate's result quoted alongside its
`trust`; every claim you corrected;
```

to:

```
Show: what you measured versus what the ledger claimed, with each gate's result quoted alongside its
`trust`; the arc as it now stands, naming any row whose `status` or wording you changed and why;
every claim you corrected;
```

- [ ] **Step 7: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-commands` `33 run, 0 failed`; all other suites unchanged.

- [ ] **Step 8: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/commands/handoff.md plugins/programme/tests/test-commands.sh
git commit -m "feat(programme): handoff asks against the arc and flips its rows on a phase close"
```

---

### Task 5: `/programme:status` reports from the arc, and stops miscounting the Archive index

**Files:**

- Modify: `plugins/programme/commands/status.md` (§1 in full)
- Test: `plugins/programme/tests/test-commands.sh`

**Interfaces:**

- Consumes: Task 1's `## The arc` heading, its `status` column, and the Archive-index grain note.
- Produces: nothing later tasks read.

**Why this is a correction and not an accommodation:** `status.md` currently asserts that Archive index rows "are phases that finished; that is the only count in these files that is a fact rather than a narrative." That is not what `handoff.md` writes there — step 4 adds a row on a phase close, the ledger header's 250-line rule adds one whenever a position is moved out for length, and step 6 adds a closure row. It is an archiving log. The arc supplies the count `status.md` was already reaching for.

- [ ] **Step 1: Write the failing assertions**

Add to `plugins/programme/tests/test-commands.sh`, immediately after the three `handoff:` assertions from Task 4:

```bash
# --- status reads progress off the arc, and defers on WHY the Archive index is not a phase count ---
assert_contains "$STATUS" "\`## The arc\` first" "status: reads the arc first"
assert_contains "$STATUS" "never read what has closed by counting" \
  "status: stops treating Archive index rows as a phase count"
assert_contains "$STATUS" "that table's own note says why" "status: defers to the ledger for the Archive index's grain"
assert_not_contains "$STATUS" "moved out purely for length" \
  "status: does NOT restate why the Archive index is not a phase count"
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-commands.sh
```

Expected: `37 run, 3 failed` — the three `assert_contains` red, the `assert_not_contains` already green (and it must stay green).

- [ ] **Step 3: Rewrite §1**

Replace the whole of `## 1. Where the programme is` — heading kept, everything under it up to but not including `## 2. Whether the record is still true` — with:

```markdown
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
```

- [ ] **Step 4: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-commands` `37 run, 0 failed`; `test-templates` `40 run, 0 failed`; the other four unchanged.

Then re-confirm the pre-existing single-homing negatives on `status.md` specifically, since §1 was rewritten wholesale:

```bash
cd plugins/programme && bash tests/test-commands.sh 2>&1 | grep -iE "does NOT|threshold|honest"
```

Expected: every line `ok` — `status: does NOT restate the archive threshold`, `status: does NOT restate the correct-in-place rule`, `status: does NOT restate the dates rule`, `status: does NOT restate resolution`, `status: defers to the header for the threshold`, `status: pins WHY it must not write`, plus the new `status: does NOT restate why the Archive index is not a phase count`.

- [ ] **Step 5: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/commands/status.md plugins/programme/tests/test-commands.sh
git commit -m "feat(programme): status reports from the arc, and stops counting archive rows as phases"
```

---

### Task 6: The `SessionStart` hook injects the arc

**Files:**

- Modify: `plugins/programme/hooks/session-start.sh` (the header comment; the section extraction; the emitted body)
- Modify: `plugins/programme/tests/harness.sh` (`add_programme`'s fixture ledger gains an arc)
- Test: `plugins/programme/tests/test-session-start.sh`

**Interfaces:**

- Consumes: Task 1's `## The arc` heading and its HTML comments.
- Produces: nothing later tasks read.

**Why this task exists, and why it is not in the issue.** The issue's fix routes through `/programme:resume` — a command someone has to run. `hooks/session-start.sh` is what actually puts a ledger into a session's working set: it fires on every session start **and after every compaction**, with no command involved, and `tests/test-session-start.sh` already calls that re-injection "the whole point of the channel." It currently extracts `## Current position` and nothing else. So the automatic channel injects the phase and drops the programme — which is the issue's complaint stated at its most literal. Verified before writing this task: `hooks/stale-ledger.sh` parses no sections, and `session-start.sh`'s awk anchors on the `## Current position` heading by name rather than by position, so Task 1's insertion above it changes nothing on its own.

- [ ] **Step 1: Give the fixture ledger an arc**

In `plugins/programme/tests/harness.sh`, in `add_programme`, replace the heredoc body:

```
# Test — programme ledger

## Current position — 2026-08-12 (TESTING)

The position line.
```

with:

```
# Test — programme ledger

## The arc

<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

**Goal:** The goal line.

| phase         | status  | what it delivers          |
| ------------- | ------- | ------------------------- |
| 1 — the slice | current | the goal line, end to end |

## Current position — 2026-08-12 (TESTING)

The position line.
```

Leave the `## Settled decisions` / `## Open forks` / `## Archive index` headings that follow exactly as they are. Four suites call `add_programme`; only `test-session-start.sh` asserts on ledger *content* (`The position line.`), and that line is untouched — verified by grepping `test-lib.sh` and `test-pre-compact.sh`, which reference the ledger only by path.

- [ ] **Step 2: Write the failing assertions**

In `plugins/programme/tests/test-session-start.sh`, immediately after the existing `assert_contains "$OUT" "The position line." "injects the position body"` line, add:

```bash
assert_contains "$OUT" "The arc" "injects the arc"
assert_contains "$OUT" "The goal line." "injects the arc body"
assert_not_contains "$OUT" "seeded illustrations" "strips the template's HTML comments"
```

And immediately before the closing `rm -rf "$REPO" "$STATE_HOME"` / `finish` lines, add:

```bash
# A ledger written before the arc existed must still inject its position, unchanged. Strip the arc
# back off the fixture rather than building a second one — the two shapes then differ in exactly the
# thing under test. The rewrite goes via a temp file that is moved away in the same command, so it
# never shows up in the `git status --porcelain` the other hooks read.
L="$REPO/docs/programmes/headless/ledger.md"
sed -n '/^## Current position/,$p' "$L" >"$L.tmp" && mv "$L.tmp" "$L"
run_hook session-start.sh "$(payload SessionStart s9 startup)" "$REPO"
assert_contains "$OUT" "The position line." "a pre-arc ledger still injects its position"
assert_not_contains "$OUT" "The goal line." "and injects no arc, because it has none"
```

- [ ] **Step 3: Run the suite to verify the new assertions fail**

```bash
cd plugins/programme && bash tests/test-session-start.sh
```

Expected: `21 run, 2 failed` — `injects the arc body` and `injects the arc` are red. The other three pass already: with the hook unchanged the arc is never injected, so `strips the template's HTML comments` and both pre-arc assertions are vacuously true. **That is the point of Step 5's re-run**: two of these five only start meaning something once the hook changes, and one of them (`strips the template's HTML comments`) is a check that cannot fail until then.

- [ ] **Step 4: Extract both sections**

In `plugins/programme/hooks/session-start.sh`, replace:

```bash
position=$(awk '
  /^## Current position/ { grab = 1; print; next }
  /^## / { if (grab) exit }
  grab { print }
' "$ledger")
[ -n "$position" ] || exit 0
```

with:

```bash
# The arc as well as the position. This channel — not `/programme:resume` — is what puts a ledger
# into a session's working set: it fires on every start and after every compaction, with no command
# run. Injecting only the position is what made phase-local reasoning the default.
# HTML comments are dropped: they instruct whoever writes the file and are noise to a reader.
sc_section() { # sc_section <heading> <file> — the heading and its body, to the next `## `
  awk -v h="$1" '
    index($0, h) == 1 { grab = 1; print; next }
    /^## / { if (grab) exit }
    !grab { next }
    /<!--/ { skip = 1 }
    skip { if (/-->/) skip = 0; next }
    { print }
  ' "$2"
}

arc=$(sc_section '## The arc' "$ledger")
position=$(sc_section '## Current position' "$ledger")
[ -n "$position" ] || exit 0

# A ledger written before the arc existed injects exactly what it did before.
if [ -n "$arc" ]; then
  body="$arc

$position

The arc above is the programme's; the position is the current phase's."
else
  body=$position
fi
```

- [ ] **Step 5: Emit the body, and correct the file's header comment**

In the same file, in the `sc_emit_additional_context SessionStart` call, change the line that reads:

```
$position
```

to:

```
$body
```

Leave the trailing paragraph (`This is the ledger's recorded position, not a verified one. …`) exactly as it is — the arc's scope clause is inside `$body`, so it appears only when there is an arc to describe.

Then correct line 2 of the file, which currently under-describes what it now does:

```
# SessionStart — stamp the comparison baseline, and re-inject the programme's current position.
```

becomes:

```
# SessionStart — stamp the comparison baseline, and re-inject the programme's arc and current position.
```

- [ ] **Step 6: Run the suite to verify it passes**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: `test-session-start` `21 run, 0 failed`; `test-commands` `37 run, 0 failed`; `test-templates` `40 run, 0 failed`; `test-lib` `17`, `test-pre-compact` `8`, `test-stale-ledger` `13`, all `0 failed`.

- [ ] **Step 7: Prove the comment-stripping assertion can actually fail**

It passed vacuously in Step 3, so confirm it now discriminates:

```bash
cd plugins/programme
cp hooks/session-start.sh /tmp/session-start.bak      # NOT `git checkout` to restore — see below
sed -i 's|    /<!--/ { skip = 1 }|    # MUTATED|' hooks/session-start.sh
bash tests/test-session-start.sh 2>&1 | grep -E "strips the template|run,"
cp /tmp/session-start.bak hooks/session-start.sh && rm /tmp/session-start.bak
bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected: the mutated run reports `FAIL strips the template's HTML comments` and `21 run, 1 failed`; after the restore, all six suites are green again. If the mutation does not redden it, the assertion is checking nothing and the task is not done.

**Restore with the backup copy, never `git checkout -- hooks/session-start.sh`.** This step runs BEFORE step 8's commit, so steps 4 and 5 are still uncommitted — `git checkout` would discard them along with the mutation, silently reverting the whole task to its pre-change state. Measured: an implementer hit exactly this and had to reapply steps 4 and 5 by hand.

- [ ] **Step 8: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/hooks/session-start.sh plugins/programme/tests/harness.sh plugins/programme/tests/test-session-start.sh
git commit -m "feat(programme): SessionStart injects the arc alongside the position"
```

---

### Task 7: README, plugin version, and the published site

**Files:**

- Modify: `plugins/programme/README.md` (the three command bullets that changed; one new section)
- Modify: `plugins/programme/.claude-plugin/plugin.json` (version)
- Modify: `site/build.mjs` (the `TREE` line describing `ledger.md`)
- Regenerate: `docs/` via `bun run build`

**Interfaces:**

- Consumes: everything Tasks 1–5 produced. The README's "asks the four interview questions" is now false — Task 4 made it five.
- Produces: the published page, which is rendered from this README.

- [ ] **Step 1: Correct the three command bullets**

In `plugins/programme/README.md`, under `## The four commands`:

In the `/programme:init` bullet, replace `and interviews for the starting position, the terminal condition, and the project's gates (with their trust)` with:

```
and interviews for the arc (the goal, the programme's own terminal condition, and a row per phase),
the starting position, this phase's terminal condition, and the project's gates (with their trust)
```

In the `/programme:resume` bullet, replace `reads the ledger in full and `NEXT-SESSION.md` verbatim` with:

```
reads the ledger in full — `## The arc` first, so the goal and the phases still to come frame the
phase rather than trail it — then `NEXT-SESSION.md` verbatim
```

In the `/programme:handoff` bullet, replace `asks the four interview questions, corrects the ledger in place` with:

```
asks the five interview questions — the fifth against the arc, so a later phase's work can be pulled
forward or a doomed piece of work refused — corrects the ledger in place, reconciles the arc
```

- [ ] **Step 2: Add the section explaining the arc**

Insert a new section immediately after `## The four commands` and before `## The config file`:

```markdown
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
```

- [ ] **Step 3: Bump the plugin version**

In `plugins/programme/.claude-plugin/plugin.json`, change `"version": "0.1.0"` to `"version": "0.2.0"`.

- [ ] **Step 4: Correct the site's file tree**

In `site/build.mjs`, in the `TREE` array, replace:

```js
    "position · decisions · gates · open forks",
```

with:

```js
    "the arc · position · decisions · gates · open forks",
```

- [ ] **Step 5: Rebuild the site and verify the arc reached the page**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
bun run build
grep -c "why it is a table" docs/programme/index.html
grep -c "the arc &middot; position &middot; decisions" docs/programme/index.html || \
  grep -c "the arc · position · decisions" docs/programme/index.html
```

Expected: the build prints no error, the first grep returns **`1`** (the README section reached the page), and one of the two tree greps returns **`1`** — which of them depends on whether `build.mjs` HTML-escapes the separator, so try the entity form first and fall back. If the first grep returns `0`, the README edit did not land: `docs/` is regenerated from `README.md` and `site/build.mjs` and is never edited by hand.

- [ ] **Step 6: Run the full suite one last time**

```bash
cd plugins/programme && bash tests/run-all.sh 2>&1 | grep -E "^(test-|[0-9]+ run)"
```

Expected, exactly:

```
test-commands
37 run, 0 failed
test-lib
17 run, 0 failed
test-pre-compact
8 run, 0 failed
test-session-start
21 run, 0 failed
test-stale-ledger
13 run, 0 failed
test-templates
40 run, 0 failed
```

- [ ] **Step 7: Commit**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins
git add plugins/programme/README.md plugins/programme/.claude-plugin/plugin.json site/build.mjs docs
git commit -m "feat(programme): document the arc, bump to 0.2.0, rebuild the site"
```

---

## Verification, end to end

After Task 7, prove the change does what the issue asked rather than only that the tests are green.

- [ ] **Step 1: The three greps the issue ran, re-run**

```bash
cd /home/srinath/_workarea/personal/github/longthread/claude-plugins/plugins/programme
grep -rniE "overall goal|programme goal|roadmap|later phase|decomposition|phase map" . \
  --include='*.md' --include='*.sh' --include='*.json' | grep -v '^./tests/' | wc -l
```

Expected: **non-zero** — it was `0` before this plan, which was the issue's headline measurement.

- [ ] **Step 2: A fresh reader following `/programme:resume` reaches the arc**

```bash
sed -n '/^## Read, in this order/,/^## Run every check/p' commands/resume.md
head -40 templates/ledger.md
```

Expected: resume's item 1 names `## The arc`, and it is the first `##` heading in the template — above `## Current position`.

- [ ] **Step 3: The two failures the issue describes are now refusable**

Read `commands/handoff.md` question 5 and confirm both shapes are named in it: work a `planned` phase later deletes, and work scoped out as a later phase's that is cheaper taken now. Those are the two incidents the issue reports; question 5 is the artifact that asks about them.

- [ ] **Step 4: Report on the issue**

Comment on issue #1 with what shipped, the assertion counts before and after (**108 → 136** across the six suites: `test-commands` 24 → 37, `test-session-start` 16 → 21, `test-templates` 30 → 40), and say the `SessionStart` injection was added beyond what the issue asked for.

```bash
gh issue comment 1 --body "<what shipped>"
```

**Do not close the issue.** It is the user's, and closing it is their call — ask, and close only on a yes.

---

## Self-review

**Spec coverage** — every item in the issue and the agreed comment maps to a task:

| requirement                                                 | task           |
| ----------------------------------------------------------- | -------------- |
| phase-map section above `## Current position`                | 1              |
| a table with a `status` column, not a paragraph              | 1              |
| the programme's terminal condition, as command + output      | 1              |
| `/programme:resume` reads it first                           | 3              |
| `/programme:handoff` asks one question against it            | 4              |
| `init` seeds it, or it ships empty                           | 2              |
| `status.md` §1 corrected, not accommodated                   | 5              |
| `tests/test-templates.sh` asserts the new table              | 1              |
| ordering has a test hook (the issue's "ABOVE" requirement)   | 1, step 1      |
| programme- vs phase-level terminal conditions single-homed   | 1, step 1      |
| ordering constraint (1) → (2) → (3)                          | task order     |
| README's "four interview questions" is now false             | 7              |
| the automatic channel injected only the phase, not the arc   | 6              |

**Placeholder scan** — every step names exact file paths, exact strings to replace, exact replacement text, an exact command, and an exact expected result. No "TBD", no "handle edge cases", no "similar to Task N".

**Type consistency** — the anchor strings are used identically across tasks: `## The arc` (Tasks 1, 2, 3, 4, 5, 6), `| phase | status | what it delivers |` (Tasks 1, 2, 6), `done`/`current`/`planned` (Tasks 1, 2, 3, 4, 5), `Row count is NOT a phase count` (Task 1, deferred to by Task 5). The assertion counts chain: templates 30 → 40 (Task 1); commands 24 → 27 (Task 2) → 29 (Task 3) → 33 (Task 4) → 37 (Task 5); session-start 16 → 21 (Task 6). Total 108 → 136.

**A second risk, and the step that covers it.** Task 6's five new assertions include three that pass *before* the hook changes — the exact "check that cannot fail" shape. Step 3 says so out loud rather than reporting `21 run, 2 failed` as if all five were meaningful, and Step 7 mutates the hook to prove the comment-stripping one discriminates. Do not skip Step 7; it is the only thing separating that assertion from decoration.

**One risk worth stating.** Task 1 puts `**Command:**` and `**Expected output:**` into `ledger.md`, which `NEXT-SESSION.md` already uses. That is a shared *schema* at two scopes, not a restated *rule* — the scope line `the programme's, not the phase's` lives only in `ledger.md`, and Task 1 step 1 adds the negative assertion that keeps it there. If a future edit puts a scope disambiguator into `NEXT-SESSION.md` as well, that assertion is what reddens.
