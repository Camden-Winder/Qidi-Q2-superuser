# FAQ – Bunny Box & HelixScreen on the Qidi Q2

---

### How do I toggle adaptive bed leveling on/off?

The AIO macro files use Qidi's `G29`/`G31`/`G32` wrappers:

- `G31` — enables adaptive bed leveling (default state after install). Every `PRINT_START` will call `G29`, which runs a KAMP adaptive mesh over the print area.
- `G32` — disables adaptive bed leveling. `PRINT_START` will load an existing `default` mesh profile instead of running a new mesh. Useful for fast test prints or debugging.

To re-enable after disabling: run `G31` once from the console, then `FIRMWARE_RESTART` is not needed — the setting takes effect immediately for the next print.

---

### Which profile does KAMP save the bed mesh to?

KAMP saves the adaptive mesh to the `kamp` profile (not `default`). This means your manually-saved `default` mesh is not overwritten by print-start meshing. To load a previously saved KAMP mesh without re-probing, run:

```
BED_MESH_PROFILE LOAD=kamp
```

The `kamp` profile is regenerated every print, so there is no benefit to loading it manually — this is mainly useful for debugging mesh data after a print.

---

### After installing, the console shows a calibration warning and Bunny Box won't work

You'll see something like:

```
!! Warning: Calibration steps are not complete:
Required:
 - Use MMU_CALIBRATE_GEAR (with gate 0 selected) to calibrate gear rotation_distance on gate: 0
```

This means Happy Hare needs to measure the gear rotation distance before it can move filament. Run this in the console:

```sh
MMU_CALIBRATE_GEAR MEASURED=100
```

`MEASURED=100` tells it you manually fed 100mm of filament. Happy Hare records the actual distance moved and calculates the correct rotation distance. You only need to do this once per gate — repeat for any additional gates if prompted.

---

### What is Bunny Box?

Bunny Box is a community firmware replacement for the Qidi Box (the multi-material unit that comes with the Q2). It's built on top of Happy Hare, which is the same MMU management layer used by projects like ERCF and Box Turtle.

Compared to Qidi's stock box firmware, Bunny Box gives you:

- Faster and more reliable filament loading and unloading
- Better error recovery when jams or runout events happen
- Full control over every parameter of the MMU system
- Compatibility with HelixScreen's UI widgets (lane status, spool display, etc.)

Bunny Box requires HelixScreen. The stock Qidi touchscreen UI does not support it.

[Bunny Box Documentation](https://github.com/Wazzup77/Bunny-Box)

---

### What is HelixScreen?

HelixScreen is a replacement UI for the Qidi Q2's touchscreen, built specifically for the Q2's hardware.

Compared to the stock Qidi screen software, HelixScreen gives you:

- A cleaner, more customizable home screen layout
- Native support for Bunny Box lane and spool status
- Faster access to common actions (nozzle clean, bed level, etc.)
- Regular updates from an active development team

[HelixScreen Documentation](https://github.com/prestonbrown/helixscreen)

---

### Day-to-day usage

Once Bunny Box and HelixScreen are installed, normal printing works the same way — slice in Orca, send to the printer, and hit start. The differences show up in how the box system behaves:

- **Loading filament:** Use the lane buttons in HelixScreen or run `LOAD_FILAMENT` from the console. Bunny Box manages the handoff between the MMU gears and the extruder automatically.
- **Unloading:** Use `UNLOAD_FILAMENT` or the HelixScreen UI. Bunny Box retracts the filament back to the gate cleanly.
- **Color changes mid-print:** Handled automatically by the slicer-generated tool change commands. Bunny Box manages the sequence.
- **If something jams:** HelixScreen will surface the error. Most jam recovery is handled through the on-screen prompts — you don't need to manually run G-code for typical recovery steps.
- **Checking lane status:** The home screen widget shows which lane is loaded and the spool color/material if you have Spoolman set up.

---

### How do I use the bypass gate for TPU or other direct-drive filaments?

The bypass gate lets you feed filament directly into the extruder, skipping the MMU gears entirely. This is useful for flexible filaments like TPU that don't feed well through the MMU.

To use it:

1. Select the bypass gate in the Bunny Box / Happy Hare UI
2. Once bypass is selected, the UI will show **Load EXT** — use this to load filament directly into the extruder
3. To remove it, use **Unload EXT**

**Recommended: Top Spool Holder for Flexibles**

When printing TPU or other flexibles via bypass, routing the filament from the top of the printer reduces the tight bends that cause jams. This printable top spool holder is designed specifically for the Q2 and fits risers too:

[Q2 Flexibles Top Spool Holder – The Mi3 Channel](https://odysee.com/@The_Mi3_Channel:f/Q2-Flexibles-Top-Spool-Holder:a)

**Notes:**
- If you have an encoder, clog detection still works in bypass mode
- Compression/tension sensors are disabled in bypass since the gear stepper isn't involved
- After using bypass, manually select a managed gate before your next MMU print — the UI may not deselect bypass automatically between jobs
