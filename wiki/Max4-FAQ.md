# Max 4 FAQ

---

## Fan Assignments

| `M106 P<n>` | Fan | Notes |
|---|---|---|
| `P0` | Part cooling fan | Main layer cooling |
| `P2` | Aux / side cooling | Secondary cooling |
| `P3` | Chamber exhaust | Runs post-print cooldown via `MAX4_END_FAN_COOLDOWN` |
| `P4` | Polar cooler | High-power auxiliary cooling |

**Direct G-code commands:**

```gcode
M106 P3 S255        ; chamber exhaust full speed
M106 P4 S128        ; polar cooler half speed

; Using SET_PIN (alternative):
SET_PIN PIN=Polar_cooler VALUE=1   ; polar cooler on
SET_PIN PIN=Polar_cooler VALUE=0   ; polar cooler off

; Using SET_FAN_SPEED:
SET_FAN_SPEED FAN=chamber_exhaust_fan SPEED=1.0
```

The polar cooler is also auto-activated by `MAX4_M1004` at print start if `enable_polar_cooler` is set in `saved_variables.cfg`.

---

## NeoPixel / Bed RGB Control

The touchscreen controls the NeoPixels by default. To take manual control:

1. Disable automatic touchscreen control first:
   ```gcode
   NEOPIXEL_ENABLE ENABLE=0
   ```
2. Set colour or mode:
   ```gcode
   NEOPIXEL_MODE MODE=solid
   SET_LED LED=bed_light RED=1.0 GREEN=0.5 BLUE=0.0
   ```
3. Re-enable touchscreen control when done:
   ```gcode
   NEOPIXEL_ENABLE ENABLE=1
   ```

If you skip step 1, the touchscreen will immediately override your colour.

---

## Z Offset

**Setting during a print:** Use the touchscreen Z offset dial during the first layer. The value is stored live in `saved_variables.cfg` as `z_offset`.

**Critical:** After adjusting the Z offset on the touchscreen, always do **Save Config + Restart** from the Fluidd/Mainsail interface (or send `SAVE_CONFIG`) before power-cycling. The offset is not written to `printer.cfg` until you save — a power cut before saving loses it.

---

## Polar Cooler

The polar cooler (P4 fan) provides targeted high-velocity airflow at the nozzle tip.

```gcode
M106 P4 S255              ; full speed
M106 P4 S0                ; off
SET_PIN PIN=Polar_cooler VALUE=1   ; on (alternative)
SET_PIN PIN=Polar_cooler VALUE=0   ; off
```

It is auto-activated at print start if `saved_variables.cfg` has `enable_polar_cooler` set to a non-zero value (the value is used as the fan speed, 0–255).

---

## Qidi Box Drying

Do not use the box drying function while a print is in progress. The drying function rotates the spool motors to prevent flat spots — this rotation occurs even with filament loaded into the hotend path and will cause a print failure or jam.

Run drying only when no print is active and the hotend is at standby temperature.

---

## KAMP Symlink

The `KAMP` directory inside `config/` is a symlink:

```
config/KAMP → /home/qidi/Klipper-Adaptive-Meshing-Purging/Configuration
```

This is how the stock firmware ships it. It survives firmware updates because the updater replaces files but does not resolve or remove symlinks. Do not convert it to a real directory or copy files into it.

---

## Bed Mesh in Fluidd

The bed mesh is not visible in Fluidd by default. To enable:

1. Open Fluidd → Settings (gear icon)
2. Find **Mesh Display** or **Full Display**
3. Toggle **Full Display** on

The mesh will appear in the Dashboard view after the next `BED_MESH_CALIBRATE` run.

---

## algo_app — AI Detection Service

`algo_app.service` is Qidi's AI/video detection service. It ships with plaintext credentials exposed on LAN port 9010. See [Max 4 System Optimizations](Max4-System-Optimizations.md) for how to disable it and what stops working.

---

## `saved_variables.cfg` missing

This file is created by the stock firmware on first boot. If it is missing, the AIO will warn you when you try to use Just Faster Box (since it reads `box_count` from this file).

Create it manually:

```ini
[Variables]
box_count = 4
enable_box = 0
z_offset = 0.0
```

Save it to `/home/qidi/printer_data/config/saved_variables.cfg`.

---

## `box_count` not readable

Same cause as above — `saved_variables.cfg` is missing or malformed. Create it using the template above.

---

## Checking Klipper Logs

SSH into the printer and run:

```bash
journalctl -u klipper -n 50 --no-pager
```

Or tail live:

```bash
journalctl -u klipper -f
```

Config errors appear here on startup. If Klipper won't start after AIO install, this is the first place to look.
