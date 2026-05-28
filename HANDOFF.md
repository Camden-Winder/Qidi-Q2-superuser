# Session Handoff — Qidi Q2 Superuser AIO

## Project

**Repo:** `Camden-Winder/Qidi-Q2-superuser`
**Dev branch:** `claude/practical-feynman-OZEHL`

The project is an all-in-one Bash installer menu for the **Qidi Q2 Pro 3D printer** running Klipper. It installs and manages:
- **BunnyBox (Happy Hare)** — MMU filament switcher firmware
- **HelixScreen** — LVGL touchscreen UI (by Preston Brown, `prestonbrown/helixscreen`)
- **Qidi Box** — 4-slot filament dry-box/AMS peripheral (RFID, slot steppers)
- **Idle Fan Shutdown** — optional addon, turns off fans/heaters after 10 min idle

---

## Current State (end of last session)

### RC2.14 — KAMP path fix complete, pushed to `claude/practical-feynman-OZEHL`

| Commit | What it does |
|--------|-------------|
| `016c96f` | RC2.14: all KAMP files now installed to `${CONFIG_DIR}/KAMP/` subdir (not config root). Both BunnyBox and JustFasterPrinter flows updated. Adaptive_Meshing.cfg and Line_Purge.cfg fetched from `REPO_BASE/KAMP/`. Smart_Park.cfg still from upstream `KAMP_BASE`. Sub-file includes in `KAMP_settings.cfg` prefixed with `KAMP/`. All four printer template cfgs normalised to `[include KAMP/KAMP_Settings.cfg]`. Uninstall changed to `rm -rf ${CONFIG_DIR}/KAMP`. `fix_printer_cfg_after_uninstall()` updated for new path form. Safety-net sed (was wrongly re-rooting the path) removed. Case-sensitivity check and `fix_known_klipper_conflicts` legacy re-fetch updated. |

**PR not yet opened** — open one targeting `main` when ready.

### Task 2 (Happier Hare release mirror) — NOT DONE, needs manual step

`HAPPIER_HARE_RELEASE_ZIP` in `aio_menu.sh` already points to the right URL. The release just doesn't exist yet. The source asset (`helixscreen-pi.zip`, 61 MB) was already downloaded to `/tmp/helixscreen-pi.zip` in the session but could not be uploaded — the execution environment has no GitHub credentials or `gh` CLI for release asset uploads.

**You need to run this manually** (authenticated as Camden-Winder):

```bash
# If /tmp/helixscreen-pi.zip doesn't still exist, re-download:
curl -L -o helixscreen-pi.zip \
  "https://github.com/ChanceVegas/Qidi-Q2-superuser_helpinghands/releases/download/happier-hare-rc2.12/helixscreen-pi.zip"

gh release create happier-hare-rc2.12 helixscreen-pi.zip \
  --repo Camden-Winder/Qidi-Q2-superuser \
  --title "Happier Hare RC2.12 HelixScreen" \
  --notes "Patched HelixScreen binary for Happier Hare MMU_HEATER protocol (mirrored from ChanceVegas/Qidi-Q2-superuser_helpinghands@happier-hare-rc2.12)" \
  --prerelease

# Verify
curl -I "https://github.com/Camden-Winder/Qidi-Q2-superuser/releases/download/happier-hare-rc2.12/helixscreen-pi.zip"
# Expect: HTTP 302 or 200
```

No changes to `aio_menu.sh` are needed — the URL already points to the right place.

---

## Established Conventions (follow these)

- **Commit messages:** one-line subjects only, no body
- **Shell changes:** always `bash -n aio_menu.sh` before committing
- **JSON changes:** always `python3 -m json.tool <file>` before committing
- **Version bump:** increment `AIO_VERSION` minor (e.g. RC2.14 → RC2.15) on every script change
- **New `install_*` function:** must have matching `uninstall_*`, a `*_installed()` / `*_enabled()` detection helper, be wired into `revert_to_backup`, and add a status indicator to `show_status_line()`
- **Helpers:** use `banner`, `info`, `warn`, `ok`, `err` — never raw `echo`
- **Write files:** use `sudo tee` pattern, never `echo >` with sudo
- **Never touch:** `Configurations/` and `Plugins/` are stock Qidi reference files — read-only mirrors
- **Dev branch:** all work goes to a `claude/*` branch, never push to `main` directly

---

## Key Files

| Path | Purpose |
|------|---------|
| `All_in_One_Installer/aio_menu.sh` | Main installer script — current version RC2.14 |
| `Install-Script/KAMP/KAMP_settings.cfg` | Our KAMP settings (includes now use `KAMP/` prefix) |
| `Install-Script/KAMP/Adaptive_Meshing.cfg` | Fetched by both BunnyBox and JFP installs from REPO_BASE |
| `Install-Script/KAMP/Line_Purge.cfg` | Fetched by both BunnyBox and JFP installs from REPO_BASE |
| `Install-Script/helixscreen_settings.json` | Shipped to `/home/mks/.config/helixscreen/settings.json` |
| `Install-Script/printer(BunnyBox&HelixScreen).cfg` | BunnyBox printer.cfg template |
| `Install-Script/printer-BunnyBox&HelixScreen.cfg` | Second BunnyBox printer.cfg template |
| `Install-Script/JustFasterPrinter.cfg` | JFP printer.cfg template |
| `Configurations/` | Stock Klipper cfg reference — do not modify |
| `Plugins/` | Stock plugin reference — do not modify |

---

