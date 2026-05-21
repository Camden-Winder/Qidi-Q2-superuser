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
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/testing/Install-Script/gcode_macro-BunnyBox%26HelixScreen.cfg \
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
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/testing/Install-Script/printer-BunnyBox%26HelixScreen.cfg \
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
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/testing/Install-Script/KAMP_settings.cfg \
  -o /home/mks/printer_data/config/KAMP/KAMP_Settings.cfg
echo "KAMP settings applied."
echo ""

echo "Applying HelixScreen layout..."
# The HelixScreen setup wizard runs on first boot and overwrites layout fields.
# To prevent that, we pre-populate every field the wizard would set and mark
# wizard_completed=true so it is skipped entirely. This gives a hands-off install
# where the user lands directly in the configured HelixScreen UI.
#
# The Moonraker host IP is detected at install time via Python socket so it is
# always correct for the machine running this script — never hardcoded.
#
# Fields we set (all Q2-specific constants or dynamically detected):
#   wizard_completed     — true at top level and printers.default to skip wizard
#   active_printer_id    — "default"
#   language / telemetry — sensible defaults (en / disabled)
#   moonraker_host/port  — detected from primary LAN interface / 7125
#   printer_name         — "Q2"
#   heaters/temp_sensors — Q2 Klipper object names
#   hardware.expected    — 12-item list for Q2 BunnyBox build
#   filament_sensors     — 8 MMU + runout sensors present on Q2 BunnyBox
#   panel_widgets.home   — custom home screen widget layout
#   dark_mode/theme      — Ayu dark theme, color preset 0
#   display.*            — brightness, sleep, time format
#   motion.jog_mode      — jog preference
#   fans                 — Q2 fan mappings
#   default_macros       — BunnyBox macro shortcuts
#   leds.*               — color palette and startup behaviour
#
# Fields we leave untouched (setdefault / not assigned):
#   input.calibration    — touchscreen calibration unique to each unit
#   filament             — runtime spool data
#   hardware.last_snapshot, thermal.rates, print_start_history — runtime state
#   moonraker_api_key    — user-specific
python3 << 'PYEOF'
import json, os, sys, socket

SETTINGS_PATH = "/home/mks/helixscreen/config/settings.json"

def get_local_ip():
    # Opens a UDP socket toward an external address to discover which local
    # interface the OS would use. No data is actually sent.
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# Hardware constants — correct for every Q2 BunnyBox build (confirmed from live machine).
HARDWARE_EXPECTED = [
    "heater_bed", "extruder", "fan_generic cooling_fan", "heater_fan hotend_fan",
    "output_pin caselight", "filament_switch_sensor filament_switch_sensor", "mmu",
    "heater_fan box1_heater_fan_a", "heater_fan box1_heater_fan_b",
    "controller_fan box1_board_fan", "controller_fan board_fan",
    "fan_generic auxiliary_cooling_fan"
]

FILAMENT_SENSORS = {
    "master_enabled": True,
    "sensors": [
        {"enabled": True, "klipper_name": "filament_switch_sensor mmu_pre_gate_0",          "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor mmu_pre_gate_1",          "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor mmu_pre_gate_2",          "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor mmu_pre_gate_3",          "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor mmu_gate_sensor",         "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor extruder_sensor",         "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor filament_tension_sensor", "role": "none",   "type": "switch"},
        {"enabled": True, "klipper_name": "filament_switch_sensor filament_switch_sensor",  "role": "runout", "type": "switch"},
    ]
}

# Layout and appearance values sourced from a configured Q2 BunnyBox machine.
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

# Top-level wizard skip and defaults
s["wizard_completed"]   = True
s["active_printer_id"]  = "default"
s.setdefault("language",          "en")
s.setdefault("telemetry_enabled", False)

# Top-level appearance settings
s["dark_mode"] = True
s["theme"]     = {"preset": 0}
s.setdefault("motion", {})["jog_mode"] = 1
s.setdefault("display", {}).update({
    "bed_mesh_render_mode": 0,
    "dim_brightness":       30,
    "dim_sec":              600,
    "gcode_render_mode":    0,
    "sleep_sec":            1200,
    "time_format":          1,
    "timezone":             "America/Los_Angeles"
})

# Printer-level settings — printers.default confirmed as correct path from live Q2 settings.json
p = s.setdefault("printers", {}).setdefault("default", {})

# Skip the wizard for this printer entry
p["wizard_completed"] = True

# Moonraker connection — IP detected dynamically so every machine uses its own LAN address
p.setdefault("moonraker_host", get_local_ip())
p.setdefault("moonraker_port", 7125)

# Q2 identity and hardware mappings — constant across all Q2 BunnyBox builds
p.setdefault("printer_name",      "Q2")
p.setdefault("heaters",           {"bed": "heater_bed", "hotend": "extruder"})
p.setdefault("temp_sensors",      {"bed": "heater_bed", "hotend": "extruder"})
p.setdefault("hardware",          {})["expected"] = HARDWARE_EXPECTED
p.setdefault("filament_sensors",  FILAMENT_SENSORS)

# Layout and appearance
p["panel_widgets"]  = LAYOUT["panel_widgets"]
p["fans"]           = FANS
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

echo "Installing Mainsail..."
# Fetch and run the standalone Mainsail installer. It maps Mainsail to port 100
# and detects any existing install automatically, so it is safe to call here
# whether or not the user has run this script before.
curl -sSL https://raw.githubusercontent.com/Camden-Winder/Qidi-Q2-superuser/refs/heads/testing/Install-Script/install-mainsail.sh | bash
echo ""

echo "Install complete."
