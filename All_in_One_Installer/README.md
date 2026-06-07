# Qidi Q2 Superuser - All-in-One Installer

> **Disclaimer:** Use this tool at your own risk. The author is not responsible for any damage, malfunction, or data loss caused to your printer. Qidi states that any modifications to files on their printers may void the manufacturer warranty.

**Warning** some parts of this script are still under testing, use with caution and ask in the discord if you need to ensure it is in a working condition.

A single menu that handles every install, uninstall, and addon path for the Qidi Q2 community toolkit — no more tracking which script does what.

```
============================================
   Qidi Q2 Superuser - AIO Setup Menu (RC1.30)
============================================
  BunnyBox: not found | Display: none | IdleFan: off | BoxWrite: off
  Mainsail: not found | Camera: off
--------------------------------------------
  INSTALL
   1) Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
   2) Install KlipperScreen             (Happy Hare Edition)
   3) Install Just Faster Printer       (Q2 without Box)
  UNINSTALL
   4) Revert to Backup                  (full uninstall + restore stock)
  ADDONS
   5) Idle Fan Shutdown                 (10m idle, temp-gated)
   6) Mainsail                          (web UI on port 100)
  INFO
   7) About
   8) Health Check / Run Verifiers
   0) Exit
============================================
```

## Requirements

- Qidi Q2 running stock Klipper firmware
- SSH access as user `mks` (the default Qidi user)
- Internet access from the printer
- **Do not run as root** — the script will refuse to start

## Install

SSH into the Q2 as `mks`, then:

**One-liner:**
```bash
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/All_in_One_Installer/aio_menu.sh | bash
```

**Download first (review before running):**
```bash
curl -fsSL -o aio_menu.sh \
  https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/All_in_One_Installer/aio_menu.sh
chmod +x aio_menu.sh
./aio_menu.sh
```

## Menu options

| # | Option | What it does |
|---|--------|-------------|
| 1 | **Install BunnyBox & HelixScreen** | For Q2 owners with a Qidi Box. Installs Happy Hare MMU firmware and the HelixScreen touchscreen UI, applies optimised Klipper configs, and enables filament drying with automatic spool rotation. Option 1 automatically installs the Happier Hare patched HelixScreen build when `/home/mks/helixscreen-pi-happier-hare.zip` is present or `HAPPIER_HARE_ZIP_URL` is set; macro buttons remain the fallback. |
| 2 | **Install KlipperScreen** | Installs KlipperScreen Happy Hare Edition — a touchscreen UI built specifically for Happy Hare MMU setups. Configures 4-gate support for the Qidi Box. Does not install BunnyBox or modify Klipper configs. |
| 3 | **Install Just Faster Printer** | For Q2 owners without a Box. Keeps the stock Qidi screen but adds cleaner macros, faster print start, and adaptive bed meshing. |
| 4 | **Revert to Backup** | Fully uninstalls everything AIO has installed and restores your printer to the state it was in before the first AIO run. Runs a health check automatically at the end. |
| 5 | **Idle Fan Shutdown** | Addon toggle. Shuts off fans and heaters after 10 minutes idle, but only once all temps have dropped to safe levels. |
| 6 | **Mainsail** | Addon toggle. Installs the Mainsail web interface, accessible at `http://<printer-ip>:100`. Qidi's stock UI on port 80 is unaffected. Includes a camera proxy so the webcam stream works in Mainsail. |
| 7 | **About** | Shows the current AIO version and a brief description. |
| 8 | **Health Check / Run Verifiers** | Scans your Klipper config for common problems — duplicate macros, broken include lines, invalid settings — and offers to fix each one. Safe to run any time. |

## Filament drying (BunnyBox installs only)

After installing BunnyBox (option 1), the following one-tap drying macros are available from the touchscreen or the Klipper console. Spools rotate automatically throughout each cycle.

| Macro | Temp | Time |
|---|---|---|
| `DRY_PLA` | 45 °C | 4 h |
| `DRY_PETG` | 65 °C | 4 h |
| `DRY_ABS` | 65 °C | 4 h |
| `DRY_TPU` | 55 °C | 4 h |
| `DRY_PA` | 70 °C | 8 h |

