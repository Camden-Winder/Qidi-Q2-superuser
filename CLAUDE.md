# CLAUDE.md — Qidi Q2 Superuser AIO

Project context for Claude Code sessions. Read this first every time.

## Core Goals

The Qidi Superuser repository exists to give basic users better tools for their Qidi printers. The target audience is new or non-technical users who want improved performance without deep Klipper knowledge.

Two principles drive every decision:

1. **Simple instructions.** Documentation should assume minimal prior knowledge. Steps should be explicit, numbered, and copy-pasteable.
2. **Automate everything possible.** Anything a user could misconfigure manually — KAMP settings, printer.cfg includes, macro file placement, backup creation — should be handled by the installer. Users should not need to hand-edit config files to complete a supported install path.

## Three Install Paths (Canon — Q2 and Max 4)

| Path | Who it's for | What it installs |
|---|---|---|
| **Just Faster Printer** | Stock experience with faster/cleaner macros. No Qidi Box. | Optimised macros only |
| **Just Faster Box** | Stock experience with faster/cleaner macros. They have a Qidi Box. | Optimised macros + box-aware paths enabled |
| **BunnyBox + HelixScreen** | Users who want the full advanced stack. | Happy Hare MMU firmware + HelixScreen LVGL UI + BunnyBox **(Q2 only — not applicable to Max 4)** |

For the Max 4, only paths 1 and 2 are in scope. Path 3 does not exist on the Max 4.

## Quick Start — Test Commands

Always run these before committing:

```bash
bash -n Q2/aio_menu.sh                            # shell syntax check (Q2)
bash -n Max4/aio_menu_max4.sh                     # shell syntax check (Max 4)
python3 -m json.tool Q2/helixscreen_settings.json  # JSON lint
shellcheck -S warning Q2/aio_menu.sh              # style (advisory)
shellcheck -S warning Max4/aio_menu_max4.sh       # style (advisory)
```

## Repo Layout

