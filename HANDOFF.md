# Session Handoff — Qidi Q2 Superuser AIO

## Known Issues (carry-forward)

- **JFP + Qidi Box: no warning in installer** — Users who select Just Faster Printer but have a Qidi Box connected get `QDE_004_007: Extruder not loaded` at end of print, because JFP's `PRINT_END` doesn't call `UNLOAD_FILAMENT`. The installer should warn box owners to use Just Faster Box instead. (See issue #33.)
- **CONTRIBUTING.md missing** — No contributor guide covering the branching convention, `claude/*` branch rule, and how to run the syntax checks.
- [ ] `show_about()` text is stale re: q2_112 — the "What it can install" and "Known limitations" sections still describe q2_112 installs as blocked/paused pending a "compatibility lane." This is no longer accurate as of RC3.00: `install_jfp_q2_112()`/`install_jfb_q2_112()` are now reachable directly from the top-level menu (options 2/3) on that layout. Left untouched in RC3.00 per session scope — needs a future docs-cleanup pass.

---

## RC3.00 — Collapse firmware submenu into top-level menu; add optional process-optimization step

### What changed

- **`draw_menu()`** — removed the `FIRMWARE` section and the `11) 01.01.02+ / qidi firmware` item. The Install section (options 1–3) is unchanged in appearance.
- **`main_loop()`** — options `2` and `3` now branch on `$AIO_LAYOUT`: on `q2_112` they call `install_jfp_q2_112`/`install_jfb_q2_112`, otherwise the legacy `install_just_faster`/`install_just_faster_box`. Option `1` is unchanged — it already self-gates via `preflight()` → `require_supported_firmware_layout()` on `q2_112`. Removed the `case 11) q2_112_submenu ;;` entry.
- **`q2_112_submenu()` deleted entirely** — its Revert option duplicated top-level option 5 (`revert_to_backup()` has no layout guard of its own and was already shared), and its "show layout report" option duplicated `run_readonly_diagnostics()`'s existing behavior under top-level option 9.
- **New: `offer_process_optimization()` / `undo_process_optimization()`** — all five install functions (`install_bunnybox_helixscreen()`/`_install_bunnybox()`, `install_just_faster()`, `install_just_faster_box()`, `install_jfp_q2_112()`, `install_jfb_q2_112()`) now end with an opt-in prompt ("Would you like to disable unnecessary processes? (recommended)"). If accepted, disables/masks a fixed list of unused stock services (VPN clients, Bluetooth, pulseaudio, lightdm, packagekit, etc. — never `QD_Q2` or `polkitd`), and on `q2_112` additionally runs the community QidiClient static-GIF patch (`thelegendtubaguy/QidiMax4CommunityWiki`, curled at install time — not vendored). What actually succeeded is recorded in a plain-text manifest under `aio_state_dir()` (`${BACKUP_ROOT}/_AIO_STATE/optimizations_applied`), **not** `aoi.ini` — `aoi.ini` lives inside `CONFIG_DIR` and is wiped by `revert_to_backup()`'s `rsync --delete` before revert logic could read it, same reasoning as the existing `aio_preexisting_paths_file()` manifest. `revert_to_backup()` now calls `undo_process_optimization()` early (before the config rsync), which reads the manifest, re-enables/unmasks exactly what was recorded, restores GIFs from the recorded backup dir on `q2_112`, and deletes the manifest afterward so a repeated revert is a clean no-op.
- **Drive-by fix in `_install_bunnybox()`** — removed a duplicated `banner "Installing unified gcode_macro.cfg & printer.cfg"` line (was printed twice back-to-back).
- **`CLAUDE.md`** — "Current Menu Layout" block corrected to match the live 10-item menu (it was already out of sync before this session — previously showed items 1–10 with a stale `10) 01.01.02+ / qidi firmware` line, while live code had 11 items). Added a note documenting the new optimization prompt.
- **Wiki** — pushed `Wiki-RC1.15`, updating the ASCII menu preview in `Q2-Install-Guide.md` to the RC3.00 layout. This supersedes the previously-outstanding RC2.52 menu-renumbering screenshot debt (see prior carry-forward entries, now removed) in a single update.

### Why

Simplifies the top-level menu for non-technical users — `q2_112` owners no longer need to know a separate submenu exists; options 2/3 "just work" regardless of detected firmware. The optimization step reduces idle CPU/RAM load from stock services that serve no purpose on a headless/kiosk printer controller, while remaining fully opt-in and cleanly reversible via the existing revert flow.

---

## RC2.66 — Fix KAMP paths in verify_bunnybox_install() (Issue #79)

### What changed

- **`verify_bunnybox_install()`** — fixed KAMP file paths in the health check file loop. Files are installed to `${CONFIG_DIR}/KAMP/` but the check was looking at `${CONFIG_DIR}/` root, causing false-negative errors. Updated to match the correct paths already used in `verify_jfp_install()` and `verify_jfb_install()`.

References #79

---

## RC2.65 — JFB BunnyBox conflict detection + printer.mmu guard

### What changed

- **`install_just_faster_box()`** — added pre-flight check for existing BunnyBox/Happy Hare install. If detected, warns user of incompatibility and asks for confirmation before proceeding. JFB and BunnyBox cannot safely coexist — JFB provides its own box macros without HH's MMU system.
- **`gcode_macro-JustFasterBox.cfg` `PRINT_START`** — replaced `printer.mmu.enabled` with `printer.save_variables.variables.enable_box == 1` to match the pattern used consistently everywhere else in `PRINT_START` and `PRINT_END`. `printer.mmu` only exists when Happy Hare is loaded; JFB has no Happy Hare dependency and should use saved variables for box state.

### Root cause

A user had BunnyBox pre-installed, ran option 1 (BB&HS), reverted to stock, then ran JFB (option 3). The JFB installer had no awareness of the existing BunnyBox install. After revert stripped the MMU includes from `printer.cfg`, `PRINT_START` crashed because `printer.mmu` no longer existed as a Klipper object.

---

## RC2.64 — Move webcam duplicate check to start of install_camera()

### What changed

- **`install_camera()`** — replaced the `# TEMPORARY` grep-based webcam check (which could only detect config-file-sourced entries) with a Moonraker API query at the very start of the function, before any changes are made. This catches both `config`- and `database`-sourced webcam entries (e.g. a stock Qidi camera auto-registered by Mainsail) and warns the user before ustreamer is installed or `moonraker.conf` is touched.
- **`purge_mainsail_ui_webcams()` call** — kept as a secondary best-effort cleanup at the end of install, but no longer relied upon as the primary detection mechanism since its post-restart timing has been confirmed unreliable.

### Root cause

The previous grep-based check could not detect `database`-sourced webcam entries (e.g. Qidi's stock auto-registered camera) because those entries never appear in `moonraker.conf` — they live only in Moonraker's runtime database. The only mechanism that could see them, `purge_mainsail_ui_webcams()`, ran after a Moonraker restart and was confirmed in live user testing to silently fail to reach the API despite a 6-attempt retry loop (~12s). Moving the check to the start of the function, before any restart occurs, avoids the timing problem entirely.

---

## RC2.63 — Retry loop for Moonraker webcam duplicate check

### What changed

- **`purge_mainsail_ui_webcams()`** — added a retry loop (6 attempts, 2s apart, ~12s total) before giving up on reaching the Moonraker API. Previously this ran immediately after `systemctl restart moonraker` with no wait and failed almost every time, silently skipping the duplicate-webcam cleanup.

### Root cause

Confirmed via live user test (issue #74 thread): `purge_mainsail_ui_webcams()` is called right after `sudo systemctl restart moonraker`, before Moonraker has finished restarting. The single 5-second curl attempt failed every time during install, but succeeded immediately when run manually moments later. This left UI-database-sourced webcam entries (e.g. a pre-existing camera auto-detected by Mainsail before the AOI ran) undetected, resulting in duplicate cameras shown in Mainsail.

---

## RC2.62 — Menu cleanup: Uninstall Mainsail, status line, post-install text

### What changed

- **Menu renumbered** — added option 6 "Uninstall Mainsail" under UNINSTALL. Mainsail (addon) shifts to 7, About to 8, Health Check to 9, Testing to 10, firmware submenu to 11.
- **`show_status_line()`** — removed `Camera` indicator; camera is bundled into Mainsail and no longer warrants its own status line entry.
- **`_install_bunnybox()` post-install summary** — added recommendation to install Mainsail (option 7) for box controls, since Qidi's stock UI/Fluidd fork only recognizes Qidi's own box software (root cause from issue #74).
- **`sudo reboot` removed from all 7 locations** — camera migration/setup confirmations, Mainsail install confirmation, roundtrip probe completion, revert completion, BunnyBox post-install summary, and About/known limitations text. All replaced with `FIRMWARE_RESTART` only.

---

## RC2.61 — Detect existing webcam before ustreamer install

### What changed

- **`install_camera()`** — added detection of any existing `[webcam ...]` section in `moonraker.conf` before proceeding with ustreamer install. If found, warns user and asks for confirmation before continuing. Avoids duplicate webcam entries in Mainsail on setups where crowsnest or another camera stack is already configured. Marked `# TEMPORARY` in code pending a more complete solution.

---

## RC2.60 — Revert/restore sudo fallbacks for q2_112

Branch: `claude/revert-restore-sudo-rc260`

### What changed

- **`revert_to_backup()`** (~line 4248) — added `sudo rsync` fallback when bare rsync fails with Permission Denied
- **Health check force snapshot** (~line 5848) — added `sudo mkdir -p` fallback and `sudo rsync` fallback for snapshot capture
- **Health check force restore** (~line 5865) — added `sudo rsync` fallback for force restore

### Root cause

On `q2_112` firmware, `CONFIG_DIR` is owned by `qidi:netdev`. Files written by AIO (via sudo) end up owned by `root` or `qidi`. `rsync` running as `mks` without sudo cannot delete those files, set timestamps on the directory, or write new files — producing `Permission denied (13)` on `unlink(aoi.ini)` and `mkstemp(".printer.cfg.XXXXXX")`. Same root cause as RC2.55 (L008). Fix is the standard `cmd 2>/dev/null || sudo cmd` pattern used elsewhere in the script.

---

## RC2.59 — /tmp staging fix for printer.cfg patch on q2_112

Branch: `claude/printer-cfg-tmp-staging-rc259`

### What changed

- **`install_jfp_q2_112()`** — replaced two-heredoc fallback with single python3 heredoc writing to a `/tmp` tempfile, verified with `grep`, then `sudo cp` into place
- **`install_jfb_q2_112()`** — same fix
- **`update_macros()` JustFasterPrinter branch** — same `/tmp` staging approach for the append block
- **`update_macros()` JustFasterBox branch** — same

### Root cause

On `q2_112` firmware, `printer.cfg` is `644` owned by `qidi`; `mks` cannot write it directly. RC2.56–58 used a `python3 direct-write || python3 | sudo tee` fallback. The problem: `$?` after a bash heredoc captures the shell's heredoc setup exit code, not python3's. The `sudo tee` fallback therefore ran even on success, and received empty stdin (python3 had already exited), blanking `printer.cfg`. The `/tmp` staging approach avoids this entirely — python3 writes to a temp file it owns, `sudo cp` does the privileged copy only after `grep` confirms the tempfile is correct.

---

## RC2.58 — Write aoi.ini in q2_112 install variants

### What changed

- **`install_jfp_q2_112()`** — added `write_aoi_ini "JustFasterPrinter"` call after KAMP install
- **`install_jfb_q2_112()`** — added `write_aoi_ini "JustFasterBox"` call after KAMP install

### Root cause

`do_backup()` writes a placeholder `install_group=unknown` before the install group is known. The standard install paths (`install_just_faster`, `install_just_faster_box`) overwrite this with the correct group after completing. The q2_112 variants were missing this final step, leaving `unknown` in `aoi.ini` and breaking option 4 (Update Macros) for all q2_112 users.

---

## RC2.57 — Fix JFP and JFB post-install summary text

### What changed

- **`install_just_faster()` post-install summary** — removed `sudo reboot` and `screws_tilt_adjust` from next steps. `FIRMWARE_RESTART` only.
- **`install_just_faster_box()` post-install summary** — same fix.

---

## RC2.56 — printer.cfg KAMP patch sudo fallback

Branch: `claude/printer-cfg-kamp-sudo-9885k8`

### What changed

- `update_macros()` JustFasterPrinter branch (~line 1164): added `$?` check after python3 heredoc, `sudo tee` retry, and `grep` verification before `ok`/`err`
- `update_macros()` JustFasterBox branch (~line 1183): same fix
- `install_jfp_q2_112()` (~line 1684): same fix with re.sub variant python3 script
- `install_jfb_q2_112()` (~line 1732): same fix
- `Q2/CLAUDE.md`: added `printer.cfg` row to key-paths table noting it is `644` on `q2_112` — no group write bit, requires `sudo tee` for patching

### Root cause

`printer.cfg` on 01.01.02+ firmware is `644`. `mks` is in `netdev` group but is not the owner, so `open(path, 'w')` raises `PermissionError`. The shell heredoc exit code was not checked, so `ok "KAMP include added to printer.cfg"` fired unconditionally even on failure. Klipper never received the `[include KAMP/KAMP_settings.cfg]` line, causing startup errors.

---

## RC2.55 — q2_112 Write Permission Fixes

Branch: `claude/q2-112-write-perms-xhtqxv`

### What changed

- `take_snapshot()`: added `|| sudo` fallback to `mkdir` and `rsync` calls
- `capture_first_run_state()`: added `|| sudo` fallback to `mkdir` and `: >` (touch) calls
- `clean_kamp_dir()`: added `q2_112` block at top to delete stock `klipper-macros-qd/KAMP_Settings.cfg` before it collides with ours (`[gcode_macro _KAMP_Settings]` duplicate)
- `install_camera()`: fixed `User=mks` → `User=${AIO_USER}` in ustreamer systemd service heredoc
- `install_mainsail()` + `install_camera()`: added `q2_112` warn banner (untested on 01.01.02+ firmware)
- `Q2/CLAUDE.md`: replaced single-column key-paths table with dual-column layout (legacy_mks / q2_112) plus write-permissions note
- `.claude/LESSONS.md`: added L008 (q2_112 write permissions root cause)

### Root cause

On 01.01.02+ firmware, `/home/mks` is a root-owned symlink to `/home/qidi`. SSH logs in as `mks` but the OS user is `qidi` (netdev group, 755/664 perms). Bare `mkdir`/`rsync`/`touch` calls into `AIO_HOME`-derived paths fail with Permission Denied when running as `mks`.

---

## docs-only — PR Template + CLAUDE.md PR Instructions

### What changed

- **`.github/PULL_REQUEST_TEMPLATE.md` created** — standard PR template with Summary, Changes, Implementation, and Testing sections. Title format varies by change type (RC X.XX / Wiki-RC / docs-only).
- **`CLAUDE.md`** — replaced the old PR comment instruction with full PR template usage guidance; added testing format examples section showing syntax-only and medium-description patterns.

---

## docs-only — CLAUDE.md + session_brief.md guardrails

Branch: `claude/update-claude-docs-9368y9`

### What changed

- Added issue-reference rule to `CLAUDE.md` (`must ask first` list): never use `Closes #N`, `Fixes #N`, or `Resolves #N` — use `References #N` only.
- Added attribution note to `CLAUDE.md`: do not add generated-by footers to commits/PRs/comments.
- Added `## Before Planning` rule to `## Rules` in `.claude/session_brief.md`.
- Added `## Before Planning` required subsection to the Session Brief Format in `.claude/session_brief.md`.

### Why

Claude Code triggered unintended issue closure via `Closes #N` in a commit message. Plan mode was restating the Session Brief instead of reflecting code Claude Code actually read.

---

## RC2.54 — BunnyBox & HelixScreen Install Fixes

Branch: `claude/aio-bunnybox-helixscreen-fixes-7pmi9j`

### What changed

- **`update_macros()`** — fixed missing space in unknown group error message (`please reinstall` → `please reinstall using option 1, 2, or 3`)
- **`_install_bunnybox()`** — BunnyBox cancel no longer aborts the full install; HelixScreen and KAMP continue if BunnyBox is not detected post-install
- **`_install_bunnybox()`** — removed legacy `sed` that rewrote `[include ./KAMP/KAMP_settings.cfg]` to `[include KAMP_settings.cfg]`; `printer-BunnyBox.cfg` already has the correct path
- **`apply_helixscreen_dashboard_layout()`** — suppressed verbose Python output (`Updated N/N widgets`, `OK /path`, `SKIP /path`); replaced with existing `ok "HelixScreen dashboard layout applied"` line
- **Post-install summary** — removed stale BOX_DRY / DRY_PLA / DRY_PETG / DRY_ABS / DRY_TPU / DRY_PA / BOX_DRY_STATUS / BOX_DRY_STOP references (macros removed in RC2.46)

---

## RC2.53 — Function Comment Standard (Issue #55)

Branch: `claude/serene-thompson-kaqxsu`

### What changed

- **`CLAUDE.md`** — added Function Comment Standard: 1–2 line prose comments required above all `install_*`, `uninstall_*`, `verify_*`, `*_installed`, and functions over 20 lines.
- **`Q2/aio_menu.sh`** — all functions updated to comply with the standard; missing comments added, multi-line comments condensed.

References #55

---

## RC2.52 — aoi.ini State File, Update Macros Option, Menu Renumber (Issue #57)

Branch: `claude/friendly-knuth-qtvkpb` | PR: #61

### What changed

- **`aoi.ini`** — replaces empty `.aio_installed` marker. Stores `install_version`, `macro_version`, `install_group`, `install_date` in INI key=value format. `AIO_MARKER` repointed to `${CONFIG_DIR}/aoi.ini`.
- **`write_aoi_ini()`** — new helper; writes all four fields atomically using `install -m 0644`.
- **`read_aoi_ini()`** — new helper; reads a single key from `aoi.ini`.
- **`update_macros()`** — new function (menu option 4); reads `install_group` from `aoi.ini`, warns user of overwrite, re-fetches all AOI-owned macro files and KAMP folder for the detected group, updates `macro_version` in `aoi.ini`.
- **Migration** — on first run after upgrade, `.aio_installed` is deleted and `aoi.ini` is written in its place (in `do_backup()`).
- **Marker writes updated** — BB, JFP, and JFB installers now call `write_aoi_ini()` with their group name instead of bare `touch`.
- **Menu option 4 (Update Macros)** added; Revert → 5, Mainsail → 6, About → 7, Health Check → 8, Testing → 9.
- **`F)` → `10)`** — firmware submenu renumbered to comply with standing rule (issue #57).
- **`CLAUDE.md`** — menu layout and install functions table updated.

---

## RC2.51 — Remove Idle Fan Shutdown as AOI Addon

### What changed

- **`Q2/macros/idle_fan_shutdown.cfg` deleted** — idle fan shutdown logic now lives in the stock gcode_macro configs as the default behavior
- **`idle_fan_shutdown_installed()`, `uninstall_idle_fan_shutdown()`, `menu_idle_fan_shutdown()`, `install_idle_fan_shutdown()` removed** from `aio_menu.sh`
- **Menu option 5 (Idle Fan Shutdown) removed** — options renumbered: Mainsail 5, About 6, Health Check 7, Testing 8
- **`show_status_line()`** — `IdleFan` status indicator removed
- **Health check** — idle fan verifier block removed
- **`revert_to_backup()`** — `[idle_timeout]` un-patch moved here from the deleted `uninstall_idle_fan_shutdown()` to preserve backward compatibility for users who had the old addon
- **`show_about()`** — idle fan shutdown line removed from addon list
- **`CLAUDE.md`** — replaced `idle_fan_shutdown` examples with `mainsail`; updated menu layout
- **`docs/WHAT_WAS_DONE.md`** — updated `_IDLE_SHUTDOWN` entry; removed install path row

---

## Wiki-RC1.1.0 — Wiki audit from issue #48

- Wiki-only session — no AIO_VERSION bump
- 3 new pages: `Q2-Troubleshooting.md`, `Max4-Troubleshooting.md`, `Q2-JustFaster.md`
- `Troubleshooting.md` deleted (content split into printer-specific pages)
- 9 pages updated: Q2-Install-Guide, SSH-Guide, Q2-BunnyBox-HelixScreen, Plugins, Printables, Max4-Install-Guide, Q2-FAQ, _Sidebar, Home
- WIKI_VERSION bumped to Wiki-RC1.1.0
- Closes issue #48

---

## Wiki-RC1.01 — Move wiki to GitHub Wiki tab

- Branch: `claude/wiki-rc1-push`
- Wiki content pushed to `Qidi-Q2-superuser.wiki.git` (GitHub Wiki tab)
- `wiki/` folder removed from main repo
- README links updated to point to `github.com/.../wiki/` URLs
- WIKI_VERSION bumped to Wiki-RC1.01 in Home.md

---

## Wiki-RC1.0 — Wiki creation & repo restructure

- Branch: `claude/kind-albattani-0lgk38`
- Wiki created — 17 pages under `wiki/` plus `wiki/assets/` (docker-compose-spoolman.yml, docker-compose-octoapp.yml, fan_test.py)
- README rewritten — clean landing page, Thanks.md content absorbed, links point to wiki
- `All_in_One_Installer/` renamed to `docs/` — stale git clone Usage section updated to curl one-liners, CLAUDE.md stub deleted, Instructions.md links updated to wiki
- `Configurations/` dissolved — `Basic Changes/` deleted, `filament configs.txt` moved to `Q2/`, `My Resources.md` → `wiki/References.md`, `Filamet Configurations.md` → `wiki/Filament-Config.md`
- `Plugins/` dissolved — docker-compose files extracted to `wiki/assets/`, tutorial docs deleted, OctoEverywhere docker-compose deleted (no longer referenced)
- Deleted: `Beginers/`, `Q2/Instructions.md`, `Q2/FAQ-BunnyBox&Helixscreen.md`, `Max4/Instructions.md`, `Max4/FAQ.md`, `Calibrations/`, `Printables/`, `Thanks.md`
- No AIO_VERSION bump — docs and structure only

---

## RC2.50 — Harden KAMP install + update warranty warning (branch: `claude/nice-goodall-1d3n7r`)

### What changed

- **`clean_kamp_dir()` helper added** — new function that wipes all KAMP-related files from `CONFIG_DIR` root (case-insensitive), removes the `KAMP/` folder entirely, then re-creates it fresh. Prevents duplicate/stale files (`KAMP_Settings.cfg`, `KAMP_Settings (1).cfg`, root-level copies) from conflicting with the AIO's canonical install.
- **5 install sites updated** — `mkdir -p "${CONFIG_DIR}/KAMP"` replaced with `clean_kamp_dir` in `install_just_faster()`, `install_just_faster_box()`, `install_bunnybox_helixscreen()`, and both 1.1.2 migration paths. `fix_known_klipper_conflicts()` (~line 4999) left untouched.
- **Warranty warning updated** — added a bold "Note: This tool will make significant changes to your printer's configuration files..." paragraph before the closing `===` line.
- **`CLAUDE.md` updated** — added wiki screenshot rule: when `AIO_VERSION` ends in `0` or `5`, update the wiki preview screenshot. If the wiki repo is not accessible, add a carry-forward to-do.
- **`AIO_VERSION` bumped to `RC2.50`**

### Wiki preview to-do (carry-forward)

RC2.50 ends in `0` — the wiki menu preview screenshot should be updated. The GitHub Wiki repo (`camden-winder/qidi-q2-superuser.wiki`) was not accessible in this session. **TODO:** In a future session (or manually), update the AIO menu preview image in the wiki to reflect the current menu layout.

---

## RC2.49 — HelixScreen health check auto-restart (branch: `claude/magical-ptolemy-padrcs`)

### What changed

- **`verify_helixscreen_runtime_health()`** now attempts `sudo systemctl restart helixscreen` automatically when the service is found inactive during a health check (option 8). If the restart succeeds it prints `ok "HelixScreen: restarted successfully"`; if it fails it prints an `err` and tails the journal via `show_systemd_journal_tail`. Previously the function only reported an error and told users to re-run the installer.
- **`AIO_VERSION` bumped to `RC2.49`**
- Closes issue #48.

---

## RC2.48 — Fix KAMP_settings.cfg case mismatch (branch: `claude/busy-curie-9gu7tw`)

### What changed

- **Global rename** — all 7 occurrences of `KAMP_Settings.cfg` (capital S) in `Q2/aio_menu.sh` changed to `KAMP_settings.cfg` (lowercase s), matching the source file and the `[include ./KAMP/KAMP_settings.cfg]` directive in `printer-BunnyBox.cfg`.
- **Dedup block removed** — `fix_known_klipper_conflicts()` contained a block that deleted `KAMP_settings.cfg` (the correct file) when both case variants were present. After the rename, the condition was always a no-op tautology. Block removed entirely.
- **`AIO_VERSION` bumped to `RC2.48`**

### Root cause

The installer was fetching and writing KAMP config as `KAMP_Settings.cfg` (capital S) while every include directive and the source repo file use `KAMP_settings.cfg` (lowercase s). On Linux (case-sensitive filesystem), Klipper could not find the file at startup. The dedup block then made it worse by deleting the correct lowercase copy if a user somehow had both.

---

## RC2.46-docs — Claude docs overhaul + installer restructure (branch: `claude/stoic-pasteur-92gmir`)

### What changed

- **Installer scripts moved** — `All_in_One_Installer/aio_menu.sh` → `Q2/aio_menu.sh`; `All_in_One_Installer/aio_menu_max4.sh` → `Max4/aio_menu_max4.sh`. All references updated across the repo.
- **CLAUDE.md overhauled** — paths updated, Troubleshooting Protocol section added, version history rule added (history belongs in HANDOFF.md only), all RC history migrated to HANDOFF.md.
- **`.claudeignore` created** — excludes `Configurations/`, `Plugins/`, reference-only files, git, and IDE dirs.
- **`.claude/LESSONS.md` created** — 6 seed entries covering known gotchas (symlink writes, duplicate JSON keys, HelixScreen backup locations, first-run wizard, Max4 isolation, sudo tee).
- **`.claude/commands/start.md` created** — `/start` slash command for session startup protocol.
- **`.claude/github-issue-response.md` created** — issue response format, tone rules, superuser diagnostic commands, LESSONS.md auto-population trigger.
- **`All_in_One_Installer/CLAUDE.md` created** — redirect pointing to new script locations.
- **`Q2/CLAUDE.md` created** — Q2-scoped conventions, test commands, key paths, settings.json symlink warning.
- **`Max4/CLAUDE.md` created** — Max4-scoped conventions, test commands, key paths, scope limits.
- **`.claude/session_brief.md` updated** — LESSONS.md protocol added to startup/end-of-session steps.
- **No AIO_VERSION bump** — docs-only session.

---

## RC2.47 — Add 01.01.02+ / qidi firmware submenu (branch: `claude/ecstatic-tesla-zyuqek`)

### What changed

- **New `F)` main-menu option** routes to `q2_112_submenu()` for firmware 01.01.02+ users (previously blocked by layout guard on all install paths).
- **`preflight_q2_112()`** — network-only preflight; skips the mutation layout guard; keeps network, config dir, and force_move checks.
- **`install_jfp_q2_112()`** — Just Faster Printer for q2_112: writes macro to `klipper-macros-qd/gcode_macro.cfg`, installs KAMP files, patches `printer.cfg` in-place. Never overwrites `printer.cfg`.
- **`install_jfb_q2_112()`** — same as above for Just Faster Box (`gcode_macro-JustFasterBox.cfg`).
- **`q2_112_submenu()`** — guarded submenu with JFP, JFB, Revert to Backup (delegates to existing `revert_to_backup()` which is layout-aware), and layout report.
- **No existing functions modified** — all legacy_mks code paths untouched.
- **`AIO_VERSION` bumped to `RC2.47`**

### Root cause (issue #17)

Firmware 01.01.02+ made `/home/mks` a root-owned symlink to `/home/qidi`; writes as `mks` fail. The new q2_112 submenu targets `/home/qidi` directly via `AIO_HOME` and never touches `printer.cfg` wholesale.

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
| `Q2/aio_menu.sh` | Main installer script — current version RC2.14 |
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

## RC2.36 — What's In It

- `AIO_VERSION='RC2.36'`
- **Just Faster Box added to Q2 AIO** — Option 4 (`install_just_faster_box()`) installs `gcode_macro-JustFasterBox.cfg` + `JustFasterPrinter.cfg` + KAMP files. Same structure as JFP but with live box branches (`BOX_PRINT_START`, box heater control). No Happy Hare, no HelixScreen.
- **Detection helpers** — `just_faster_printer_installed()` and `just_faster_box_installed()` fingerprint on `PRINTER_PARAM` / `BOX_PRINT_START` in `gcode_macro.cfg`.
- **Status line updated** — `Just Faster: Just Faster Box / Just Faster Printer / not found` now shown alongside BunnyBox/Display.
- **`verify_jfb_install()`** — post-install check confirms files present and `BOX_PRINT_START` in macro file.
- **`revert_to_backup()` updated** — removes `gcode_macro.cfg` when JFP or JFB detected before restoring from backup.
- **Menu renumbered** — Revert→5, Idle Fan→6, Mainsail→7, About→8, Health Check→9, Testing 9–15→10–16.
- **Q2/Instructions.md** — JFB row added to path table, Option 4 subsection added, AIO menu preview added, option number references updated.

---

## Max4-RC1.01 — What's In It

- `AIO_VERSION='Max4-RC1.01'`
- No functional changes to the Max 4 installer.
- **Max4/Instructions.md** — AIO menu preview section added showing current Max 4 menu layout.

---

## RC2.13 — What's In It

Merged via PR #13 (2026-05-28):

- `AIO_VERSION='RC2.13'`
- **KlipperScreen install disabled** — Option 2 now shows a warning that KlipperScreen install is unavailable in this version. Removed due to reliability issues.
- **Full MMU config suite** (`Q2/mmu/`) — complete Happy Hare config file set shipped with the installer.
- **`helixscreen_settings.json` updated** — AMS/display settings updated for Qidi Box.

---

## RC1.26 — What's In It

- `AIO_VERSION='RC1.26'`
- **Option 2 is now standalone `install_klipperscreen()`** — installs KlipperScreen Happy Hare Edition only. No longer bundles BunnyBox, config templates, KAMP, or drying macros. Completely decoupled from `_install_bunnybox()`.
- **`_install_bunnybox()` simplified** — no longer accepts a `display_ui` parameter; always installs HelixScreen. All KlipperScreen conditionals removed.
- **`prepare_display_for_klipperscreen()`** replaces `switch_display_to_klipperscreen()`: stops/disables/masks `makerbase-client` and `helixscreen` only — no lightdm or graphical.target manipulation. The upstream installer handles its own X/console setup.
- **`NETWORK=N`** still passed to prevent the installer killing dhcpcd/NetworkManager. `xserver-xorg-legacy` still stripped (not available on Debian Bullseye ARM).
- **`uninstall_klipperscreen()`** simplified: removes service/dirs, restores `graphical.target`, unmasks/enables lightdm and makerbase-client. No lightdm.conf backup/restore needed.
- Removed all custom xinit/xsetup/lightdm.conf constants (`KLIPPERSCREEN_UNIT`, `KLIPPERSCREEN_XSETUP`, `LIGHTDM_CONF`).

---

## RC1 — What's In It

Merged to `main` via PR #1 (2026-05-20):

- `AIO_VERSION='RC1'` constant; rendered in banner and About screen
- `verify_qidi_box_helixscreen()` — post-install check (warns, never fails)
- `install_qidi_box_write()` — systemd drop-in for `HELIX_QIDI_BOX_WRITE=1`; `BoxWrite:` status line
- `helixscreen_settings.json`: `"ams": { "spool_style": "3d" }` for Qidi Box AMS view

---

## RC2 — Candidate Features (not implemented)

- `update_qidi_box_dropin` migration helper
- `/release` slash command for version bump + changelog + tag + push

---

## RC11 — What's In It

- `AIO_VERSION='RC11'`
- **`Option 'gcode' is not valid in section 'bed_mesh'` fixed**: `check_invalid_klipper_options()` now also detects and removes `gcode:` keys (and their indented body) that appear inside `[bed_mesh]`. Some Qidi stock `printer.cfg` versions place the entire `[idle_timeout]` body inside `[bed_mesh]` with no section header; Klipper rejects both `timeout:` (already caught in RC8) and `gcode:`.
- **`BED_MESH_CALIBRATE already registered` fix hardened**: `fix_known_klipper_conflicts()` check #6 now scans ALL `.cfg` files at the config root for `[gcode_macro BED_MESH_CALIBRATE]` definitions, not just `KAMP_Settings.cfg`. Any file that is NOT `Adaptive_Meshing.cfg` gets its duplicate definition commented out with `## AIO_DISABLED:`.
- **PIPESTATUS install-abort bug fixed**: `install_bunnybox_helixscreen()` previously only aborted on exit code 99 (user BunnyBox cancel). Any other non-zero exit (e.g., a failed `fetch()` for `printer.cfg`) would silently print "Install complete" and leave the printer with partial/broken configs. Now any non-zero exit code aborts the install with an error message pointing to the log file.

---

## RC10 — What's In It

- `AIO_VERSION='RC10'`
- **Fresh-install black screen fixed**: HelixScreen now activates correctly after option 1. Added `switch_display_to_helixscreen()` which stops/disables/masks `lightdm` and `makerbase-client`, then enables/starts `helixscreen.service`. Called automatically at the end of `install_bunnybox_helixscreen()`.

---

## RC8 — Candidate Features (not implemented)

- Symmetric `uninstall_just_faster()` (option 2 currently has no individual uninstall path; Revert to Backup is the only way to undo it)

---

## RC8 — What's In It

- `AIO_VERSION='RC8'`
- **Post-revert sanity check**: `revert_to_backup()` now runs the full verifier sweep (`_run_verifiers_core`) at the end so any leftover problems (orphan includes, leftover MMU extras, duplicate macros, invalid Klipper options) are caught before the user is told the revert is complete. The same checks run from menu option 7.
- **`check_invalid_klipper_options()`** — catches `timeout: 43200` misplaced inside `[bed_mesh]` (some Qidi stock printer.cfg versions ship it there; Klipper rejects with "Option 'timeout' is not valid in section 'bed_mesh'"). Prompts before fixing.
- **`check_orphan_includes()`** — finds `[include X]` lines whose target file doesn't exist on disk and offers to comment them out. Prevents "Unable to open config file" boot failures.
- **`check_leftover_mmu_artifacts()`** — detects surviving Happy Hare v3 `extras/mmu/` package, `mmu_*.py` symlinks, and active `[mmu*]` sections that escaped uninstall. Prompts before each cleanup.
- **`run_all_verifiers()` refactored**: split into `_run_verifiers_core()` (no press_enter, callable from anywhere) and `run_all_verifiers()` (core + press_enter for the menu).

---

## RC7 — What's In It

- `AIO_VERSION='RC7'`
- **Mainsail install added as menu option 5**: delegates to Camden-Winder's `install-mainsail.sh` (same `curl | bash` pattern we use for BunnyBox and HelixScreen). Mainsail listens on port 100; Qidi's stock lighttpd on port 80 is untouched.
- **`install_mainsail()` / `uninstall_mainsail()` / `mainsail_installed()` / `verify_mainsail()` / `menu_mainsail()`** added per the install-function convention.
- **Revert to Backup** now uninstalls Mainsail too (removes nginx site, `/home/mks/mainsail`, reloads nginx). Moonraker CORS entries are left in place (harmless).
- **Status line** now shows `Mainsail: installed/not found`.
- **Menu renumbered**: About → 6, Run all verifiers → 7.

---

## RC6 — What's In It

- `AIO_VERSION='RC6'`
- **`BED_MESH_CALIBRATE` duplicate fixed**: `fix_known_klipper_conflicts()` now detects when `KAMP_Settings.cfg` defines `[gcode_macro BED_MESH_CALIBRATE]` inline (older BunnyBox/KAMP versions put this at line ~46) while `Adaptive_Meshing.cfg` also defines it. The correct structure has `KAMP_Settings.cfg` using `[include ./Adaptive_Meshing.cfg]` only — not redefining the macro inline. When the conflict is detected, AIO re-fetches the correct `KAMP_Settings.cfg` from the repo, resolving the duplicate without manual intervention.
- **Verifier order fixed**: `run_all_verifiers()` (option 6) now runs `fix_known_klipper_conflicts` *before* `find_duplicate_macros` so conflicts are healed before the scan report. Previously the scan ran first, showing problems that `fix_known_klipper_conflicts` would have fixed a moment later.

---

## RC5 — What's In It

- `AIO_VERSION='RC5'`
- **Fresh-install crash fixed**: `install_bunnybox_helixscreen()` no longer re-enables `[include box.cfg]` in `printer.cfg`. Including `box.cfg` loads Qidi's `box_extras.so` plugin, which registers `CLEAR_TOOLCHANGE_STATE` — the same gcode command Happy Hare's `mmu/` package registers. Loading both crashes Klipper on startup. The shipped `printer(BunnyBox&HelixScreen).cfg` template already ships with the include commented out (BunnyBox's installer disables it); RC1–RC4 had explicit code to re-enable it for the Qidi UI "Control Box" panel, which was the source of the crash.
- **Trade-off documented**: while BunnyBox is installed, the Qidi UI's "Control Box" panel does NOT work — Happy Hare owns box hardware via `[mmu]` steppers and its own gcode commands. Revert to Backup restores stock `printer.cfg` with `[include box.cfg]` active, bringing the Qidi UI panel back.
- **Defensive disable**: install now also comments out any existing `^[include box.cfg]` line in `printer.cfg`, so users carrying state from RC1–RC4 are healed by re-running option 1.
- **`verify_qidi_box_helixscreen()` flipped**: with BunnyBox installed, `[include box.cfg]` active is now flagged as an error (it WILL crash Klipper) instead of being treated as the desired state.

---

## RC4 — What's In It

- `AIO_VERSION='RC4'`
- **`purge_happy_hare_all()`** now removes Happy Hare v3's package layout: `~/klipper/klippy/extras/mmu/` directory and all `mmu_*.py` symlinks (mmu_espooler, mmu_servo, mmu_led_effect). The previous v2-style file list missed everything in v3, leaving the mmu package live in Klipper after uninstall — which caused `CLEAR_TOOLCHANGE_STATE already registered` crashes when `box_extras.so` tried to re-register the same command.
- **`purge_happy_hare_all()`** now removes root-level KAMP files (`KAMP_Settings.cfg`, `Adaptive_Meshing.cfg`, `Line_Purge.cfg`, `Smart_Park.cfg`). The stale BunnyBox-shipped `KAMP_Settings.cfg` was defining `BED_MESH_CALIBRATE` and clashing with `Adaptive_Meshing.cfg`. `fix_printer_cfg_after_uninstall()` handles the resulting orphan `[include]` lines.
- **`restore_aio_disabled_macros()`** (new) — reverses the `## AIO_DISABLED:` prefixes that `fix_known_klipper_conflicts()` applies to `box1.cfg` (T0-T3, UNLOAD_T0-T3) and `gcode_macro.cfg` (EXTRUSION_AND_FLUSH). Called from `purge_happy_hare_all()` so uninstall restores Qidi's native tool-change buttons and the flush macro.
- **Menu simplified**: options 3 (Uninstall BunnyBox), 4 (Uninstall HelixScreen), 5 (Uninstall Both) removed. Revert to Backup is the single uninstall path; it now delegates to `uninstall_helixscreen()` and `uninstall_bunnybox()` internally so it picks up every cleanup step (qidi-box-write systemd drop-in, helixscreen state dir, moonraker bak, restore_aio_disabled_macros, fix_printer_cfg_after_uninstall).
- Remaining menu numbers: `3) Revert`, `4) Idle Fan Shutdown`, `5) About`, `6) Run all verifiers`.

---

## RC3 — What's In It

- `AIO_VERSION='RC3'`
- Removed `heater_vent_macro` / `heater_vent_interval` patching in `mmu_parameters.cfg`. Happy Hare's vent macro is for MMU enclosures with motorized vents; Q2's box has a manual vent.
- Removed the `wget | bash -- --revert` call in `revert_to_backup()` — Camden-Winder's BunnyBox installer has no `--revert` flag. `purge_happy_hare_all()` handles the full teardown.
- `install_bunnybox_helixscreen()` now strips the `HELIX_QIDI_BOX_WRITE` drop-in (instead of installing it). HelixScreen ENV docs confirm the flag gates `load_filament`, `unload_filament`, `change_tool`, `set_tool_mapping` on the **native Qidi Box AMS backend** — exactly what BunnyBox + Happy Hare own when installed.
- Verifier and status line flipped: with BunnyBox installed, drop-in **absent** is the desired state (`BoxWrite: off` shown green).

---

## Known Bugs Fixed in RC2 (merged)

| PR | Fix |
|---|---|
| #7 | Duplicate gcode_macro conflict resolver (`fix_known_klipper_conflicts`) |
| #8 | Install KAMP sub-files alongside `KAMP_Settings.cfg` |
| #9 | Fix bogus flags to Happy Hare (`-u`) and HelixScreen (`--remove`) uninstallers |
| #10 | Clean backup dirs, HelixScreen dir, moonraker bak on uninstall |
| #11 | Patch `printer.cfg` broken includes after uninstall; drop pre-revert backup |
| #12 | Comment out `TOOL_CHANGE_START/END` in `bunnybox_macros.cfg` (Qidi Python plugin owns them) |
| #13 | Detect `box_extras.so` (Qidi ships compiled `.so`, not `.py`) |

