# FAQ – Qidi Q2 Superuser

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
