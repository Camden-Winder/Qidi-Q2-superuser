# Qidi Q2 Superuser - What Was Done

A summary of the toolkit assembled in `Camden-Winder/Qidi-Q2-superuser`, what each piece does, and where the All-in-One (AIO) menu fits in.

## Project

**Qidi Q2 Superuser** is a community-driven toolkit that unlocks advanced features on the Qidi Q2 3D printer beyond stock Qidi firmware: multi-material printing, a modern touchscreen UI, adaptive bed meshing, and faster, cleaner print start/end macros — all with a backup/restore safety net.

This repo hardens the upstream installers and adds an AIO menu so anything you can do to a Q2 can be done from a single script.

## Install Paths

| Path | What it installs |
|---|---|
| **Just Faster Printer** | Optimised macros only; stock screen |
| **Just Faster Box** | Optimised macros with Qidi Box-aware paths |
| **BunnyBox + HelixScreen** | Happy Hare MMU firmware + HelixScreen LVGL UI (`legacy_mks` firmware only) |

## Accomplished

### `Q2/aio_menu.sh` — Q2 AIO Menu (RC3.00)

Single-entry, ANSI-coloured bash menu for the Qidi Q2. Refuses to run as root.

Menu items:

| # | Action |
|---|--------|
| 1 | Install BunnyBox & HelixScreen (Q2 with Qidi Box) |
| 2 | Install Just Faster Printer (Q2 without Box, stock screen) |
| 3 | Install Just Faster Box (Q2 with Qidi Box, no BunnyBox) |
| 4 | Update Macros (re-fetch AOI-owned macro files for installed group) |
| 5 | Revert to Backup (full uninstall + restore stock) |
| 6 | Uninstall Mainsail (remove web UI only) |
| 7 | Mainsail (web UI on port 100) |
| 8 | About |
| 9 | Health Check / Run Verifiers |
| 10 | Testing |
| 0 | Exit |

