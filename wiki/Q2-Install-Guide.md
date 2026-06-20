# Q2 Install Guide

This guide covers installing the AIO on a stock Qidi Q2.

---

## Section 1 — Before You Install

**Requirements:**

- Qidi Q2 running stock Klipper firmware (legacy_mks layout)
- SSH access to the printer — see [SSH Guide](SSH-Guide.md) if you haven't set this up yet
- Printer connected to your network with outbound HTTPS access to GitHub

**Firmware layout note:** The AIO targets the `legacy_mks` firmware layout. If the AIO detects you are on `01.01.02+` firmware, it will flag this — support for that layout is available under the `F)` menu option. If you're unsure which layout you have, the installer will tell you on the status line.

---

## Section 2 — Which option do I pick?

**Do you have a Qidi Box?**

- **No** → Option 2: Just Faster Printer
  - Installs faster, cleaner macros. Keeps the stock Makerbase touchscreen UI. No multi-material support.

- **Yes, and I want the full MMU stack (Happy Hare + HelixScreen)** → Option 1: BunnyBox + HelixScreen
  - Installs Happy Hare MMU firmware (BunnyBox) and the HelixScreen LVGL touchscreen UI. The stock screen is replaced. Full multi-material printing with the Qidi Box.

- **Yes, but I want to keep the stock screen and use the box as-is** → Option 3: Just Faster Box
  - Same as Just Faster Printer but with box-aware macros active. The stock Makerbase UI stays. The Qidi Box AMS backend remains in control.

---

## Section 3 — Running the Installer

SSH into the printer first:

```bash
ssh mks@<printer-ip>
```

Default password: `makerbase`

Then run the installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/main/Q2/aio_menu.sh)
```

Do not run as root (`sudo bash ...`). The script elevates with `sudo` only where needed and enforces this.

The installer will show a disclaimer screen, then the main menu:

```
============================================
   Qidi Q2 Superuser - AIO Setup Menu (RC2.48)
============================================
  Just Faster: not found | BunnyBox: not found | Helixscreen: not found
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
   9) Testing
  FIRMWARE
   F) 01.01.02+ / qidi firmware
   0) Exit
============================================
Enter selection:
```

---

## Section 4 — After Install

### Option 1 — BunnyBox + HelixScreen

The installer backs up your config and runs the BunnyBox and HelixScreen installers. After it finishes:

1. Run `FIRMWARE_RESTART` from the HelixScreen terminal or Fluidd console
2. Run `sudo reboot` over SSH
3. From the AIO menu, run option **8 — Health Check** to verify everything loaded correctly
4. **First-time only:** calibrate the MMU gear steppers for each gate:
   1. Mark the filament at the MMU entry point with a pen
   2. Run `MMU_CALIBRATE_GEAR GATE=0 LENGTH=100` from the console
   3. Measure how far the filament actually moved (in mm)
   4. Re-run with the measured value: `MMU_CALIBRATE_GEAR GATE=0 LENGTH=100 MEASURED=<mm>`
   5. Repeat steps 1–4 for each gate (`GATE=1`, `GATE=2`, etc.)

The screen will switch to HelixScreen after the reboot. If the screen is black, re-run the installer — it will detect and fix the display service state.

### Option 2 — Just Faster Printer

The installer backs up your config and writes the optimised macro file. After it finishes:

1. Run `FIRMWARE_RESTART` from the Fluidd console or touchscreen
2. Run a bed level and `SCREWS_TILT_CALCULATE` before your first print

The stock Makerbase touchscreen UI is unchanged.

### Option 3 — Just Faster Box

Same as Option 2. After it finishes:

1. Run `FIRMWARE_RESTART`
2. Run a bed level and `SCREWS_TILT_CALCULATE` before your first print

The stock Makerbase touchscreen UI is unchanged. The Qidi Box AMS backend remains in control.

---

## Section 5 — Addons

These can be toggled at any time from the main menu, regardless of which install path you chose.

**Option 5 — Idle Fan Shutdown**

Shuts off fans and heaters after 10 minutes of idle, but only once all temperatures have dropped to safe levels. Safe to enable on any install path.

**Option 6 — Mainsail**

Installs the Mainsail web interface, accessible at `http://<printer-ip>:100`. The stock Qidi UI on port 80 is not affected. Includes a camera proxy so the webcam stream works in Mainsail.

---

## Section 6 — Reverting

**Option 4 — Revert to Backup** uninstalls everything the AIO installed and restores your config from the `_FIRST_STOCK` backup taken on the very first AIO run. This gets you back to factory stock, including re-enabling the stock Makerbase UI.

After reverting, Klipper will restart. Check the touchscreen to confirm it comes back up cleanly. The Health Check runs automatically at the end of every revert.

---

## Section 7 — Filament Drying (BunnyBox installs only)

After installing BunnyBox (option 1), drying macros are available from the HelixScreen terminal or Fluidd console. Spools rotate automatically throughout each cycle.

| Macro | Temp | Time |
|---|---|---|
| `DRY_PLA` | 45 °C | 4 h |
| `DRY_PETG` | 65 °C | 4 h |
| `DRY_ABS` | 65 °C | 4 h |
| `DRY_TPU` | 55 °C | 4 h |
| `DRY_PA` | 70 °C | 8 h |
