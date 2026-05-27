# Session Handoff — Qidi Q2 Superuser AIO

## Project

**Repo:** `Camden-Winder/Qidi-Q2-superuser`
**Dev branch:** `claude/hopeful-lovelace-6cJ0Q`

The project is an all-in-one Bash installer menu for the **Qidi Q2 Pro 3D printer** running Klipper. It installs and manages:
- **BunnyBox (Happy Hare)** — MMU filament switcher firmware
- **HelixScreen** — LVGL touchscreen UI (by Preston Brown, `prestonbrown/helixscreen`)
- **Qidi Box** — 4-slot filament dry-box/AMS peripheral (RFID, slot steppers)
- **Idle Fan Shutdown** — optional addon, turns off fans/heaters after 10 min idle

---

## Current State (end of last session)

### RC1 is complete and pushed

Four RC1 commits on the dev branch (on top of ~14 earlier commits):

| Commit | What it does |
|--------|-------------|
| `8bbdd3c` | `AIO_VERSION='RC1'` constant; rendered in banner `(RC1)` and About screen |
| `b3b9954` | `verify_qidi_box_helixscreen()` — post-install check for `box.cfg`, `[box_stepper]`, `officiall_filas_list.cfg`, HelixScreen >= v0.99.66; warns, never fails |
| `5ff5eb9` | `install_qidi_box_write()` — writes `/etc/systemd/system/helixscreen.service.d/qidi-box-write.conf` with `HELIX_QIDI_BOX_WRITE=1`; enabled by default in BB+HS install; `uninstall_qidi_box_write()` wired into `uninstall_helixscreen` and `revert_to_backup`; `BoxWrite: on/off` added to menu header status line |
| `d3bcb39` | `helixscreen_settings.json`: root key `"ams": { "spool_style": "3d" }` |

### PR #1 — draft, no CI, no review comments yet

No GitHub Actions are configured on the repo. PR is waiting for manual review and merge decision.

---

## Established Conventions (follow these)

- **Commit messages:** one-line subjects only, no body
- **Shell changes:** always `bash -n aio_menu.sh` before committing
- **JSON changes:** always `python3 -m json.tool <file>` before committing
- **New `install_*` function:** must have matching `uninstall_*`, a `*_installed()` / `*_enabled()` detection helper, be wired into `revert_to_backup`, and add a status indicator to `show_status_line()`
- **Helpers:** use `banner`, `info`, `warn`, `ok`, `err` — never raw `echo`
- **Write files:** use `sudo tee` pattern, never `echo >` with sudo
- **Never touch:** `Configurations/` and `Plugins/` are stock Qidi reference files — read-only mirrors
- **Dev branch:** all work goes to `claude/qidi-q2-aio-menu-lwyb6`, never push to `main` directly

---

## Next Priorities (in suggested order)

### 1. Merge PR #1 into `main` (your call — review the diff first)

### 2. Create `.claude/` tooling for the repo (researched last session from Preston Brown's helixscreen repo)

High-value items to port/create:

**a) `CLAUDE.md` at repo root** ← biggest payoff, makes every new session start with full context
- Sections: Quick Start (test commands), Repo layout, Critical rules, Install-function conventions, Autonomous-session policy (what Claude can do without asking)
- Ask Claude to draft it and confirm the autonomous-session policy before committing

```

**c) `.claude/hooks/pre-commit-check.sh`** — auto-lint on every commit:
- All `*.sh` → `bash -n`
- All `*.json` → `python3 -m json.tool`
- Warn if `aio_menu.sh` changed but `AIO_VERSION` didn't bump
- Warn if new `install_*` added without matching `uninstall_*`

**d) `.claude/checklist.md`** — pre-flight checklists (before committing, before new install function, before changing printer.cfg)

### 3. RC2 planning

Candidate features discussed but not yet scoped:
- `/release` slash command to automate version bumps + changelog + tag + push
- `update_qidi_box_dropin` migration logic for future drop-in changes
- Confirm-on-first-run gate for `HELIX_QIDI_BOX_WRITE` (y/N with 5s default-yes timeout for headless)
- HelixScreen version pinning to a tagged release instead of `main`
- "9) Run all verifiers" self-test menu item

---

## Key Files

| Path | Purpose |
|------|---------|
| `All_in_One_Installer/aio_menu.sh` | Main installer script |
| `Install-Script/helixscreen_settings.json` | Shipped to `/home/mks/.config/helixscreen/settings.json` |
| `Install-Script/BunnyBox&HelixScreen.sh` | Legacy single-shot installer (superseded by AIO) |
| `Configurations/` | Stock Klipper cfg reference — do not modify |
| `Plugins/` | Stock plugin reference — do not modify |

---

