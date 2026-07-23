# CLAUDE.md — Qidi Q2 Superuser AIO

Project context for Claude Code sessions. Read this first every time.

## Core Goals

The Qidi Superuser repository exists to give basic users better tools for their Qidi printers. The target audience is new or non-technical users who want improved performance without deep Klipper knowledge.

Two principles drive every decision:

1. **Simple instructions.** Documentation should assume minimal prior knowledge. Steps should be explicit, numbered, and copy-pasteable.
2. **Automate everything possible.** Anything a user could misconfigure manually — KAMP settings, printer.cfg includes, macro file placement, backup creation — should be handled by the installer. Users should not need to hand-edit config files to complete a supported install path.

## Three Install Paths

| Path | Who it's for | What it installs |
|---|---|---|
| **Just Faster Printer** | Stock experience with faster/cleaner macros. No Qidi Box. | Optimised macros only |
| **Just Faster Box** | Stock experience with faster/cleaner macros. They have a Qidi Box. | Optimised macros + box-aware paths enabled |
| **BunnyBox + HelixScreen** | Users who want the full advanced stack. | Happy Hare MMU firmware + HelixScreen LVGL UI + BunnyBox |

## Quick Start — Test Commands

Always run these before committing:

```bash
bash -n Q2/aio_menu.sh                            # shell syntax check (Q2)
python3 -m json.tool Q2/helixscreen_settings.json  # JSON lint
shellcheck -S warning Q2/aio_menu.sh              # style (advisory)
```

## Repo Layout

```
Q2/
  aio_menu.sh              ← Q2 installer. All Q2 logic lives here.
  CLAUDE.md                ← Q2-scoped conventions and key paths
  helixscreen_settings.json← Reference copy of HelixScreen settings
  KAMP/
    KAMP_settings.cfg      ← KAMP settings (installed to CONFIG_DIR/KAMP/)
    Adaptive_Meshing.cfg   ← Vendored upstream KAMP file
    Line_Purge.cfg         ← Vendored upstream KAMP file
    Smart_Park.cfg         ← Vendored upstream KAMP file
  mmu/                     ← Happy Hare / BunnyBox Klipper config files
  macros/                  ← gcode_macro cfg templates
  Printer Presets/         ← OrcaSlicer printer profiles

README.md                  ← Project overview, supported printers, what it does
docs/
  README.md                ← Changelog and supported-printer summary
  WHAT_WAS_DONE.md          ← Detailed feature/menu/file-path reference

Configurations/            ← Stock Qidi reference files. DO NOT MODIFY.
Plugins/                   ← Stock plugin reference. DO NOT MODIFY.

.claude/
  settings.json            ← Pre-approved Bash/WebFetch permissions
  hooks/pre-commit-check.sh← Auto-lint on every commit
  checklist.md             ← Pre-flight checklists
  LESSONS.md               ← Known gotchas; read before touching any file
  commands/start.md        ← /start slash command: session startup protocol
  github-issue-response.md ← Issue response format, tone rules, diagnostic commands
```

## Target Environments

### Qidi Q2 (existing)
- Hardware: Qidi Q2 3D printer
- Runs Debian 10
- OS: ARM Linux, user `mks`
- Stack: Klipper + Moonraker + Happy Hare (MMU) + HelixScreen (LVGL UI) + Qidi Box (4-slot AMS)
- Key paths on the printer:
  - `/home/mks/printer_data/config/` — Klipper config root
  - `/home/mks/mudstockbackups/` — AIO backup snapshots
  - `/home/mks/helixscreen/` — HelixScreen install dir
  - `/home/mks/Happy-Hare/` — Happy Hare MMU firmware

## Critical Rules

1. **Never modify** `Configurations/` or `Plugins/` — read-only stock Qidi mirrors.
2. **Never push to `main` directly** — all work goes on a `claude/*` branch; merge via PR.
3. **Bump `AIO_VERSION`** whenever `Q2/aio_menu.sh` changes. Version format is `RC<major>.<minor>` (e.g. `RC1.14`). Increment the minor on each change; bump the major for a breaking generational shift.
   - **Wiki screenshot rule:** Whenever `AIO_VERSION` is bumped to a number ending in `0` or `5`, the AIO menu preview screenshot in the wiki must be updated to reflect the current menu layout. At the start of any session targeting one of these versions, Claude Code should attempt to reach the wiki repo and push the updated preview. If the wiki repo is not accessible in that session, notify the user and add a to-do item to the session's carry-forward in `HANDOFF.md`.
   - **`WHAT_WAS_DONE.md` menu table rule:** Whenever `AIO_VERSION` is bumped to a number ending in `0` or `5`, also update the menu table in `docs/WHAT_WAS_DONE.md` to reflect the current layout.
