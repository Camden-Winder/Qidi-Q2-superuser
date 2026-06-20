# Q2 FAQ

---

## What does Health Check (option 8) actually check?

The Health Check runs a suite of verifiers across your Klipper config:

- Orphan includes — `[include X]` lines whose target file doesn't exist
- Duplicate macro definitions — e.g. two `BED_MESH_CALIBRATE` definitions
- Invalid Klipper options — keys that don't belong in a section (e.g. `timeout:` inside `[bed_mesh]`)
- Leftover MMU artifacts — Happy Hare v3 `extras/mmu/` package or `mmu_*.py` symlinks that survive after a revert
- Display service state — checks that the correct screen service is running after a revert

It reports problems and offers to fix the most common ones automatically.

---

## Where are my backups stored?

The AIO creates timestamped backups in `~/mudstockbackups/` on the printer before every install and revert. The very first backup is labeled `_FIRST_STOCK` — this is what **Revert to Backup** restores from.

```bash
ls ~/mudstockbackups/
```

---

## Can I run the AIO more than once?

Yes. Most install paths are idempotent — running them again on an already-installed printer is safe and will re-apply any changes. The installer detects current state and adjusts accordingly.

---

## `Cannot reach raw.githubusercontent.com`

This is a network or DNS issue from the printer, not a problem with the installer. The AIO requires outbound HTTPS to GitHub to download files.

Things to check:

- Make sure the printer has internet access (not just local network)
- Check your router's DNS settings
- Max 4 users: apply the DNS Fix from System Optimizations, which removes the hardcoded Chinese DNS resolver

---

## No stock backup exists — what do I do?

`~/mudstockbackups/` is created automatically on the first AIO run. The `_FIRST_STOCK` snapshot is only as clean as your config was at that moment.

If your configs were already changed before the first AIO run, the backup will contain those changes. To get a truly clean baseline, restore from a Qidi factory image first, then run the AIO to capture the clean stock config.

---

## `QDE_004_007: Extruder not loaded` at end of print

This happens when you have a Qidi Box attached but chose **Just Faster Printer** (option 2) instead of **Just Faster Box** (option 3).

Just Faster Printer's `PRINT_END` doesn't call `UNLOAD_FILAMENT`, so the box system throws an error at the end of the print.

To fix it: run the AIO and choose **option 3 — Just Faster Box**. See issue [#33](https://github.com/Camden-Winder/Qidi-Q2-superuser/issues/33).
