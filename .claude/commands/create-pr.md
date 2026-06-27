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
