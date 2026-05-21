# Session Handoff - Qidi Q2 automated insatllers

## Project - Frozen (do not edit this section)
- Repo: https://github.com/Camden-Winder/Qidi-Q2-superuser
- Test branch: https://github.com/Camden-Winder/Qidi-Q2-superuser/tree/testing

This project is an automated insatller of different configurations for the Qidi Q2

What each preset is designed for
- Whole 9 yards: Automates the install of both bunny box, helixscreen, and supporting changes needed to go along with it (ie config changes, mainsail)
- Just Faster: For users without a qidi box who wish to retain stock box and screen firmware, strictly configuration changes
- Just Faster Box: For users with the qidi box who wish to retain stock box and screen firmware, strictly configuration changes

## Current state (end of last section, beginning of writable section)

### Branch: `claude/mainsail-install-script-D3d1z`

**New file: `Install-Script/install-mainsail.sh`**
- Standalone Mainsail installer; maps to port 100 (avoids stock Qidi lighttpd on 80)
- Detects existing Mainsail install and exits early with the running URL
- Clean terminal output: only prints start line, final URL, and errors
- Debian 10 compatible: `DEBIAN_FRONTEND=noninteractive`, `unzip -t` for ZIP validation, tolerates broken bullseye-backports mirror
- Designed to be called by the AIO installer later

**Bug fix + wizard skip: `Install-Script/BunnyBox&HelixScreen.sh` — Python settings.json merge**
- `printer` (singular) reverted back to `printers.default` — live Q2 settings.json confirmed plural path is correct; the earlier "fix" to singular was wrong
- `s["display"].update()` → `s.setdefault("display", {}).update()` — prevents KeyError on fresh installs
- `s["motion"] = {}` → merge pattern — preserves other motion settings
- Added `wizard_completed: true` at top level and under `printers.default` — skips the first-boot wizard that was clobbering our `panel_widgets` layout
- Added dynamic Moonraker IP detection via Python socket (connect to 8.8.8.8:80, read local address — no data sent) — each machine gets its own LAN IP, never hardcoded
- Added full Q2 hardware config to replace what the wizard would have set: `heaters`, `temp_sensors`, `hardware.expected`, `filament_sensors`, `printer_name`, `moonraker_port`

**Live Q2 settings.json findings (2026-05-21)**
- `printers.default` is the correct path (confirmed)
- `fans`, `default_macros`, `leds` survived the wizard correctly
- `panel_widgets` was clobbered by the wizard with its own default layout
- `display` was missing `time_format` and `timezone` (wizard didn't set them, our script ran before the wizard)
- Wizard set: `moonraker_host: 192.168.254.210`, `input.calibration` (touch matrix), `heaters`, `temp_sensors`, `filament_sensors`, `hardware.expected`, `printer_name: Q2`, `language: en`, `telemetry_enabled: false`

**HelixScreen service logs — all entries were noise (2026-05-21)**
- `server.files.metascan` timeouts — slow startup scan, not a problem
- `Klipper disconnected` — expected during testing reboots
- `Cannot write to backlight/brightness` — permission issue unrelated to our work
- `SpoolmanManager` failures — Spoolman lost connection during testing
- LVGL warnings about missing callbacks — HelixScreen version compatibility, not our issue
- `PrinterPrintState safety reset` — Klipper disconnect during testing

**Touch calibration** — can be triggered post-install without the wizard:
https://helixscreen.org/guide/touch-calibration/

**First-time setup reference:**
https://helixscreen.org/guide/getting-started/#first-time-setup
