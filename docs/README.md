# Qidi Superuser — All-in-One Installers

> **Disclaimer:** Use these tools at your own risk. The author is not responsible for any damage, malfunction, or data loss caused to your printer. Qidi states that any modifications to files on their printers may void the manufacturer warranty.

A single ANSI-coloured bash menu per printer that handles every supported install, uninstall, and addon path — no need to track which script does what.

Each installer backs up your config automatically before making any changes and provides a **Revert to Backup** option that restores your printer to the state it was in before the first AIO run.

---

## Supported Printers

| Printer | Installer | Instructions |
|---|---|---|
| **Qidi Q2** | [`Q2/aio_menu.sh`](../Q2/aio_menu.sh) | [wiki/Q2-Install-Guide.md](../wiki/Q2-Install-Guide.md) |

See the install guide for SSH credentials, curl commands, menu options, and troubleshooting.

---

## Changelog

### Qidi Q2

| Version | Notable additions |
|---------|------------------|
| RC3.00 | Collapsed the 01.01.02+ firmware submenu into the top-level Install menu; added an optional process-optimization step (disables unused background services, plus a touchscreen spinner-animation fix on 01.01.02+ firmware) to every install path, reversible via Revert to Backup — current release |
| RC2.35 | See git history for this release's changes — not backfilled in this changelog (RC2.36–RC2.99 are also not yet backfilled) |
| RC2.9 | Hardened Revert to Backup stock display restoration: resets failed lightdm/makerbase state, restores `graphical.target`, unmasks `display-manager.service`, prints recent service logs if the stock display stack does not come back |
| RC1.22 | Added filament drying macro buttons to HelixScreen settings |
| RC1.14 | Adopted `RC<major>.<minor>` version format; fixed duplicate webcam entries in Mainsail |
| RC13 | Fixed camera stream in Mainsail (nginx `/webcam/` proxy + correct ustreamer paths) |
| RC11 | Fixed two post-install Klipper errors: `gcode: not valid in section 'bed_mesh'` and `BED_MESH_CALIBRATE already registered`; install now aborts correctly if a required step fails |
| RC10 | Fixed fresh-install black screen — HelixScreen now activates correctly after option 1 |
| RC9 | Automatic spool rotation during filament drying cycles |
| RC8 | Health check runs automatically after every Revert to Backup; new config validators (orphan includes, invalid settings, leftover MMU files) |
| RC7 | Mainsail web UI as a menu addon |
| RC6 | Fixed `BED_MESH_CALIBRATE` duplicate crash from older BunnyBox installs |
| RC5 | Fixed Klipper startup crash caused by conflicting Box hardware drivers |
| RC4 | Simplified uninstall — Revert to Backup is now the single restore path |
| RC1–3 | Initial AIO release; HelixScreen + BunnyBox install/uninstall; idle fan shutdown addon |
