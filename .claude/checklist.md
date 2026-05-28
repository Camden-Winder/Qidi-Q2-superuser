# Pre-flight Checklists

## Before Every Commit

- [ ] `bash -n All_in_One_Installer/aio_menu.sh` — no syntax errors
- [ ] `python3 -m json.tool Install-Script/helixscreen_settings.json` — valid JSON
- [ ] `AIO_VERSION` bumped if `aio_menu.sh` changed (currently `RC1`)
- [ ] No raw `echo` in installer logic — use `banner`, `info`, `warn`, `ok`, `err`
- [ ] No `Configurations/` or `Plugins/` files touched

## Before Adding a New Install Function

- [ ] `install_*()` function written
- [ ] Matching `uninstall_*()` function written
- [ ] `*_installed()` or `*_enabled()` detection helper written
- [ ] `uninstall_*()` called from `revert_to_backup()`
- [ ] Status indicator added to `show_status_line()`
- [ ] `verify_*()` post-install check written (warn, never fail)
- [ ] New menu item added to `draw_menu()` and `main_loop()` if user-visible
- [ ] `fetch()` helper used for any remote file download (not raw `curl`)
- [ ] `sudo tee` pattern used for any file written with elevated perms

## Before Changing printer.cfg Logic

- [ ] Idempotency verified — safe to re-run multiple times
- [ ] `sed -i` edits are reversible by the matching `uninstall_*`
- [ ] `[include ...]` additions are removed by `uninstall_*`
- [ ] `revert_to_backup()` restores printer.cfg from snapshot (not just strips includes)

## Before a New Release (RC bump)

- [ ] `AIO_VERSION='RCx'` updated in `aio_menu.sh`
- [ ] Banner renders new version: `Qidi Q2 Superuser - AIO Setup Menu (RCx)`
- [ ] About screen renders new version
- [ ] All RC candidate features listed in CLAUDE.md RC section are done or explicitly deferred
- [ ] PR description has a complete test plan
- [ ] PR #N reviewed, un-drafted, and merged to `main`
- [ ] Git tag `vRCx` created on the merge commit

## Before Merging to main

- [ ] All shell scripts pass `bash -n`
- [ ] All JSON files pass `python3 -m json.tool`
- [ ] PR is not draft
- [ ] No unresolved merge conflicts
- [ ] Test plan in PR description reviewed
