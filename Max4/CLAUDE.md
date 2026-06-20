# Max4/CLAUDE.md

Scope: Max 4 hardware files — installer, macros, and documentation.

## Installer

`Max4/aio_menu_max4.sh` — Max 4 AIO installer. All Max 4 logic lives here.
**Never modify `Q2/aio_menu.sh` when working on Max 4 tasks.**

Quick-start test commands (run before every commit that touches aio_menu_max4.sh):

```bash
bash -n Max4/aio_menu_max4.sh                       # syntax check
shellcheck -S warning Max4/aio_menu_max4.sh         # style (advisory)
```

## Key Paths on the Printer (Max 4)

| Purpose | Path |
|---------|------|
| Klipper config root | `/home/qidi/printer_data/config/` |
| AIO backup snapshots | `/home/qidi/mudstockbackups/` |
| Touchscreen UI assets | `/home/qidi/QIDI_Client/` |
| Stock Qidi macro directory | `config/klipper-macros-qd/` |

## Scope Limits

- Supported firmware: `01.01.06.03`, `01.01.06.04`
- No Happy Hare, no HelixScreen — stock UI only
- Install paths: Just Faster Printer and Just Faster Box only (no BunnyBox/HelixScreen path)
