# CLAUDE.md — Qidi Q2 Superuser AIO

Project context for Claude Code sessions. Read this first every time.

## Quick Start — Test Commands

Always run these before committing:

```bash
bash -n All_in_One_Installer/aio_menu.sh          # shell syntax check
python3 -m json.tool Install-Script/helixscreen_settings.json  # JSON lint
shellcheck -S warning All_in_One_Installer/aio_menu.sh         # style (advisory)
```

## Repo Layout

```
All_in_One_Installer/
  aio_menu.sh              ← Main artifact. All installer logic lives here.
  README.md
  WHAT_WAS_DONE.md

Install-Script/
  BunnyBox&HelixScreen.sh  ← Legacy single-shot installer (superseded by AIO)
  helixscreen_settings.json← Shipped to /home/mks/.config/helixscreen/settings.json
  idle_fan_shutdown.cfg
  box_drying.cfg
  mmu/                     ← Happy Hare / BunnyBox Klipper config files
  printer(BunnyBox&HelixScreen).cfg

Configurations/            ← Stock Qidi reference files. DO NOT MODIFY.
Plugins/                   ← Stock plugin reference. DO NOT MODIFY.

.claude/
  settings.json            ← Pre-approved Bash/WebFetch permissions
  hooks/pre-commit-check.sh← Auto-lint on every commit
  checklist.md             ← Pre-flight checklists
```

## Target Environment

- Hardware: Qidi Q2 Pro 3D printer
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
3. **Bump `AIO_VERSION`** whenever `aio_menu.sh` changes. Version format is `RC<major>.<minor>` (e.g. `RC1.14`). Increment the minor on each change; bump the major for a breaking generational shift.
4. **`bash -n` before every commit** touching any `.sh` file.
5. **`python3 -m json.tool` before every commit** touching any `.json` file.
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
| `install_bunnybox_helixscreen()` | Happy Hare + HelixScreen | `BunnyBox: installed/not found`, `HelixScreen: installed/not found` |
| `install_klipperscreen()` | KlipperScreen Happy Hare Edition (standalone) | `Display: KlipperScreen/none` |
| `install_just_faster()` | JustFasterPrinter macros | (no AMS/Box) |
| `install_idle_fan_shutdown()` | 10m idle fan+heater shutdown | `IdleFan: on/off` |
| `install_qidi_box_write()` | HelixScreen HELIX_QIDI_BOX_WRITE drop-in | `BoxWrite: on/off` |
| `install_mainsail()` | Mainsail web UI (delegates to Camden-Winder's installer) | `Mainsail: installed/not found` |

### Current Menu Layout

```
1) Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
2) Install KlipperScreen             (Happy Hare Edition)
3) Install Just Faster Printer       (Q2 without Box)
4) Revert to Backup                  (full uninstall + restore stock)
5) Idle Fan Shutdown                 (10m idle, temp-gated)
6) Mainsail                          (web UI on port 100)
7) About
8) Run all verifiers
0) Exit
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

- HelixScreen version pinning to a tagged release instead of `main`
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
- **HelixScreen installer URL pinned to tag**: was fetching from `main/scripts/install.sh` (always latest). Now pins to `HELIXSCREEN_PIN='v0.99.66'` (constant near top of script). Prevents silent upstream regressions.

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