```
Q2/
  aio_menu.sh              ← Q2 installer. All Q2 logic lives here. DO NOT MODIFY for Max 4.
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

Max4/
  aio_menu_max4.sh         ← Max 4 installer. Sibling to Q2/aio_menu.sh.
  CLAUDE.md                ← Max4-scoped conventions and key paths
  macros/
    gcode_macro-JustFasterPrinter.cfg ← JFP macro file (no box)
    gcode_macro-JustFasterBox.cfg     ← JFB macro file (with box)
  Instructions.md          ← User-facing SSH + install guide
  FAQ.md                   ← Fan assignments, NeoPixel, Z offset, polar cooler, misc

All_in_One_Installer/
  CLAUDE.md                ← Redirect to Q2/ and Max4/ script locations
  README.md
  WHAT_WAS_DONE.md

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

### Qidi Max 4 (new)
- Hardware: Qidi Max 4 3D printer
- Runs Debian Bullseye
- OS: ARM Linux, user `qidi`
- Stack: Klipper + Moonraker + stock qidi-client touchscreen UI + Qidi Box (4-slot AMS, optional)
- Key paths on the printer:
  - `/home/qidi/printer_data/config/` — Klipper config root
  - `/home/qidi/mudstockbackups/` — AIO backup snapshots
  - `/home/qidi/QIDI_Client/` — touchscreen UI assets
  - `config/klipper-macros-qd/` — stock Qidi macro directory
- Supported firmware: `01.01.06.03`, `01.01.06.04`
- No Happy Hare, no HelixScreen — stock UI only

## Critical Rules

1. **Never modify** `Configurations/` or `Plugins/` — read-only stock Qidi mirrors.
2. **Never push to `main` directly** — all work goes on a `claude/*` branch; merge via PR.
3. **Bump `AIO_VERSION`** whenever `Q2/aio_menu.sh` changes. Version format is `RC<major>.<minor>` (e.g. `RC1.14`). Increment the minor on each change; bump the major for a breaking generational shift.
   - **Wiki screenshot rule:** Whenever `AIO_VERSION` is bumped to a number ending in `0` or `5`, the AIO menu preview screenshot in the wiki must be updated to reflect the current menu layout. At the start of any session targeting one of these versions, Claude Code should attempt to reach the wiki repo and push the updated preview. If the wiki repo is not accessible in that session, notify the user and add a to-do item to the session's carry-forward in `HANDOFF.md`.
4. **Version history belongs in HANDOFF.md only.** Do not add RC entries to CLAUDE.md. After a session, add the new entry to HANDOFF.md. Replace any history here with: **Version history:** See HANDOFF.md — newest entries at top.
5. **Do not run `Q2/aio_menu.sh` as root** — the script self-enforces this.
6. **`sudo tee` pattern for writing files with elevated perms**, never `echo > file` with sudo.
7. **Use `banner`, `info`, `warn`, `ok`, `err` helpers** — never raw `echo` in installer logic.
8. **AIO menu options must always be numbers** — never letters or other characters.

## Install-Function Conventions

Every new capability that installs something must follow this checklist:

| Requirement | Example |
|---|---|
| `install_*()` function | `install_idle_fan_shutdown()` |
| `uninstall_*()` function | `uninstall_idle_fan_shutdown()` |
| `*_installed()` or `*_enabled()` detection helper | `idle_fan_shutdown_installed()` |
| Wired into `revert_to_backup()` | call `uninstall_*` in the revert block |
| Status indicator added to `show_status_line()` | `IdleFan: on/off` |
| `verify_*()` post-install check (warn, never fail) | `verify_qidi_box_helixscreen()` |

When `install_*` fetches a remote file, use the `fetch()` helper, not `curl` directly.

### Current Install Functions

| Function | Feature | Status indicator |
|---|---|---|
| `install_bunnybox_helixscreen()` | Happy Hare + HelixScreen | `BunnyBox: installed/not found`, `Display: HelixScreen/none` |
| `install_just_faster()` | JustFasterPrinter macros (Q2) | `Just Faster: Just Faster Printer` |
| `install_just_faster_box()` | JustFasterBox macros (Q2) | `Just Faster: Just Faster Box` |
| `install_idle_fan_shutdown()` | 10m idle fan+heater shutdown | `IdleFan: on/off` |
| `install_qidi_box_write()` | HelixScreen HELIX_QIDI_BOX_WRITE drop-in | `BoxWrite: on/off` |
| `install_mainsail()` | Mainsail web UI (delegates to Camden-Winder's installer) | `Mainsail: installed/not found` |

### Current Menu Layout

```
1)  Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
2)  Install Just Faster Printer       (Q2 without Box)
3)  Install Just Faster Box           (Q2 with Qidi Box, no BunnyBox)
4)  Revert to Backup                  (full uninstall + restore stock)
5)  Idle Fan Shutdown                 (10m idle, temp-gated)
6)  Mainsail                          (web UI on port 100)
7)  About
8)  Health Check / Run Verifiers
9)  Testing                           (submenu: snapshot tools + 1.1.2 probes)
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
- When creating a PR, post a comment on the PR with testing instructions for Camden:
  specific menu paths, commands to run on the printer, and expected outcomes for all
  new or changed features.

Claude **must ask first** before:

- Pushing to `main` directly
- Force-pushing any branch
- Deleting branches or files not created in the same session
- Taking actions visible to users outside this repo (posting comments, etc.)

**When creating a PR:** post a comment on the PR explaining how Camden can manually test all new or changed features. Include specific menu paths to navigate, commands to run on the printer over SSH, and expected outcomes for each feature.

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

## External Resources

- HelixScreen: `prestonbrown/helixscreen` on GitHub
- Happy Hare: `moggieuk/Happy-Hare`
- BunnyBox installer: `Camden-Winder/Bunny-Box` → `Q2/install-bb-q2.sh`
- Qidi Box: `wiki.qidi3d.com`
