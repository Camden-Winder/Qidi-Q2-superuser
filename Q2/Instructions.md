# Qidi Q2 — AIO Installer Guide

This guide covers installing the Q2 AIO (`aio_menu.sh`) on a stock Qidi Q2.

---

## What the AIO Does

The AIO installer for the Q2 offers three install paths:

| Path | Who it's for |
|---|---|
| **Just Faster Printer** | Stock experience with faster/cleaner macros. No Qidi Box. Keeps stock screen. |
| **Just Faster Box** | Same as JFP but with Qidi Box-aware macros active. No BunnyBox. Keeps stock screen. |
| **BunnyBox + HelixScreen** | Full advanced stack. Happy Hare MMU firmware + HelixScreen LVGL UI. Requires Qidi Box. |
| **Addons** | Optional toggles: Idle Fan Shutdown, Mainsail web UI, camera stream. |

The AIO also handles a full **Revert to Backup** that restores your printer to factory config.

---

## AIO Menu Preview

```
============================================
   Qidi Q2 Superuser - AIO Setup Menu (RC2.36)
============================================
  Just Faster: not found | BunnyBox: not found | Display: none
  IdleFan: off | BoxWrite: off | Mainsail: not found | Camera: off
  Firmware: legacy mks layout
--------------------------------------------
  INSTALL
   1) Install BunnyBox & HelixScreen    (Q2 with Qidi Box)
   2) Install Just Faster Printer       (Q2 without Box)
   3) Install Just Faster Box           (Q2 with Qidi Box, no BunnyBox)
  UNINSTALL
   4) Revert to Backup                  (full uninstall + restore stock)
  ADDONS
   5) Idle Fan Shutdown                 (10m idle, temp-gated)
   6) Mainsail                          (web UI on port 100)
  INFO
   7) About
   8) Health Check / Run Verifiers
  TESTING
   9) 1.1.2 Compatibility Probe          (reversible round trip)
  10) 1.1.2 Restore Rehearsal             (isolated, no live changes)
  11) 1.1.2 Live Restore Proof            (controlled contract restore)
  12) 1.1.2 External Restore Audit         (read-only drift report)
  13) 1.1.2 Present-Path Restore Proof     (controlled systemd path)
  14) 1.1.2 Klipper Extras Restore Proof    (controlled runtime path)
  15) 1.1.2 Moonraker Components Proof      (controlled runtime path)
   0) Exit
============================================
Enter selection:
```

---

## Requirements

- Qidi Q2 running stock Klipper firmware (legacy mks layout)
- SSH access to the printer (user: `mks`, default password: `makerbase`)
- Printer connected to your network

---

## Step 1 — SSH into the Printer

From your computer:

```bash
ssh mks@<printer-ip>
```

Default password: `makerbase`

To find the IP: check your router's DHCP table, or look in the printer touchscreen under **Settings → Network**.

---

