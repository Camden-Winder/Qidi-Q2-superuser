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
bash -n All_in_One_Installer/aio_menu.sh          # shell syntax check (Q2)
bash -n All_in_One_Installer/aio_menu_max4.sh     # shell syntax check (Max 4)
python3 -m json.tool Q2/helixscreen_settings.json  # JSON lint
shellcheck -S warning All_in_One_Installer/aio_menu.sh         # style (advisory)
shellcheck -S warning All_in_One_Installer/aio_menu_max4.sh    # style (advisory)
```

## Repo Layout

```
All_in_One_Installer/
  aio_menu.sh              ← Q2 installer. All Q2 logic lives here. DO NOT MODIFY for Max 4.
  aio_menu_max4.sh         ← Max 4 installer. Sibling to aio_menu.sh.
  README.md
  WHAT_WAS_DONE.md

Q2/
  printer-BunnyBox.cfg     ← BunnyBox printer.cfg template
  JustFasterPrinter.cfg    ← JFP printer.cfg template
  helixscreen_settings.json← Shipped to /home/mks/.config/helixscreen/settings.json
  KAMP/
    KAMP_settings.cfg      ← KAMP settings (installed to CONFIG_DIR/KAMP/)
    Adaptive_Meshing.cfg   ← Vendored upstream KAMP file
    Line_Purge.cfg         ← Vendored upstream KAMP file
    Smart_Park.cfg         ← Vendored upstream KAMP file
  idle_fan_shutdown.cfg
  box_drying.cfg
  mmu/                     ← Happy Hare / BunnyBox Klipper config files
  macros/                  ← gcode_macro cfg templates
  Printer Presets/         ← OrcaSlicer printer profiles

Max4/
  macros/
    gcode_macro-JustFasterPrinter.cfg ← JFP macro file (no box)
    gcode_macro-JustFasterBox.cfg     ← JFB macro file (with box)
  Instructions.md          ← User-facing SSH + install guide
  FAQ.md                   ← Fan assignments, NeoPixel, Z offset, polar cooler, misc

Configurations/            ← Stock Qidi reference files. DO NOT MODIFY.
Plugins/                   ← Stock plugin reference. DO NOT MODIFY.

