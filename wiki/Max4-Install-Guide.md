# Max 4 Install Guide

This guide covers installing the AIO on a stock Qidi Max 4.

---

## Section 1 — Before You Install

**Requirements:**

- Qidi Max 4 running firmware `01.01.06.03` or `01.01.06.04`
- SSH access to the printer — see [SSH Guide](SSH-Guide.md) if you haven't set this up yet
  - User: `qidi`, default password: `qiditech`
- Printer connected to your network with outbound HTTPS access to GitHub

**Note:** The Max 4 does not support BunnyBox or HelixScreen — those are Q2-only. The Max 4 uses its stock touchscreen UI throughout.

---

## Section 2 — Which option do I pick?

**Do you have a Qidi Box attached?**

- **No** → Option 1: Just Faster Printer
  - Installs faster, cleaner macros. Keeps the stock touchscreen UI. No multi-material support.

- **Yes** → Option 2: Just Faster Box
  - Same as Just Faster Printer plus box-aware filament prep macros. The stock touchscreen UI stays. The Qidi Box AMS backend remains in control.

---

## Section 3 — Running the Installer

SSH into the printer first:

```bash
ssh qidi@<printer-ip>
```

Default password: `qiditech`

To find the IP: check your router's DHCP table, or look in the printer touchscreen under **Settings → Network**.

Then run the installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/Max4/aio_menu_max4.sh)
```

Do not run as root (`sudo bash ...`). The script elevates with `sudo` only where needed and enforces this.

The installer will show the main menu:

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

## Section 4 — Slicer Setup

After installing, update your slicer's `PRINT_START` macro to call the AIO entry points. This step is easy to miss — the installer does not update your slicer for you.

Basic form:

```gcode
PRINT_START EXTRUDER={first_layer_temperature} BED={first_layer_bed_temperature}
```

Or the full optimised sequence:

```gcode
MAX4_PRINT_START_HOME
MAX4_START_PRINT_FILAMENT_PREP EXTRUDER=0 FIRSTLAYERTEMP={first_layer_temperature} PURGETEMP={temperature} BEDTEMP={first_layer_bed_temperature}
```

In Orca Slicer, paste the above into the **Machine start G-code** field for your printer profile.

---

## Section 5 — System Optimizations

The AIO also includes optional system-level improvements under option 3. These are independent of the install path and can be applied any time.

See [Max 4 System Optimizations](Max4-System-Optimizations.md) for what each one does.

---

## Section 6 — Reverting

**Option 4 — Revert to Backup** uninstalls everything the AIO installed and restores your config from the `_FIRST_STOCK` backup taken on the very first AIO run. This gets you back to factory stock.

After reverting, Klipper will restart automatically. Check the touchscreen or Fluidd to confirm it comes back up cleanly.
