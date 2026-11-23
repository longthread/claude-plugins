# Herdr: panes, tabs and other sessions (explicit triggers only)

You may open Claude Code sessions, or talk to other sessions, ONLY when my message starts with `pane:`, `tab:` or `sessions:`. Otherwise never open panes, tabs or sessions, and never read from or send to other terminals: not to parallelize, not in place of sub-agents (the Agent tool), not because something "is a separate task". Use sub-agents and your own task lists as usual.

Exception: a slash command or skill I invoked, or one running in a chain I started with one (a session that command opened, or a command such a session runs or is sent), counts as my trigger for exactly the Herdr steps its own instructions spell out: opening, reading, messaging, notifying and closing panes or sessions, and only on this session's own pane and the panes or sessions that same chain opened, never on any other session; that includes closing this session's own pane if it says to. Follow that command's instructions for those steps; everything else here still applies.

## What each trigger must produce
- `pane: <what I want>`: exactly one new interactive Claude Code session in a visible split beside THIS session (not a background child without a pane). My focus stays here.
- `tab: <what I want>`: exactly one new interactive Claude Code session in a new tab in THIS session's space/workspace, opened in the background. My focus stays here.
- `sessions: <what I want>`: find the other Claude Code session(s) that match what I said, then read from or message them.
I may add details ("below", "in ~/other-repo", "name it x"); honor them.

For pane/tab: turn what I wrote into a self-contained first message, because the new session has none of our context. Give it a short name (lowercase letters, digits, `-`). Start it in this session's folder unless I say otherwise. Then go back to what we were doing; don't monitor it unless I ask.

For sessions: narrow candidates by space/workspace or tab name, folder/repo and session name; read their screens when more than one could match. Act on every session that matches (one or several). If it's still unclear, list the candidates (id, where, one-line summary) and ask; don't guess. Messages must stand alone: say which session you are and what you need back. Report back who you talked to, what you sent and what they said.

## Guardrails
- Target this session's own pane/terminal by its id (below), never "whatever is focused": I may be looking at another tab.
- Only message idle sessions. Busy: tell me, or wait if I said to. Blocked (permission prompt or question): never answer or force through it; tell me.
- A timeout doesn't prove a message wasn't delivered: read before resending.
- Never kill, interrupt, close or send keys to sessions, panes or tabs you didn't create, unless I explicitly ask.
- Never stop or restart Herdr's server or core.

## How to find the commands
Don't guess command syntax and don't rely on memory: Herdr changes often. On the first trigger in this session, read the manual(s) for the Herdr you're in (below), then work out the commands from them. Reuse what you read for later triggers in this session; re-read only if a command fails. Never run bare `herdr` (it attaches the TUI).
