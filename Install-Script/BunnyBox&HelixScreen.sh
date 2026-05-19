#!/bin/bash

# bash is used explicitly (not sh) because pipefail is bash-only and not
# supported by dash, which is the Q2's /bin/sh. bash is available on the Q2.

# Exit immediately if any command fails. This prevents the script from
# continuing and overwriting config files if a download or install step errors.
set -e
# pipefail makes the script treat a failure anywhere in a pipe as fatal.
# Without this, `wget ... | bash` would succeed even if wget failed silently,
# and the script would continue as if the install completed successfully.
set -o pipefail

echo "Backing up current configs..."
# Create backup folder if missing. -p avoids errors if it already exists.
mkdir -p /home/mks/mudstockbackups

# rsync -a preserves structure, permissions, timestamps, and handles nested folders.
rsync -a /home/mks/printer_data/config/ /home/mks/mudstockbackups/
echo "Backup complete."
echo ""

echo "Installing Bunny Box..."
echo ">>> NOTE: The BunnyBox installer is interactive. You will be prompted to:"
echo ">>>   - Confirm you want to install"
echo ">>>   - Confirm or enter your serial port for the Bunny Box"
echo ">>>   - Choose whether to install the AHT10 environment sensor module"
echo ">>> Watch the output and respond to each prompt to continue."
echo ""
# wget -qO - downloads quietly and pipes directly into bash.
# pipefail ensures wget failures are caught even when piped.
wget -qO - https://raw.githubusercontent.com/Camden-Winder/Bunny-Box/refs/heads/main/Q2/install-bb-q2.sh | bash
echo "Bunny Box installed."
echo ""

echo "Installing HelixScreen..."
# curl -sSL:
#   -s  silent (no progress meter)
#   -S  show errors even when silent
#   -L  follow redirects (required for GitHub raw URLs)
curl -sSL https://raw.githubusercontent.com/prestonbrown/helixscreen/main/scripts/install.sh | bash
echo "HelixScreen installed."
echo ""

echo "Updating gcode_macro.cfg..."
# BunnyBox modifies gcode_macro.cfg during its install. We overwrite it here
# with our combined BunnyBox + HelixScreen version, which is the intended final state.
# If BunnyBox's required macro structure ever changes, this file must be updated too.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/gcode_macro-BunnyBox&HelixScreen.cfg
# Destination:   /home/mks/printer_data/config/gcode_macro.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/gcode_macro-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/gcode_macro.cfg
echo "gcode_macro.cfg updated."
echo ""

echo "Updating printer.cfg..."
# BunnyBox modifies printer.cfg during its install. We overwrite it here with our
# unified version that includes all required BunnyBox, HelixScreen, and KAMP includes.
# printer.cfg also expects timelapse.cfg, plr.cfg, and MCU_ID.cfg to already exist
# on the machine from stock firmware — these are not installed by this script.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/printer-BunnyBox&HelixScreen.cfg
# Destination:   /home/mks/printer_data/config/printer.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/printer-BunnyBox%26HelixScreen.cfg \
  -o /home/mks/printer_data/config/printer.cfg
echo "printer.cfg updated."
echo ""

echo "Applying KAMP settings..."
# Creates the KAMP subdirectory if it doesn't exist, matching the path that
# printer.cfg expects: [include ./KAMP/KAMP_Settings.cfg]
mkdir -p /home/mks/printer_data/config/KAMP
# Filename uses capital S (KAMP_Settings.cfg) to match the [include] directive
# in printer.cfg exactly. Linux is case-sensitive — wrong case = file not found at boot.
# Verified live: github.com/Camden-Winder/Qidi-Q2-superuser Install-Script/KAMP_settings.cfg
# Destination:   /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/main/Install-Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
echo "KAMP settings applied."
echo ""

echo "Applying HelixScreen layout..."
# The preset system only runs during the first-launch wizard. Since HelixScreen
# sets wizard_completed=true on first run, the preset picker never appears on a
# machine that has already booted HelixScreen — even once. Dropping a file into
# assets/config/presets/ therefore does nothing on a fresh install after first boot.
#
# The correct approach is to merge our layout directly into settings.json.
# We use Python to do a targeted merge so machine-specific values (IP, touch
# calibration, Moonraker port) are preserved and only layout/appearance fields
# are overwritten.
#
# Fields we inject (safe to apply to any Q2 BunnyBox machine):
#   panel_widgets.home   — home screen widget layout (the whole point of this step)
#   dark_mode            — Ayu dark theme
#   theme.preset         — color preset 0
#   display.*            — brightness, sleep, timezone, time format
#   motion.jog_mode      — jog mode preference
#   fans                 — Q2 fan mappings (correct for all Q2s)
#   default_macros       — BunnyBox macro shortcuts
#   leds.color_presets   — color palette
#   leds.led_on_at_start — startup LED behavior
#   leds.startup_brightness
#
# Fields we leave untouched:
#   moonraker_host/port  — machine-specific IP and port
#   input.calibration    — touchscreen calibration unique to each physical unit
#   filament             — runtime spool data
#   hardware.last_snapshot, thermal.rates, print_start_history — runtime state
python3 << 'PYEOF'
import json, os, sys

SETTINGS_PATH = "/home/mks/helixscreen/config/settings.json"

