# Qidi Max 4 — FAQ & Reference

Quick-reference for common Max 4 topics. For install steps see `Instructions.md`.

---

## Fan Assignments

| `M106 P<n>` | Fan | Notes |
|---|---|---|
| `P0` | Part cooling fan | Main layer cooling |
| `P2` | Aux / side cooling | Secondary cooling |
| `P3` | Chamber exhaust | Runs post-print cooldown via `MAX4_END_FAN_COOLDOWN` |
| `P4` | Polar cooler | High-power auxiliary cooling |

**Direct gcode commands:**

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

If you skip step 1 the touchscreen will immediately override your colour.

---

## Z Offset

**Setting during a print:**
Use the touchscreen Z offset dial during the first layer. The value is stored live in `saved_variables.cfg` as `z_offset`.

**Requirement:** `saved_variables.cfg` must exist at `config/saved_variables.cfg` and must be referenced in `printer.cfg` via `[save_variables]`. Stock firmware ships this correctly.

**Critical:** After adjusting the Z offset on the touchscreen, always do **Save Config + Restart** from the Fluidd/Mainsail interface (or send `SAVE_CONFIG`) before power-cycling. The offset is not written to `printer.cfg` until you save — a power cut before saving loses it.

The `_km_apply_print_offset` macro (replaced by this AIO) reads `z_offset` from `saved_variables.cfg` and applies it at print start via `SET_GCODE_OFFSET`.

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

**Do not use the box drying function while a print is in progress.** The drying function rotates the spool motors to prevent flat spots — this rotation occurs even with filament loaded into the hotend path and will cause a print failure or jam.

Run drying only when no print is active and the hotend is at standby temperature.

---

## KAMP Symlink

The `KAMP` directory inside `config/` is a symlink:

```
config/KAMP → /home/qidi/Klipper-Adaptive-Meshing-Purging/Configuration
```

This is how the stock firmware ships it. Because it is a symlink and not a real directory, it **survives firmware updates** — the firmware updater replaces files but does not resolve or remove symlinks. Do not convert it to a real directory or copy files into it; the symlink is intentional.

The `BED_MESH_CALIBRATE PROFILE=kamp` call in the AIO macros relies on KAMP being active via this symlink.

---

## Bed Mesh in Fluidd

The bed mesh is not visible in Fluidd by default. To enable:

1. Open Fluidd → Settings (gear icon)
2. Find **Mesh Display** or **Full Display**
3. Toggle **Full Display** on

The mesh will then appear in the Dashboard view after the next `BED_MESH_CALIBRATE` run.

---

## algo_app — AI Detection Service

`algo_app.service` is Qidi's AI/video detection service. It ships with the following **plaintext credentials** in its config:

- **Username:** `qidi`
- **Password:** `qiditech`
- **LAN API port:** `9010`

The API is exposed to your local network with no authentication beyond these credentials. If you are not using the detection features, disable it via the AIO installer's **System Optimizations → Disable algo_app** option. This removes 13–15% idle CPU usage and closes the LAN-exposed endpoint.

After disabling, the AI detection features in the touchscreen UI stop working. Re-enable via System Optimizations if needed.

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
