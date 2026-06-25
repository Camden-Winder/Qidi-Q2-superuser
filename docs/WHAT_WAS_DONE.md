# Qidi Q2 Superuser - What Was Done

A summary of the toolkit assembled in `Camden-Winder/Qidi-Q2-superuser`, what each piece does, and where the All-in-One (AIO) menu fits in.

## Project

**Qidi Q2 Superuser** is a community-driven toolkit that unlocks advanced features on the Qidi Q2 and Qidi Max 4 3D printers beyond stock Qidi firmware: multi-material printing (Q2 only), a modern touchscreen UI (Q2 only), automatic filament drying with humidity sensing, adaptive bed meshing, and faster, cleaner print start/end macros — all with a backup/restore safety net.

This repo hardens the upstream installers and adds per-printer AIO menus so anything you can do to a Q2 or Max 4 can be done from a single script.

## Install Paths

| Path | Printer | What it installs |
|---|---|---|
| **Just Faster Printer** | Q2 and Max 4 | Optimised macros only; stock screen |
| **Just Faster Box** | Max 4 only | Optimised macros with Qidi Box AMS paths |
| **BunnyBox + HelixScreen** | Q2 only | Happy Hare MMU firmware + HelixScreen LVGL UI |

## Accomplished

### `Q2/aio_menu.sh` — Q2 AIO Menu (RC2.36 / macro files RC2.37)

Single-entry, ANSI-coloured bash menu for the Qidi Q2. Refuses to run as root.

Menu items:

| # | Action |
|---|--------|
| 1 | Install BunnyBox & HelixScreen (Q2 with Qidi Box) |
| 2 | Install Just Faster Printer (Q2 without Box, stock screen) |
| 3 | Install Just Faster Box (Q2 with Qidi Box, no BunnyBox) |
| 4 | Revert to Backup (full uninstall + restore stock) |
| 5 | Idle Fan Shutdown (10 min idle, temp-gated) |
| 6 | Mainsail (web UI on port 100) |
| 7 | About |
| 8 | Health Check / Run Verifiers |
| 0 | Exit |

Features:
- Preflight (network reachability to GitHub, `${CONFIG_DIR}` present, `enable_force_move` sanity check)
- Timestamped backups to `/home/mks/mudstockbackups/YYYYMMDD_HHMMSS/` before every install and revert
- Install log via `tee` for BunnyBox+HelixScreen flow
- Per-action `[OK] / [INFO] / [WARN] / [ERR]` status lines (green / cyan / yellow / red)
- Live status header: `BunnyBox`, `HelixScreen`, `IdleFan`, `BoxWrite`, `Mainsail` installed-state
- Y/N confirmation on destructive actions
- Post-install verifiers: `verify_qidi_box_helixscreen()`, `verify_mainsail()`, etc.
- `run_all_verifiers()` (option 8) sweeps for orphan includes, duplicate macros, invalid Klipper options, and leftover MMU artifacts — also auto-runs at the end of `revert_to_backup()`
- `fix_known_klipper_conflicts()` — detects and resolves: duplicate `BED_MESH_CALIBRATE` macro definitions across config files; `timeout:` / `gcode:` keys misplaced inside `[bed_mesh]`; `[include box.cfg]` active while BunnyBox is installed (crashes Klipper)
- `check_orphan_includes()` — finds `[include X]` lines whose target doesn't exist and offers to comment them out
- `check_leftover_mmu_artifacts()` — detects surviving Happy Hare v3 `extras/mmu/` package and `mmu_*.py` symlinks
- `switch_display_to_helixscreen()` — stops/disables `lightdm` and `makerbase-client`, then enables `helixscreen.service` (fixes fresh-install black screen)
- Revert to Backup is the single uninstall path; internally delegates to `uninstall_bunnybox()` and `uninstall_helixscreen()` and then rsyncs the newest timestamped stock backup back over `${CONFIG_DIR}`
- Happier Hare (custom patched HelixScreen binary) subsystem removed in RC2.34; HelixScreen is always pulled from the upstream `main` branch
- **RC2.37 macro audit** — four missing macros (`M4032`, `SMART_STATUS`, `prepare_filament_dry`, `restore_factory_settings`) restored to JFB and JFP; `SET_PRINT_MAIN_STATUS`/`SET_PRINT_SUB_STATUS` calls re-inserted in `M901`, `M4029`, `M603`, `M604`; `CLEAR_NOZZLE` cross-ported JFP→JFB; `EXTRUSION_AND_FLUSH` loop count fixed; `CANCEL_PRINT`/`PAUSE`/`RESUME_PRINT`/`RESUME` restored to JFP