# Layout and appearance values sourced from a configured Q2 BunnyBox machine.
# Only non-machine-specific fields are included here.
LAYOUT = {
  "panel_widgets": {
    "home": {
      "main_page_index": 0,
      "next_page_id": 1,
      "pages": [
        {
          "id": "main",
          "widgets": [
            {"col": 2,  "colspan": 2, "enabled": True,  "id": "printer_image",     "row": 0,  "rowspan": 2},
            {"col": 0,  "colspan": 2, "enabled": True,  "id": "print_status",      "row": 2,  "rowspan": 2},
            {"col": 2,  "colspan": 2, "enabled": False, "id": "tips",              "row": 0,  "rowspan": 2},
            {"col": 2,  "colspan": 1, "enabled": True,  "id": "temperature",       "row": 2,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "shutdown",          "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "lock",              "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "power_device",      "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "network",           "row": -1, "rowspan": 1},
            {"col": 4,  "colspan": 1, "enabled": True,  "id": "firmware_restart",  "row": 1,  "rowspan": 1},
            {"col": 4,  "colspan": 1, "enabled": True,  "id": "ams",               "row": 3,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "tool_switcher",     "row": -1, "rowspan": 1},
            {"col": 5,  "colspan": 1, "enabled": True,  "id": "led",               "row": 2,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "led_controls",      "row": -1, "rowspan": 1},
            {"col": 3,  "colspan": 1, "enabled": True,  "id": "fan_stack",         "row": 2,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "fan",               "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "nozzle_temps",      "row": -1, "rowspan": 2},
            {"col": 3,  "colspan": 1, "enabled": True,  "id": "temp_stack",        "row": 3,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "thermistor",        "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 2, "enabled": False, "id": "temp_graph",        "row": -1, "rowspan": 2},
            {"col": 0,  "colspan": 2, "enabled": True,  "id": "preheat",           "row": 1,  "rowspan": 1},
            {"col": 4,  "colspan": 1, "enabled": True,  "id": "active_spool",      "row": 2,  "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "filament",          "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "humidity",          "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "width_sensor",      "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "favorite_macro",    "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "macros",            "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 1, "enabled": False, "id": "motion",            "row": -1, "rowspan": 1},
            {"col": 0,  "colspan": 2, "enabled": True,  "id": "clock",             "row": 0,  "rowspan": 1},
            {"col": -1, "colspan": 2, "enabled": False, "id": "job_queue",         "row": -1, "rowspan": 2},
            {"col": -1, "colspan": 1, "enabled": False, "id": "clog_detection",    "row": -1, "rowspan": 1},
            {"col": -1, "colspan": 2, "enabled": False, "id": "print_stats",       "row": -1, "rowspan": 2},
            {"col": 5,  "colspan": 1, "enabled": True,  "id": "gcode_console",     "row": 1,  "rowspan": 1},
            {"col": -1, "colspan": 2, "enabled": False, "id": "camera",            "row": -1, "rowspan": 2},
            {"col": 5,  "colspan": 1, "enabled": True,  "id": "notifications",     "row": 3,  "rowspan": 1},
            {"col": 2,  "colspan": 1, "enabled": True,  "id": "bed_temperature",   "row": 3,  "rowspan": 1}
          ]
        }
      ]
    }
  }
}

FANS = {
  "chamber": "controller_fan chamber_fan",
  "exhaust":  "fan_generic chamber_circulation_fan",
  "hotend":   "heater_fan hotend_fan",
  "part":     "fan_generic cooling_fan"
}

DEFAULT_MACROS = {
  "cooldown":       "SET_HEATER_TEMPERATURE HEATER=extruder TARGET=0\nSET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=0",
  "load_filament":  {"gcode": "LOAD_FILAMENT",           "label": "Load"},
  "unload_filament":{"gcode": "UNLOAD_FILAMENT",         "label": "Unload"},
  "macro_1":        {"gcode": "HELIX_CLEAN_NOZZLE",      "label": "Clean Nozzle"},
  "macro_2":        {"gcode": "HELIX_BED_MESH_IF_NEEDED","label": "Bed Level"}
}

LED_SAFE = {
  "color_presets":      ["#FFFFFF","#FFD700","#FF6B35","#4FC3F7","#FF4444","#66BB6A","#9C27B0","#00BCD4"],
  "led_on_at_start":    False,
  "startup_brightness": 80
}

if not os.path.exists(SETTINGS_PATH):
    print(f"ERROR: {SETTINGS_PATH} not found. HelixScreen may not have installed correctly.")
    sys.exit(1)

with open(SETTINGS_PATH, "r") as f:
    s = json.load(f)

# Top-level appearance settings
s["dark_mode"] = True
s["theme"] = {"preset": 0}
s["motion"] = {"jog_mode": 1}
s["display"].update({
    "bed_mesh_render_mode": 0,
    "dim_brightness": 30,
    "dim_sec": 600,
    "gcode_render_mode": 0,
    "sleep_sec": 1200,
    "time_format": 1,
    "timezone": "America/Los_Angeles"
})

# Printer-level settings — merged into printers.default, preserving machine-specific keys
p = s.setdefault("printers", {}).setdefault("default", {})
p["panel_widgets"] = LAYOUT["panel_widgets"]
p["fans"] = FANS
p["default_macros"] = DEFAULT_MACROS
p.setdefault("leds", {}).update(LED_SAFE)

# Write back atomically: write to a temp file then rename
tmp = SETTINGS_PATH + ".tmp"
with open(tmp, "w") as f:
    json.dump(s, f, indent=2)
os.replace(tmp, SETTINGS_PATH)

print("HelixScreen layout applied successfully.")
PYEOF
echo "HelixScreen layout applied."
echo ""

echo "Install complete."