Features:
- Checks network, config directory, and Klipper safety settings before any install starts
- Creates a timestamped backup before every install or revert — one menu choice restores your printer to stock
- Colour-coded status output and a live header showing what's currently installed
- Asks for confirmation before any destructive action
- Post-install checks verify each feature landed correctly; Health Check (option 9) sweeps the whole config for common problems
- Automatically fixes known Klipper conflicts: duplicate macro definitions, misplaced bed mesh keys, conflicting includes
- Webcam/camera support — plug in a USB camera and the installer sets it up; live view appears inside Mainsail automatically
- Revert to Backup never deletes files that existed before AIO was installed
- Before reverting, shows exactly what will be removed and what will be kept — without touching anything
- After installing HelixScreen, patches the dashboard layout automatically so you get a useful widget arrangement out of the box
- Update Macros (option 4) re-downloads your macro files without re-running the full installer
- Tracks your install path, version, and date internally so the menu always shows accurate status
- Full support for newer Q2 firmware (01.01.02+) — options 2 and 3 (Just Faster Printer/Box) auto-detect the layout and install to the correct paths; option 1 (BunnyBox + HelixScreen) is `legacy_mks`-only for now
- Every install path ends with an optional prompt to disable unused background services (VPN clients, Bluetooth, pulseaudio, etc. — never the touchscreen or Moonraker's `polkitd`); on 01.01.02+ firmware this also offers a fix for animated touchscreen spinners that otherwise run continuously in the background. Both are reversible via Revert to Backup.
- The 1.1.2 compatibility testing tools (Testing submenu) can capture a verified restore contract and rehearse a full restore in isolation before ever touching live state — separate from, and more cautious than, the normal install/revert flow used above

### `Q2/` — Q2 Config Templates

Replaced the old `Install-Script/` folder in RC2.33. All Q2-specific source files live here.

| File | Purpose |
|---|---|
| `printer-BunnyBox.cfg` | `printer.cfg` template for BunnyBox + HelixScreen path |
| `JustFasterPrinter.cfg` | `printer.cfg` template for Just Faster Printer path |
| `helixscreen_settings.json` | Shipped to `/home/mks/.config/helixscreen/settings.json`; includes `"spool_style": "3d"` for Qidi Box AMS view |
| `_IDLE_SHUTDOWN` gcode macro | 5-minute idle fan + heater shutdown — moved into stock macro configs in RC2.51; no longer a standalone file |
| ~~`box_drying.cfg`~~ | Removed in RC2.46 — spool rotation during drying is now handled upstream by Happy Hare's Environment Manager |
| `macros/` | `gcode_macro.cfg` templates for each install path |
| `KAMP/` | `KAMP_settings.cfg` + vendored `Adaptive_Meshing.cfg`, `Line_Purge.cfg`, `Smart_Park.cfg` (moved into subdirectory in RC2.34) |
| `mmu/` | Complete Happy Hare Klipper config file set shipped with the BunnyBox installer |
| `Printer Presets/` | OrcaSlicer printer profiles |
| `aoi.ini` (written to printer) | `/home/mks/printer_data/config/aoi.ini` — AIO state file; stores install group, install version, macro version, install date |

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

- **Multi-material printing** via Happy Hare MMU / BunnyBox.
- **HelixScreen** replacement touchscreen UI — modern, themeable, Klipper-native.
- **KAMP adaptive bed meshing** — meshes only the printed area.
- **`screws_tilt_adjust`** for guided manual bed levelling.
- **Faster, cleaner `PRINT_START` / `PRINT_END`** macros.
- **Spoolman hooks** for filament inventory.
- **Mainsail web UI** — parallel web interface on port 100; stock lighttpd on port 80 is untouched.
- **Full backup/restore safety net** — every install writes a timestamped backup; Revert to Backup is one menu choice away.
- **Automated verifier suite** — catches orphan includes, duplicate macros, invalid Klipper options, and leftover MMU artifacts before they cause boot failures.
- **Optional background-service optimization** — disables unused stock services and, on 01.01.02+ firmware, a CPU-heavy touchscreen spinner animation; fully reversible via Revert to Backup.
- **01.01.02+ firmware support** — Just Faster Printer and Just Faster Box install directly on the newer home-directory layout.

## File Paths Reference

| Source file | Destination on printer |
|---|---|
| `Q2/macros/gcode_macro-BunnyBox.cfg` | `/home/mks/printer_data/config/gcode_macro.cfg` |
| `Q2/printer-BunnyBox.cfg` | `/home/mks/printer_data/config/printer.cfg` |
| `Q2/KAMP/KAMP_settings.cfg` | `/home/mks/printer_data/config/KAMP/KAMP_Settings.cfg` |
| `Q2/helixscreen_settings.json` | `/home/mks/.config/helixscreen/settings.json` |
| `Q2/macros/gcode_macro-JustFasterPrinter.cfg` | `/home/mks/printer_data/config/gcode_macro.cfg` |
| `Q2/JustFasterPrinter.cfg` | `/home/mks/printer_data/config/printer.cfg` |
| Backups (legacy_mks) | `/home/mks/mudstockbackups/YYYYMMDD_HHMMSS/` |
| `Q2/macros/gcode_macro-JustFasterPrinter.cfg` (01.01.02+) | `/home/qidi/printer_data/config/klipper-macros-qd/gcode_macro.cfg` |
| `Q2/macros/gcode_macro-JustFasterBox.cfg` (01.01.02+) | `/home/qidi/printer_data/config/klipper-macros-qd/gcode_macro.cfg` |
| Backups (01.01.02+) | `/home/qidi/mudstockbackups/YYYYMMDD_HHMMSS/` |

## Known Limitations

- **BunnyBox requires HelixScreen for MMU workflows** — the stock Qidi screen does not expose the MMU UI. While BunnyBox is installed, the Qidi UI's "Control Box" panel does not work (Happy Hare owns the box hardware). Revert to Backup restores the stock panel.
- **`MMU_CALIBRATE_GEAR` required after clean installs**: mark filament, run `MMU_CALIBRATE_GEAR GATE=0 LENGTH=100`, measure travel, re-run with `MEASURED=<mm>`.
- **BunnyBox + HelixScreen is `legacy_mks`-only** — not available on 01.01.02+ firmware yet. Just Faster Printer and Just Faster Box both work on either firmware layout.
- Filament drying is handled by Happy Hare's Environment Manager, not a dedicated AIO macro — see the [upstream Happy Hare wiki](https://github.com/moggieuk/Happy-Hare/wiki) for the drying workflow.

## Usage

### Q2 (as user `mks`, never root)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/Q2/aio_menu.sh)
```

## Upstream Lineage

- **Repo:** [`Camden-Winder/Qidi-Q2-superuser`](https://github.com/Camden-Winder/Qidi-Q2-superuser)
- **BunnyBox:** [`Camden-Winder/Bunny-Box`](https://github.com/Camden-Winder/Bunny-Box)
- **HelixScreen:** [`prestonbrown/helixscreen`](https://github.com/prestonbrown/helixscreen)
- **Happy Hare:** [`moggieuk/Happy-Hare`](https://github.com/moggieuk/Happy-Hare)
