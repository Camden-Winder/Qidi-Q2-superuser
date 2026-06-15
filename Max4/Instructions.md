# Qidi Max 4 — AIO Installer Guide

This guide covers installing the Max 4 AIO (`aio_menu_max4.sh`) on a stock Qidi Max 4.

---

## What the AIO Does

The AIO installer for the Max 4 offers two install paths:

| Path | Who it's for |
|---|---|
| **Just Faster Printer** | Stock experience with faster/cleaner macros. No Qidi Box. |
| **Just Faster Box** | Same as above plus box-aware filament prep. Requires a Qidi Box attached. |

Neither path installs Happy Hare or HelixScreen — those are Q2-only. The Max 4 uses its stock touchscreen UI throughout.

The AIO also offers **System Optimizations** (DNS fix, APT sources, service hardening, static GIFs) as an optional step.

---

## AIO Menu Preview

```
============================================
   Qidi Max 4 Superuser - AIO Setup Menu (Max4-RC1.01)
============================================
  JFP: not found | JFB: not found | SysOpts: not applied
--------------------------------------------
  INSTALL
   1) Install Just Faster Printer       (Max 4, no Qidi Box)
   2) Install Just Faster Box           (Max 4 with Qidi Box)
   3) System Optimizations              (DNS, APT, services, GIFs)
  UNINSTALL
   4) Revert to Backup                  (full uninstall + restore stock)
  INFO
   5) About
   6) Run all verifiers
   0) Exit
============================================
Enter selection:
```

---

## Requirements

- Qidi Max 4 running stock firmware `01.01.06.03` or `01.01.06.04`
- SSH access to the printer (user: `qidi`, default password: `qiditech`)
- Printer connected to your network

---

## Step 1 — SSH into the Printer

From your computer:

```bash
ssh qidi@<printer-ip>
```

Default password: `qiditech`

To find the IP: check your router's DHCP table, or look in the printer touchscreen under **Settings → Network**.

---

## Step 2 — Download and Run the Installer

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/All_in_One_Installer/aio_menu_max4.sh)
```

The installer will run a disclaimer screen and then show the main menu.

> **Note:** Do not run as root (`sudo bash ...`). The script elevates with `sudo` only where needed and enforces this.

---

## Step 3 — Choose an Install Path

### Option 1 — Just Faster Printer (no Qidi Box)

Choose this if you do not have a Qidi Box or do not want box-aware filament prep.

What it does:
- Backs up your current `config/` to `~/mudstockbackups/`
- Fetches the optimised macro file and writes it to `config/gcode_macro.cfg`
- Patches `printer.cfg` to include `gcode_macro.cfg` and applies speed optimisations (homing, bed mesh, Z tilt speeds)
- Comments out the stock `[homing_override]` and `[gcode_macro _km_apply_print_offset]` (replaced by our macros)
- Patches `timelapse.cfg` to silence verbose timelapse output
- Patches `virtual_sdcard on_error_gcode` to call `MAX4_CANCEL_PRINT_ON_ERROR`
- Runs `verify_just_faster_printer()` post-install

### Option 2 — Just Faster Box (with Qidi Box)

Choose this if you have a Qidi Box attached.

Does everything Option 1 does, plus:
- Reads `box_count` from `saved_variables.cfg`; if `box_count > 0` and `enable_box` is currently `0`, sets `enable_box = 1`
- The macro's box branches will now fire at runtime (extrusion flush, box heater control, filament reuse between prints)

### Option 3 — System Optimizations

A sub-menu that lets you apply each optimization individually:

1. **DNS Fix** — switches `/etc/resolv.conf` from the hardcoded Chinese DNS (`114.114.114.114`) to Cloudflare/Google with proper DHCP integration
2. **APT Sources Fix** — switches from USTC China mirrors to standard `deb.debian.org` mirrors
3. **Disable xl2tpd** — removes the unused L2TP VPN daemon (attack surface, no purpose on a printer)
4. **Disable algo_app** — removes the AI detection service (frees 13–15% CPU, closes LAN port 9010)
5. **Static qidiclient GIFs** — replaces animated UI spinners with single-frame GIFs (drops touchscreen CPU usage from ~55% to ~3%)

Each item is individually confirmed before running. All can be undone via **Revert to Backup**.

---

## Slicer Setup

Update your slicer's `PRINT_START` macro to call the AIO entry points:

```gcode
PRINT_START EXTRUDER={first_layer_temperature} BED={first_layer_bed_temperature}
```

Or, if you want to use the full optimised sequence:

```gcode
MAX4_PRINT_START_HOME
MAX4_START_PRINT_FILAMENT_PREP EXTRUDER=0 FIRSTLAYERTEMP={first_layer_temperature} PURGETEMP={temperature} BEDTEMP={first_layer_bed_temperature}
```

The stock `print_start` macro in `klipper-macros-qd/start_end.cfg` is unchanged — the AIO adds to it rather than replacing it wholesale.

---

## Reverting

**Option 4 — Revert to Backup** uninstalls everything the AIO installed and restores your config from the `_FIRST_STOCK` backup taken on the first AIO run. This always gets you back to factory stock.

After reverting, Klipper will restart automatically. Check the touchscreen or Fluidd to confirm it comes back up cleanly.

---

## Troubleshooting

**Klipper won't start after install:**

```bash
journalctl -u klipper -n 50 --no-pager
```

Look for `Option '...' is not valid in section '...'` or `Unable to open config file` errors. Run option **6 — Run All Verifiers** from the AIO menu; it will detect and offer to fix common problems.

**Touchscreen shows an error:**

The touchscreen UI (`qidi-client`) reads from Moonraker. If Klipper is down, the touchscreen will show a connection error. Fix Klipper first.

**I accidentally broke my config:**

Run the AIO and choose **Revert to Backup**. The `_FIRST_STOCK` snapshot contains your original factory config.

**The AIO says `box_count` is not readable:**

This means `saved_variables.cfg` does not exist or does not contain a `box_count` entry. This file is created by the stock firmware on first boot. If it is missing, restore it from a factory backup or create it manually:

```ini
[Variables]
box_count = 4
enable_box = 0
z_offset = 0.0
```

Save it to `/home/qidi/printer_data/config/saved_variables.cfg`.
