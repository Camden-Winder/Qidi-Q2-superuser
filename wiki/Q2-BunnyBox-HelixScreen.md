# Q2 BunnyBox & HelixScreen

---

## What is BunnyBox?

BunnyBox is a community firmware replacement for the Qidi Box (the multi-material unit that comes with the Q2). It's built on top of Happy Hare, which is the same MMU management layer used by projects like ERCF and Box Turtle.

Compared to Qidi's stock box firmware, BunnyBox gives you:

- Faster and more reliable filament loading and unloading
- Better error recovery when jams or runout events happen
- Full control over every parameter of the MMU system
- Compatibility with HelixScreen's UI widgets (lane status, spool display, etc.)

BunnyBox requires HelixScreen. The stock Qidi touchscreen UI does not support it.

[BunnyBox Documentation](https://github.com/Wazzup77/Bunny-Box)

---

## What is HelixScreen?

HelixScreen is a replacement UI for the Qidi Q2's touchscreen, built specifically for the Q2's hardware.

Compared to the stock Qidi screen software, HelixScreen gives you:

- A cleaner, more customizable home screen layout
- Native support for BunnyBox lane and spool status
- Faster access to common actions (nozzle clean, bed level, etc.)
- Regular updates from an active development team

[HelixScreen Documentation](https://github.com/prestonbrown/helixscreen)

---

## Day-to-day usage

Once BunnyBox and HelixScreen are installed, normal printing works the same way — slice in Orca, send to the printer, and hit start. The differences show up in how the box system behaves.

### Loading filament

1. From the HelixScreen home screen, select the lane you want to load
2. Tap **Load** (or run `LOAD_FILAMENT` from the console)
3. BunnyBox manages the handoff between the MMU gears and the extruder automatically
4. The lane status widget updates once filament is confirmed loaded

### Unloading filament

1. Select the loaded lane in HelixScreen
2. Tap **Unload** (or run `UNLOAD_FILAMENT` from the console)
3. BunnyBox retracts the filament back to the gate cleanly

### Tool changes mid-print

Tool changes are handled automatically from slicer-generated tool change commands. BunnyBox manages the entire sequence — unloading the current filament, loading the next, purging, and resuming the print. You don't need to do anything.

### Jam recovery

When a jam or runout is detected, HelixScreen surfaces the error on screen. Most recovery steps are available directly through the on-screen prompts — you typically don't need to manually run G-code for standard recovery. Follow the prompts on screen.

### Checking lane status

The home screen widget shows which lane is loaded and displays spool color and material if you have Spoolman set up. See [Spoolman](Plugins-Spoolman.md) for filament tracking setup.

---

## Bypass gate for TPU or direct-drive filaments

The bypass gate lets you feed filament directly into the extruder, skipping the MMU gears entirely. This is useful for flexible filaments like TPU that don't feed well through the MMU.

To use it:

1. Select the bypass gate in the BunnyBox / Happy Hare UI
2. Once bypass is selected, the UI will show **Load EXT** — use this to load filament directly into the extruder
3. To remove it, use **Unload EXT**

**Recommended: Top Spool Holder for Flexibles**

When printing TPU or other flexibles via bypass, routing the filament from the top of the printer reduces tight bends that cause jams. This printable top spool holder is designed specifically for the Q2 and works with risers too:

[Q2 Flexibles Top Spool Holder – The Mi3 Channel](https://odysee.com/@The_Mi3_Channel:f/Q2-Flexibles-Top-Spool-Holder:a)

Notes:
- If you have an encoder, clog detection still works in bypass mode
- Compression/tension sensors are disabled in bypass since the gear stepper isn't involved
- After using bypass, manually select a managed gate before your next MMU print — the UI may not deselect bypass automatically between jobs

---

## Adaptive bed leveling

The AIO macro files use Qidi's `G29`/`G31`/`G32` wrappers:

- `G31` — enables adaptive bed leveling (default state after install). Every `PRINT_START` will call `G29`, which runs a KAMP adaptive mesh over the print area.
- `G32` — disables adaptive bed leveling. `PRINT_START` will load an existing `default` mesh profile instead of running a new mesh. Useful for fast test prints or debugging.

To re-enable after disabling: run `G31` once from the console. The setting takes effect immediately for the next print — no restart needed.

KAMP saves the adaptive mesh to the `kamp` profile (not `default`). Your manually-saved `default` mesh is not overwritten by print-start meshing.
