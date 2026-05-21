# CLAUDE.md — Qidi Q2 Superuser AIO

Project context for Claude Code sessions. Read this first every time.

## Project Guidlines

This project has two main guidlines
1. Ensure a hands off user experience when running an install script. This means they should not be prompted any questions when running a script, and if they must, the need a recommend option.

2. All other branches should remain with verbose error logs and feedback when running any commands to ensure troubleshooting is easy.


## Target Environment

- Hardware: Qidi Q2 Pro 3D printer
- OS: ARM Linux, user `mks`
- Stack: Klipper + Moonraker + Happy Hare (MMU) + HelixScreen (LVGL UI) + Qidi Box (4-slot AMS)
- Key paths on the printer:
  - `/home/mks/printer_data/config/` — Klipper config root
  - `/home/mks/mudstockbackups/` — AIO backup snapshots
  - `/home/mks/helixscreen/` — HelixScreen install dir
  - `/home/mks/Happy-Hare/` — Happy Hare MMU firmware

## Critical Rules

1. **Never modify** `Configurations/` or `Plugins/` — read-only stock Qidi mirrors.
2. **Never push to `main` directly** — all work goes on a `claude/*` branch; merge via PR.
3. **Bump `AIO_VERSION`** whenever `aio_menu.sh` changes (currently `RC6`).
4. **`bash -n` before every commit** touching any `.sh` file.
5. **`python3 -m json.tool` before every commit** touching any `.json` file.
6. **Do not run `aio_menu.sh` as root** — the script self-enforces this.
7. **`sudo tee` pattern for writing files with elevated perms**, never `echo > file` with sudo.
8. **Use `banner`, `info`, `warn`, `ok`, `err` helpers** — never raw `echo` in installer logic.

## Autonomous-Session Policy

Claude may do the following **without asking first**:

- Commit and push to any `claude/*` branch
- Create a draft PR after pushing a new branch
- Run `bash -n`, `python3 -m json.tool`, `shellcheck` (lint/syntax checks)
- Merge a PR to `main` when the handoff context explicitly says to do so

Claude **must ask first** before:

- Pushing to `main` directly
- Force-pushing any branch
- Deleting branches or files not created in the same session
- Taking actions visible to users outside this repo (posting comments, etc.)


## External Resources

- HelixScreen: `prestonbrown/helixscreen` on GitHub
- Happy Hare: `moggieuk/Happy-Hare`
- BunnyBox installer: `Camden-Winder/Bunny-Box` → `Q2/install-bb-q2.sh`
- Qidi Box: `wiki.qidi3d.com`
