# Troubleshooting

---

## Klipper won't start after install

Run:

```bash
journalctl -u klipper -n 50 --no-pager
```

Look for `Option '...' is not valid in section '...'` or `Unable to open config file` errors. Then run **option 8 — Health Check** from the AIO menu; it detects and offers to fix the most common causes, including orphan includes, duplicate macro definitions, and invalid Klipper options.

---

## Stock screen doesn't come back after Revert to Backup

Run:

```bash
journalctl -u makerbase-client -n 50 --no-pager
journalctl -u lightdm -n 50 --no-pager
```

The Health Check runs automatically at the end of every revert and prints recent display service logs if the stock UI doesn't come back. Re-running option 8 from the AIO menu will re-check and attempt to fix the display service state.

---

## `Cannot reach raw.githubusercontent.com`

This is a network or DNS issue from the printer — not a problem with the installer. The AIO requires outbound HTTPS to GitHub.

- Make sure the printer has internet access, not just local network
- Check your router's DNS settings
- Max 4 users: apply the DNS Fix from System Optimizations (option 3 in the Max 4 AIO) — this removes the hardcoded Chinese DNS resolver that ships on the Max 4

---

## `QDE_004_007: Extruder not loaded` at end of print

You have a Qidi Box attached but chose **Just Faster Printer** (option 2) instead of **Just Faster Box** (option 3). JFP's `PRINT_END` doesn't call `UNLOAD_FILAMENT`, so the box system throws this error.

Fix: run the AIO and choose **option 3 — Just Faster Box**. See [issue #33](https://github.com/Camden-Winder/Qidi-Q2-superuser/issues/33).

---

## MMU calibration warning on first print

You'll see something like:

```
!! Warning: Calibration steps are not complete:
Required:
 - Use MMU_CALIBRATE_GEAR (with gate 0 selected) to calibrate gear rotation_distance on gate: 0
```

This is normal after a fresh BunnyBox install. Happy Hare needs to measure the gear rotation distance before it can move filament. See the [Q2 Install Guide — Section 4](Q2-Install-Guide.md#section-4--after-install) for the full calibration steps.

---

## `Host key verification failed` on SSH

This happens when the printer was reflashed and its SSH key changed. Run:

```sh
ssh-keygen -R <printer-ip>
```

Then reconnect.

---

## No stock backup exists (`~/mudstockbackups/` empty or missing)

The backup is taken on the first AIO run. If your configs were already changed before the first run, the backup will include those changes — or the directory may not exist yet.

To get a clean baseline: restore from a Qidi factory image first, then run the AIO to capture a clean stock snapshot.

---

## HelixScreen shows black screen after install

Re-run the installer. The installer detects the display service state and fixes it. If `panel_widgets` is missing from the HelixScreen settings, run **Testing → option 10** from the AIO menu (if available on your version).

---

## `saved_variables.cfg` missing (Max 4)

Create it manually. SSH into the printer and run:

```bash
cat > /home/qidi/printer_data/config/saved_variables.cfg << 'EOF'
[Variables]
box_count = 4
enable_box = 0
z_offset = 0.0
EOF
```

Or see the full template in [Max 4 FAQ](Max4-FAQ.md#saved_variablescfg-missing).

---

## `box_count` not readable (Max 4)

Same cause as `saved_variables.cfg` missing — see above.

---

## I accidentally broke my config

Run the AIO and choose **Revert to Backup**. The `_FIRST_STOCK` snapshot contains your original factory config and is always preserved, even if you run the installer multiple times.
