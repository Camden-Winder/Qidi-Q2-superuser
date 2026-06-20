# Session Brief Instructions

## What is a Session Brief?

A Session Brief is a document prepared by the user (via Claude.ai) before starting a Claude
Code session. It is Claude Code's source of truth for the current session — what to do, how
to do it, and what not to touch. It is **not** a handoff between Claude Code instances; that
is `HANDOFF.md`.

The user will not provide any extra files to Claude Code. Everything Claude Code needs must
be embedded in or referenced from the Session Brief.

---

## At the Start of Every Session

1. Read the Session Brief provided by the user.
2. Read `CLAUDE.md` for project conventions, rules, and version history.
3. Read `HANDOFF.md` for open known issues and prior session context.
4. Confirm your understanding of the task to the user before making any changes.
5. If the Session Brief conflicts with `CLAUDE.md` or `HANDOFF.md`, flag it before proceeding.

---

## At the End of Every Session

1. Add a new entry at the top of `HANDOFF.md` documenting what was done this session.
2. Update `CLAUDE.md` — add a version history entry for this session's changes.
3. Commit everything on a `claude/*` branch. Never push to `main` directly.

---

## Rules

- Never make changes outside the scope defined in the Session Brief without confirming first.
- All conventions in `CLAUDE.md` apply regardless of what the Session Brief says.
- Claude documents (`CLAUDE.md`, `HANDOFF.md`, `.claude/`) are **never** out of scope.
- Known issues are tracked in `HANDOFF.md` — do not carry them into the Session Brief.

---

## Session Brief Format

Every Session Brief written by Claude.ai must follow this structure exactly:

---

### `# Session Brief — RCX.XX: <Short Title>`

### `## Goal`
One or two sentences. What is this session trying to achieve?

### `## Background`
Context Claude Code needs to understand the problem. Include root causes of any bugs being
fixed, prior approaches that failed and why, and any environment-specific facts (paths,
ownership, symlinks, tool behavior) that are non-obvious. This section must be complete
enough that Claude Code can act without any additional files or context from the user.

### `## Tasks`
Numbered list. Each task must be specific and self-contained:
- State exactly what to change and where (function name, line reference, file).
- Include code snippets for non-trivial changes.
- Embed any required data (widget dicts, config values, file content) directly in the task.
- State explicitly what must NOT change if there is risk of Claude Code touching it.

### `## Files to Change`
Table listing every file that must be modified and why. Claude documents (`CLAUDE.md`,
`HANDOFF.md`) are always included here.

| File | Change |
|------|--------|
| `path/to/file` | What changes and why |
| `CLAUDE.md` | Add RCX.XX version history entry |
| `HANDOFF.md` | Add RCX.XX session entry at top |

### `## Files NOT to Change`
Table listing files that must not be touched and why.

| File | Reason |
|------|--------|
| `path/to/file` | Why it is out of scope |

### `## Version`
```
Bump AIO_VERSION to RCX.XX.
```
