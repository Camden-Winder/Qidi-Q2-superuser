# Lessons Learned — Qidi Q2 Superuser

## [L001] os.replace() breaks symlinks
- **Category:** gotcha
- **Context:** settings.json patching
> `os.replace()` atomically replaces the symlink itself, not the file it points to.
> Use `open(path, 'w')` for in-place writes that must follow symlinks.
> Canonical path: `~/helixscreen/config/settings.json` → `printer_data/config/helixscreen/settings.json`

## [L002] Python json.load vs nlohmann on duplicate keys
- **Category:** gotcha
- **Context:** settings.json structure
> Python's `json.load` silently merges duplicate keys (last wins). nlohmann C++ rejects them outright.
> The RC2.40 preset fetch block introduced duplicate keys that looked fine in Python testing but broke HelixScreen.
> Always validate settings.json structure with a duplicate-key-aware linter before shipping.

## [L003] HelixScreen backup locations (3 total)
- **Category:** pattern
- **Context:** dashboard layout patching
> settings.json exists in 3 places: canonical (`${HELIX_CONFIG_DIR}/settings.json`),
> rolling backup (`/var/lib/helixscreen/settings.json.backup`, root-owned),
> and user backup (`~/.helixscreen/` — created lazily, may not exist on fresh install).
> Patch all three. Gate the ~/.helixscreen write on `os.path.isdir(backup2_dir)`.

## [L004] First-run wizard requires physical interaction
- **Category:** gotcha
- **Context:** install flow / panel_widgets
> `panel_widgets` key does not exist in settings.json until the user completes the HelixScreen
> first-run wizard at the printer. Cannot poll or timeout around this — must prompt user
> to walk to printer and confirm with `y`. Do not attempt to patch before confirmation.

## [L005] aio_menu_max4.sh must never be modified in Q2 sessions
- **Category:** pattern
- **Context:** repo structure
> The Max 4 variant is a sibling installer. All Q2 work targets `Q2/aio_menu.sh` only.
> Even when refactoring shared patterns, do not touch `Max4/aio_menu_max4.sh` without
> explicit user instruction.

## [L007] KAMP_settings.cfg — installer must use lowercase 's'
- **Category:** gotcha
- **Context:** KAMP install / fix_known_klipper_conflicts
> The source file and all include directives use `KAMP_settings.cfg` (lowercase s).
> Linux filesystems are case-sensitive, so installing as `KAMP_Settings.cfg` (capital S)
> causes Klipper to fail at startup with "Include file does not exist".
> Additionally, a now-removed dedup block in `fix_known_klipper_conflicts()` was actively
> deleting the correct lowercase file as "stale" — compounding the bug.
> Always use lowercase `KAMP_settings.cfg` in fetch calls, include patches, and any comment
> referencing the filename.

## [L008] q2_112 firmware: mks user cannot write to /home/qidi without sudo
- **Category:** gotcha
- **Context:** q2_112 install path — any function that writes to AIO_HOME-derived paths
- **Triggered by:** RC2.55 session (firmware 01.01.02+)
> On 01.01.02+ firmware, /home/mks is a root-owned symlink to /home/qidi.
> SSH logs in as mks but the OS user is qidi (netdev group, 755/664 perms).
> Every bare mkdir/rsync/touch into AIO_HOME fails with Permission Denied.
> Always use the `cmd 2>/dev/null || sudo cmd` fallback pattern for any write
> touching BACKUP_ROOT, SNAPSHOT_DIR, or CONFIG_DIR on this layout.

## [L006] sudo tee pattern for elevated file writes
- **Category:** pattern
- **Context:** installer script conventions
> Never use `echo > file` with sudo — that redirects as the current user before sudo takes effect.
> Always use `sudo tee` or `sudo tee -a` for writes requiring elevated permissions.