## After installing BunnyBox & HelixScreen (option 1)

1. Run `FIRMWARE_RESTART` from the Klipper console or HelixScreen.
2. Run `sudo reboot` over SSH.
3. Run **option 8 (Health Check)** to verify everything loaded correctly.
4. **First-time only:** calibrate the MMU gear steppers:
   ```
   MMU_CALIBRATE_GEAR GATE=0 LENGTH=100
   ```
   Mark the filament at the entry point, measure how far it moved, then re-run with `MEASURED=<mm>`. Repeat for each gate.
5. Load filament into each gate and start a drying preset from the HelixScreen AMS environment UI when using the Happier Hare patched zip, or from the macro buttons/console as a fallback.

## After installing KlipperScreen (option 2)

1. Run `FIRMWARE_RESTART` from the Klipper console or KlipperScreen.
2. Run `sudo reboot` over SSH.
3. Verify KlipperScreen is running: `systemctl status KlipperScreen`

## After installing Just Faster Printer (option 3)

1. Run `FIRMWARE_RESTART`.
2. Run `sudo reboot` over SSH.
3. Run a bed level and `SCREWS_TILT_CALCULATE` before your first print.

## Release history

| Version | Notable additions |
|---------|------------------|
| RC2.13 | Points Option 1 at the hosted Happier Hare patched HelixScreen release asset (`happier-hare-rc2.12/helixscreen-pi.zip`) so installs no longer require SCP when the release asset is available |
| RC2.12 | Option 1 now automatically installs the Happier Hare patched HelixScreen archive from `/home/mks/helixscreen-pi-happier-hare.zip` when present, without requiring `HAPPIER_HARE_ZIP_URL` |
| RC2.11 | Hardened Happier Hare install verification so it scans all installed `helix-screen*` binaries and reports which binary contains the dryer and Qidi Box sensor patches |
| RC2.10 | Updated Happier Hare Qidi Box sensor matching for the Happy Hare config names (`temperature_sensor box1_env`, `heater_generic box1_heater`) and made install/revert instructions explicitly require `FIRMWARE_RESTART` followed by `sudo reboot` |
| RC2.9 | Hardened Revert to Backup stock display restoration: resets failed lightdm/makerbase state, restores `graphical.target`, unmasks `display-manager.service`, prints recent service logs if the stock display stack does not come back, and keeps `/home/mks/mudstockbackups/` when stock display verification fails |
| RC1.30 | Option 2 (KlipperScreen) temporarily disabled — display not rendering despite service running; under investigation |
| RC1.29 | Fixed KlipperScreen Xorg crash: Q2 kernel lacks `/dev/tty0` (no VT subsystem); systemd drop-in now creates the device node via `ExecStartPre` before each service start and clears the `ConditionPathExists` gate |
| RC1.28 | Fixed KlipperScreen not launching: upstream service unit has `ConditionPathExists=/dev/tty0` which fails on the Q2; a systemd drop-in now clears this condition after install |
| RC1.27 | Option 2 is now standalone KlipperScreen — no longer bundles BunnyBox, config templates, KAMP, or drying macros; `_install_bunnybox()` simplified to HelixScreen-only |
| RC1.26 | KlipperScreen option 2 rewritten to use upstream `KlipperScreen-install.sh` as-is (stops fighting lightdm/tty0); `makerbase-client` and `helixscreen` are masked before the upstream installer runs; removed all custom X/lightdm manipulation; `xserver-xorg-legacy` stripped from install script (not available on Debian Bullseye ARM) |
| RC1.25 | Fixed `install_ks.sh` aborting on `git describe` — switched from shallow clone (`--depth 1`) to full clone so tag history is available; fixed service starting before custom `launch_KlipperScreen.sh` is in place by changing `START=1` → `START=0` in KlipperScreen-install.sh invocation |
| RC1.24 | Fixed KlipperScreen service crash (`Group=mks` — Q2 has no `mks` group); fixed wrong KlipperScreen clone (existing non-HH-Edition clone is now detected and replaced); fixed `daemon-reload` ordering so the service unit is loaded before `enable`/`start` |
| RC1.23 | KlipperScreen option 2 rewritten: uses KlipperScreen Happy Hare Edition as an X client on lightdm's `:0` display (no xinit, no tty switching, no network changes); `NETWORK=N` to prevent the installer from killing dhcpcd/NetworkManager; 4-gate Qidi Box support via `install_ks.sh -g 4`; clean revert restores lightdm config and stock display |
| RC1.22 | Removed KlipperScreen option (Q2 display constraints made it unreliable); added filament drying macro buttons (Dry PLA/PETG/ABS/TPU/Nylon, Stop Dry) to HelixScreen settings; menu renumbered to 7 options |
| RC1.14 | Adopted `RC<major>.<minor>` version format; fixed duplicate webcam entries in Mainsail |
| RC13 | Fixed camera stream in Mainsail (nginx `/webcam/` proxy + correct ustreamer paths) |
| RC11 | Fixed two post-install Klipper errors: `gcode: not valid in section 'bed_mesh'` and `BED_MESH_CALIBRATE already registered`; install now aborts correctly if a required step fails |
| RC10 | Fixed fresh-install black screen — HelixScreen now activates correctly after option 1 |
| RC9 | Automatic spool rotation during filament drying cycles |
| RC8 | Health check runs automatically after every Revert to Backup; new config validators (orphan includes, invalid settings, leftover MMU files) |
| RC7 | Mainsail web UI as a menu addon |
| RC6 | Fixed `BED_MESH_CALIBRATE` duplicate crash from older BunnyBox installs |
| RC5 | Fixed Klipper startup crash caused by conflicting Box hardware drivers |
| RC4 | Simplified uninstall — Revert to Backup is now the single restore path |
| RC1–3 | Initial AIO release; HelixScreen + BunnyBox install/uninstall; idle fan shutdown addon |