4. **Version history belongs in HANDOFF.md only.** Do not add RC entries to CLAUDE.md. After a session, add the new entry to HANDOFF.md. Replace any history here with: **Version history:** See HANDOFF.md — newest entries at top.
5. **Do not run `Q2/aio_menu.sh` as root** — the script self-enforces this.
6. **`sudo tee` pattern for writing files with elevated perms**, never `echo > file` with sudo.
7. **Use `banner`, `info`, `warn`, `ok`, `err` helpers** — never raw `echo` in installer logic.
8. **AIO menu options must always be numbers** — never letters or other characters.

## Install-Function Conventions

Every new capability that installs something must follow this checklist:

| Requirement | Example |
|---|---|
| `install_*()` function | `install_mainsail()` |
| `uninstall_*()` function | `uninstall_mainsail()` |
| `*_installed()` or `*_enabled()` detection helper | `mainsail_installed()` |
| Wired into `revert_to_backup()` | call `uninstall_*` in the revert block |
| Status indicator added to `show_status_line()` | `Mainsail: installed/not found` |
| `verify_*()` post-install check (warn, never fail) | `verify_qidi_box_helixscreen()` |

When `install_*` fetches a remote file, use the `fetch()` helper, not `curl` directly.

### Function Comment Standard

Every `install_*`, `uninstall_*`, `verify_*`, `*_installed`, and any function over 20 lines must have a comment immediately above the `functionname()` line.

Rules:
- One line maximum. Two lines only if a genuinely distinct second thought is needed.
- Prose style, third person. No structured fields (`# Purpose:`, `# Side effects:`, etc.).
- Written by reading the function body directly — do not copy or reformat the existing comment.
- Blank line between the comment and any preceding code block, but no blank line between the comment and the function definition.

Examples:

**One line (single thought):**
```bash
# Removes Happy Hare/BunnyBox artifacts outside CONFIG_DIR (source tree, klipper extras, moonraker component). Called from revert_to_backup() only.
uninstall_bunnybox_system() {
```

**Two lines (two distinct thoughts):**
```bash
# Removes every known Happy Hare/BunnyBox footprint regardless of whether upstream uninstallers ran.
# Called from both uninstall_bunnybox() and the verifier repair path.
purge_bunnybox_footprint() {
```

### Current Install Functions