### `Max4/aio_menu_max4.sh` — Max 4 AIO Menu (Max4-RC1)

Sibling installer for the Qidi Max 4. Separate file; `aio_menu.sh` is never modified for Max 4 changes.

Menu items:

| # | Action |
|---|--------|
| 1 | Install Just Faster Printer (Max 4, no Qidi Box) |
| 2 | Install Just Faster Box (Max 4 with Qidi Box) |
| 3 | System Optimizations (DNS, APT, services, GIFs) |
| 4 | Revert to Backup (full uninstall + restore stock) |
| 5 | About |
| 6 | Run all verifiers |
| 0 | Exit |

Key differences from the Q2 installer:
- No BunnyBox / Happy Hare — stock UI only
- No HelixScreen — Max 4 uses the stock `qidi-client` touchscreen
- Runs as user `qidi` (not `mks`); config root is `/home/qidi/printer_data/config/`
- Two macro variants: `gcode_macro-JustFasterPrinter.cfg` (no box) and `gcode_macro-JustFasterBox.cfg` (with box)
- Supports firmware `01.01.06.03` and `01.01.06.04`
- System Optimizations option: faster DNS, quieter APT, disables unused services, removes boot GIFs

### `Q2/` — Q2 Config Templates

Replaced the old `Install-Script/` folder in RC2.33. All Q2-specific source files live here.

| File | Purpose |
|---|---|
| `printer-BunnyBox.cfg` | `printer.cfg` template for BunnyBox + HelixScreen path |
| `JustFasterPrinter.cfg` | `printer.cfg` template for Just Faster Printer path |
| `helixscreen_settings.json` | Shipped to `/home/mks/.config/helixscreen/settings.json`; includes `"spool_style": "3d"` for Qidi Box AMS view |
| `_IDLE_SHUTDOWN` gcode macro | 5-minute idle fan + heater shutdown — moved into stock macro configs in RC2.51; no longer a standalone file |
| `box_drying.cfg` | Spool rotation during filament drying via Happy Hare Environment Manager |
| `macros/` | `gcode_macro.cfg` templates for each install path |
| `KAMP/` | `KAMP_settings.cfg` + vendored `Adaptive_Meshing.cfg`, `Line_Purge.cfg`, `Smart_Park.cfg` (moved into subdirectory in RC2.34) |
| `mmu/` | Complete Happy Hare Klipper config file set shipped with the BunnyBox installer |
| `Printer Presets/` | OrcaSlicer printer profiles |

### `Max4/` — Max 4 Config Templates

| File | Purpose |
|---|---|
| `macros/gcode_macro-JustFasterPrinter.cfg` | Macro file for Max 4 without Qidi Box |
| `macros/gcode_macro-JustFasterBox.cfg` | Macro file for Max 4 with Qidi Box |
| `Instructions.md` | User-facing SSH + install guide |
| `FAQ.md` | Fan assignments, NeoPixel, Z offset, polar cooler, misc |

### `Q2/box_drying.cfg`

Klipper config that restores spool rotation during filament drying using Happy Hare's Environment Manager:

- `BOX_DRY [TEMP=] [TIME=] [HUMIDITY=]` — wraps `MMU_HEATER DRY=1` with humidity-based early termination via the AHT2X sensor
- `BOX_DRY_STOP`, `BOX_DRY_STATUS`, `BOX_ROTATE_SPOOLS`
- `_QIDI_BOX_VENT` — called by Happy Hare on its venting interval; rotates spools via `FORCE_MOVE` so heat penetrates evenly

### Install-Function Conventions

Every install capability follows this pattern:

- `install_*()` — installs the feature
- `uninstall_*()` — removes it cleanly
- `*_installed()` or `*_enabled()` — detection helper
- Wired into `revert_to_backup()` — called during full revert
- Status indicator in `show_status_line()` — e.g. `IdleFan: on/off`
- `verify_*()` — post-install sanity check (warns, never fails)
- Remote files fetched with the `fetch()` helper, not `curl` directly

