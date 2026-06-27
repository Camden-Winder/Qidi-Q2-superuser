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

Paths vary by firmware layout. The AIO detects the layout at startup and sets
`AIO_HOME` accordingly.

| Purpose | legacy_mks (`/home/mks`) | q2_112 (`/home/qidi`) |
|---------|--------------------------|----------------------|
| Klipper config root | `/home/mks/printer_data/config/` | `/home/qidi/printer_data/config/` |
| AIO backup snapshots | `/home/mks/mudstockbackups/` | `/home/qidi/mudstockbackups/` |
| AIO config snapshot | `/home/mks/aio_config_backup/` | `/home/qidi/aio_config_backup/` |
| HelixScreen install dir | `/home/mks/helixscreen/` | `/home/qidi/helixscreen/` |
| Happy Hare MMU firmware | `/home/mks/Happy-Hare/` | `/home/qidi/Happy-Hare/` |
| HelixScreen config (canonical) | `~/helixscreen/config/settings.json` | `~/helixscreen/config/settings.json` |
| HelixScreen config (symlink target) | `~/printer_data/config/helixscreen/settings.json` | `~/printer_data/config/helixscreen/settings.json` |
| HelixScreen rolling backup | `/var/lib/helixscreen/settings.json.backup` (root-owned) | `/var/lib/helixscreen/settings.json.backup` (root-owned) |
| HelixScreen user backup | `~/.helixscreen/` (created lazily) | `~/.helixscreen/` (created lazily) |
| SSH login user | `mks` (password: `makerbase`) | `mks` (password: `makerbase`) |
| Printer OS user | `mks` | `qidi` |
| `printer.cfg` permissions | `664` (group-writable) | `644` — no group write bit; requires `sudo tee` for patching |

**q2_112 write permissions:** On 01.01.02+ firmware, `mks` does not own
`/home/qidi`. All write operations that touch `AIO_HOME`-derived paths must use
the `cmd 2>/dev/null || sudo cmd` fallback pattern so that `mks` can escalate
via `sudo` (password: `makerbase`) when needed.

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
