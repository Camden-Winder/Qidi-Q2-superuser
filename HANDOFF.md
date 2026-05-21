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

**Bug fix: `Install-Script/BunnyBox&HelixScreen.sh` — Python settings.json merge**
- `printers.default` → `printer` (singular) — critical path fix; all fan/macro/layout values were being written to a key HelixScreen never reads
- `s["display"].update()` → `s.setdefault("display", {}).update()` — prevents KeyError on fresh installs
- `s["motion"] = {}` → merge pattern — preserves other motion settings instead of wiping them

**Next steps**
- Verify HelixScreen `printer.*` paths on a live Q2 settings.json after the merge fix