## Achievements

- **Multi-material printing** via Happy Hare MMU / BunnyBox (Q2).
- **HelixScreen** replacement touchscreen UI — modern, themeable, Klipper-native (Q2).
- **Automatic filament drying** with humidity-based early termination (AHT2X) and active spool rotation while drying (Q2).
- **KAMP adaptive bed meshing** — meshes only the printed area.
- **`screws_tilt_adjust`** for guided manual bed levelling.
- **Faster, cleaner `PRINT_START` / `PRINT_END`** macros.
- **Spoolman hooks** for filament inventory.
- **Idle Fan Shutdown** — fans and heaters turn off after 10 minutes of idle (temp-gated).
- **Mainsail web UI** — parallel web interface on port 100; stock lighttpd on port 80 is untouched.
- **System Optimizations** (Max 4) — DNS, APT, service, and boot-animation improvements.
- **Full backup/restore safety net** — every install writes a timestamped backup; Revert to Backup is one menu choice away.
- **Automated verifier suite** — catches orphan includes, duplicate macros, invalid Klipper options, and leftover MMU artifacts before they cause boot failures.
- **Dual-printer scope** — single repo covers both the Qidi Q2 and Qidi Max 4 with separate, non-interfering installers.

## File Paths Reference

### Q2

| Source file | Destination on printer |
|---|---|
| `Q2/macros/gcode_macro-BunnyBox.cfg` | `/home/mks/printer_data/config/gcode_macro.cfg` |
| `Q2/printer-BunnyBox.cfg` | `/home/mks/printer_data/config/printer.cfg` |
| `Q2/box_drying.cfg` | `/home/mks/printer_data/config/box_drying.cfg` |
| `Q2/KAMP/KAMP_settings.cfg` | `/home/mks/printer_data/config/KAMP/KAMP_Settings.cfg` |
| `Q2/helixscreen_settings.json` | `/home/mks/.config/helixscreen/settings.json` |
| `Q2/macros/gcode_macro-JustFasterPrinter.cfg` | `/home/mks/printer_data/config/gcode_macro.cfg` |
| `Q2/JustFasterPrinter.cfg` | `/home/mks/printer_data/config/printer.cfg` |
| Backups | `/home/mks/mudstockbackups/YYYYMMDD_HHMMSS/` |

### Max 4

| Source file | Destination on printer |
|---|---|
| `Max4/macros/gcode_macro-JustFasterPrinter.cfg` | `/home/qidi/printer_data/config/gcode_macro.cfg` |
| `Max4/macros/gcode_macro-JustFasterBox.cfg` | `/home/qidi/printer_data/config/gcode_macro.cfg` |
| Backups | `/home/qidi/mudstockbackups/YYYYMMDD_HHMMSS/` |

## Known Limitations

- **BunnyBox requires HelixScreen for MMU workflows** — the stock Qidi screen does not expose the MMU UI. While BunnyBox is installed, the Qidi UI's "Control Box" panel does not work (Happy Hare owns the box hardware). Revert to Backup restores the stock panel.
- **`MMU_CALIBRATE_GEAR` required after clean installs**: mark filament, run `MMU_CALIBRATE_GEAR GATE=0 LENGTH=100`, measure travel, re-run with `MEASURED=<mm>`.
- Use the `BOX_DRY` macro or the Klipper console to start filament drying on the Q2.

## Usage

### Q2 (as user `mks`, never root)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/Q2/aio_menu.sh)
```

### Max 4 (as user `qidi`, never root)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/Max4/aio_menu_max4.sh)
```

## Upstream Lineage

- **Repo:** [`Camden-Winder/Qidi-Q2-superuser`](https://github.com/Camden-Winder/Qidi-Q2-superuser)
- **BunnyBox:** [`Camden-Winder/Bunny-Box`](https://github.com/Camden-Winder/Bunny-Box)
- **HelixScreen:** [`prestonbrown/helixscreen`](https://github.com/prestonbrown/helixscreen)
- **Happy Hare:** [`moggieuk/Happy-Hare`](https://github.com/moggieuk/Happy-Hare)
