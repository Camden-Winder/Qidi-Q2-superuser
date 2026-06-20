# Q2/CLAUDE.md

Scope: Q2 hardware files — installer, config templates, macros, and KAMP files.

## Installer

`Q2/aio_menu.sh` — Q2 AIO installer. All Q2 logic lives here.
**Never modify `Max4/aio_menu_max4.sh` when working on Q2 tasks.**

Quick-start test commands (run before every commit that touches aio_menu.sh):

```bash
bash -n Q2/aio_menu.sh                              # syntax check
python3 -m json.tool Q2/helixscreen_settings.json   # JSON lint
shellcheck -S warning Q2/aio_menu.sh                # style (advisory)
```

## Key Paths on the Printer (Q2)

| Purpose | Path |
|---------|------|
| Klipper config root | `/home/mks/printer_data/config/` |
| AIO backup snapshots | `/home/mks/mudstockbackups/` |
| HelixScreen install dir | `/home/mks/helixscreen/` |
| Happy Hare MMU firmware | `/home/mks/Happy-Hare/` |
| HelixScreen config (canonical) | `~/helixscreen/config/settings.json` |
| HelixScreen config (symlink target) | `~/printer_data/config/helixscreen/settings.json` |
| HelixScreen rolling backup | `/var/lib/helixscreen/settings.json.backup` (root-owned) |
| HelixScreen user backup | `~/.helixscreen/` (created lazily — may not exist) |

## Critical: settings.json Symlink

`~/helixscreen/config/settings.json` is a symlink to
`~/printer_data/config/helixscreen/settings.json`.

**Use `open(path, 'w')` for in-place writes — never `os.replace()`.** `os.replace()`
replaces the symlink itself rather than the file it points to. See LESSONS.md [L001].

When patching settings.json, patch all three locations:
1. Canonical (`${HELIX_CONFIG_DIR}/settings.json`) — always present
2. Rolling backup (`/var/lib/helixscreen/settings.json.backup`) — always present after first run
3. User backup (`~/.helixscreen/`) — gate write on `os.path.isdir(backup2_dir)`

## Config Files in This Directory

| File | Purpose |
|------|---------|
| `aio_menu.sh` | Q2 AIO installer — edit this for all Q2 install logic |
| `helixscreen_settings.json` | Reference copy of HelixScreen settings — not used by installer |
| `helixscreen_preset.json` | Reference preset — not used by installer (kept for reference only) |
| `macros/` | gcode_macro cfg templates shipped to the printer |
| `KAMP/` | Vendored KAMP config files |
| `mmu/` | Happy Hare / BunnyBox Klipper config files |
| `Printer Presets/` | OrcaSlicer printer profiles |