| Function | Feature | Status indicator |
|---|---|---|
| `install_bunnybox_helixscreen()` | Happy Hare + HelixScreen | `BunnyBox: installed/not found`, `Display: HelixScreen/none` |
| `install_just_faster()` | JustFasterPrinter macros (Q2) | `Just Faster: Just Faster Printer` |
| `install_just_faster_box()` | JustFasterBox macros (Q2) | `Just Faster: Just Faster Box` |
| `update_macros()` | Re-fetch AOI-owned macro files for installed group | — |
| `install_qidi_box_write()` | HelixScreen HELIX_QIDI_BOX_WRITE drop-in | `BoxWrite: on/off` |
| `install_mainsail()` | Mainsail web UI (delegates to Camden-Winder's installer) | `Mainsail: installed/not found` |

All five install functions (`install_bunnybox_helixscreen()`, `install_just_faster()`, `install_just_faster_box()`, `install_jfp_q2_112()`, `install_jfb_q2_112()`) end with an opt-in "disable unnecessary processes" prompt (`offer_process_optimization()`), which masks/disables a fixed list of unused stock services. On the `q2_112` layout it additionally offers the community static-GIF patch for the QIDIClient touchscreen UI. State is recorded under `aio_state_dir()` and undone automatically by `revert_to_backup()` via `undo_process_optimization()`.

### Current Menu Layout

Options 1–3 route by detected firmware layout automatically (`install_jfp_q2_112`/`install_jfb_q2_112` on `q2_112`, otherwise the legacy functions) — there is no separate firmware submenu.

```
1)  Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
2)  Install Just Faster Printer       (Q2 without Box)
3)  Install Just Faster Box           (Q2 with Qidi Box, no BunnyBox)
4)  Update Macros                     (re-fetch AOI macro files)
5)  Revert to Backup                  (full uninstall + restore stock)
6)  Uninstall Mainsail                (remove web UI only)
7)  Mainsail                          (web UI on port 100)
8)  About
9)  Health Check / Run Verifiers
10) Testing                           (submenu: snapshot tools + 1.1.2 probes)
0)  Exit
```

Testing submenu (option 9):
```
1)  Force Snapshot Capture   (overwrites snapshot with current config)
2)  Force Config Restore     (rsync --delete from snapshot to config)
3)  1.1.2 Compatibility Probe
4)  1.1.2 Restore Rehearsal
5)  1.1.2 Live Restore Proof
6)  1.1.2 External Restore Audit
7)  1.1.2 Present-Path Restore Proof
8)  1.1.2 Klipper Extras Restore Proof
9)  1.1.2 Moonraker Components Proof
0)  Back
```

Per-component uninstall options (BunnyBox-only / HelixScreen-only / Both) were removed in RC4. Revert to Backup is the single uninstall path and delegates to `uninstall_bunnybox()` and `uninstall_helixscreen()` internally before restoring from `_FIRST_STOCK`.

## Troubleshooting Protocol

When a task fails or produces unexpected output:

1. **Diagnose before asking.** Check logs, run the syntax check, inspect the relevant function. Form a hypothesis before surfacing the problem to the user.
2. **3-attempt limit.** After 3 failed attempts on the same problem, stop. Report: what you tried, why each attempt failed, current hypothesis, and what information from the user would unblock you. Do not keep iterating blindly.
3. **When telling the user what to do:** give one specific command or action, not a list of things to try. If multiple paths exist, recommend one and explain why.
4. **Printer-side actions:** always include the expected output alongside any command you ask the user to run.
5. **Don't narrate obvious steps.** Show the change, state what it fixes.

## Autonomous-Session Policy

Claude may do the following **without asking first**:

- Commit and push to any `claude/*` branch
- Create a draft PR after pushing a new branch
- Run `bash -n`, `python3 -m json.tool`, `shellcheck` (lint/syntax checks)
- Merge a PR to `main` when the handoff context explicitly says to do so
- When creating a PR, use the repo's pull request template (`.github/PULL_REQUEST_TEMPLATE.md`).
  Fill in all sections based on what was changed:
  - **Title:** `RC X.XX — [main change]` for AOI changes, `Wiki-RC X.X — [main change]` for wiki
    changes, `docs-only — [main change]` for docs with no version bump
  - **Testing:** provide specific SSH commands to run on the printer with expected output.
    Use a checklist for complex changes, a short paragraph for simple ones. Do not ask
    Calvin to "verify" or "check" things manually — give him the exact command and
    expected result. Reference the testing examples in `.github/PULL_REQUEST_TEMPLATE.md`.
  - **Issue reference:** include `References #N` in the PR body and in the commit message
    when the PR addresses a tracked issue.
  - Do not include Claude session links, generated-by footers, or attribution in the PR body.

#### PR Testing Format Examples

**Syntax-only (no user-facing changes):**
```
Syntax check: `bash -n Q2/aio_menu.sh`
```

**Medium description (user-facing changes):**
```
Syntax check: `bash -n Q2/aio_menu.sh`

**[Feature name]:**
[What to do]. After completion:
`[command to run]` — expected: [what to expect]

**[Second feature]:**
[What to do]:
- `[command]` — should return [expected output]
- `[command]` — should return [expected output]
```

Claude **must ask first** before:

- Pushing to `main` directly
- Force-pushing any branch
- Deleting branches or files not created in the same session
- Taking actions visible to users outside this repo (posting comments, etc.)
- Using `Closes #N`, `Fixes #N`, or `Resolves #N` in commit messages or PR bodies — use `References #N` only. Issue closure is Calvin's decision.

### End-of-session requirements (always, no exceptions)

Every session that modifies `aio_menu.sh` or bumps `AIO_VERSION` **must** update `HANDOFF.md` in the same commit (or a follow-up commit before the session ends):

- Add a new `## <version> — <short title>` section **at the top of the RC log** (below the Known Issues section)
- Include: current branch, PR number, what changed, and root causes if it was a bug fix
- Do **not** include carry-forward known issues in the per-version section — those belong in the `## Known Issues (carry-forward)` section pinned at the very top of `HANDOFF.md`
- The version heading must match `AIO_VERSION` in `aio_menu.sh`

**`HANDOFF.md` structure:**
```
## Known Issues (carry-forward)      ← pinned at top, updated in-place
## RC2.XX — <title>                  ← newest RC entry, added each session
## RC2.XX-1 — <title>               ← previous entries below
...
```

**Version history:** See HANDOFF.md — newest entries at top.

**Attribution:** Claude Code's `settings.json` has attribution disabled for commits and PRs (`"commit": "", "pr": "", "sessionUrl": false`). However, when running Claude Code from the web interface, `settings.json` is not read correctly and attribution may still appear. Until this is resolved, do not add attribution footers or generated-by links to commit messages, PR bodies, or issue comments.

## External Resources

- HelixScreen: `prestonbrown/helixscreen` on GitHub
- Happy Hare: `moggieuk/Happy-Hare`
- BunnyBox installer: `Camden-Winder/Bunny-Box` → `Q2/install-bb-q2.sh`
- Qidi Box: `wiki.qidi3d.com`
