# Session Handoff — Qidi Q2 Superuser AIO

## Known Issues (carry-forward)

None.

---

## RC2.46 — Repo cleanup & documentation pass (branch: `claude/determined-allen-46bm3f`)

### What changed

- **`box_drying.cfg` removed** — deleted from repo; `[include box_drying.cfg]` removed from `printer-BunnyBox.cfg`; box_drying install blocks, heater_vent_macro wiring, and all path-list references removed from `aio_menu.sh`. Spool rotation during drying is now handled upstream by BunnyBox/Happy Hare.
- **Config files moved to `Q2/macros/`** — `printer-BunnyBox.cfg`, `JustFasterPrinter.cfg`, and `idle_fan_shutdown.cfg` moved from `Q2/` root to `Q2/macros/`. Fetch paths in `aio_menu.sh` updated accordingly (3 call sites for JustFasterPrinter.cfg, 1 each for the others).
- **Stale G31 comment fixed** — `PRINT_END` in `gcode_macro-BunnyBox.cfg` now reads `G31 # Reset bed leveling mode to adaptive (KAMP) — see G31/G32 macro definitions`.
- **Header comments added** to 10 undocumented utility functions: `aio_state_dir`, `aio_preexisting_paths_file`, `capture_first_run_state`, `path_was_preexisting`, `should_remove_aio_path`, `ensure_repair_backup`, `cleanup_aio_runtime_artifacts`, `dry_run_path_state`, `dry_run_removal_state`, `backup_missing_active_stock_essentials`.
- **FAQ reordered** — "What is BunnyBox?" and "What is HelixScreen?" moved to the top of `Q2/FAQ-BunnyBox&Helixscreen.md`.
- **README restructured** — AIO installer is now Chapter 1 (was buried after Plugins); chapters renumbered accordingly.
- **`Thanks.md` updated** — Sykocis (Discord) / Chance Vegas (GitHub) credited as creator of the AIO groundwork.
- **`AIO_VERSION` bumped to `RC2.46`**

---

## RC2.45 — Fix backup paths in `apply_helixscreen_dashboard_layout()` (branch: `claude/optimistic-newton-c2kena`)

### What changed

- **`BACKUP1` filename corrected** — changed `local BACKUP1="/var/lib/helixscreen/settings.json"` to `local BACKUP1="/var/lib/helixscreen/settings.json.backup"`. HelixScreen writes its `/var/lib` backup as `settings.json.backup`, not `settings.json`; the old path did not exist.
- **`BACKUP2` write made conditional** — the `write_direct(BACKUP2, content)` call is now gated on `os.path.isdir(backup2_dir)`. After a clean install the `~/.helixscreen/` directory does not yet exist (HelixScreen creates it lazily on first `Config::save()`). The unconditional write raised `FileNotFoundError` and caused the entire Python block to exit non-zero, reporting `[ERR] Dashboard layout patch failed` even though the canonical file was patched correctly.
- **`AIO_VERSION` bumped to `RC2.45`**

### Root causes

1. The `/var/lib/helixscreen/` directory contains `settings.json.backup` (and `helixscreen.env.backup`), confirmed on-printer. The previous path targeted a file that never exists.
2. `~/.helixscreen/` is created lazily by HelixScreen; it is absent after a fresh install + wizard completion. The unconditional write failed immediately, masking the successful canonical patch.

---

## RC2.44 — Remove preset fetch, fix race condition with wizard prompt (branch: `claude/relaxed-albattani-04n23d`)

### What changed

- **Preset fetch removed from install flow** — the `banner "Applying HelixScreen preset"` block that fetched `helixscreen_preset.json` and wrote it as `${HELIX_CONFIG_DIR}/settings.json` has been deleted entirely from `install_bunnybox_helixscreen()`. This block overwrote HelixScreen's generated settings with a file that lacks `panel_widgets`, causing `KeyError: 'panel_widgets'` in the dashboard layout patch. `Q2/helixscreen_preset.json` is retained in the repo for reference only.
- **Race condition fixed with wizard prompt** — the 30-second polling wait loop is replaced with a user-facing prompt. After `switch_display_to_helixscreen`, the installer tells the user to walk to the printer and complete the first-run wizard, then waits for `y` confirmation before calling `apply_helixscreen_dashboard_layout`. After confirmation, a Python one-liner validates that `panel_widgets` is present in the settings before patching; if missing, it warns and directs the user to Testing > option 10.
- **`AIO_VERSION` bumped to `RC2.44`**