## Known limitations

- **Native Qidi Box humidity/dryer UI requires the Happier Hare patched HelixScreen zip.** Without that zip, use the macro buttons or Klipper console.
- **MMU gear calibration is required after a fresh install.**
- **Camera streaming (Mainsail)** requires a USB camera connected to the printer.

## Troubleshooting

**`ERROR: Cannot reach raw.githubusercontent.com`** — No internet from the printer. Check network settings.

**`ERROR: Config directory not found`** — Not running as `mks`, or this isn't a Klipper-based Q2.

**Klipper won't start after install** — Run option 8 (Health Check). It will identify and offer to fix the most common causes.

**KlipperScreen not showing on display** — Check `sudo journalctl -u KlipperScreen -n 50`. Verify lightdm is running (`systemctl status lightdm`) and that `display-setup-script` is set in `/etc/lightdm/lightdm.conf`.

**Klipper won't start after uninstall** — Use option 4 (Revert to Backup) for a clean restore.

**LightDM fails after Revert to Backup** — Run option 8 (Health Check) or inspect `journalctl -u lightdm -n 80 --no-pager` and `journalctl -u makerbase-client -n 80 --no-pager`. RC2.9+ prints recent stock-display service logs during revert when either service fails.

**No stock backup exists** — `/home/mks/mudstockbackups/` is created automatically on first run. If configs were already changed before the first AIO run, restore from a Qidi factory image first, then run AIO to capture a clean baseline.

## Links

- Repo: https://github.com/Camden-Winder/Qidi-Q2-superuser
- Upstream: https://github.com/Camden-Winder/Qidi-Q2-superuser
- BunnyBox: https://github.com/Camden-Winder/Bunny-Box
- HelixScreen: https://github.com/prestonbrown/helixscreen
- KlipperScreen Happy Hare Edition: https://github.com/moggieuk/KlipperScreen-Happy-Hare-Edition
- Mainsail: https://github.com/mainsail-crew/mainsail