.claude/
  settings.json            ← Pre-approved Bash/WebFetch permissions
  hooks/pre-commit-check.sh← Auto-lint on every commit
  checklist.md             ← Pre-flight checklists
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
3. **Bump `AIO_VERSION`** whenever `aio_menu.sh` changes. Version format is `RC<major>.<minor>` (e.g. `RC1.14`). Increment the minor on each change; bump the major for a breaking generational shift.
6. **Do not run `aio_menu.sh` as root** — the script self-enforces this.
7. **`sudo tee` pattern for writing files with elevated perms**, never `echo > file` with sudo.
8. **Use `banner`, `info`, `warn`, `ok`, `err` helpers** — never raw `echo` in installer logic.

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
| `install_bunnybox_helixscreen()` | Happy Hare + HelixScreen | `BunnyBox: installed/not found`, `Display: KlipperScreen/HelixScreen/none` |
| `install_klipperscreen()` | KlipperScreen Happy Hare Edition (standalone) | `Display: KlipperScreen/none` |
| `install_just_faster()` | JustFasterPrinter macros (Q2) | `Just Faster: Just Faster Printer` |
| `install_just_faster_box()` | JustFasterBox macros (Q2) | `Just Faster: Just Faster Box` |
| `install_idle_fan_shutdown()` | 10m idle fan+heater shutdown | `IdleFan: on/off` |
| `install_qidi_box_write()` | HelixScreen HELIX_QIDI_BOX_WRITE drop-in | `BoxWrite: on/off` |
| `install_mainsail()` | Mainsail web UI (delegates to Camden-Winder's installer) | `Mainsail: installed/not found` |

### Current Menu Layout

```
1)  Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
2)  Install KlipperScreen             (temporarily disabled)
3)  Install Just Faster Printer       (Q2 without Box)
4)  Install Just Faster Box           (Q2 with Qidi Box, no BunnyBox)
5)  Revert to Backup                  (full uninstall + restore stock)
6)  Idle Fan Shutdown                 (10m idle, temp-gated)
7)  Mainsail                          (web UI on port 100)
8)  About
9)  Health Check / Run Verifiers
10) 1.1.2 Compatibility Probe          (reversible round trip)
11) 1.1.2 Restore Rehearsal             (isolated, no live changes)
12) 1.1.2 Live Restore Proof            (controlled contract restore)
13) 1.1.2 External Restore Audit         (read-only drift report)
14) 1.1.2 Present-Path Restore Proof     (controlled systemd path)
15) 1.1.2 Klipper Extras Restore Proof    (controlled runtime path)
16) 1.1.2 Moonraker Components Proof      (controlled runtime path)
0)  Exit
```

Per-component uninstall options (BunnyBox-only / HelixScreen-only / Both) were removed in RC4. Revert to Backup is the single uninstall path and delegates to `uninstall_bunnybox()` and `uninstall_helixscreen()` internally before restoring from `_FIRST_STOCK`.

## Autonomous-Session Policy

Claude may do the following **without asking first**:

- Commit and push to any `claude/*` branch
- Create a draft PR after pushing a new branch
- Run `bash -n`, `python3 -m json.tool`, `shellcheck` (lint/syntax checks)
- Merge a PR to `main` when the handoff context explicitly says to do so

Claude **must ask first** before:

- Pushing to `main` directly
- Force-pushing any branch
- Deleting branches or files not created in the same session
- Taking actions visible to users outside this repo (posting comments, etc.)

## RC2.36 — What's In It

- `AIO_VERSION='RC2.36'`
- **Just Faster Box added to Q2 AIO** — Option 4 (`install_just_faster_box()`) installs `gcode_macro-JustFasterBox.cfg` + `JustFasterPrinter.cfg` + KAMP files. Same structure as JFP but with live box branches (`BOX_PRINT_START`, box heater control). No Happy Hare, no HelixScreen.
- **Detection helpers** — `just_faster_printer_installed()` and `just_faster_box_installed()` fingerprint on `PRINTER_PARAM` / `BOX_PRINT_START` in `gcode_macro.cfg`.
- **Status line updated** — `Just Faster: Just Faster Box / Just Faster Printer / not found` now shown alongside BunnyBox/Display.
- **`verify_jfb_install()`** — post-install check confirms files present and `BOX_PRINT_START` in macro file.
- **`revert_to_backup()` updated** — removes `gcode_macro.cfg` when JFP or JFB detected before restoring from backup.
- **Menu renumbered** — Revert→5, Idle Fan→6, Mainsail→7, About→8, Health Check→9, Testing 9–15→10–16.
- **Q2/Instructions.md** — JFB row added to path table, Option 4 subsection added, AIO menu preview added, option number references updated.

## Max4-RC1.01 — What's In It

- `AIO_VERSION='Max4-RC1.01'`
- No functional changes to the Max 4 installer.
- **Max4/Instructions.md** — AIO menu preview section added showing current Max 4 menu layout.

## RC2.13 — What's In It

Merged via PR #13 (2026-05-28):

- `AIO_VERSION='RC2.13'`
- **KlipperScreen install disabled** — Option 2 now shows a warning that KlipperScreen install is unavailable in this version. Removed due to reliability issues.
- **Full MMU config suite** (`Q2/mmu/`) — complete Happy Hare config file set shipped with the installer.
- **`helixscreen_settings.json` updated** — AMS/display settings updated for Qidi Box.

## RC1.26 — What's In It

- `AIO_VERSION='RC1.26'`
- **Option 2 is now standalone `install_klipperscreen()`** — installs KlipperScreen Happy Hare Edition only. No longer bundles BunnyBox, config templates, KAMP, or drying macros. Completely decoupled from `_install_bunnybox()`.
- **`_install_bunnybox()` simplified** — no longer accepts a `display_ui` parameter; always installs HelixScreen. All KlipperScreen conditionals removed.
- **`prepare_display_for_klipperscreen()`** replaces `switch_display_to_klipperscreen()`: stops/disables/masks `makerbase-client` and `helixscreen` only — no lightdm or graphical.target manipulation. The upstream installer handles its own X/console setup.
- **`NETWORK=N`** still passed to prevent the installer killing dhcpcd/NetworkManager. `xserver-xorg-legacy` still stripped (not available on Debian Bullseye ARM).
- **`uninstall_klipperscreen()`** simplified: removes service/dirs, restores `graphical.target`, unmasks/enables lightdm and makerbase-client. No lightdm.conf backup/restore needed.
- Removed all custom xinit/xsetup/lightdm.conf constants (`KLIPPERSCREEN_UNIT`, `KLIPPERSCREEN_XSETUP`, `LIGHTDM_CONF`).

## RC1 — What's In It

Merged to `main` via PR #1 (2026-05-20):

- `AIO_VERSION='RC1'` constant; rendered in banner and About screen
- `verify_qidi_box_helixscreen()` — post-install check (warns, never fails)
- `install_qidi_box_write()` — systemd drop-in for `HELIX_QIDI_BOX_WRITE=1`; `BoxWrite:` status line
- `helixscreen_settings.json`: `"ams": { "spool_style": "3d" }` for Qidi Box AMS view

## RC2 — Candidate Features (not yet implemented)

- `update_qidi_box_dropin` migration helper
- `/release` slash command for version bump + changelog + tag + push

## RC11 — What's In It

- `AIO_VERSION='RC11'`
- **`Option 'gcode' is not valid in section 'bed_mesh'` fixed**: `check_invalid_klipper_options()` now also detects and removes `gcode:` keys (and their indented body) that appear inside `[bed_mesh]`. Some Qidi stock `printer.cfg` versions place the entire `[idle_timeout]` body inside `[bed_mesh]` with no section header; Klipper rejects both `timeout:` (already caught in RC8) and `gcode:`.
- **`BED_MESH_CALIBRATE already registered` fix hardened**: `fix_known_klipper_conflicts()` check #6 now scans ALL `.cfg` files at the config root for `[gcode_macro BED_MESH_CALIBRATE]` definitions, not just `KAMP_Settings.cfg`. Any file that is NOT `Adaptive_Meshing.cfg` gets its duplicate definition commented out with `## AIO_DISABLED:`.
- **PIPESTATUS install-abort bug fixed**: `install_bunnybox_helixscreen()` previously only aborted on exit code 99 (user BunnyBox cancel). Any other non-zero exit (e.g., a failed `fetch()` for `printer.cfg`) would silently print "Install complete" and leave the printer with partial/broken configs. Now any non-zero exit code aborts the install with an error message pointing to the log file.

## RC10 — What's In It

- `AIO_VERSION='RC10'`
- **Fresh-install black screen fixed**: HelixScreen now activates correctly after option 1. Added `switch_display_to_helixscreen()` which stops/disables/masks `lightdm` and `makerbase-client`, then enables/starts `helixscreen.service`. Called automatically at the end of `install_bunnybox_helixscreen()`.

## RC8 — Candidate Features (not yet implemented)

- Symmetric `uninstall_just_faster()` (option 2 currently has no individual uninstall path; Revert to Backup is the only way to undo it)

## RC8 — What's In It

- `AIO_VERSION='RC8'`
- **Post-revert sanity check**: `revert_to_backup()` now runs the full verifier sweep (`_run_verifiers_core`) at the end so any leftover problems (orphan includes, leftover MMU extras, duplicate macros, invalid Klipper options) are caught before the user is told the revert is complete. The same checks run from menu option 7.
- **`check_invalid_klipper_options()`** — catches `timeout: 43200` misplaced inside `[bed_mesh]` (some Qidi stock printer.cfg versions ship it there; Klipper rejects with "Option 'timeout' is not valid in section 'bed_mesh'"). Prompts before fixing.
- **`check_orphan_includes()`** — finds `[include X]` lines whose target file doesn't exist on disk and offers to comment them out. Prevents "Unable to open config file" boot failures.
- **`check_leftover_mmu_artifacts()`** — detects surviving Happy Hare v3 `extras/mmu/` package, `mmu_*.py` symlinks, and active `[mmu*]` sections that escaped uninstall. Prompts before each cleanup.
- **`run_all_verifiers()` refactored**: split into `_run_verifiers_core()` (no press_enter, callable from anywhere) and `run_all_verifiers()` (core + press_enter for the menu).

## RC7 — What's In It

- `AIO_VERSION='RC7'`
- **Mainsail install added as menu option 5**: delegates to Camden-Winder's `install-mainsail.sh` (same `curl | bash` pattern we use for BunnyBox and HelixScreen). Mainsail listens on port 100; Qidi's stock lighttpd on port 80 is untouched.
- **`install_mainsail()` / `uninstall_mainsail()` / `mainsail_installed()` / `verify_mainsail()` / `menu_mainsail()`** added per the install-function convention.
- **Revert to Backup** now uninstalls Mainsail too (removes nginx site, `/home/mks/mainsail`, reloads nginx). Moonraker CORS entries are left in place (harmless).
- **Status line** now shows `Mainsail: installed/not found`.
- **Menu renumbered**: About → 6, Run all verifiers → 7.

## RC6 — What's In It

- `AIO_VERSION='RC6'`
- **`BED_MESH_CALIBRATE` duplicate fixed**: `fix_known_klipper_conflicts()` now detects when `KAMP_Settings.cfg` defines `[gcode_macro BED_MESH_CALIBRATE]` inline (older BunnyBox/KAMP versions put this at line ~46) while `Adaptive_Meshing.cfg` also defines it. The correct structure has `KAMP_Settings.cfg` using `[include ./Adaptive_Meshing.cfg]` only — not redefining the macro inline. When the conflict is detected, AIO re-fetches the correct `KAMP_Settings.cfg` from the repo, resolving the duplicate without manual intervention.
- **Verifier order fixed**: `run_all_verifiers()` (option 6) now runs `fix_known_klipper_conflicts` *before* `find_duplicate_macros` so conflicts are healed before the scan report. Previously the scan ran first, showing problems that `fix_known_klipper_conflicts` would have fixed a moment later.

## RC5 — What's In It

- `AIO_VERSION='RC5'`
- **Fresh-install crash fixed**: `install_bunnybox_helixscreen()` no longer re-enables `[include box.cfg]` in `printer.cfg`. Including `box.cfg` loads Qidi's `box_extras.so` plugin, which registers `CLEAR_TOOLCHANGE_STATE` — the same gcode command Happy Hare's `mmu/` package registers. Loading both crashes Klipper on startup. The shipped `printer(BunnyBox&HelixScreen).cfg` template already ships with the include commented out (BunnyBox's installer disables it); RC1–RC4 had explicit code to re-enable it for the Qidi UI "Control Box" panel, which was the source of the crash.
- **Trade-off documented**: while BunnyBox is installed, the Qidi UI's "Control Box" panel does NOT work — Happy Hare owns box hardware via `[mmu]` steppers and its own gcode commands. Revert to Backup restores stock `printer.cfg` with `[include box.cfg]` active, bringing the Qidi UI panel back.
- **Defensive disable**: install now also comments out any existing `^[include box.cfg]` line in `printer.cfg`, so users carrying state from RC1–RC4 are healed by re-running option 1.
- **`verify_qidi_box_helixscreen()` flipped**: with BunnyBox installed, `[include box.cfg]` active is now flagged as an error (it WILL crash Klipper) instead of being treated as the desired state.

## RC4 — What's In It

- `AIO_VERSION='RC4'`
- **`purge_happy_hare_all()`** now removes Happy Hare v3's package layout: `~/klipper/klippy/extras/mmu/` directory and all `mmu_*.py` symlinks (mmu_espooler, mmu_servo, mmu_led_effect). The previous v2-style file list missed everything in v3, leaving the mmu package live in Klipper after uninstall — which caused `CLEAR_TOOLCHANGE_STATE already registered` crashes when `box_extras.so` tried to re-register the same command.
- **`purge_happy_hare_all()`** now removes root-level KAMP files (`KAMP_Settings.cfg`, `Adaptive_Meshing.cfg`, `Line_Purge.cfg`, `Smart_Park.cfg`). The stale BunnyBox-shipped `KAMP_Settings.cfg` was defining `BED_MESH_CALIBRATE` and clashing with `Adaptive_Meshing.cfg`. `fix_printer_cfg_after_uninstall()` handles the resulting orphan `[include]` lines.
- **`restore_aio_disabled_macros()`** (new) — reverses the `## AIO_DISABLED:` prefixes that `fix_known_klipper_conflicts()` applies to `box1.cfg` (T0-T3, UNLOAD_T0-T3) and `gcode_macro.cfg` (EXTRUSION_AND_FLUSH). Called from `purge_happy_hare_all()` so uninstall restores Qidi's native tool-change buttons and the flush macro.
- **Menu simplified**: options 3 (Uninstall BunnyBox), 4 (Uninstall HelixScreen), 5 (Uninstall Both) removed. Revert to Backup is the single uninstall path; it now delegates to `uninstall_helixscreen()` and `uninstall_bunnybox()` internally so it picks up every cleanup step (qidi-box-write systemd drop-in, helixscreen state dir, moonraker bak, restore_aio_disabled_macros, fix_printer_cfg_after_uninstall).
- Remaining menu numbers: `3) Revert`, `4) Idle Fan Shutdown`, `5) About`, `6) Run all verifiers`.

## RC3 — What's In It

- `AIO_VERSION='RC3'`
- Removed `heater_vent_macro` / `heater_vent_interval` patching in `mmu_parameters.cfg`. Happy Hare's vent macro is for MMU enclosures with motorized vents; Q2's box has a manual vent.
- Removed the `wget | bash -- --revert` call in `revert_to_backup()` — Camden-Winder's BunnyBox installer has no `--revert` flag. `purge_happy_hare_all()` handles the full teardown.
- `install_bunnybox_helixscreen()` now strips the `HELIX_QIDI_BOX_WRITE` drop-in (instead of installing it). HelixScreen ENV docs confirm the flag gates `load_filament`, `unload_filament`, `change_tool`, `set_tool_mapping` on the **native Qidi Box AMS backend** — exactly what BunnyBox + Happy Hare own when installed.
- Verifier and status line flipped: with BunnyBox installed, drop-in **absent** is the desired state (`BoxWrite: off` shown green).

## Known Bugs Fixed in RC2 (merged)

| PR | Fix |
|---|---|
| #7 | Duplicate gcode_macro conflict resolver (`fix_known_klipper_conflicts`) |
| #8 | Install KAMP sub-files alongside `KAMP_Settings.cfg` |
| #9 | Fix bogus flags to Happy Hare (`-u`) and HelixScreen (`--remove`) uninstallers |
| #10 | Clean backup dirs, HelixScreen dir, moonraker bak on uninstall |
| #11 | Patch `printer.cfg` broken includes after uninstall; drop pre-revert backup |
| #12 | Comment out `TOOL_CHANGE_START/END` in `bunnybox_macros.cfg` (Qidi Python plugin owns them) |
| #13 | Detect `box_extras.so` (Qidi ships compiled `.so`, not `.py`) |

## External Resources

- HelixScreen: `prestonbrown/helixscreen` on GitHub
- Happy Hare: `moggieuk/Happy-Hare`
- BunnyBox installer: `Camden-Winder/Bunny-Box` → `Q2/install-bb-q2.sh`
- Qidi Box: `wiki.qidi3d.com`
