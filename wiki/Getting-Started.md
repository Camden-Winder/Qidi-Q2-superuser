# Getting Started — Qidi Q2

This page is for someone who just unboxed a Qidi Q2 and wants a clean, reliable first setup without diving into every detail of Klipper.

By the end of this, you'll have:

- Unboxed and prepared your printer
- Installed Orca Slicer
- Connected Orca to your Q2
- Tuned your filament settings
- Printed your first upgrades

If you already have experience, you can skim this. If you're brand new, follow it step-by-step.

---

## What is the AIO changing?

The Q2 already runs Klipper and Moonraker — the same open-source 3D printer firmware used across hundreds of printer models. What the AIO replaces is the vendor macro configuration and, optionally, the Makerbase touchscreen UI. Klipper itself is not replaced or modified.

---

## What is SSH and do I need it?

SSH is a way to run commands on your printer from your computer, over your local network. You need it to run the AIO installer. See the [SSH Guide](SSH-Guide.md) for step-by-step instructions.

---

## Hardware checklist

Before running the installer, make sure:

- [ ] Printer is unboxed
- [ ] Every zip tie is cut — including the one on top of the Z screws
- [ ] If you have a Qidi Box, hold off on installing the PTFE tubes until you're ready to set up the box
- [ ] Printer is powered on and connected to your network

---

## 1. Unbox the printer

Qidi's official unboxing videos are clear and accurate. Use them as your reference.

- [Printer Unboxing](https://youtu.be/uJN3zx54gSY?si=NtEK8UqE_umBzVKw)
- [Setting up Qidi Box](https://youtu.be/lL_5cXKLCfY?si=tI121EERZS4Fo5q)

---

## 2. Download a slicer

Orca Slicer is the recommended slicer for the Q2.

[Download Orca Slicer](https://github.com/OrcaSlicer/OrcaSlicer/releases/tag/v2.3.2)

Scroll to the bottom of the release page to find the installer for your operating system.

---

## 3. Find your printer's IP address

On the printer touchscreen:

1. Go to **Settings → Network**
2. Note the IP address shown (e.g. `192.168.1.42`)
3. While you're here, enable **LAN Only** mode

The IP address is what you'll use to SSH into the printer and to connect Orca Slicer.

---

## 4. Slicer setup

When Orca Slicer prompts you for a printer IP address during setup, enter the IP you found above. This lets you send prints to your Q2 over the network.

---

## 5. Tune filament settings

If you're not using Qidi's own filament — and even if you are — tuning your filament profiles can greatly increase print quality and reduce print time.

[Filament Calibration Masterclass](https://youtu.be/gVU5If1VsAM)

---

## 6. Printable upgrades

These prints improve the Q2's usability and are a good first print once everything is running.

[Printable Upgrades](Printables.md)

---

## What's next?

- Ready to install the AIO on your Q2 → [Q2 Install Guide](Q2-Install-Guide.md)
- Need help with SSH first → [SSH Guide](SSH-Guide.md)
