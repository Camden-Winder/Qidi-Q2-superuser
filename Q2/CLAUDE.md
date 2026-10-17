# Q2/CLAUDE.md

Scope: Q2 hardware files — installer, config templates, macros, and KAMP files.

## Installer

`Q2/aio_menu.sh` — Q2 AIO installer. All Q2 logic lives here.

Quick-start test commands (run before every commit that touches aio_menu.sh):

```bash
bash -n Q2/aio_menu.sh                              # syntax check
python3 -m json.tool Q2/helixscreen_settings.json   # JSON lint
shellcheck -S warning Q2/aio_menu.sh                # style (advisory)
```

## Key Paths on the Printer (Q2)

Paths vary by firmware layout. The AIO detects the layout at startup and sets
`AIO_HOME` accordingly. The per-layout path table (`legacy_mks` `/home/mks` vs
`q2_112` `/home/qidi`) and the q2_112 `sudo` write-fallback rule are in
`memory.md` → Printer-side facts (local file, not committed).

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
| `install-mainsail.sh` | Standalone Mainsail installer fetched and executed by `install_mainsail()` at runtime. **Hardcodes `/home/mks`** (lines 41, 43, 133) — will not work on the `q2_112` layout without an `AIO_HOME` pass. |
| `helixscreen_settings.json` | Reference copy of HelixScreen settings — not used by installer |
| `helixscreen_preset.json` | Reference preset — not used by installer (kept for reference only) |
| `filament configs.txt` | Qidi Box filament profile reference (`[fila1]`…) — reference only, not read by the installer; moved here from `Configurations/` in Wiki-RC1.0 |
| `macros/` | gcode_macro + `printer.cfg` templates shipped to the printer |
| `KAMP/` | Vendored KAMP config files |
| `mmu/` | Happy Hare / BunnyBox Klipper configs. Contains two layouts: flat `mmu/*.cfg` (Happy Hare v2-style) and nested `mmu/mmu/{base,addons,optional}/` (v3-style). `find_mmu_params()` probes for both on the printer. Not fetched by `aio_menu.sh`. |
| `Printer Presets/` | OrcaSlicer printer profiles |
