# Session Handoff — Qidi Q2 Superuser AIO

## RC2.40 — HelixScreen Homescreen Preset Fix (current branch: `claude/beautiful-einstein-5mibrb`)

### Changes made

- **`Q2/helixscreen_preset.json` created** — new preset-formatted JSON with `"preset": "qiauh_q2"`, `"wizard_completed": false`, and all hardware mappings (fans, heaters, LEDs, filament sensors, macros, `panel_widgets` home layout). Excludes deployment-specific and user-preference fields per preset spec.
- **`aio_menu.sh` updated** — `install_bunnybox_helixscreen()` now fetches `helixscreen_preset.json` instead of `helixscreen_settings.json` and writes it to `${HELIX_CONFIG_DIR}/settings.json`. Banner and ok messages updated to match.
- **`AIO_VERSION` bumped to `RC2.40`**.
- **`CLAUDE.md` updated** — RC2.40 section added.
- **`Q2/helixscreen_settings.json` retained** — kept as reference; no longer used by the installer.

### Known Issue (unfixed) — Problem B: T0–T3 / UNLOAD_T0-T3 not restored on uninstall

**Reported bug:** After reverting from BunnyBox, T0–T3 and UNLOAD_T0-T3 buttons in OrcaSlicer do nothing.

These macros live in `box1.cfg` on the printer (not in this repo). They are disabled by `fix_known_klipper_conflicts()` in `aio_menu.sh` (~lines 5021–5039) using a `## AIO_DISABLED:` prefix when BunnyBox/Happy Hare is active. `restore_aio_disabled_macros()` is supposed to reverse this on uninstall but likely has a bug.

**Do not fix in this session.** Investigate `fix_known_klipper_conflicts()` and `restore_aio_disabled_macros()` in `aio_menu.sh` in a future session.

---

## RC2.37 — PR #24 Port + Macro Audit (current branch: `claude/upbeat-brahmagupta-ymemga`)

### Changes made

- **Section 1 (docs):** Updated `Q2/Instructions.md`, `Q2/FAQ-BunnyBox&Helixscreen.md`, `All_in_One_Installer/WHAT_WAS_DONE.md`, and `CLAUDE.md` with PR #24 fix descriptions (KAMP profile, G29/G31/G32, WIPE, retraction tuning).
- **Section 2:** `M4032`, `SMART_STATUS`, `prepare_filament_dry`, `restore_factory_settings` added to both `Q2/macros/gcode_macro-JustFasterBox.cfg` and `Q2/macros/gcode_macro-JustFasterPrinter.cfg`.
- **Section 3:** `SET_PRINT_MAIN_STATUS` / `SET_PRINT_SUB_STATUS` calls restored in `M901`, `M4029`, `M603`, `M604` in both files.
- **Section 4:** `CLEAR_NOZZLE` improvements ported JFP→JFB; `EXTRUSION_AND_FLUSH` loop count fixed in JFB (range(1,6)→range(1,4)); retraction comment added in JFP; `RESUME_1` `printer.mmu.enabled` bug fixed in JFP.
- **Section 5:** JFP's commented-out `CANCEL_PRINT`/`PAUSE`/`RESUME_PRINT`/`RESUME` block replaced with live, no-box-adapted versions. `DETECT_INTERRUPTION` macro definition uncommented.
- **Section 7:** `.claude/settings.json` updated with `Edit(*)`, `Write(*)`, `MultiEdit(*)`.
- **Section 8:** Version bumped to RC2.37 in CLAUDE.md (no `AIO_VERSION` change — installer not modified).

### Known Issue (unfixed) — Problem B: T0–T3 / UNLOAD_T0-T3 not restored on uninstall

**Reported bug:** After reverting from BunnyBox, T0–T3 and UNLOAD_T0-T3 buttons in OrcaSlicer do nothing.

These macros live in `box1.cfg` on the printer (not in this repo). They are disabled by `fix_known_klipper_conflicts()` in `aio_menu.sh` (~lines 5021–5039) using a `## AIO_DISABLED:` prefix when BunnyBox/Happy Hare is active. `restore_aio_disabled_macros()` (see CLAUDE.md, also in `aio_menu.sh`) is supposed to reverse this on uninstall but likely has a bug that causes it to miss these macros.

**Do not fix in this session.** Investigate `fix_known_klipper_conflicts()` and `restore_aio_disabled_macros()` in `aio_menu.sh` in a future session.

---



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
| `Q2/KAMP_settings.cfg` | Our KAMP settings — flat in Q2/ |
| `Q2/Adaptive_Meshing.cfg` | Vendored from upstream KAMP — flat in Q2/ |
| `Q2/Line_Purge.cfg` | Vendored from upstream KAMP — flat in Q2/ |
| `Q2/Smart_Park.cfg` | Vendored from upstream KAMP — flat in Q2/ |
| `Q2/helixscreen_settings.json` | Shipped to `/home/mks/.config/helixscreen/settings.json` |
| `Q2/printer-BunnyBox.cfg` | BunnyBox printer.cfg template |
| `Q2/JustFasterPrinter.cfg` | JFP printer.cfg template |
| `Configurations/` | Stock Klipper cfg reference — do not modify |
| `Plugins/` | Stock plugin reference — do not modify |

---

