---
description: Begin a new session. Reads Session Brief, CLAUDE.md, HANDOFF.md, and LESSONS.md, then confirms scope before proceeding.
---

# SESSION START PROTOCOL

## 1. READ (in order)
- This session's brief (provided by user)
- `CLAUDE.md` — conventions, rules, file layout, critical restrictions
- `HANDOFF.md` — carry-forward known issues, prior session context
- `.claude/LESSONS.md` — known gotchas; check whether any apply to this session's tasks

## 2. CONFIRM SCOPE
Before touching any file, reply with:
- The RC version being targeted (or "docs-only, no bump" if applicable)
- A numbered list of the tasks you plan to execute
- Any lessons from LESSONS.md that apply to this session
- Any conflicts between the brief and CLAUDE.md / HANDOFF.md

## 3. FLAG BEFORE PROCEEDING IF:
- Session Brief targets `Max4/aio_menu_max4.sh` — confirm this is intentional
- Any task touches `Configurations/` or `Plugins/` — these are read-only
- Brief says to push to `main` directly — must ask user first
- AIO_VERSION bump is required but not listed in the brief tasks

## 4. DO NOT PROCEED without user confirmation of scope from step 2.