### Root causes

1. The preset file approach (RC2.40) was never removed after RC2.43 fixed the path issue, so it still overwrote the real HelixScreen-generated settings.json before patching could run.
2. The first-run HelixScreen wizard requires physical interaction at the printer screen — a silent timeout loop cannot detect wizard completion; only the user can confirm it.

---

## RC2.43 — Fix `apply_helixscreen_dashboard_layout()` path hardcoding + race condition (branch: `claude/focused-dirac-yb1582`)

### What changed

- **`apply_helixscreen_dashboard_layout()` path hardcoding removed** — replaced `local CANONICAL="/home/mks/printer_data/config/helixscreen/settings.json"` with `local CANONICAL="${HELIX_CONFIG_DIR}/settings.json"` and `local BACKUP2` now uses `${AIO_HOME}/.helixscreen/settings.json`. `/var/lib/helixscreen/settings.json` remains hardcoded (systemd `StateDirectory`, user-invariant).
- **Python heredoc paths de-hardcoded** — paths passed via env vars (`HELIX_SETTINGS`, `HELIX_BACKUP2`, `HELIX_BACKUP1`) and read with `os.environ` inside the heredoc. No `/home/mks/` strings remain in the Python block.
- **Race condition fixed in install flow** — added a 30-second wait loop between `switch_display_to_helixscreen` and `apply_helixscreen_dashboard_layout` in `install_bunnybox_helixscreen()`. Polls `${HELIX_CONFIG_DIR}/settings.json` every 2 seconds until it exists and is valid JSON. If not ready after 30s, logs a warning and skips the layout patch rather than failing. The wait loop is in the install flow only — Testing submenu option 10 still calls `apply_helixscreen_dashboard_layout` directly (HelixScreen already running there).

### Root causes

1. Pre-migration installs have `settings.json` at `~/helixscreen/config/settings.json` (no symlink to `printer_data`). The hardcoded `printer_data` path doesn't exist on those systems.
2. `switch_display_to_helixscreen` issues `systemctl restart` and returns immediately. HelixScreen hadn't had time to generate or migrate `settings.json` before `apply_helixscreen_dashboard_layout` checked for it.

---

## RC2.43 — HANDOFF.md restructure + process fix (branch: `claude/vibrant-mayer-hkdfgt`, PR #36)

### What changed

- **`CLAUDE.md`** — added "End-of-session requirements" rule to the Autonomous-Session Policy section. Every session that bumps `AIO_VERSION` must update `HANDOFF.md` in the same commit. Carry-forward known issues now live in a single pinned section at the top of `HANDOFF.md` instead of being copied into every per-RC entry.
- **`HANDOFF.md`** — restructured: `## Known Issues (carry-forward)` section added at top; T0–T3 known issue consolidated there and removed from all per-RC sections; RC2.43 entry added.
- **`AIO_VERSION` bumped to `RC2.43`** (version bump only, no functional installer changes).

---

## RC2.42 — HelixScreen Dashboard Layout: Final Working Implementation (branch: `claude/vibrant-mayer-hkdfgt`, PR #36)

### What was done

