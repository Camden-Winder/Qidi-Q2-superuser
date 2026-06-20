# Session Brief Instructions

## What is a Session Brief?

A Session Brief is a document prepared by the user (via Claude.ai) before starting a Claude Code session. It describes the problem, the fix, and any risks or carry-forwards for the session. It is **not** a handoff between Claude Code instances — that is `HANDOFF.md`. The Session Brief is the user's instruction to Claude Code for the current session.

---

## At the Start of Every Session

1. Read the Session Brief provided by the user before doing anything else.
2. Read `CLAUDE.md` for project conventions, rules, and version history.
3. Read `HANDOFF.md` for known issues and any carry-forward context from the previous session.
4. Confirm your understanding of the task before making any changes.

---

## At the End of Every Session

1. Create a **Session Brief** in the same format as a handoff. Carry forward any unfixed Known Issues at the bottom of the new entry. 
3. **Update `CLAUDE.md`** — add a version history entry for this session's changes.
4. **Commit everything** on a `claude/*` branch. Never push to `main` directly.

---

## Rules

- The Session Brief is the source of truth for what to do this session. If it conflicts with `HANDOFF.md`, flag it to the user before proceeding.
- Never make changes outside the scope defined in the Session Brief without confirming with the user.
- All conventions in `CLAUDE.md` apply regardless of what the Session Brief says — the Brief defines *what* to do, `CLAUDE.md` defines *how* to do it.
- The session brief needs to include any required resources. The user will not provide any extra files to Claude Code, just the session brief.
