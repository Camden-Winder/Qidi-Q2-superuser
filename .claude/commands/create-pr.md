---
description: Create a pull request for the current branch using the GitHub MCP tool. Avoids the web UI session-link injection.
---

# CREATE PULL REQUEST

## 1. GATHER CONTEXT

Run these to understand what's on the branch:
- `git rev-parse --abbrev-ref HEAD` — current branch name
- `git log origin/main..HEAD --oneline` — commits ahead of main
- `git diff origin/main...HEAD --stat` — files changed
- Read `.github/PULL_REQUEST_TEMPLATE.md` — use its section headings as the body structure

## 1.1 SYNC CHECK — Bug Report Dropdown

If this PR changes the AIO menu numbering or labels in `Q2/aio_menu.sh` (`draw_menu()`), check whether `.github/ISSUE_TEMPLATE/bug_report.yml`'s `install_path` dropdown options still match. If they do not match:
- Update the dropdown options in `bug_report.yml` to reflect the current menu
- Include this change as part of the same PR
- Note it in the PR body under Changes

This check is mandatory any time `draw_menu()` is touched, even if the brief did not explicitly mention the bug report template.

## 1.2 SYNC CHECK — Wiki Preview Screenshot

If this PR bumps `AIO_VERSION` to a number ending in `0` or `5` (per the Wiki screenshot rule in `CLAUDE.md`), attempt to reach the wiki repo and push an updated AOI menu preview screenshot reflecting the current `draw_menu()` layout. If the wiki repo is not accessible in this session, notify the user and add a to-do item to the `## Known Issues (carry-forward)` section in `HANDOFF.md`.

## 2. COMPOSE THE PR

**Title format** (pick one, match what changed):
- `RC X.XX — <short description>`
- `docs-only — <short description>`
- `Wiki-RC X.X — <short description>`

**Body:** Populate every section from the PR template. Fill in real content — do not leave placeholder comments.

**Hard rules — violation is not acceptable:**
- Do NOT include any session URLs (e.g. `claude.ai/...`)
- Do NOT include generated-by footers, attribution lines, or "Created with Claude" text
- Do NOT use `Closes #N`, `Fixes #N`, or `Resolves #N` — use `References #N` only
- Do NOT leave the issue-reference line if there is no applicable issue

## 3. CREATE THE PR

Call `mcp__github__create_pull_request` with:
- `owner`: `Camden-Winder`
- `repo`: `Qidi-Q2-superuser`
- `base`: `main`
- `head`: current branch name
- `title`: composed title
- `body`: composed body (no session links, no attribution)

## 4. REPORT

Return the PR URL to the user.