## Step 2 — Download and Run the Installer

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/All_in_One_Installer/aio_menu.sh)
```

The installer will run a disclaimer screen and then show the main menu.

> **Note:** Do not run as root (`sudo bash ...`). The script elevates with `sudo` only where needed and enforces this.

---

## Step 3 — Choose an Install Path

### Option 1 — BunnyBox + HelixScreen (with Qidi Box)

Choose this if you have a Qidi Box and want the full MMU stack.

What it does:
- Backs up your current `config/` to `~/mudstockbackups/`
- Runs the BunnyBox installer (Happy Hare MMU firmware for the Q2)
- Runs the HelixScreen installer (LVGL touchscreen UI built for Happy Hare)
- Writes optimised Klipper configs, KAMP adaptive meshing, and drying macros
- Disables `[include box.cfg]` in `printer.cfg` — the Qidi Box hardware is owned by Happy Hare, not the stock plugin
- Switches the display from the stock Makerbase UI to HelixScreen

After install:
1. Run `FIRMWARE_RESTART` from the Klipper console or HelixScreen
2. Run `sudo reboot` over SSH
3. Run **option 8 — Health Check** to verify everything loaded correctly
4. **First-time only:** calibrate the MMU gear steppers:
   ```
   MMU_CALIBRATE_GEAR GATE=0 LENGTH=100
   ```
   Mark the filament at the entry point, measure how far it moved, then re-run with `MEASURED=<mm>`. Repeat for each gate.

### Option 3 — Just Faster Printer (no Qidi Box)

Choose this if you do not have a Qidi Box, or want to keep the stock screen without BunnyBox.

What it does:
- Backs up your current `config/` to `~/mudstockbackups/`
- Writes optimised Klipper macros (`gcode_macro.cfg`) — faster `PRINT_START`, cleaner `PRINT_END`, adaptive bed meshing via KAMP
- Patches `printer.cfg` to include the new macro file
- Keeps the stock Makerbase touchscreen UI unchanged

Bed meshing notes:
- `G29` runs an adaptive KAMP mesh and saves it to the `kamp` profile. The `default` profile is untouched.
- `G31` enables adaptive bed leveling (default on). `G32` disables it — useful for diagnosing bed issues or skipping the mesh for a quick test print.
- `WIPE` runs a nozzle wipe at the trash chute using the live extruder target temperature. It is called automatically by `PRINT_END`.

After install:
1. Run `FIRMWARE_RESTART`
2. Run a bed level and `SCREWS_TILT_CALCULATE` before your first print

### Option 4 — Just Faster Box (with Qidi Box, no BunnyBox)

Choose this if you have a Qidi Box and want improved macros without installing Happy Hare or HelixScreen.

What it does:
- Everything Option 3 does, but installs `gcode_macro-JustFasterBox.cfg` instead of the printer-only variant
- The box-aware macro branches (`BOX_PRINT_START`, box heater control) are live — the stock Qidi Box AMS backend remains in control
- Does not install Happy Hare, BunnyBox, or HelixScreen
- Keeps the stock Makerbase touchscreen UI unchanged

Bed meshing notes:
- Same `G29`/`G31`/`G32` behavior as Option 3. KAMP saves to the `kamp` profile.
- `WIPE` works the same way — reads the live hotend target and calls `MOVE_TO_TRASH` first so oozing lands in the chute.

After install:
1. Run `FIRMWARE_RESTART`
2. Run a bed level and `SCREWS_TILT_CALCULATE` before your first print

### Option 5 — Idle Fan Shutdown (addon)

Toggle. Shuts off fans and heaters after 10 minutes of idle, but only once all temperatures have dropped to safe levels. Safe to enable on any install path.

### Option 6 — Mainsail (addon)

Toggle. Installs the Mainsail web interface, accessible at `http://<printer-ip>:100`. Qidi's stock UI on port 80 is unaffected. Includes a camera proxy so the webcam stream works in Mainsail.

---

## Filament Drying (BunnyBox installs only)

After installing BunnyBox (option 1), drying macros are available from the touchscreen or console. Spools rotate automatically throughout each cycle.

| Macro | Temp | Time |
|---|---|---|
| `DRY_PLA` | 45 °C | 4 h |
| `DRY_PETG` | 65 °C | 4 h |
| `DRY_ABS` | 65 °C | 4 h |
| `DRY_TPU` | 55 °C | 4 h |
| `DRY_PA` | 70 °C | 8 h |

---

## Reverting

**Option 4 — Revert to Backup** uninstalls everything the AIO installed and restores your config from the `_FIRST_STOCK` backup taken on the first AIO run. This always gets you back to factory stock, including re-enabling the stock Makerbase UI.

After reverting, Klipper will restart. Check the touchscreen or the web UI to confirm it comes back up cleanly.

---

## Troubleshooting

**Klipper won't start after install:**

```bash
journalctl -u klipper -n 50 --no-pager
```

Look for `Option '...' is not valid in section '...'` or `Unable to open config file` errors. Run option **8 — Health Check** from the AIO menu; it will detect and offer to fix the most common causes.

**Stock screen not coming back after Revert to Backup:**

```bash
journalctl -u makerbase-client -n 50 --no-pager
journalctl -u lightdm -n 50 --no-pager
```

Option 8 (Health Check) also runs automatically at the end of every revert and prints recent display service logs if the stock UI does not come back.

**I accidentally broke my config:**

Run the AIO and choose **Revert to Backup**. The `_FIRST_STOCK` snapshot contains your original factory config.

**`Cannot reach raw.githubusercontent.com`:**

No internet from the printer. Check network settings or DNS. The AIO requires outbound HTTPS to GitHub.

**No stock backup exists:**

`~/mudstockbackups/` is created automatically on the first AIO run. If your configs were already changed before the first AIO run, restore from a Qidi factory image first, then run AIO to capture a clean baseline.
