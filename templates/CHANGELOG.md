# <PLUGIN_NAME> — changelog

> **What changed in each release, for someone deciding whether to upgrade.** Not a commit log — a
> reader here already has the plugin installed and wants to know what will be different afterwards.
>
> **How to write here.**
>
> - **Newest first**, one `##` per released version. The heading is `## <VERSION> — <YYYY-MM-DD>`,
>   and the version starts with a digit — the site build reads it.
> - **Absolute dates only** (`YYYY-MM-DD`). "Last week" ages into a lie.
> - **Write the change, not the commit.** "`/x:handoff` now asks whether later work is cheaper taken
>   now" is a change; "refactor handoff.md" is a commit subject, and the reader cannot act on it.
> - **Lead each entry with what is different**, then why it matters. A reader scanning only the bold
>   opening of every line should still learn what this release does.
> - **`Added` · `Changed` · `Fixed`, and only the ones with entries.** An empty heading reads as a
>   section someone forgot to fill.
> - **Say when a release needs the reader to do something** — migrate a file, re-run a command, or
>   nothing at all. "Nothing to do" is worth one line; silence is not.
> - **The newest version here must equal `version` in `.claude-plugin/plugin.json`.** The site build
>   fails when they disagree, so a bump that forgets this file cannot ship.

## <VERSION> — <YYYY-MM-DD>

### Added

- **<what a reader can now do that they could not before>** — <why it matters to them>

### Changed

- **<what behaves differently>** — <and what, if anything, the reader has to do about it>

### Fixed

- **<the symptom someone would have hit>** — <not the internal cause, unless the cause is the symptom>