Three changes in one commit (PR #36):

1. **`apply_helixscreen_dashboard_layout()` fully replaced** in `aio_menu.sh`:
   - Stops HelixScreen at the top before touching any files
   - Validates canonical path (`/home/mks/printer_data/config/helixscreen/settings.json`) is present and valid JSON before proceeding
   - Python patch updates widgets **in-place** from `DESIRED_BY_ID` dict (preserves unknown widget keys HelixScreen may store)
   - Uses `open(path, 'w')` directly — never `os.replace()`, which replaces the symlink inode instead of writing through it
   - Validates for duplicate keys before and after patch (guards against nlohmann C++ parser rejecting the file)
   - Writes all three locations: canonical, `~/.helixscreen/settings.json`, `/var/lib/helixscreen/settings.json` (root-owned, written via `sudo sh -c 'cat >'`)
   - Starts HelixScreen at the end; aborts cleanly and starts HelixScreen if Python fails

2. **`apply_helixscreen_dashboard_layout()` called from `install_bunnybox_helixscreen()`** immediately after `switch_display_to_helixscreen`. The function handles its own stop/start, so the restart from `switch_display_to_helixscreen` is superseded safely.

3. **`Q2/helixscreen_preset.json` `panel_widgets` updated** to match the final desired layout: `clog_detection` enabled at row 1, `chamber_temperature` added, `ams` colspan 4, `notifications` at row 0, `led` at col 4 row 0, various other corrections from the stale RC2.40 values.

### Root causes that were discovered and fixed (from RC2.41 failures)

- `os.replace()` replaces the symlink inode — writes went to the wrong real file
- Duplicate keys in settings.json from RC2.40's corrupt write caused nlohmann C++ parser to reject the file and trigger backup restore
- `/var/lib/helixscreen/` is root-owned mode 0700; `sudo cp` didn't work; `sudo sh -c 'cat >'` does
- Patching only the canonical path while leaving rolling backups intact meant every restart restored the old layout

---

## RC2.42 — HelixScreen Dashboard Layout: Rolling Backup Patch (branch: `claude/cool-ritchie-0wkhiu`)

### Problem fixed

HelixScreen was rejecting the patched `settings.json` on restart, auto-restoring from rolling backup copies in `/var/lib/helixscreen/` and `~/.helixscreen/`, undoing the `panel_widgets` change.

### Changes made

- **`aio_menu.sh` — `apply_helixscreen_dashboard_layout()` updated:**
  - Stops helixscreen *before* patching (prevents HelixScreen writing a new backup during the patch window)
  - Adds trailing newline to `json.dump` output to exactly match HelixScreen's own write format
  - After patching `settings.json`, also patches `~/.helixscreen/settings.json` and `/var/lib/helixscreen/settings.json` so auto-restore cannot undo the layout change
  - `/var/lib/helixscreen/` is root-owned; the script detects `PermissionError` (exit 2) and retries that path via `sudo tee`
  - Uses `systemctl start` (not `restart`) after the patch since we already stopped the service
- **`AIO_VERSION` bumped to `RC2.42`**

---

## RC2.40 — HelixScreen Homescreen Preset Fix (branch: `claude/beautiful-einstein-5mibrb`)

### Changes made

- **`Q2/helixscreen_preset.json` created** — new preset-formatted JSON with `"preset": "qiauh_q2"`, `"wizard_completed": false`, and all hardware mappings (fans, heaters, LEDs, filament sensors, macros, `panel_widgets` home layout). Excludes deployment-specific and user-preference fields per preset spec.
- **`aio_menu.sh` updated** — `install_bunnybox_helixscreen()` now fetches `helixscreen_preset.json` instead of `helixscreen_settings.json` and writes it to `${HELIX_CONFIG_DIR}/settings.json`. Banner and ok messages updated to match.
- **`AIO_VERSION` bumped to `RC2.40`**.
- **`CLAUDE.md` updated** — RC2.40 section added.
- **`Q2/helixscreen_settings.json` retained** — kept as reference; no longer used by the installer.

---

## RC2.37 — PR #24 Port + Macro Audit (branch: `claude/upbeat-brahmagupta-ymemga`)

### Changes made

- **Section 1 (docs):** Updated `Q2/Instructions.md`, `Q2/FAQ-BunnyBox&Helixscreen.md`, `All_in_One_Installer/WHAT_WAS_DONE.md`, and `CLAUDE.md` with PR #24 fix descriptions (KAMP profile, G29/G31/G32, WIPE, retraction tuning).
- **Section 2:** `M4032`, `SMART_STATUS`, `prepare_filament_dry`, `restore_factory_settings` added to both `Q2/macros/gcode_macro-JustFasterBox.cfg` and `Q2/macros/gcode_macro-JustFasterPrinter.cfg`.
- **Section 3:** `SET_PRINT_MAIN_STATUS` / `SET_PRINT_SUB_STATUS` calls restored in `M901`, `M4029`, `M603`, `M604` in both files.
- **Section 4:** `CLEAR_NOZZLE` improvements ported JFP→JFB; `EXTRUSION_AND_FLUSH` loop count fixed in JFB (range(1,6)→range(1,4)); retraction comment added in JFP; `RESUME_1` `printer.mmu.enabled` bug fixed in JFP.
- **Section 5:** JFP's commented-out `CANCEL_PRINT`/`PAUSE`/`RESUME_PRINT`/`RESUME` block replaced with live, no-box-adapted versions. `DETECT_INTERRUPTION` macro definition uncommented.
- **Section 7:** `.claude/settings.json` updated with `Edit(*)`, `Write(*)`, `MultiEdit(*)`.
- **Section 8:** Version bumped to RC2.37 in CLAUDE.md (no `AIO_VERSION` change — installer not modified).

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

