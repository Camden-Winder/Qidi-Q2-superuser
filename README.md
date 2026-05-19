# Qidi Q2 Superuser Guide

Welcome — this repo is everything I use to turn a stock Qidi Q2 into a faster, cleaner, and more capable printer.

Join the Discord: https://discord.gg/aZGUk69Mp

---

# What’s in this guide

This repo covers:

- Beginner‑friendly first‑time setup  
- Remote and mobile access options  
- Filament tracking with Spoolman  
- Faster, cleaner printer macros  
- One‑line install and uninstall tools  
- **Bunny Box** – improved multi-material firmware for the Qidi Box  
- **HelixScreen** – touchscreen UI replacement with Bunny Box support  
- Recommended printables for the Q2  

Everything here is optional — take what you want, skip what you don’t.

---

# Chapter 0 – True Beginners

If this is your first 3D printer (or your first Klipper printer), start here.  
This section walks you through slicer setup, basic usage, and the “what do I do first?” questions.

[Beginner Setup](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Beginers/First%20Setup.md)

---

# Chapter 1 – Plugins

## Remote Access

I used to recommend OctoEverywhere, but recent reliability issues and aggressive paywalling make it hard to suggest now.

I’m moving toward Tailscale‑based remote access. Once I’ve fully tested it on the Q2, I’ll publish a full guide.

Alternatives worth considering: **Obico**

[Remote Access Tutorial](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Plugins/Remote%20Access/Remote%20Access%20Tutorial.md)

---

## Mobile Access

I use **OctoApp**, which works well on both iOS and Android.

Alternative: **Mobilraker**

[Mobile Access Tutorial](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Plugins/Mobile%20Access/Mobile%20Access%20Tutorial.md)

---

# Chapter 2 – Filament Tracking

I use **Spoolman** for filament tracking.  
This becomes especially useful once Bunny Box is installed on the Qidi Box.

[Spoolman Tutorial](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Plugins/Spoolman/Spoolman%20Tutorial.md)

---

# Chapter 3 – Printer Configs

The Q2 ships with a very heavy PRINT_START macro and a lot of vendor‑specific glue code.  
This repo documents what those macros do and provides faster, cleaner replacements.

All macro adjustments are now handled by my one‑line install tool:

[Install Script Instructions](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Install-Script/Instructions.md)

Additional config resources:

- [My Resources](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/My%20Resources.md)  
- [Filament Configurations](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Configurations/Filamet%20Configurations.md)

---

# Chapter 4 – Printables

Once your Q2 is running smoothly, here are prints that actually improve the machine.

[Printables](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Printables/Prints.md)

---

# You’re Done

Congratulations — you’ve reached the end of the guide.

If you have ideas, corrections, or additional tips for the Q2, feel free to open an issue or PR.  
I’m always improving this setup and appreciate good suggestions.

[Thanks](https://github.com/Camden-Winder/Qidi-Q2-superuser/blob/main/Thanks.md)
